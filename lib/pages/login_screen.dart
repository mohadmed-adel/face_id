import 'dart:io';

import 'package:face_net_authentication/pages/models/user.model.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  final User? predictedUser;
  final String? imagePath;

  const LoginScreen({Key? key, required this.predictedUser, this.imagePath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool found = predictedUser != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 16),
            Text(
              found ? 'Welcome back, ${predictedUser!.user}' : 'User not found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  // ignore: deprecated_member_use_from_same_package
                  // Image.file requires dart:io which is available in app
                  // The parent passes a valid path
                  File(imagePath!),
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            SizedBox(height: 24),
            if (found)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: Icon(Icons.login),
                label: Text('Continue'),
                style:
                    ElevatedButton.styleFrom(minimumSize: Size.fromHeight(48)),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.arrow_back),
                label: Text('Back'),
                style:
                    ElevatedButton.styleFrom(minimumSize: Size.fromHeight(48)),
              ),
          ],
        ),
      ),
    );
  }
}
