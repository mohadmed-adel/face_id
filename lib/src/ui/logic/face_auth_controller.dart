import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:face_recognition_auth/face_recognition_auth.dart';
import 'package:face_recognition_auth/src/isolate/FaceAuthIsolate.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceAuthController extends ChangeNotifier {
  final FaceAuthIsolate _faceAuth = FaceAuthIsolate();
  FaceAuthState? _state;
  User? _user;
  List<Face>? _faces;
  Size? _imageSize;

  FaceAuthState? get state => _state;
  User? get user => _user;
  List<Face>? get faces => _faces;
  Size? get imageSize => _imageSize;

  Future<void> initialize() async {
    await _faceAuth.initialize();
  }

  Future<void> register({
    int samples = 4,
    void Function(User? user)? onDone,
    FaceAuthProgress? onProgress,
  }) async {
    _user = null;
    _update(FaceAuthState.cameraOpened);

    try {
      _user = await _faceAuth.registerWithCamera(
        requiredSamples: samples,
        onProgress: (data) {
          onProgress?.call(data);
          _update(data);
        },
        onFaceDetected: (faces, image) {
          _updateFace(faces, image);
        },
      );
      _update(FaceAuthState.success);
    } catch (_) {
      _update(FaceAuthState.failed);
    }

    notifyListeners();
    onDone?.call(_user);
  }

  Future<void> login({
    void Function(User? user)? onDone,
    FaceAuthProgress? onProgress,
  }) async {
    _user = null;
    _update(FaceAuthState.cameraOpened);

    try {
      _user = await _faceAuth.loginWithCamera(
        onFaceDetected: (faces, image) {
          _updateFace(faces, image);
        },
        onProgress: (data) {
          onProgress?.call(data);
          _update(data);
        },
      );
      _update(FaceAuthState.success);
    } catch (_) {
      _update(FaceAuthState.failed);
    }

    notifyListeners();
    onDone?.call(_user);
  }

  void _update(FaceAuthState state) {
    _state = state;
    notifyListeners();
  }

  void _updateFace(List<Face>? faces, CameraImage image) {
    _faces = faces;
    _imageSize = updateImageSize(image);
    notifyListeners();
  }

  @override
  void dispose() {
    if (cameraService.cameraController != null &&
        cameraService.cameraController!.value.isInitialized &&
        cameraService.cameraController!.value.isStreamingImages) {
      cameraService.cameraController!.stopImageStream();
    }
    cameraService.cameraController?.dispose();

    _faceAuth.cameraService.dispose();
    _faceAuth.dispose();
    super.dispose();
  }

  Size updateImageSize(CameraImage? image) {
    if (image == null) return Size.zero;

    return Size(image.width.toDouble(), image.height.toDouble());
  }

  CameraService get cameraService => _faceAuth.cameraService;
}
