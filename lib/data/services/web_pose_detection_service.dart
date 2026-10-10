import 'dart:convert';
import 'dart:js_interop';

import '../../core/filters/one_euro_filter.dart';
import '../../domain/models/pose_models.dart';
import 'camera_service.dart';
import 'pose_detection_service.dart';

@JS('rehabXPoseDetector.initialize')
external JSPromise<JSAny?> _initializeBrowserPoseDetector();

@JS('rehabXPoseDetector.detect')
external JSString _detectBrowserPose();

class PoseDetectionServiceImpl implements PoseDetectionService {
  final LandmarkTemporalFilter _temporalFilter = LandmarkTemporalFilter();
  bool _initialized = false;
  bool _disposed = false;

  @override
  bool get isConfigured => _initialized && !_disposed;

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    try {
      await _initializeBrowserPoseDetector().toDart;
      _temporalFilter.reset();
      _initialized = true;
    } catch (error) {
      throw StateError(
        'Browser pose detection could not load. Check the internet connection and allow the MediaPipe model download. $error',
      );
    }
  }

  @override
  Future<PoseFrame?> processFrame(Object frame) async {
    if (!isConfigured || frame is! BrowserCameraFrame) return null;

    final rawJson = _detectBrowserPose().toDart;
    final result = jsonDecode(rawJson) as Map<String, dynamic>;
    final width = (result['width'] as num?)?.toInt() ?? 0;
    final height = (result['height'] as num?)?.toInt() ?? 0;
    final people = (result['people'] as num?)?.toInt() ?? 0;
    if (people > 1) {
      return PoseFrame(
        timestamp: DateTime.now(),
        landmarks: const {},
        imageWidth: width,
        imageHeight: height,
        personCount: people,
        isMultiPerson: true,
      );
    }

    final landmarks = <String, PoseLandmark>{};
    for (final item in (result['landmarks'] as List<dynamic>? ?? const [])) {
      final value = item as Map<String, dynamic>;
      final landmark = PoseLandmark(
        name: value['name'] as String,
        x: (value['x'] as num).toDouble(),
        y: (value['y'] as num).toDouble(),
        z: (value['z'] as num?)?.toDouble() ?? 0,
        confidence: (value['confidence'] as num?)?.toDouble() ?? 0,
      );
      if (landmark.isValid) landmarks[landmark.name] = landmark;
    }

    _addCenterLandmarks(landmarks);
    if (width <= 0 || height <= 0 || landmarks.isEmpty) return null;

    return _temporalFilter.filterFrame(
      PoseFrame(
        timestamp: DateTime.now(),
        landmarks: landmarks,
        imageWidth: width,
        imageHeight: height,
        personCount: people,
      ),
    );
  }

  void _addCenterLandmarks(Map<String, PoseLandmark> landmarks) {
    for (final joint in const [
      'Shoulder',
      'Elbow',
      'Wrist',
      'Hip',
      'Knee',
      'Ankle',
    ]) {
      final left = landmarks['left$joint'];
      final right = landmarks['right$joint'];
      if (left == null || right == null) continue;
      final name = '${joint[0].toLowerCase()}${joint.substring(1)}';
      landmarks[name] = PoseLandmark(
        name: name,
        x: (left.x + right.x) / 2,
        y: (left.y + right.y) / 2,
        z: (left.z + right.z) / 2,
        confidence: left.confidence < right.confidence
            ? left.confidence
            : right.confidence,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _initialized = false;
  }
}
