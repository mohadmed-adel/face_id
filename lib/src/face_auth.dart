import 'package:face_recognition_auth/face_recognition_auth.dart';

/// High-level facade for common face auth operations.
///
/// Exposes simple methods the UI can call without wiring internals.
class FaceAuth {
  FaceAuth({
    MLService? mlService,
    DatabaseHelper? databaseHelper,
    CameraService? cameraService,
    FaceDetectorService? faceDetectorService,
  }) : mlService = mlService ?? MLService(),
       _database = databaseHelper ?? DatabaseHelper.instance,
       cameraService = cameraService ?? CameraService(),
       faceDetectorService =
           faceDetectorService ??
           FaceDetectorService(cameraService ?? CameraService());

  final MLService mlService;
  final DatabaseHelper _database;
  final CameraService cameraService;
  final FaceDetectorService faceDetectorService;

  /// Initialize the ML interpreter. Call during app startup.
  Future<void> initialize() async {
    await mlService.initialize();
    await cameraService.initialize();
    faceDetectorService.initialize();
  }

  /// Register a user by saving their embedding(s).
  ///
  /// If multiple samples are provided, a centroid is stored via MLService helper.
  Future<void> registerFace({
    required String username,
    required String password,
    required List<dynamic> samplesOrSingleEmbedding,
  }) async {
    // Normalize to either a centroid (List<double>) or store raw list(s)
    late final List modelData;
    if (samplesOrSingleEmbedding.isNotEmpty &&
        samplesOrSingleEmbedding.first is List) {
      final List<double> centroid = mlService.centroidFromSamples(
        samplesOrSingleEmbedding.cast<List<num>>(),
      );
      modelData = centroid;
    } else {
      modelData = samplesOrSingleEmbedding;
    }

    final user = User(user: username, password: password, modelData: modelData);
    await _database.insert(user);
  }

  /// Try to match a provided embedding against registered users.
  Future<User?> matchFace(List embedding) async {
    return mlService.predictFromEmbedding(embedding);
  }

  /// Delete all registered users/embeddings.
  Future<int> deleteAllFaces() {
    return _database.deleteAll();
  }
}
