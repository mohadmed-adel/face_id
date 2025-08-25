import 'package:face_net_authentication/locator.dart';
import 'package:face_net_authentication/pages/db/databse_helper.dart';
import 'package:face_net_authentication/pages/models/user.model.dart';
import 'package:face_net_authentication/pages/profile.dart';
import 'package:face_net_authentication/pages/widgets/app_button.dart';
import 'package:face_net_authentication/services/camera.service.dart';
import 'package:face_net_authentication/services/ml_service.dart';
import 'package:flutter/material.dart';

import '../home.dart';
import 'app_text_field.dart';

class AuthActionButton extends StatefulWidget {
  AuthActionButton(
      {Key? key,
      required this.onPressed,
      required this.reload,
      this.isLogin = false});
  final Function onPressed;
  final bool isLogin;
  final Function reload;
  @override
  _AuthActionButtonState createState() => _AuthActionButtonState();
}

class _AuthActionButtonState extends State<AuthActionButton> {
  final MLService _mlService = locator<MLService>();
  final CameraService _cameraService = locator<CameraService>();

  final TextEditingController _userTextEditingController =
      TextEditingController(text: '');
  final TextEditingController _passwordTextEditingController =
      TextEditingController(text: '');

  User? predictedUser;
  // Keep multiple samples during sign-up
  final List<List> _enrollmentSamples = [];
  // Require exactly three samples before allowing sign-up
  static const int _requiredSamples = 3;
  bool _isCapturing = false;

  Future _signUp(context) async {
    DatabaseHelper _databaseHelper = DatabaseHelper.instance;
    List predictedData = _mlService.predictedData;
    String user = _userTextEditingController.text;
    String password = _passwordTextEditingController.text;
    // If multiple samples were captured, store them all; else, store single embedding
    final List modelDataToSave =
        _enrollmentSamples.isNotEmpty ? _enrollmentSamples : predictedData;
    User userToSave = User(
      user: user,
      password: password,
      modelData: modelDataToSave,
    );
    await _databaseHelper.insert(userToSave);
    this._mlService.setPredictedData([]);
    _enrollmentSamples.clear();
    Navigator.push(context,
        MaterialPageRoute(builder: (BuildContext context) => MyHomePage()));
  }

  Future _signIn(context) async {
    String password = _passwordTextEditingController.text;
    if (this.predictedUser!.password == password) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (BuildContext context) => Profile(
                    this.predictedUser!.user,
                    imagePath: _cameraService.imagePath!,
                  )));
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('Wrong password!'),
          );
        },
      );
    }
  }

  Future onTap() async {
    try {
      if (_isCapturing) return;
      // For sign-up: capture one sample per tap and open when finished

      setState(() {
        _isCapturing = true;
      });

      bool ok = await widget.onPressed();
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed. Please try again.')),
        );
        setState(() {
          _isCapturing = false;
        });
        return;
      }
      final List emb = List.from(_mlService.predictedData);
      if (emb.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No face embedding detected.')),
        );
        setState(() {
          _isCapturing = false;
        });
        return;
      }
      // During registration, block if this sample matches any existing user
      if (!widget.isLogin) {
        final existing = await _mlService.predictFromEmbedding(emb);
        if (existing != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Text('This face seems already registered as ' +
                  existing.user +
                  '. Please use another account or sign in.'),
            ),
          );
          setState(() {
            _isCapturing = false;
          });
          return;
        }
      }
      _enrollmentSamples.add(emb);
      setState(() {
        _isCapturing = false;
      });

      if (_enrollmentSamples.length >= _requiredSamples) {
        await _cameraService.stopImageStreamIfActive();
        await _cameraService.dispose();
        if (!mounted) return;
        PersistentBottomSheetController bottomSheetController =
            Scaffold.of(context)
                .showBottomSheet((context) => signSheet(context));
        bottomSheetController.closed.whenComplete(() => widget.reload());
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine dynamic guidance during sign-up
    String nextGuidance = '';

    final int count = _enrollmentSamples.length;
    nextGuidance = count == 0
        ? 'Look straight at the camera.'
        : count == 1
            ? 'Now turn slightly to your left.'
            : count == 2
                ? 'Now turn slightly to your right.'
                : 'All samples captured.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_enrollmentSamples.length < _requiredSamples)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Text(
                  'Samples captured: ' +
                      _enrollmentSamples.length.toString() +
                      ' / ' +
                      _requiredSamples.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  nextGuidance,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (_enrollmentSamples.length < _requiredSamples)
          InkWell(
            onTap: _isCapturing ? null : onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.blue[200],
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 1,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              width: MediaQuery.of(context).size.width * 0.8,
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isCapturing) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('CAPTURING...', style: TextStyle(color: Colors.white)),
                  ] else ...[
                    Text(
                      'CAPTURE',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Icon(Icons.camera_alt, color: Colors.white)
                  ]
                ],
              ),
            ),
          ),
      ],
    );
  }

  signSheet(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          widget.isLogin && predictedUser != null
              ? Container(
                  child: Text(
                    'Welcome back, ' + predictedUser!.user + '.',
                    style: TextStyle(fontSize: 20),
                  ),
                )
              : widget.isLogin
                  ? Container(
                      child: Text(
                      'User not found 😞',
                      style: TextStyle(fontSize: 20),
                    ))
                  : Container(),
          Container(
            child: Column(
              children: [
                !widget.isLogin
                    ? AppTextField(
                        controller: _userTextEditingController,
                        labelText: "Your Name",
                      )
                    : Container(),
                SizedBox(height: 10),
                widget.isLogin && predictedUser == null
                    ? Container()
                    : AppTextField(
                        controller: _passwordTextEditingController,
                        labelText: "Password",
                        isPassword: true,
                      ),
                if (!widget.isLogin) ...[
                  SizedBox(height: 8),
                  Text('Samples captured: ' +
                      _enrollmentSamples.length.toString() +
                      ' / ' +
                      _requiredSamples.toString()),
                  SizedBox(height: 8),
                  AppButton(
                    text: 'SIGN UP',
                    onPressed: () async {
                      // Enforce exactly three samples
                      if (_enrollmentSamples.length < _requiredSamples) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Text('Please capture ' +
                                _requiredSamples.toString() +
                                ' samples before signing up.'),
                          ),
                        );
                        return;
                      }

                      // Check if this user already exists by comparing centroid to DB
                      final centroid = _mlService.centroidFromSamples(
                          _enrollmentSamples
                              .map((e) => e.cast<num>())
                              .toList());
                      final existing =
                          await _mlService.predictFromEmbedding(centroid);
                      if (existing != null) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Text(
                                'A similar face is already registered as ' +
                                    existing.user +
                                    '. Registration blocked.'),
                          ),
                        );
                        return;
                      }

                      await _signUp(context);
                    },
                    icon: Icon(
                      Icons.person_add,
                      color: Colors.white,
                    ),
                  ),
                ],
                SizedBox(height: 10),
                Divider(),
                SizedBox(height: 10),
                widget.isLogin && predictedUser != null
                    ? AppButton(
                        text: 'LOGIN',
                        onPressed: () async {
                          _signIn(context);
                        },
                        icon: Icon(
                          Icons.login,
                          color: Colors.white,
                        ),
                      )
                    : !widget.isLogin
                        ? Container() // handled above with multi-button row
                        : Container(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
