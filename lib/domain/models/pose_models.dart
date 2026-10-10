import '../../core/utils/joint_angle_calculator.dart';

class PoseCoordinateTransformer {
  const PoseCoordinateTransformer();

  static PoseLandmark displayPose(
    PoseLandmark landmark, {
    required double imageWidth,
    required bool isFrontCamera,
  }) {
    if (imageWidth <= 0 || !isFrontCamera) {
      return landmark;
    }

    final mirroredX = imageWidth - landmark.x;
    return PoseLandmark(
      name: landmark.name,
      x: mirroredX,
      y: landmark.y,
      z: landmark.z,
      confidence: landmark.confidence,
      rawX: landmark.rawX ?? landmark.x,
      rawY: landmark.rawY ?? landmark.y,
      isFiltered: landmark.isFiltered,
    );
  }

  static Map<String, PoseLandmark> displayMap(
    Map<String, PoseLandmark> source, {
    required double imageWidth,
    required bool isFrontCamera,
  }) {
    if (!isFrontCamera || imageWidth <= 0) {
      return source;
    }

    return source.map(
      (key, value) => MapEntry(
        key,
        displayPose(value, imageWidth: imageWidth, isFrontCamera: true),
      ),
    );
  }
}

class PoseLandmark {
  const PoseLandmark({
    required this.name,
    required this.x,
    required this.y,
    this.z = 0,
    this.confidence = 1,
    this.rawX,
    this.rawY,
    this.isFiltered = false,
  });
  final String name;
  final double x;
  final double y;
  final double z;
  final double confidence;
  final double? rawX;
  final double? rawY;
  final bool isFiltered;

  bool get isValid =>
      x.isFinite &&
      y.isFinite &&
      z.isFinite &&
      confidence.isFinite &&
      confidence >= 0.5;

  Map<String, Object?> toJson() => {
    'name': name,
    'x': x,
    'y': y,
    'z': z,
    'confidence': confidence,
    'rawX': rawX,
    'rawY': rawY,
    'isFiltered': isFiltered,
  };

  factory PoseLandmark.fromJson(Map<String, Object?> json) => PoseLandmark(
    name: json['name'] as String? ?? '',
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    z: (json['z'] as num?)?.toDouble() ?? 0,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    rawX: (json['rawX'] as num?)?.toDouble(),
    rawY: (json['rawY'] as num?)?.toDouble(),
    isFiltered: json['isFiltered'] as bool? ?? false,
  );
}

class PoseFrame {
  const PoseFrame({
    required this.timestamp,
    required this.landmarks,
    this.imageWidth,
    this.imageHeight,
    this.personCount = 1,
    this.isMultiPerson = false,
  });
  final DateTime timestamp;
  final Map<String, PoseLandmark> landmarks;
  final int? imageWidth;
  final int? imageHeight;
  final int personCount;
  final bool isMultiPerson;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'personCount': personCount,
    'isMultiPerson': isMultiPerson,
    'landmarks': landmarks.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory PoseFrame.fromJson(Map<String, Object?> json) => PoseFrame(
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    imageWidth: (json['imageWidth'] as num?)?.toInt(),
    imageHeight: (json['imageHeight'] as num?)?.toInt(),
    personCount: (json['personCount'] as num?)?.toInt() ?? 1,
    isMultiPerson: json['isMultiPerson'] as bool? ?? false,
    landmarks: Map<String, PoseLandmark>.fromEntries(
      (json['landmarks'] as Map? ?? {}).entries.map(
        (entry) => MapEntry(
          entry.key.toString(),
          PoseLandmark.fromJson(Map<String, Object?>.from(entry.value as Map)),
        ),
      ),
    ),
  );
}

class PoseSequence {
  const PoseSequence(this.frames);
  final List<PoseFrame> frames;
  bool get isSufficient =>
      frames.length >= 3 &&
      frames.any(
        (frame) => frame.landmarks.values.any((landmark) => landmark.isValid),
      );
  double get dataConfidence {
    final landmarks = frames
        .expand((frame) => frame.landmarks.values)
        .where((landmark) => landmark.confidence.isFinite)
        .toList();
    if (landmarks.isEmpty) return 0;
    return landmarks
            .map((landmark) => landmark.confidence)
            .reduce((first, second) => first + second) /
        landmarks.length;
  }

  bool hasLandmarks(Iterable<String> names) =>
      frames.any((frame) => names.every((name) => _hasLandmark(frame, name)));

  bool _hasLandmark(PoseFrame frame, String name) {
    if (frame.landmarks[name]?.isValid == true) return true;
    final aliases = switch (name) {
      'hip' || 'knee' || 'ankle' || 'shoulder' || 'elbow' || 'wrist' => [
        'left${name[0].toUpperCase()}${name.substring(1)}',
        'right${name[0].toUpperCase()}${name.substring(1)}',
      ],
      'foot' => const [
        'leftFootIndex',
        'rightFootIndex',
        'leftHeel',
        'rightHeel',
      ],
      _ => const <String>[],
    };
    return aliases.any((alias) => frame.landmarks[alias]?.isValid == true);
  }
}

class RepetitionDetail {
  const RepetitionDetail({
    required this.repNumber,
    required this.durationSeconds,
    required this.rangeOfMotion,
    this.tempo,
    this.consistency,
    this.phase = 'completed',
    this.timestampSeconds = 0,
    this.hasVariation = false,
    this.descentDuration,
    this.bottomDuration,
    this.ascentDuration,
    this.confidenceLevel = 'HIGH',
  });

  final int repNumber;
  final double durationSeconds;
  final double rangeOfMotion;
  final double? tempo;
  final double? consistency;
  final String phase;
  final double timestampSeconds;
  final bool hasVariation;
  final double? descentDuration;
  final double? bottomDuration;
  final double? ascentDuration;
  final String confidenceLevel;

  Map<String, Object?> toJson() => {
    'repNumber': repNumber,
    'durationSeconds': durationSeconds,
    'rangeOfMotion': rangeOfMotion,
    'tempo': tempo,
    'consistency': consistency,
    'phase': phase,
    'timestampSeconds': timestampSeconds,
    'hasVariation': hasVariation,
    'descentDuration': descentDuration,
    'bottomDuration': bottomDuration,
    'ascentDuration': ascentDuration,
    'confidenceLevel': confidenceLevel,
  };

  factory RepetitionDetail.fromJson(Map<String, Object?> json) =>
      RepetitionDetail(
        repNumber: (json['repNumber'] as num?)?.toInt() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
        rangeOfMotion: (json['rangeOfMotion'] as num?)?.toDouble() ?? 0,
        tempo: (json['tempo'] as num?)?.toDouble(),
        consistency: (json['consistency'] as num?)?.toDouble(),
        phase: json['phase'] as String? ?? 'completed',
        timestampSeconds: (json['timestampSeconds'] as num?)?.toDouble() ?? 0,
        hasVariation: json['hasVariation'] as bool? ?? false,
        descentDuration: (json['descentDuration'] as num?)?.toDouble(),
        bottomDuration: (json['bottomDuration'] as num?)?.toDouble(),
        ascentDuration: (json['ascentDuration'] as num?)?.toDouble(),
        confidenceLevel: json['confidenceLevel'] as String? ?? 'HIGH',
      );
}

class JointMetricSummary {
  const JointMetricSummary({
    required this.jointName,
    required this.currentAngle,
    required this.rangeOfMotion,
    this.minAngle,
    this.maxAngle,
    this.symmetryDifference,
    this.consistency,
    this.observation = '',
    this.confidenceLevel = 'HIGH',
    this.isAvailable = true,
  });

  final String jointName;
  final double currentAngle;
  final double rangeOfMotion;
  final double? minAngle;
  final double? maxAngle;
  final double? symmetryDifference;
  final double? consistency;
  final String observation;
  final String confidenceLevel;
  final bool isAvailable;

  Map<String, Object?> toJson() => {
    'jointName': jointName,
    'currentAngle': currentAngle,
    'rangeOfMotion': rangeOfMotion,
    'minAngle': minAngle,
    'maxAngle': maxAngle,
    'symmetryDifference': symmetryDifference,
    'consistency': consistency,
    'observation': observation,
    'confidenceLevel': confidenceLevel,
    'isAvailable': isAvailable,
  };

  factory JointMetricSummary.fromJson(Map<String, Object?> json) =>
      JointMetricSummary(
        jointName: json['jointName'] as String? ?? '',
        currentAngle: (json['currentAngle'] as num?)?.toDouble() ?? 0,
        rangeOfMotion: (json['rangeOfMotion'] as num?)?.toDouble() ?? 0,
        minAngle: (json['minAngle'] as num?)?.toDouble(),
        maxAngle: (json['maxAngle'] as num?)?.toDouble(),
        symmetryDifference: (json['symmetryDifference'] as num?)?.toDouble(),
        consistency: (json['consistency'] as num?)?.toDouble(),
        observation: json['observation'] as String? ?? '',
        confidenceLevel: json['confidenceLevel'] as String? ?? 'HIGH',
        isAvailable: json['isAvailable'] as bool? ?? true,
      );
}

class MovementMetrics {
  const MovementMetrics({
    required this.rangeOfMotion,
    required this.symmetry,
    required this.consistency,
    required this.duration,
    required this.repetitions,
    this.stability,
    this.velocity,
    this.tempo,
    this.dataConfidence = 0,
    this.validFrameRatio = 0,
    this.repetitionDetails = const [],
    this.jointBreakdown = const {},
    this.dataConfidenceState = 'HIGH',
    this.viewAngleObserved = 'side',
    this.isMeasurementValid = true,
  });

  final double rangeOfMotion;
  final double? symmetry;
  final double consistency;
  final double? stability;
  final double? velocity;
  final double? tempo;
  final double dataConfidence;
  final double validFrameRatio;
  final Duration duration;
  final int repetitions;
  final List<RepetitionDetail> repetitionDetails;
  final Map<String, JointMetricSummary> jointBreakdown;
  final String dataConfidenceState;
  final String viewAngleObserved;
  final bool isMeasurementValid;

  Map<String, Object?> toJson() => {
    'rangeOfMotion': rangeOfMotion,
    'symmetry': symmetry,
    'consistency': consistency,
    'stability': stability,
    'velocity': velocity,
    'tempo': tempo,
    'dataConfidence': dataConfidence,
    'validFrameRatio': validFrameRatio,
    'durationSeconds': duration.inSeconds,
    'repetitions': repetitions,
    'repetitionDetails': repetitionDetails
        .map((detail) => detail.toJson())
        .toList(),
    'jointBreakdown': jointBreakdown.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'dataConfidenceState': dataConfidenceState,
    'viewAngleObserved': viewAngleObserved,
    'isMeasurementValid': isMeasurementValid,
  };

  factory MovementMetrics.fromJson(Map<String, Object?> json) =>
      MovementMetrics(
        rangeOfMotion: (json['rangeOfMotion'] as num?)?.toDouble() ?? 0,
        symmetry: (json['symmetry'] as num?)?.toDouble(),
        consistency: (json['consistency'] as num?)?.toDouble() ?? 0,
        stability: (json['stability'] as num?)?.toDouble(),
        velocity: (json['velocity'] as num?)?.toDouble(),
        tempo: (json['tempo'] as num?)?.toDouble(),
        dataConfidence: (json['dataConfidence'] as num?)?.toDouble() ?? 0,
        validFrameRatio: (json['validFrameRatio'] as num?)?.toDouble() ?? 0,
        duration: Duration(
          seconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        ),
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
        repetitionDetails: (json['repetitionDetails'] as List? ?? const [])
            .map(
              (e) => RepetitionDetail.fromJson(
                Map<String, Object?>.from(e as Map),
              ),
            )
            .toList(),
        jointBreakdown: (json['jointBreakdown'] as Map? ?? const {}).map(
          (k, v) => MapEntry(
            k.toString(),
            JointMetricSummary.fromJson(Map<String, Object?>.from(v as Map)),
          ),
        ),
        dataConfidenceState: json['dataConfidenceState'] as String? ?? 'HIGH',
        viewAngleObserved: json['viewAngleObserved'] as String? ?? 'side',
        isMeasurementValid: json['isMeasurementValid'] as bool? ?? true,
      );
}

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.athleteId,
    required this.exercise,
    this.exerciseId = '',
    required this.timestamp,
    required this.metrics,
    this.observations = const [],
    this.limitations = const [],
    this.qualityLabel = 'unknown',
    this.modelVersion = 'unconfigured',
    this.analysisStatus = 'measured',
    this.isDemo = false,
    this.sourceMode = 'live',
  });

  final String id;
  final String athleteId;
  final String exercise;
  final String exerciseId;
  final DateTime timestamp;
  final MovementMetrics metrics;
  final List<String> observations;
  final List<String> limitations;
  final String qualityLabel;
  final String modelVersion;
  final String analysisStatus;
  final bool isDemo;
  final String sourceMode; // 'live' | 'video' | 'demo'

  double get qualityScore {
    final confidence = metrics.dataConfidence * 100;
    return ((metrics.consistency * 0.6) + (confidence * 0.4)).clamp(0.0, 100.0);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'athleteId': athleteId,
    'exercise': exercise,
    'exerciseId': exerciseId,
    'timestamp': timestamp.toIso8601String(),
    'metrics': metrics.toJson(),
    'observations': observations,
    'limitations': limitations,
    'qualityLabel': qualityLabel,
    'modelVersion': modelVersion,
    'analysisStatus': analysisStatus,
    'isDemo': isDemo,
    'sourceMode': sourceMode,
  };

  factory SessionRecord.fromJson(Map<String, Object?> json) => SessionRecord(
    id: json['id'] as String? ?? '',
    athleteId: json['athleteId'] as String? ?? '',
    exercise: json['exercise'] as String? ?? '',
    exerciseId: json['exerciseId'] as String? ?? '',
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    metrics: MovementMetrics.fromJson(
      Map<String, Object?>.from(json['metrics'] as Map? ?? {}),
    ),
    observations: List<String>.from(json['observations'] as List? ?? const []),
    limitations: List<String>.from(json['limitations'] as List? ?? const []),
    qualityLabel: json['qualityLabel'] as String? ?? 'unknown',
    modelVersion: json['modelVersion'] as String? ?? 'unknown',
    analysisStatus: json['analysisStatus'] as String? ?? 'unknown',
    isDemo: json['isDemo'] as bool? ?? false,
    sourceMode: json['sourceMode'] as String? ?? 'live',
  );
}

double angleBetween(
  PoseLandmark first,
  PoseLandmark vertex,
  PoseLandmark third,
) {
  return JointAngleCalculator.calculateAngle(first, vertex, third) ?? 0.0;
}
