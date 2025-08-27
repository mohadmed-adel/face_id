import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:face_recognition_auth/src/isolate/frame_request.dart';
import 'package:face_recognition_auth/src/isolate/ml_isolate_login.dart';
import 'package:face_recognition_auth/src/isolate/ml_isolate_register.dart';

class IsolateHelper {
  late SendPort _sendPort;
  late Isolate _isolate;
  final Completer<void> _initCompleter = Completer<void>();

 
Future<void> init({
  bool forRegister = true,
  required Uint8List interpreterBytes,
  required RootIsolateToken rootIsolateToken,
}) async {
  final receivePort = ReceivePort();

  _isolate = await Isolate.spawn(
    forRegister ? mlRegisterWorkerEntry : mlLoginWorkerEntry,
    receivePort.sendPort,
  );


  receivePort.listen((message) {
    if (message is SendPort) {
      _sendPort = message;

      _sendPort?.send([
        interpreterBytes,
        rootIsolateToken,
      ]);

      _initCompleter.complete();
    }
  });

  await _initCompleter.future;
}

  Future<FrameResponse> sendAndWait(FrameRequest request) async {
    final responsePort = ReceivePort();
    _sendPort.send([request, responsePort.sendPort]);

    final result = await responsePort.first as FrameResponse;
    responsePort.close();
    return result;
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
  }
}
