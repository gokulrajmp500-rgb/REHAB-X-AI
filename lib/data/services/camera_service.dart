import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

enum CameraStatus { idle, requestingPermission, ready, denied, permanentlyDenied, unavailable, error }
typedef CameraFrameCallback = Future<void> Function(Object frame);

class CameraFrame {
  const CameraFrame({
    required this.image,
    required this.sensorOrientation,
    required this.isFrontFacing,
    this.deviceOrientation = DeviceOrientation.portraitUp,
  });
  final CameraImage image;
  final int sensorOrientation;
  final bool isFrontFacing;
  final DeviceOrientation deviceOrientation;
}

abstract interface class CameraService {
  CameraStatus get status;
  CameraController? get controller;
  Future<void> initialize({bool frontCamera = false});
  Future<void> pause();
  Future<void> resume();
  Future<void> startImageStream(CameraFrameCallback callback);
  Future<void> stopImageStream();
  Future<void> dispose();
}

class UnavailableCameraService implements CameraService {
  @override CameraStatus status = CameraStatus.unavailable;
  @override CameraController? get controller => null;
  @override Future<void> initialize({bool frontCamera = false}) async {}
  @override Future<void> pause() async {}
  @override Future<void> resume() async {}
  @override Future<void> startImageStream(CameraFrameCallback callback) async {}
  @override Future<void> stopImageStream() async {}
  @override Future<void> dispose() async {}
}

class PluginCameraService implements CameraService {
  CameraStatus _status = CameraStatus.idle;
  CameraController? _controller;

  @override CameraStatus get status => _status;
  @override CameraController? get controller => _controller;

  @override
  Future<void> initialize({bool frontCamera = false}) async {
    _status = CameraStatus.requestingPermission;
    try {
      if (_controller != null) {
        if (_controller!.value.isStreamingImages) {
          try {
            await _controller!.stopImageStream();
          } catch (_) {}
        }
        await _controller!.dispose();
        _controller = null;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _status = CameraStatus.unavailable;
        return;
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == (frontCamera ? CameraLensDirection.front : CameraLensDirection.back),
        orElse: () => cameras.first,
      );
      final nextController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await nextController.initialize();
      _controller = nextController;
      _status = CameraStatus.ready;
    } on CameraException catch (error) {
      _status = error.code == 'CameraAccessDenied' ? CameraStatus.denied : CameraStatus.error;
      await _controller?.dispose();
      _controller = null;
    } on Object {
      _status = CameraStatus.unavailable;
      await _controller?.dispose();
      _controller = null;
    }
  }

  @override Future<void> pause() async { await _controller?.pausePreview(); }
  @override Future<void> resume() async { await _controller?.resumePreview(); }
  @override
  Future<void> startImageStream(CameraFrameCallback callback) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;
    await controller.startImageStream((image) => callback(
      CameraFrame(
        image: image,
        sensorOrientation: controller.description.sensorOrientation,
        isFrontFacing: controller.description.lensDirection == CameraLensDirection.front,
        deviceOrientation: controller.value.deviceOrientation,
      ),
    ));
  }

  @override
  Future<void> stopImageStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  @override Future<void> dispose() async { await _controller?.dispose(); _controller = null; _status = CameraStatus.idle; }
}