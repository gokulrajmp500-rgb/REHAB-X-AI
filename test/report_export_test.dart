import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/services/report_export_service.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/models/session_report.dart';

void main() {
  test('exports a report-ready text representation without medical claims', () {
    final session = SessionRecord(id: 's', athleteId: 'a', exercise: 'Squat', timestamp: DateTime(2026), metrics: const MovementMetrics(rangeOfMotion: 20, symmetry: null, consistency: 80, duration: Duration(seconds: 30), repetitions: 3, dataConfidence: .8), qualityLabel: 'strong');
    final text = ReportExportService().toShareableText(SessionReport(athleteId: 'a', exercise: 'Squat', session: session, historicalComparison: const {}, observations: const ['Observed ROM increased.'], limitations: const [], professionalReviewNote: 'Professional review recommended.'));
    expect(text, contains('REHAB-X AI'));
    expect(text, contains('not medical diagnosis'));
    expect(text, isNot(contains('medically cleared')));
  });

  test('generates non-empty PDF bytes and structured sections', () async {
    final session = SessionRecord(id: 's', athleteId: 'a', exercise: 'Squat', timestamp: DateTime(2026), metrics: const MovementMetrics(rangeOfMotion: 20, symmetry: null, consistency: 80, duration: Duration(seconds: 30), repetitions: 3, dataConfidence: .8), qualityLabel: 'strong');
    final report = SessionReport(athleteId: 'a', exercise: 'Squat', session: session, historicalComparison: const {}, observations: const ['Observed ROM increased.'], limitations: const [], professionalReviewNote: 'Professional review recommended.');
    final service = ReportExportService();
    expect(service.toDocument(report).sections, isNotEmpty);
    final result = await service.toPdf(report);
    expect(result.success, isTrue);
    expect(result.bytes, isNotEmpty);
  });
}