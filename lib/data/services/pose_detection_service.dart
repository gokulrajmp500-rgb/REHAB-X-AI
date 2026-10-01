import '../../domain/models/pose_models.dart';

abstract interface class PoseDetectionService {
  Future<void> initialize();
  Future<PoseFrame?> processFrame(Object frame);
  Future<void> dispose();
  bool get isConfigured;
}

class UnavailablePoseDetectionService implements PoseDetectionService {
  @override bool get isConfigured => false;
  @override Future<void> initialize() async {}
  @override Future<PoseFrame?> processFrame(Object frame) async => null;
  @override Future<void> dispose() async {}
}