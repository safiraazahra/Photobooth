import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  bool get isInitialized {
    return _controller?.value.isInitialized ?? false;
  }

  Future<void> initialize() async {
    await _startCamera();
  }

  Future<void> restartCamera() async {
    await _startCamera();
  }

  Future<void> _startCamera({
    int retryCount = 0,
  }) async {
    await _disposeCurrentController();

    await Future.delayed(
      const Duration(
        milliseconds: 300,
      ),
    );

    final List<CameraDescription> cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw Exception(
        'Tidak ada kamera yang tersedia.',
      );
    }

    final CameraDescription camera = cameras.first;

    final CameraController controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      _controller = controller;
    } on CameraException catch (error) {
      try {
        await controller.dispose();
      } catch (_) {}

      final bool isHardwareBusy = error.code == 'cameraNotReadable' ||
          error.description?.toLowerCase().contains(
                    'hardware error',
                  ) ==
              true;

      if (isHardwareBusy && retryCount < 2) {
        if (kDebugMode) {
          print(
            'Kamera masih sibuk, mencoba lagi... '
            '(percobaan ke-${retryCount + 2})',
          );
        }

        await Future.delayed(
          const Duration(
            milliseconds: 800,
          ),
        );

        return _startCamera(
          retryCount: retryCount + 1,
        );
      }

      rethrow;
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? controller = _controller;

    if (controller == null) {
      return null;
    }

    if (!controller.value.isInitialized) {
      return null;
    }

    if (controller.value.isTakingPicture) {
      return null;
    }

    return controller.takePicture();
  }

  Future<void> _disposeCurrentController() async {
    final CameraController? controller = _controller;

    _controller = null;

    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await _disposeCurrentController();
  }
}
