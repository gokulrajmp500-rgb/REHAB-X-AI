import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/core/utils/joint_angle_calculator.dart';
import 'package:flutter_application_1/core/filters/one_euro_filter.dart';
import 'package:flutter_application_1/core/filters/outlier_detector.dart';
import 'package:flutter_application_1/core/calibration/distance_calibrator.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/models/exercise_analysis_config.dart';
import 'package:flutter_application_1/domain/services/measurement_validator.dart';
import 'package:flutter_application_1/domain/services/movement_features.dart';
import 'package:flutter_application_1/data/repositories/session_repository.dart';
import 'package:flutter_application_1/data/services/ai_coach_service.dart';

void main() {
  group('Precision Computer Vision Engine Tests (Requirement 54)', () {
    // 1. Vector Angle Calculation
    test('1. Vector angle calculation produces exact geometric angles', () {
      // 90 degree orthogonal angle: (0, 1) -> (0, 0) -> (1, 0)
      final angle90 = JointAngleCalculator.calculateAngle(
        const PoseLandmark(name: 'hip', x: 0, y: 1),
        const PoseLandmark(name: 'knee', x: 0, y: 0),
        const PoseLandmark(name: 'ankle', x: 1, y: 0),
      );
      expect(angle90, isNotNull);
      expect((angle90! - 90.0).abs(), lessThan(0.01));

      // 180 degree straight angle: (0, 1) -> (0, 0) -> (0, -1)
      final angle180 = JointAngleCalculator.calculateAngle(
        const PoseLandmark(name: 'hip', x: 0, y: 1),
        const PoseLandmark(name: 'knee', x: 0, y: 0),
        const PoseLandmark(name: 'ankle', x: 0, y: -1),
      );
      expect(angle180, isNotNull);
      expect((angle180! - 180.0).abs(), lessThan(0.01));

      // 45 degree angle: (0, 1) -> (0, 0) -> (1, 1)
      final angle45 = JointAngleCalculator.calculateAngle(
        const PoseLandmark(name: 'hip', x: 0, y: 1),
        const PoseLandmark(name: 'knee', x: 0, y: 0),
        const PoseLandmark(name: 'ankle', x: 1, y: 1),
      );
      expect(angle45, isNotNull);
      expect((angle45! - 45.0).abs(), lessThan(0.01));

      // Degenerate / coincident points return null because angle is undefined
      final angleZero = JointAngleCalculator.calculateAngle(
        const PoseLandmark(name: 'hip', x: 0, y: 0),
        const PoseLandmark(name: 'knee', x: 0, y: 0),
        const PoseLandmark(name: 'ankle', x: 1, y: 0),
      );
      expect(angleZero, isNull);
    });

    test('Front camera mirror is display-only and does not alter anatomical left/right data', () {
      const raw = PoseLandmark(name: 'leftShoulder', x: 120, y: 150, confidence: 0.9);

      final displayed = PoseCoordinateTransformer.displayPose(
        raw,
        imageWidth: 400,
        isFrontCamera: true,
      );

      expect(displayed.x, 280);
      expect(displayed.y, 150);
      expect(raw.x, 120);
      expect(raw.name, 'leftShoulder');
    });

    // 2. One Euro Filter Temporal Smoothing
    test('2. One Euro Filter reduces landmark jitter while tracking movement', () {
      final filter = OneEuroFilter1D(minCutoff: 1.0, beta: 0.005);
      final rawXValues = [100.0, 103.2, 98.4, 102.1, 99.0, 101.5, 98.7, 102.8];
      final filteredXValues = <double>[];

      for (var i = 0; i < rawXValues.length; i++) {
        final t = i * (1.0 / 30.0);
        final filtered = filter.filter(rawXValues[i], t);
        filteredXValues.add(filtered);
      }

      // Filtered values should have lower variance around mean 100.0 than noisy inputs
      final rawDev = rawXValues.map((v) => (v - 100.0).abs()).reduce((a, b) => a + b) / rawXValues.length;
      final filteredDev = filteredXValues.map((v) => (v - 100.0).abs()).reduce((a, b) => a + b) / filteredXValues.length;

      expect(filteredDev, lessThan(rawDev));

      // Landmark temporal filter preserves raw coordinates and marks isFiltered
      final frameFilter = LandmarkTemporalFilter();
      final rawFrame = PoseFrame(
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
        landmarks: const {
          'knee': PoseLandmark(name: 'knee', x: 104.0, y: 202.0, confidence: 0.95),
        },
      );

      final smoothedFrame = frameFilter.filterFrame(rawFrame);
      final kneeLandmark = smoothedFrame.landmarks['knee']!;
      expect(kneeLandmark.isFiltered, isTrue);
      expect(kneeLandmark.rawX, 104.0);
      expect(kneeLandmark.rawY, 202.0);
    });

    // 3. Angular Outlier Rejection
    test('3. Outlier detector rejects physically impossible angular velocity spikes', () {
      const detector = OutlierDetector(maxSingleFrameJumpDeg: 45.0);

      // Spike: 82 -> 171 -> 84 (a +89 jump then -87 fall)
      final sanitized = detector.sanitizeAngleSeries([82.0, 171.0, 84.0]);

      expect(sanitized.length, 3);
      expect(sanitized[0], 82.0);
      // Spike at index 1 is suppressed and replaced by linear interpolation: (82 + 84) / 2 = 83.0
      expect(sanitized[1], 83.0);
      expect(sanitized[2], 84.0);
    });

    // 4. Repetition State Machine
    test('4. Repetition state machine completes cycle and rejects partial excursions', () {
      final machine = RepetitionStateMachine(
        minimumAngleChange: 20.0,
        isFlexionFirst: true,
      );

      // Initial standing
      machine.add(165.0, timestampSeconds: 0.0);
      expect(machine.phase, RepetitionPhase.ready);
      expect(machine.count, 0);

      // Descending
      machine.add(140.0, timestampSeconds: 1.0);
      expect(machine.phase, RepetitionPhase.descending);

      // Bottom
      machine.add(100.0, timestampSeconds: 2.0);
      expect(machine.phase, RepetitionPhase.bottom);

      // Ascending
      machine.add(145.0, timestampSeconds: 3.0);
      expect(machine.phase, RepetitionPhase.ascending);

      // Completed
      machine.add(165.0, timestampSeconds: 4.0);
      expect(machine.phase, RepetitionPhase.completed);
      expect(machine.count, 1);
      expect(machine.details.length, 1);
      expect(machine.details.first.phase, 'completed');

      // Next movement: partial movement that only descends slightly (165 -> 155)
      machine.add(165.0, timestampSeconds: 5.0);
      machine.add(155.0, timestampSeconds: 6.0);
      machine.add(165.0, timestampSeconds: 7.0);
      expect(machine.count, 1); // Not counted as a full repetition
    });

    // 5. Validation Gate Evaluation
    test('5. Validation Gate evaluates all 9 checks and enforces measurement validity', () {
      final validator = const MeasurementValidator();
      const config = ExerciseAnalysisConfig.squat;

      // Passing scenario: complete movement, full landmarks, high confidence
      final now = DateTime.now();
      final validFrames = List.generate(
        30,
        (i) => PoseFrame(
          timestamp: now.add(Duration(milliseconds: i * 33)),
          landmarks: const {
            'hip': PoseLandmark(name: 'hip', x: 160, y: 200, confidence: 0.92),
            'knee': PoseLandmark(name: 'knee', x: 180, y: 320, confidence: 0.94),
            'ankle': PoseLandmark(name: 'ankle', x: 160, y: 440, confidence: 0.90),
          },
        ),
      );
      final validSequence = PoseSequence(validFrames);
      const validMetrics = MovementMetrics(
        rangeOfMotion: 75.0,
        symmetry: 92.0,
        consistency: 88.0,
        duration: Duration(seconds: 2),
        repetitions: 1,
        dataConfidence: 0.92,
        validFrameRatio: 1.0,
      );

      final passResult = validator.validate(
        sequence: validSequence,
        config: config,
        metrics: validMetrics,
        observedView: CameraViewOrientation.side,
      );

      expect(passResult.isValid, isTrue);
      expect(passResult.confidenceState, 'HIGH');
      expect(passResult.passedChecks.length, 9);
      expect(passResult.failedChecks, isEmpty);

      // Failing scenario: Missing required knee landmark
      final missingFrames = List.generate(
        20,
        (i) => PoseFrame(
          timestamp: now.add(Duration(milliseconds: i * 33)),
          landmarks: const {
            'hip': PoseLandmark(name: 'hip', x: 160, y: 200, confidence: 0.92),
            'ankle': PoseLandmark(name: 'ankle', x: 160, y: 440, confidence: 0.90),
          },
        ),
      );
      final missingSequence = PoseSequence(missingFrames);
      final failResult = validator.validate(
        sequence: missingSequence,
        config: config,
        metrics: const MovementMetrics(
          rangeOfMotion: 0.0,
          symmetry: 0.0,
          consistency: 0.0,
          duration: Duration(seconds: 1),
          repetitions: 0,
          dataConfidence: 0.40,
          validFrameRatio: 0.30,
        ),
      );

      expect(failResult.isValid, isFalse);
      expect(failResult.confidenceState, 'INSUFFICIENT');
      expect(failResult.failureReason, contains('Required Knee landmarks were not visible'));
    });

    // 6. Insufficient Data Handling
    test('6. Refuses insufficient pose data instead of manufacturing metrics', () {
      const config = ExerciseAnalysisConfig.squat;
      final validator = const MeasurementValidator();

      // Sequence with zero dynamic excursion (static standing for 15 frames)
      final staticFrames = List.generate(
        15,
        (i) => PoseFrame(
          timestamp: DateTime.now().add(Duration(milliseconds: i * 50)),
          landmarks: const {
            'hip': PoseLandmark(name: 'hip', x: 160, y: 200, confidence: 0.9),
            'knee': PoseLandmark(name: 'knee', x: 160, y: 320, confidence: 0.9),
            'ankle': PoseLandmark(name: 'ankle', x: 160, y: 440, confidence: 0.9),
          },
        ),
      );
      final staticSeq = PoseSequence(staticFrames);
      const staticMetrics = MovementMetrics(
        rangeOfMotion: 0.0,
        symmetry: 100.0,
        consistency: 100.0,
        duration: Duration(seconds: 1),
        repetitions: 0,
        dataConfidence: 0.9,
        validFrameRatio: 1.0,
      );

      final result = validator.validate(sequence: staticSeq, config: config, metrics: staticMetrics);
      expect(result.isValid, isFalse);
      expect(result.statusMessage, 'INSUFFICIENT DATA');
      expect(result.failedChecks, anyElement(contains('No significant dynamic movement detected')));
    });

    // 7. Distance Calibration
    test('7. Enforces relative measurement when uncalibrated and prevents fake centimeters', () {
      // Uncalibrated state
      const uncalibrated = DistanceCalibration(isCalibrated: false);
      expect(uncalibrated.isCalibrated, isFalse);
      expect(uncalibrated.estimateCm(120.0), isNull);
      expect(uncalibrated.formatDistance(120.0), contains('uncalibrated'));

      // Calibrated state using athlete height (180 cm) with body span of 1440 pixels
      final calibrated = DistanceCalibration.fromAthleteHeight(
        athleteHeightCm: 180.0,
        bodyPixelHeight: 1440.0,
      );
      expect(calibrated.isCalibrated, isTrue);
      expect(calibrated.estimateCm(120.0), isNotNull);
      expect((calibrated.estimateCm(120.0)! - 15.0).abs(), lessThan(0.01)); // 120 / (1440 / 180) = 15 cm
      expect(calibrated.formatDistance(120.0), contains('15.0 cm'));
      expect(calibrated.formatDistance(120.0), contains('Camera-calibrated estimate'));
    });

    // 8. Bilateral Asymmetry Calculation
    test('8. Calculates bilateral asymmetry without fabricated numbers', () {
      // 0% asymmetry when left and right are identical
      final sym100 = calculateAsymmetry(90.0, 90.0);
      expect(sym100, 0.0);

      // Asymmetry calculation: |100 - 80| / 90 * 100 = 22.22%
      final symDiff = calculateAsymmetry(100.0, 80.0);
      expect((symDiff - 22.22).abs(), lessThan(0.1));
    });

    // 9. AI Safety Grounding Filter
    test('9. AI Safety Filter withholds medical claims and diagnoses', () {
      final filter = AiSafetyFilter();

      const unsafeResponse = AiCoachResponse(
        summary: 'Athlete is medically cleared. Your ligament tear is healed.',
        observations: ['Good knee stability.'],
        trainingSuggestions: ['Safe to play soccer tomorrow.'],
        professionalReviewQuestions: [],
        limitations: [],
      );

      final safeResponse = filter.validate(unsafeResponse);
      expect(safeResponse.summary, contains('withheld'));
      expect(safeResponse.limitations, contains('Movement-analysis support, not medical diagnosis.'));
      expect(safeResponse.basedOn, 'Safety compliance policy');

      // Compliant kinematic response passes through unchanged
      const compliantResponse = AiCoachResponse(
        summary: 'Active knee flexion achieved 115° with smooth 2.4s tempo.',
        observations: ['Consistent movement trajectory observed.'],
        trainingSuggestions: ['Maintain current cadence.'],
        professionalReviewQuestions: ['Discuss depth progression with your trainer.'],
        limitations: ['2D camera approximation.'],
      );

      final cleanResponse = filter.validate(compliantResponse);
      expect(cleanResponse.summary, compliantResponse.summary);
    });

    // 10. Precision Session Persistence
    test('10. Session persistence round-trips precision CV metadata', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = LocalSessionRepository(preferences);

      const metrics = MovementMetrics(
        rangeOfMotion: 88.5,
        symmetry: 94.2,
        consistency: 91.0,
        duration: Duration(seconds: 12),
        repetitions: 5,
        dataConfidence: 0.94,
        validFrameRatio: 0.96,
        dataConfidenceState: 'HIGH',
        viewAngleObserved: 'side',
        isMeasurementValid: true,
      );

      final session = SessionRecord(
        id: 'session-prec-001',
        athleteId: 'athlete-100',
        exercise: 'Bodyweight Squat',
        exerciseId: 'squat',
        timestamp: DateTime(2026, 3, 15, 14, 30),
        metrics: metrics,
        observations: ['Kinematic trajectory verified.'],
        limitations: ['2D camera measurement.'],
        qualityLabel: 'good',
        modelVersion: 'mlkit-integrated',
        analysisStatus: 'measured',
        sourceMode: 'live',
      );

      await repository.create(session);
      final restored = await repository.read('session-prec-001');

      expect(restored, isNotNull);
      expect(restored!.metrics.rangeOfMotion, 88.5);
      expect(restored.metrics.dataConfidenceState, 'HIGH');
      expect(restored.metrics.viewAngleObserved, 'side');
      expect(restored.metrics.isMeasurementValid, isTrue);
      expect(restored.sourceMode, 'live');
    });
  });
}
