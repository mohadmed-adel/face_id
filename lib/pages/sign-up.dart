import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_net_authentication/locator.dart';
import 'package:face_net_authentication/pages/db/databse_helper.dart';
import 'package:face_net_authentication/pages/models/user.model.dart';
import 'package:face_net_authentication/pages/widgets/FacePainter.dart';
import 'package:face_net_authentication/pages/widgets/app_button.dart';
import 'package:face_net_authentication/pages/widgets/app_text_field.dart';
import 'package:face_net_authentication/pages/widgets/camera_header.dart';
import 'package:face_net_authentication/services/camera.service.dart';
import 'package:face_net_authentication/services/face_detector_service.dart';
import 'package:face_net_authentication/services/ml_service.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class SignUp extends StatefulWidget {
  const SignUp({Key? key}) : super(key: key);

  @override
  SignUpState createState() => SignUpState();
}

class SignUpState extends State<SignUp> {
  String? imagePath;
  Face? faceDetected;
  Size? imageSize;

  bool _detectingFaces = false;
  bool pictureTaken = false;

  bool _initializing = false;

  bool _saving = false;
  bool _bottomSheetVisible = false;
  int _autoCaptured = 0;
  final List<List> _enrollmentSamples = [];
  // Track pose-targeted captures: FRONT, LEFT, RIGHT, UP_OR_DOWN
  final Set<String> _capturedPoses = <String>{};
  static const int _requiredSamples = 4;
  static const List<String> _poseOrder = <String>[
    'FRONT',
    'LEFT',
    'RIGHT',
    'UP_OR_DOWN',
  ];
  bool _openingSheet = false;
  final TextEditingController _userController = TextEditingController(text: '');
  final TextEditingController _passwordController =
      TextEditingController(text: '');

  // service injection
  FaceDetectorService _faceDetectorService = locator<FaceDetectorService>();
  CameraService _cameraService = locator<CameraService>();
  MLService _mlService = locator<MLService>();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  _start() async {
    setState(() => _initializing = true);
    try {
      // Ensure dependent services are ready (in case SignUp is entered directly)
      await _cameraService.initialize();
      try {
        _faceDetectorService.initialize();
      } catch (_) {}
      try {
        // Initialize ML only if not already loaded
        await _mlService.initialize();
      } catch (_) {}
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

  Future<bool> onShot() async {
    if (faceDetected == null) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('No face detected!'),
          );
        },
      );

      return false;
    } else {
      // Validate face bounding box size and position vs image size
      try {
        final Size? imgSize = imageSize;
        final Face? fd = faceDetected;
        if (imgSize == null || fd == null) return false;
        final rect = fd.boundingBox;
        final double boxArea = rect.width * rect.height;
        final double imgArea = imgSize.width * imgSize.height;
        // Require at least 5% of the frame to avoid tiny/blurred faces
        if (boxArea / imgArea < 0.05) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Text('Face too small in the frame. Move closer.'),
            ),
          );
          return false;
        }
        // Basic in-frame check
        if (rect.left < 0 ||
            rect.top < 0 ||
            rect.right > imgSize.width ||
            rect.bottom > imgSize.height) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Text('Keep your entire face within the frame.'),
            ),
          );
          return false;
        }
      } catch (_) {}
      // Trigger one embedding capture from the live image stream
      setState(() {
        _saving = true;
      });
      // Wait until the stream loop captures and resets _saving
      final int maxWaitMs = 2000;
      int waited = 0;
      while (_saving && waited < maxWaitMs) {
        await Future.delayed(Duration(milliseconds: 50));
        waited += 50;
      }
      // Return true if embedding captured
      return !_saving;
    }
  }

  _frameFaces() {
    imageSize = _cameraService.getImageSize();

    if (_cameraService.isStreamingImages) return;
    _cameraService.cameraController?.startImageStream((image) async {
      if (_cameraService.cameraController != null) {
        if (_detectingFaces) return;

        _detectingFaces = true;

        try {
          await _faceDetectorService.detectFacesFromImage(image);

          if (_faceDetectorService.faces.isNotEmpty) {
            setState(() {
              faceDetected = _faceDetectorService.faces[0];
            });
            // Auto-capture embeddings based on head pose until 4 targeted samples collected
            if (!_bottomSheetVisible && _autoCaptured < _requiredSamples) {
              final String? pose = _currentPose(faceDetected);
              if (pose != null && !_capturedPoses.contains(pose) && !_saving) {
                _mlService.setCurrentPrediction(image, faceDetected);
                // Throttle to avoid duplicate captures
                _saving = true;
                Future.delayed(Duration(milliseconds: 450)).then((_) async {
                  if (!mounted) return;
                  setState(() {
                    final List emb = List.from(_mlService.predictedData);
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
                      final centroid = _mlService.centroidFromSamples(
                          _enrollmentSamples
                              .map((e) => e.cast<num>())
                              .toList());
                      final existing =
                          await _mlService.predictFromEmbedding(centroid);
                      if (!mounted) return;
                      if (existing != null) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Text(
                                'This face is already registered as ' +
                                    existing.user +
                                    '.'),
                          ),
                        );
                        _reload();
                        return;
                      }
                    } catch (_) {}
                    _openSignUpSheet();
                  }
                });
              }
            }
          } else {
            print('face is null');
            setState(() {
              faceDetected = null;
            });
          }

          _detectingFaces = false;
        } catch (e) {
          print('Error _faceDetectorService face => $e');
          _detectingFaces = false;
        }
      }
    });
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

  Future<void> _openSignUpSheet() async {
    if (_openingSheet) return;
    _openingSheet = true;
    try {
      if (mounted) {
        setState(() {
          _bottomSheetVisible = true;
          imageSize = null;
        });
      }
      await _cameraService.stopImageStreamIfActive();
      await _cameraService.dispose();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => _buildSignUpSheet(context),
      );
      if (mounted) {
        _reload();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bottomSheetVisible = false;
        });
      }
      try {
        await _cameraService.initialize();
        _frameFaces();
      } catch (_) {}
    } finally {
      _openingSheet = false;
    }
  }

  _onBackPressed() {
    Navigator.of(context).pop();
  }

  _reload() {
    setState(() {
      _bottomSheetVisible = false;
      pictureTaken = false;
      _autoCaptured = 0;
      _enrollmentSamples.clear();
      _capturedPoses.clear();
      _userController.text = '';
      _passwordController.text = '';
    });
    this._start();
  }

  @override
  Widget build(BuildContext context) {
    final double mirror = math.pi;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final bool isControllerReady = _cameraService.cameraController != null &&
        _cameraService.cameraController!.value.isInitialized;
    final bool isPreviewReady = isControllerReady && imageSize != null;

    late Widget body;
    if (_initializing || !isControllerReady) {
      body = Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_initializing && pictureTaken) {
      body = Container(
        width: width,
        height: height,
        child: Transform(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: Image.file(File(imagePath!)),
            ),
            transform: Matrix4.rotationY(mirror)),
      );
    }

    if (!_initializing &&
        !pictureTaken &&
        isPreviewReady &&
        !_bottomSheetVisible) {
      body = Transform.scale(
        scale: 1.0,
        child: AspectRatio(
          aspectRatio: MediaQuery.of(context).size.aspectRatio,
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.fitHeight,
              child: Container(
                width: width,
                height:
                    width * _cameraService.cameraController!.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CameraPreview(_cameraService.cameraController!),
                    if (imageSize != null)
                      CustomPaint(
                        painter: FacePainter(
                            face: faceDetected, imageSize: imageSize!),
                      ),
                    // Guidance overlay
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Captured: ' +
                                    _autoCaptured.toString() +
                                    ' / ' +
                                    _requiredSamples.toString(),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
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
      );
    }

    // Fallback while waiting for preview readiness
    if (!_initializing && !pictureTaken && !isPreviewReady) {
      body = Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          body,
          CameraHeader(
            "SIGN UP",
            onBackPressed: _onBackPressed,
          )
        ],
      ),
    );
  }

  Widget _buildSignUpSheet(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Register new user', style: TextStyle(fontSize: 20)),
          SizedBox(height: 10),
          AppTextField(
            controller: _userController,
            labelText: 'Your Name',
          ),
          SizedBox(height: 10),
          AppTextField(
            controller: _passwordController,
            labelText: 'Password',
            isPassword: true,
          ),
          SizedBox(height: 10),
          Text('Samples captured: ' +
              _enrollmentSamples.length.toString() +
              ' / ' +
              _requiredSamples.toString()),
          SizedBox(height: 16),
          AppButton(
            text: 'SIGN UP',
            onPressed: () async {
              if (_enrollmentSamples.length < _requiredSamples) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: Text('Please wait until 4 samples are captured.'),
                  ),
                );
                return;
              }
              final String user = _userController.text.trim();
              final String password = _passwordController.text.trim();
              if (user.isEmpty || password.isEmpty) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: Text('Enter name and password.'),
                  ),
                );
                return;
              }
              // Block if face already registered
              final centroid = _mlService.centroidFromSamples(
                  _enrollmentSamples.map((e) => e.cast<num>()).toList());
              final existing = await _mlService.predictFromEmbedding(centroid);
              if (existing != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: Text('A similar face is already registered as ' +
                        existing.user +
                        '. Registration blocked.'),
                  ),
                );
                return;
              }
              // Block if username already exists
              final dbCheck =
                  await DatabaseHelper.instance.getUserByUsername(user);
              if (dbCheck != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: Text('Username already exists. Choose another.'),
                  ),
                );
                return;
              }
              final db = DatabaseHelper.instance;
              final userToSave = User(
                user: user,
                password: password,
                modelData: _enrollmentSamples,
              );
              await db.insert(userToSave);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            icon: Icon(
              Icons.person_add,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
