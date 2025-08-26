import 'package:face_recognition_auth/face_recognition_auth.dart';
import 'package:get_it/get_it.dart';

final locator = GetIt.instance;

Future setupServices() async {
  locator.registerSingleton<FaceAuth>(FaceAuth());
  await locator.get<FaceAuth>().initialize();
}
