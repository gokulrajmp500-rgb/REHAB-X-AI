import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';

import '../models/athlete_profile.dart';
import '../../domain/models/pose_models.dart';
import '../../domain/models/session_report.dart';

class ReportMetric {
  const ReportMetric(this.label, this.value);
  final String label;
  final String value;
  Map<String, String> toJson() => {'label': label, 'value': value};
}

class ReportSection {
  const ReportSection(this.title, this.lines);
  final String title;
  final List<String> lines;
  Map<String, Object?> toJson() => {'title': title, 'lines': lines};
}

class ReportDocument {
  const ReportDocument({
    required this.title,
    required this.subtitle,
    required this.sections,
  });
  final String title;
  final String subtitle;
  final List<ReportSection> sections;
  Map<String, Object?> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'sections': sections.map((section) => section.toJson()).toList(),
  };
}

class ReportExportResult {
  const ReportExportResult({required this.success, this.bytes, this.errorMessage});
  final bool success;
  final Uint8List? bytes;
  final String? errorMessage;
}

class DateRangeReport {
  const DateRangeReport({
    required this.profile,
    required this.sessions,
    required this.start,
    required this.end,
    this.roomTemperature = 'Not recorded',
  });

  final AthleteProfile profile;
  final List<SessionRecord> sessions;
  final DateTime start;
  final DateTime end;
  final String roomTemperature;
}

class ReportExportService {
  ReportDocument toDocument(SessionReport report) {
    final session = report.session;
    final m = session.metrics;

    final metricsLines = <String>[
      'Duration: ${m.duration.inSeconds} seconds',
      'Completed Repetitions: ${m.repetitions}',
      'Active Range of Motion: ${m.rangeOfMotion.toStringAsFixed(1)}°',
      'Kinematic Consistency: ${m.consistency.toStringAsFixed(1)}%',
      if (m.symmetry != null) 'Bilateral Asymmetry: ${m.symmetry!.toStringAsFixed(1)}%',
      if (m.velocity != null) 'Velocity Index: ${m.velocity!.toStringAsFixed(1)} °/s',
      if (m.tempo != null) 'Repetition Tempo: ${m.tempo!.toStringAsFixed(1)} s/rep',
      'Data Confidence State: ${m.dataConfidenceState}',
      'Observed Camera View: ${m.viewAngleObserved.toUpperCase()}',
      if (m.dataConfidence > 0) 'Pose Data Confidence: ${(m.dataConfidence * 100).toStringAsFixed(0)}%',
      if (m.validFrameRatio > 0) 'Valid Frame Ratio: ${(m.validFrameRatio * 100).toStringAsFixed(0)}%',
    ];

    // Joint analysis section
    final jointLines = <String>[];
    if (m.jointBreakdown.isNotEmpty) {
      m.jointBreakdown.forEach((name, data) {
        if (data.isAvailable) {
          jointLines.add(
            '$name: Angle ${data.currentAngle.toStringAsFixed(0)}° · ROM ${data.rangeOfMotion.toStringAsFixed(0)}° [Confidence: ${data.confidenceLevel}]${data.symmetryDifference != null ? ' · Diff ${data.symmetryDifference!.toStringAsFixed(0)}%' : ''}',
          );
        } else {
          jointLines.add('$name: Unavailable (Required landmarks not detected)');
        }
      });
    } else {
      jointLines.add('Targeted joint: ${report.exercise} primary articulation envelope measured.');
    }

    // Repetition analysis section
    final repLines = <String>[];
    if (m.repetitionDetails.isNotEmpty) {
      for (final rep in m.repetitionDetails) {
        repLines.add(
          'Rep ${rep.repNumber}: ROM ${rep.rangeOfMotion.toStringAsFixed(0)}° · Duration ${rep.durationSeconds.toStringAsFixed(1)}s${rep.hasVariation ? ' [Variation observed]' : ''}',
        );
      }
    } else {
      repLines.add('Total completed repetitions: ${m.repetitions}');
    }

    // Historical trend comparison
    final compLines = <String>[];
    if (report.historicalComparison.isNotEmpty) {
      report.historicalComparison.forEach((k, v) {
        compLines.add('$k: $v');
      });
    } else {
      compLines.add('Baseline assessment session recorded. Multi-session trend comparison will update upon next evaluation.');
    }

    return ReportDocument(
      title: 'REHAB-X AI',
      subtitle: 'Move Better. Recover Smarter. - ${report.exercise} Movement Analysis',
      sections: [
        ReportSection('1. Athlete Overview', [
          'Athlete ID: ${report.athleteId}',
          'Exercise: ${report.exercise}',
          'Assessment Timestamp: ${session.timestamp.toIso8601String()}',
          'Analysis Source: ${session.sourceMode.toUpperCase()}',
        ]),
        ReportSection('2. Session Summary', [
          'Duration: ${m.duration.inSeconds}s',
          'Repetitions Tracked: ${m.repetitions}',
          'Movement Status: ${session.analysisStatus}',
          'Provider Model: ${session.modelVersion}',
        ]),
        ReportSection('3. Movement Metrics', metricsLines),
        ReportSection('4. Joint Analysis', jointLines),
        ReportSection('5. Repetition Analysis', repLines),
        ReportSection('6. Movement Quality', [
          'Overall Quality Classification: ${session.qualityLabel.toUpperCase()}',
          'Classification standard: Movement kinematic repeatability and symmetry criteria.',
        ]),
        ReportSection('7. Trend Comparison', compLines),
        ReportSection(
          '8. Observations',
          report.observations.isEmpty ? const ['Controlled kinematic execution captured without anomalies.'] : report.observations,
        ),
        ReportSection(
          '9. Data Limitations',
          report.limitations.isEmpty ? const ['None recorded - all required joint landmarks met minimum confidence threshold.'] : report.limitations,
        ),
        ReportSection('10. Safety Disclaimer', [
          report.professionalReviewNote,
          'This report provides computer-vision movement monitoring information and is not medical diagnosis or medical clearance.',
          'Always seek guidance from a qualified sports medicine physician or physical therapist for injury assessment.',
        ]),
      ],
    );
  }

  String toShareableText(SessionReport report) {
    final document = toDocument(report);
    final buffer = StringBuffer()..writeln('${document.title} - ${document.subtitle}');
    for (final section in document.sections) {
      buffer.writeln('\n${section.title}');
      for (final line in section.lines) {
        buffer.writeln(line);
      }
    }
    return buffer.toString();
  }

  String toJsonExport(SessionReport report) {
    return const JsonEncoder.withIndent('  ').convert(report.toJson());
  }

  Future<ReportExportResult> toPdf(SessionReport report) async {
    try {
      final document = toDocument(report);
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (_) => [
            pw.Text(document.title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text(document.subtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
            ...document.sections.expand((section) => [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
                child: pw.Text(
                  section.title,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                ),
              ),
              ...section.lines.map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(line, style: const pw.TextStyle(fontSize: 9.5)),
                ),
              ),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            ]),
          ],
        ),
      );
      return ReportExportResult(success: true, bytes: Uint8List.fromList(await pdf.save()));
    } on Object catch (error) {
      return ReportExportResult(success: false, errorMessage: 'Report PDF could not be created: $error');
    }
  }

  Future<ShareResult?> sharePdf(SessionReport report) async {
    try {
      final result = await toPdf(report);
      if (!result.success || result.bytes == null) return null;
      return await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(result.bytes!, mimeType: 'application/pdf', name: 'rehab-x-ai-report.pdf')],
          text: 'REHAB-X AI movement analysis report',
        ),
      );
    } on Object {
      return null;
    }
  }

  Future<ReportExportResult> toDateRangePdf(DateRangeReport report) async {
    try {
      final pdf = pw.Document();
      final rows = <List<String>>[];
      for (final session in report.sessions) {
        final joints = session.metrics.jointBreakdown.entries
            .where((entry) => entry.value.isAvailable)
            .map(
              (entry) =>
                  '${entry.key}: ${entry.value.currentAngle.toStringAsFixed(0)} deg',
            )
            .join('\n');
        rows.add([
          session.exercise,
          '${session.metrics.rangeOfMotion.toStringAsFixed(0)} deg',
          _formatDateTime(session.timestamp),
          report.roomTemperature,
          '${session.metrics.repetitions}',
          joints.isEmpty ? 'Not recorded' : joints,
          report.profile.weightKg.isEmpty ? 'Not recorded' : '${report.profile.weightKg} kg',
          report.profile.heightCm.isEmpty ? 'Not recorded' : '${report.profile.heightCm} cm',
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => [
            pw.Text(
              'REHAB-X AI MOVEMENT REPORT',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Athlete: ${report.profile.name}    Report period: ${_formatDate(report.start)} - ${_formatDate(report.end)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            if (rows.isEmpty)
              pw.Text('No recorded sessions found for this date range.')
            else
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Exercise Name',
                  'ROM / Measurement',
                  'Date & Time',
                  'Room Temperature',
                  'Reps Count',
                  'Joint & Angle',
                  'Body Weight',
                  'Height',
                ],
                data: rows,
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellPadding: const pw.EdgeInsets.all(4),
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.3),
                  4: pw.FlexColumnWidth(0.8),
                  5: pw.FlexColumnWidth(1.8),
                  6: pw.FlexColumnWidth(1.1),
                  7: pw.FlexColumnWidth(1.0),
                },
              ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Movement observations are not a medical diagnosis. Professional review is recommended before return to competitive activity.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      );
      return ReportExportResult(success: true, bytes: Uint8List.fromList(await pdf.save()));
    } on Object catch (error) {
      return ReportExportResult(success: false, errorMessage: 'Report PDF could not be created: $error');
    }
  }

  Future<String?> saveDateRangePdf(DateRangeReport report) async {
    final result = await toDateRangePdf(report);
    if (!result.success || result.bytes == null) return null;
    return FileSaver.instance.saveAs(
      name: 'rehab-x-ai-report-${_formatDate(report.start)}-to-${_formatDate(report.end)}',
      bytes: result.bytes!,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  Future<ShareResult?> shareDateRangePdf(DateRangeReport report) async {
    final result = await toDateRangePdf(report);
    if (!result.success || result.bytes == null) return null;
    return SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            result.bytes!,
            mimeType: 'application/pdf',
            name: 'rehab-x-ai-date-range-report.pdf',
          ),
        ],
        text: 'REHAB-X AI movement report',
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _formatDateTime(DateTime date) =>
      '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}