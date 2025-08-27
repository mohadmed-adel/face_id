import 'package:camera/camera.dart';
import 'package:face_recognition_auth/src/ui/logic/face_auth_controller.dart';
import 'package:face_recognition_auth/src/ui/view/widgets/face_box_painter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FaceAuthView extends StatelessWidget {
  final FaceAuthController controller;

  const FaceAuthView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<FaceAuthController>(
        builder: (context, ctrl, _) {
          final state = ctrl.state;
          final width = MediaQuery.of(context).size.width;
          final height = MediaQuery.of(context).size.height;

          var body = Transform.scale(
            scale: 1.0,
            child: AspectRatio(
              aspectRatio: MediaQuery.of(context).size.aspectRatio,
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.fitHeight,
                  child: Container(
                    width: width,
                    height:
                        width *
                        (ctrl.cameraService.cameraController?.value.aspectRatio ?? 1.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (ctrl.cameraService.cameraController != null)
                          CameraPreview(ctrl.cameraService.cameraController!),
                        if (ctrl.cameraService.cameraController != null)
                          CustomPaint(
                            painter: FaceBoxPainter(
                              ctrl.faces ?? [],
                              ctrl.imageSize ?? Size.zero,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          return body;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (ctrl.cameraService.cameraController != null)
                CameraPreview(ctrl.cameraService.cameraController!),
              if (ctrl.cameraService.cameraController != null)
                CameraPreview(ctrl.cameraService.cameraController!),
              CustomPaint(
                painter: FaceBoxPainter(ctrl.faces ?? [], ctrl.imageSize!),
              ),
              // Align(
              //   alignment: Alignment.bottomLeft,
              //   child: Container(
              //     color: Colors.black54,
              //     padding: const EdgeInsets.all(16),
              //     child: Text(
              //       controller.face?.toString() ?? "Idle",
              //       style: const TextStyle(color: Colors.white, fontSize: 18),
              //     ),
              //   ),
              // ),
            ],
          );
        },
      ),
    );
  }
}
