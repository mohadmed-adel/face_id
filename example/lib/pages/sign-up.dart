import 'package:example/locator.dart';
import 'package:face_recognition_auth/face_recognition_auth.dart';
import 'package:flutter/material.dart';

class SignUp extends StatelessWidget {
  const SignUp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FaceRegisterWidget(faceAuth: locator.get<FaceAuth>()),
    );
  }
}
