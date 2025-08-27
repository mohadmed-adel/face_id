
import 'package:camera/camera.dart';
import 'package:face_recognition_auth/face_recognition_auth.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FrameRequest {
  final CameraImage image;
  final Face? face;
  final int requiredSamples;
 
  FrameRequest({
    required this.image,
    required this.face,
    required this.requiredSamples,
  });
}

class FrameResponse {
  final User? user;
  final bool success;
  final String? msg;
 
  FrameResponse({
    required this.user,
    required this.success,
    required this.msg,
   });
}
