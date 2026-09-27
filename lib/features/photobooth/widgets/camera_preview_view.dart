import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  bool get isInitialized {
    return _controller?.value.isInitialized ?? false;
  }

  
  Future<void> initialize() async {
    await _disposeCurrentController();

    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw Exception(
        'Tidak ada kamera yang tersedia.',
      );
    }

    final camera = cameras.first;

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = controller;

    await controller.initialize();
  }

  
  Future<XFile?> takePicture() async {
    final controller = _controller;

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

  
  Future<void> restartCamera() async {
    await _disposeCurrentController();

    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw Exception(
        'Tidak ada kamera yang tersedia.',
      );
    }

    final camera = cameras.first;

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = controller;

    await controller.initialize();
  }

 
  Future<void> _disposeCurrentController() async {
    final controller = _controller;

    _controller = null;

    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {
        
      }
    }
  }


  Future<void> dispose() async {
    await _disposeCurrentController();
  }
}
