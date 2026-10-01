import 'pose_models.dart';

class SessionReport {
  const SessionReport({required this.athleteId, required this.exercise, required this.session, required this.historicalComparison, required this.observations, required this.limitations, required this.professionalReviewNote});
  final String athleteId;
  final String exercise;
  final SessionRecord session;
  final Map<String, Object?> historicalComparison;
  final List<String> observations;
  final List<String> limitations;
  final String professionalReviewNote;

  Map<String, Object?> toJson() => {
    'athleteId': athleteId,
    'exercise': exercise,
    'session': session.toJson(),
    'historicalComparison': historicalComparison,
    'observations': observations,
    'limitations': limitations,
    'professionalReviewNote': professionalReviewNote,
  };

  factory SessionReport.fromJson(Map<String, Object?> json) => SessionReport(
    athleteId: json['athleteId'] as String? ?? '',
    exercise: json['exercise'] as String? ?? '',
    session: SessionRecord.fromJson(Map<String, Object?>.from(json['session'] as Map? ?? {})),
    historicalComparison: Map<String, Object?>.from(json['historicalComparison'] as Map? ?? {}),
    observations: List<String>.from(json['observations'] as List? ?? const []),
    limitations: List<String>.from(json['limitations'] as List? ?? const []),
    professionalReviewNote: json['professionalReviewNote'] as String? ?? 'Professional assessment recommended before return to competitive activity.',
  );
}