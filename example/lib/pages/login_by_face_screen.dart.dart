import 'package:camera/camera.dart';
import 'package:example/locator.dart';
import 'package:example/pages/widgets/face_box_painter.dart';
import 'package:face_recognition_auth/face_recognition_auth.dart';
import 'package:flutter/material.dart';

class LoginByFaceScreen extends StatefulWidget {
  const LoginByFaceScreen({super.key});

  @override
  State<LoginByFaceScreen> createState() => _LoginByFaceScreenState();
}

class _LoginByFaceScreenState extends State<LoginByFaceScreen> {
  final FaceAuth _faceAuth = locator.get<FaceAuth>();
  String _status = "Initializing...";
  User? _result;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    _faceAuth.loginWithCamera(onProgress: _updateStatus).then((user) {
      setState(() => _result = user);
    });
  }

  void _updateStatus(FaceAuthState state) {
    setState(() {
      switch (state) {
        case FaceAuthState.cameraOpened:
          _status = "📷 Camera opened...";
          break;
        case FaceAuthState.detectingFace:
          _status = "🔍 Detecting face...";
          break;
        case FaceAuthState.collectingSamples:
          _status = "⏳ Collecting samples...";
          break;
        case FaceAuthState.matching:
          _status = "🤝 Matching face...";
          break;
        case FaceAuthState.success:
          _status = "✅ Success!";

          break;
        case FaceAuthState.failed:
          _status = "❌ Failed!";
          break;
        case FaceAuthState.timeout:
          _status = "⌛ Timeout!";
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _faceAuth.cameraService.cameraController;
    return Scaffold(
      body: Stack(
        children: [
          if (controller != null && controller.value.isInitialized)
            CameraPreview(controller),

          // Face boxes overlay
          if (_faceAuth.faceDetectorService.faces.isNotEmpty)
            CustomPaint(
              painter: FaceBoxPainter(
                _faceAuth.faceDetectorService.faces,
                controller!.value.previewSize!,
              ),
            ),

          // Status text
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                _result != null ? "Welcome ${_result!.id.toString()}" : _status,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
