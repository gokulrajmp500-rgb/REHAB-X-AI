import '../models/exercise_analysis_config.dart';
import '../models/pose_models.dart';

enum VoiceFeedbackLanguage { english, tamil }

class LiveVoiceFeedbackService {
  const LiveVoiceFeedbackService();

  String buildReport({
    required ExerciseAnalysisConfig config,
    required MovementMetrics? metrics,
    required double? primaryAngle,
    required String movementPhase,
    required String coachingCue,
    required VoiceFeedbackLanguage language,
  }) {
    final isTamil = language == VoiceFeedbackLanguage.tamil;
    final exerciseName = isTamil
        ? _tamilExerciseName(config.exerciseId)
        : config.displayName;
    final jointName = isTamil
        ? _tamilJointName(config.primaryJointName)
        : config.primaryJointName;
    final parts = <String>['$exerciseName ${isTamil ? 'பயிற்சி.' : 'exercise.'}'];

    if (primaryAngle != null) {
      parts.add(isTamil
          ? '$jointName கோணம் ${primaryAngle.round()} டிகிரி.'
          : '$jointName angle ${primaryAngle.round()} degrees.');
    }

    if (metrics == null || !metrics.isMeasurementValid) {
      parts.add(isTamil
          ? 'நம்பகமான அளவீடுகள் இன்னும் தயாராகவில்லை.'
          : 'Reliable measurements are not ready yet.');
    } else {
      if (config.exerciseId == 'balance' && metrics.stability != null) {
        parts.add(isTamil
            ? 'சமநிலை நிலைத்தன்மை ${metrics.stability!.round()} சதவீதம்.'
            : 'Balance stability ${metrics.stability!.round()} percent.');
      }
      if (config.exerciseId == 'balance') {
        parts.add(isTamil
            ? 'சமநிலை நேரம் ${metrics.duration.inSeconds} வினாடிகள்.'
            : 'Balance time ${metrics.duration.inSeconds} seconds.');
      } else {
        parts.add(isTamil
            ? 'இயக்க வரம்பு ${metrics.rangeOfMotion.toStringAsFixed(1)} டிகிரி; இது அதிகபட்சம் மற்றும் குறைந்தபட்ச கோணங்களின் வித்தியாசம்.'
            : 'Range of motion ${metrics.rangeOfMotion.toStringAsFixed(1)} degrees, calculated as the maximum minus minimum measured angle.');
        parts.add(isTamil
            ? 'முடிந்த மீள்செயல்கள் ${metrics.repetitions}.'
            : 'Completed repetitions ${metrics.repetitions}.');
        if (metrics.tempo != null) {
          parts.add(isTamil
              ? 'ஒரு மீள்செயலின் நேரம் ${metrics.tempo!.toStringAsFixed(1)} வினாடிகள்.'
              : 'Tempo ${metrics.tempo!.toStringAsFixed(1)} seconds per repetition.');
        }
      }
      parts.add(isTamil
          ? 'இயக்க நிலைத்தன்மை மதிப்பெண் ${metrics.consistency.toStringAsFixed(0)} சதவீதம்.'
          : 'Movement consistency score ${metrics.consistency.toStringAsFixed(0)} percent.');
      if (metrics.symmetry != null) {
        parts.add(isTamil
            ? 'இடது வலது இயக்க வேறுபாடு ${metrics.symmetry!.toStringAsFixed(1)} சதவீதம்.'
            : 'Left-to-right movement difference ${metrics.symmetry!.toStringAsFixed(1)} percent.');
      }
      if (metrics.velocity != null) {
        parts.add(isTamil
            ? 'கோண வேகம் ${metrics.velocity!.toStringAsFixed(1)} டிகிரி ஒவ்வொரு வினாடிக்கும்.'
            : 'Angular velocity ${metrics.velocity!.toStringAsFixed(1)} degrees per second.');
      }
      parts.add(isTamil
          ? 'உடல் நிலை நம்பகத்தன்மை ${(metrics.dataConfidence * 100).round()} சதவீதம்.'
          : 'Pose confidence ${(metrics.dataConfidence * 100).round()} percent.');
      parts.add(isTamil
          ? 'பயன்படுத்தக்கூடிய frame விகிதம் ${(metrics.validFrameRatio * 100).round()} சதவீதம்.'
          : 'Usable frame ratio ${(metrics.validFrameRatio * 100).round()} percent.');
    }

    final localizedPhase = _phase(movementPhase, isTamil);
    if (localizedPhase.isNotEmpty) {
      parts.add(isTamil ? 'இயக்க நிலை $localizedPhase.' : 'Movement phase $localizedPhase.');
    }
    final localizedCue = _cue(coachingCue, isTamil);
    if (localizedCue.isNotEmpty) parts.add(localizedCue);
    return parts.join(' ');
  }

  String _tamilExerciseName(String exerciseId) => switch (exerciseId) {
    'squat' || 'deep_squat' => 'ஸ்குவாட்',
    'lunge' || 'reverse_lunge' || 'forward_lunge' || 'split_squat' => 'லஞ்ச்',
    'balance' => 'ஒற்றைக்கால் சமநிலை',
    'shoulder_flexion' || 'arm_raise' => 'தோள் முன்நீட்டல்',
    'shoulder_abduction' => 'தோள் பக்கநீட்டல்',
    'calf_raise' => 'குதிகால் உயர்த்தல்',
    'hip_hinge' => 'இடுப்பு மடக்கல்',
    'elbow_flexion' => 'முழங்கை மடக்கல்',
    'push_up' => 'புஷ்-அப்',
    _ => 'உடற்பயிற்சி',
  };

  String _tamilJointName(String jointName) => switch (jointName.toLowerCase()) {
    'knee' => 'முழங்கால்',
    'shoulder' => 'தோள்',
    'ankle' => 'கணுக்கால்',
    'hip' => 'இடுப்பு',
    'elbow' => 'முழங்கை',
    _ => 'மூட்டு',
  };

  String _phase(String phase, bool isTamil) {
    if (!isTamil) return phase;
    return switch (phase) {
      'ASCENDING' => 'மேலே செல்லுதல்',
      'DESCENDING' => 'கீழே இறங்குதல்',
      'BOTTOM' => 'கீழ்நிலை',
      'COMPLETED' => 'முடிந்தது',
      'READY' => 'தயார்',
      'POSITIONING' => 'நிலை அமைத்தல்',
      _ => '',
    };
  }

  String _cue(String cue, bool isTamil) {
    if (cue.trim().isEmpty || cue == 'Maintain controlled movement') return '';
    if (!isTamil) return cue;
    final lowerCue = cue.toLowerCase();
    if (lowerCue.contains('full body') || lowerCue.contains('head to feet')) {
      return 'தலை முதல் பாதம் வரை உடல் கேமராவில் தெளிவாகத் தெரியும்படி நிலையைச் சரிசெய்யவும்.';
    }
    if (lowerCue.contains('step back') || lowerCue.contains('move farther back')) {
      return 'கேமராவிலிருந்து சிறிது பின்னால் செல்லவும்.';
    }
    if (lowerCue.contains('lighting') || lowerCue.contains('low confidence')) {
      return 'ஒளியை அதிகரித்து, மூட்டுகள் தெளிவாகத் தெரிகிறதா உறுதிசெய்யவும்.';
    }
    if (lowerCue.contains('multiple people')) {
      return 'ஒருவர் மட்டும் கேமரா முன் இருக்கட்டும்.';
    }
    if (lowerCue.contains('shallow') || lowerCue.contains('range of motion')) {
      return 'வலியில்லாத வசதியான வரம்பில் இயக்க ஆழத்தை மெதுவாக அதிகரிக்கவும்.';
    }
    if (lowerCue.contains('tempo') || lowerCue.contains('controlled')) {
      return 'இயக்கத்தை மெதுவாகவும் கட்டுப்பாட்டுடனும் செய்யவும்.';
    }
    return 'மேலும் பயிற்சி வழிகாட்டுதலுக்கு திரையில் உள்ள குறிப்பைப் பார்க்கவும்.';
  }
}