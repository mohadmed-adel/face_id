import 'package:face_recognition_auth/face_recognition_auth.dart';
import 'package:flutter/material.dart';

class RegisterNewUserScreen extends StatefulWidget {
  const RegisterNewUserScreen({super.key});

  @override
  State<RegisterNewUserScreen> createState() => _RegisterNewUserScreenState();
}

class _RegisterNewUserScreenState extends State<RegisterNewUserScreen> {
  final FaceAuthController _controller = FaceAuthController();
  String _status = "Initializing...";
  User? _result;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  void _updateStatus(FaceAuthState state) {
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
  }

  Future<void> _startFlow() async {
    await _controller.initialize();

    _controller.register(
      samples: 4,
      onProgress: _updateStatus,
      onDone: (user) {
        setState(() {
          _result = user;
          if (user != null) {
            _status = "✅ Registered: ${user.id}";
          } else {
            _status = "❌ Registration failed";
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_controller != null) FaceAuthView(controller: _controller),

          // Face boxes overlay
          // if (_controller.faceDetectorService.faces.isNotEmpty)
          //   CustomPaint(
          //     painter: FaceBoxPainter(
          //       _controller.faceDetectorService.faces,
          //       camController!.value.previewSize!,
          //     ),
          //   ),

          // Status text
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _result != null ? "Welcome ${_result!.id}" : _status,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
