import 'package:face_recognition_auth/face_recognition_auth.dart';
import 'package:get_it/get_it.dart';

final locator = GetIt.instance;

Future setupServices() async {
  locator.registerSingleton<FaceAuthIsolate>(FaceAuthIsolate());
  await locator.get<FaceAuthIsolate>().initialize();
}
