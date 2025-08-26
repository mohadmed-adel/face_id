import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:face_recognition_auth/src/face_auth.dart';
import 'package:face_recognition_auth/widgets/camera_header.dart';
import 'package:face_recognition_auth/widgets/face_painter.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceRegisterWidget extends StatefulWidget {
  const FaceRegisterWidget({super.key, required this.faceAuth});
  final FaceAuth faceAuth;

  @override
  State<FaceRegisterWidget> createState() => _FaceRegisterWidgetState();
}

class _FaceRegisterWidgetState extends State<FaceRegisterWidget> {
  Size? imageSize;
  Face? faceDetected;
  bool _initializing = false;
  bool _detectingFaces = false;
  bool _saving = false;
  bool _bottomSheetVisible = false;
  int _autoCaptured = 0;
  final List<List> _enrollmentSamples = [];
  // Track pose-targeted captures: FRONT, LEFT, RIGHT, UP_OR_DOWN
  final Set<String> _capturedPoses = <String>{};
  static const int _requiredSamples = 4;
  _start() async {
    setState(() => _initializing = true);
    try {
      _frameFaces();
    } catch (e) {
      try {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Text('Camera failed to start. Please try again.'),
          ),
        );
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  // Determine pose bucket using head Euler angles
  String? _currentPose(Face? fd) {
    if (fd == null) return null;
    final double? yaw = fd.headEulerAngleY; // left/right
    final double? pitch = fd.headEulerAngleX; // up/down
    const double yawThresh = 15.0; // degrees
    const double pitchThresh = 10.0; // degrees

    if (yaw != null && yaw < -yawThresh) return 'LEFT';
    if (yaw != null && yaw > yawThresh) return 'RIGHT';
    if (pitch != null && (pitch < -pitchThresh || pitch > pitchThresh)) {
      return 'UP_OR_DOWN';
    }
    return 'FRONT';
  }

  _frameFaces() {
    imageSize = widget.faceAuth.cameraService.getImageSize();
    log("imageSize $imageSize");
    if (widget.faceAuth.cameraService.isStreamingImages) return;
    widget.faceAuth.cameraService.cameraController?.startImageStream((
      image,
    ) async {
      if (widget.faceAuth.cameraService.cameraController != null) {
        if (_detectingFaces) return;

        _detectingFaces = true;

        try {
          // Use actual CameraImage dimensions for painter scaling once
          imageSize ??= Size(image.width.toDouble(), image.height.toDouble());
          await widget.faceAuth.faceDetectorService.detectFacesFromImage(image);

          if (widget.faceAuth.faceDetectorService.faces.isNotEmpty) {
            setState(() {
              faceDetected = widget.faceAuth.faceDetectorService.faces[0];
            });
            // Auto-capture embeddings based on head pose until 4 targeted samples collected
            if (!_bottomSheetVisible && _autoCaptured < _requiredSamples) {
              final String? pose = _currentPose(faceDetected);
              if (pose != null && !_capturedPoses.contains(pose) && !_saving) {
                widget.faceAuth.mlService.setCurrentPrediction(
                  image,
                  faceDetected,
                );
                // Throttle to avoid duplicate captures
                _saving = true;
                Future.delayed(Duration(milliseconds: 450)).then((_) async {
                  if (!mounted) return;
                  setState(() {
                    final List emb = List.from(
                      widget.faceAuth.mlService.predictedData,
                    );
                    if (emb.isNotEmpty) {
                      _enrollmentSamples.add(emb);
                      _capturedPoses.add(pose);
                      _autoCaptured = _enrollmentSamples.length;
                    }
                    _saving = false;
                  });
                  if (_autoCaptured >= _requiredSamples &&
                      !_bottomSheetVisible) {
                    // Before opening sheet, ensure this face is not already registered
                    try {
                      final centroid = widget.faceAuth.mlService
                          .centroidFromSamples(
                            _enrollmentSamples
                                .map((e) => e.cast<num>())
                                .toList(),
                          );
                      final existing = await widget.faceAuth.mlService
                          .predictFromEmbedding(centroid);
                      if (!mounted) return;
                      if (existing != null) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Text(
                              'This face is already registered as ${existing.user}.',
                            ),
                          ),
                        );
                        _reload();
                        return;
                      }
                    } catch (_) {}
                    // _openSignUpSheet();
                  }
                });
              }
            }
          } else {
            log('face is null');
            setState(() {
              faceDetected = null;
            });
          }

          _detectingFaces = false;
        } catch (e) {
          log('Error _faceDetectorService face => $e');
          _detectingFaces = false;
        }
      }
    });
  }

  _reload() {
    setState(() {
      _bottomSheetVisible = false;

      _autoCaptured = 0;
      _enrollmentSamples.clear();
      _capturedPoses.clear();
    });
    _start();
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (_initializing && _bottomSheetVisible) {
      return CircularProgressIndicator.adaptive();
    }
    return Stack(
      children: [
        Transform.scale(
          scale: 1.0,
          child: AspectRatio(
            aspectRatio: MediaQuery.of(context).size.aspectRatio,
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.fitHeight,
                child: SizedBox(
                  width: width,
                  height:
                      width *
                      widget
                          .faceAuth
                          .cameraService
                          .cameraController!
                          .value
                          .aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CameraPreview(
                        widget.faceAuth.cameraService.cameraController!,
                      ),
                      if (imageSize != null)
                        CustomPaint(
                          painter: FacePainter(
                            face: faceDetected,
                            imageSize: imageSize!,
                          ),
                        ),
                      // Guidance overlay
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Captured: $_autoCaptured / $_requiredSamples',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                if (!_bottomSheetVisible &&
                                    _autoCaptured < _requiredSamples)
                                  Text(
                                    (() {
                                      final String? next = _nextPoseTarget();
                                      return next == null
                                          ? 'Hold still'
                                          : _poseLabel(next);
                                    })(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        CameraHeader("SIGN UP", onBackPressed: () {}),
      ],
    );
  }

  static const List<String> _poseOrder = <String>[
    'FRONT',
    'LEFT',
    'RIGHT',
    'UP_OR_DOWN',
  ];
  String? _nextPoseTarget() {
    for (final String p in _poseOrder) {
      if (!_capturedPoses.contains(p)) return p;
    }
    return null;
  }

  String _poseLabel(String pose) {
    switch (pose) {
      case 'FRONT':
        return 'Look straight ahead';
      case 'LEFT':
        return 'Turn your head left';
      case 'RIGHT':
        return 'Turn your head right';
      case 'UP_OR_DOWN':
        return 'Tilt your head slightly up/down';
      default:
        return 'Hold still';
    }
  }
}
