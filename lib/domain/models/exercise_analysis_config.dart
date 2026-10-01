/// Camera view orientations supported by the analysis pipeline.
enum CameraViewOrientation {
  side,
  front,
  rear,
  oblique,
}

/// Analysis contract for each supported exercise.
class ExerciseAnalysisConfig {
  const ExerciseAnalysisConfig({
    required this.exerciseId,
    required this.displayName,
    required this.requiredLandmarks,
    this.optionalLandmarks = const [],
    this.requiresFullBody = false,
    required this.preferredCameraView,
    this.acceptableCameraViews = const [],
    this.minimumConfidence = 0.55,
    this.minimumValidFrameRatio = 0.65,
    this.minimumRepAngleChange = 15.0,
    this.minimumRepDurationSec = 0.6,
    this.maximumPlausibleAngle = 185.0,
    this.minimumPlausibleAngle = 10.0,
    this.primaryJointName = 'Knee',
    this.supportedMetrics = const [
      'Repetitions',
      'Range of Motion',
      'Kinematic Consistency',
      'Repetition Tempo',
      'Bilateral Symmetry',
    ],
    this.invalidationConditions = const [
      'Required landmarks missing or occluded',
      'Valid frame ratio below threshold',
      'Athlete orientation incompatible with geometry plane',
      'Multi-person occlusion detected',
    ],
  });

  final String exerciseId;
  final String displayName;
  final List<String> requiredLandmarks;
  final List<String> optionalLandmarks;
  final bool requiresFullBody;
  final CameraViewOrientation preferredCameraView;
  final List<CameraViewOrientation> acceptableCameraViews;
  final double minimumConfidence;
  final double minimumValidFrameRatio;
  final double minimumRepAngleChange;
  final double minimumRepDurationSec;
  final double maximumPlausibleAngle;
  final double minimumPlausibleAngle;
  final String primaryJointName;
  final List<String> supportedMetrics;
  final List<String> invalidationConditions;

  bool isViewAcceptable(CameraViewOrientation view) {
    return view == preferredCameraView || acceptableCameraViews.contains(view);
  }

  /// Preset configurations for all supported exercises
  static const squat = ExerciseAnalysisConfig(
    exerciseId: 'squat',
    displayName: 'Bodyweight Squat',
    requiredLandmarks: ['hip', 'knee', 'ankle'],
    optionalLandmarks: ['shoulder'],
    requiresFullBody: true,
    preferredCameraView: CameraViewOrientation.side,
    acceptableCameraViews: [CameraViewOrientation.front],
    minimumConfidence: 0.60,
    minimumValidFrameRatio: 0.70,
    minimumRepAngleChange: 20.0,
    primaryJointName: 'Knee',
  );

  static const lunge = ExerciseAnalysisConfig(
    exerciseId: 'lunge',
    displayName: 'Walking / Static Lunge',
    requiredLandmarks: ['hip', 'knee', 'ankle'],
    optionalLandmarks: ['shoulder'],
    requiresFullBody: true,
    preferredCameraView: CameraViewOrientation.side,
    acceptableCameraViews: [CameraViewOrientation.oblique],
    minimumConfidence: 0.60,
    minimumValidFrameRatio: 0.70,
    minimumRepAngleChange: 20.0,
    primaryJointName: 'Knee',
  );

  static const singleLegBalance = ExerciseAnalysisConfig(
    exerciseId: 'balance',
    displayName: 'Single-Leg Balance',
    requiredLandmarks: ['hip', 'ankle'],
    optionalLandmarks: ['knee', 'shoulder'],
    requiresFullBody: true,
    preferredCameraView: CameraViewOrientation.front,
    acceptableCameraViews: [CameraViewOrientation.side],
    minimumConfidence: 0.55,
    minimumValidFrameRatio: 0.65,
    minimumRepAngleChange: 5.0,
    primaryJointName: 'Hip / Pelvis',
  );

  static const shoulderFlexion = ExerciseAnalysisConfig(
    exerciseId: 'shoulder_flexion',
    displayName: 'Shoulder Flexion',
    requiredLandmarks: ['shoulder', 'elbow', 'hip'],
    optionalLandmarks: ['wrist'],
    preferredCameraView: CameraViewOrientation.side,
    acceptableCameraViews: [CameraViewOrientation.front],
    minimumConfidence: 0.60,
    minimumValidFrameRatio: 0.70,
    minimumRepAngleChange: 25.0,
    primaryJointName: 'Shoulder',
  );

  static const shoulderAbduction = ExerciseAnalysisConfig(
    exerciseId: 'shoulder_abduction',
    displayName: 'Shoulder Abduction',
    requiredLandmarks: ['shoulder', 'elbow', 'hip'],
    optionalLandmarks: ['wrist'],
    preferredCameraView: CameraViewOrientation.front,
    acceptableCameraViews: [CameraViewOrientation.rear],
    minimumConfidence: 0.60,
    minimumValidFrameRatio: 0.70,
    minimumRepAngleChange: 25.0,
    primaryJointName: 'Shoulder',
  );

  static const calfRaise = ExerciseAnalysisConfig(
    exerciseId: 'calf_raise',
    displayName: 'Standing Calf Raise',
    requiredLandmarks: ['knee', 'ankle', 'foot'],
    optionalLandmarks: ['hip'],
    requiresFullBody: true,
    preferredCameraView: CameraViewOrientation.side,
    acceptableCameraViews: [CameraViewOrientation.rear],
    minimumConfidence: 0.55,
    minimumValidFrameRatio: 0.65,
    minimumRepAngleChange: 10.0,
    primaryJointName: 'Ankle',
  );

  static const hipHinge = ExerciseAnalysisConfig(
    exerciseId: 'hip_hinge',
    displayName: 'Romanian Deadlift / Hip Hinge',
    requiredLandmarks: ['shoulder', 'hip', 'knee'],
    optionalLandmarks: ['ankle'],
    requiresFullBody: true,
    preferredCameraView: CameraViewOrientation.side,
    acceptableCameraViews: [],
    minimumConfidence: 0.60,
    minimumValidFrameRatio: 0.70,
    minimumRepAngleChange: 20.0,
    primaryJointName: 'Hip',
  );

  static const elbowFlexion = ExerciseAnalysisConfig(
    exerciseId: 'elbow_flexion',
    displayName: 'Biceps / Elbow Flexion',
    requiredLandmarks: ['shoulder', 'elbow', 'wrist'],
    optionalLandmarks: ['hip'],
    preferredCameraView: CameraViewOrientation.side,
    acceptableCameraViews: [CameraViewOrientation.front],
    minimumConfidence: 0.60,
    minimumValidFrameRatio: 0.70,
    minimumRepAngleChange: 25.0,
    primaryJointName: 'Elbow',
  );

  static const pushUp = ExerciseAnalysisConfig(
    exerciseId: 'push_up',
    displayName: 'Standard Push-Up',
    requiredLandmarks: ['shoulder', 'elbow', 'wrist'],
    optionalLandmarks: ['hip', 'knee', 'ankle'],
    requiresFullBody: true,
    preferredCameraView: CameraViewOrientation.side,
    acceptableCameraViews: [],
    minimumConfidence: 0.60,
    minimumValidFrameRatio: 0.70,
    minimumRepAngleChange: 25.0,
    primaryJointName: 'Elbow',
  );

  static ExerciseAnalysisConfig? forId(String id) => switch (id) {
        'squat' || 'deep_squat' => squat,
        'lunge' || 'reverse_lunge' || 'forward_lunge' || 'split_squat' => lunge,
        'balance' => singleLegBalance,
        'shoulder_flexion' || 'arm_raise' => shoulderFlexion,
        'shoulder_abduction' => shoulderAbduction,
        'calf_raise' => calfRaise,
        'hip_hinge' => hipHinge,
        'elbow_flexion' => elbowFlexion,
        'push_up' => pushUp,
        _ => null,
      };
}

