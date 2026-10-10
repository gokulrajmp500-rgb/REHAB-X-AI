import 'mlkit_pose_detection_service.dart'
    if (dart.library.html) 'web_pose_detection_service.dart' as implementation;
import 'pose_detection_service.dart';

PoseDetectionService createPoseDetectionService() =>
    implementation.PoseDetectionServiceImpl();
