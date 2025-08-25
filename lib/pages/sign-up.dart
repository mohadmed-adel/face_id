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
    await _cameraService.initialize();
    setState(() => _initializing = false);

    _frameFaces();
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
            // Auto-capture embeddings when face is steady, collect 3 samples
            if (!_bottomSheetVisible && _autoCaptured < 3) {
              _mlService.setCurrentPrediction(image, faceDetected);
              // Add a short throttle by toggling _saving for a moment
              _saving = true;
              Future.delayed(Duration(milliseconds: 250)).then((_) {
                if (!mounted) return;
                setState(() {
                  _saving = false;
                  final List emb = List.from(_mlService.predictedData);
                  if (emb.isNotEmpty) {
                    _enrollmentSamples.add(emb);
                    _autoCaptured = _enrollmentSamples.length;
                  }
                });
                // When enough samples collected, open sign-up sheet
                if (_autoCaptured >= 3 && !_bottomSheetVisible) {
                  _openSignUpSheet();
                }
              });
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

  Future<void> _openSignUpSheet() async {
    try {
      await _cameraService.stopImageStreamIfActive();
      await _cameraService.dispose();
      if (!mounted) return;
      setState(() {
        _bottomSheetVisible = true;
      });
      PersistentBottomSheetController bottomSheetController =
          Scaffold.of(context)
              .showBottomSheet((context) => _buildSignUpSheet(context));
      bottomSheetController.closed.whenComplete(_reload);
    } catch (_) {}
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

    if (!_initializing && !pictureTaken && isPreviewReady) {
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        // Remove capture FAB; auto-capturing from live stream
        floatingActionButton: Container());
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
              ' / 3'),
          SizedBox(height: 16),
          AppButton(
            text: 'SIGN UP',
            onPressed: () async {
              if (_enrollmentSamples.length < 3) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: Text('Please wait until 3 samples are captured.'),
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
