import '../models/pose_models.dart';

enum TrendDirection { improving, reducing, stable, insufficientData }

class TrendPoint {
  const TrendPoint({required this.timestamp, required this.value});
  final DateTime timestamp;
  final double value;
}

class MetricTrend {
  const MetricTrend({required this.metric, required this.points, required this.direction});
  final String metric;
  final List<TrendPoint> points;
  final TrendDirection direction;
  bool get hasEnoughData => points.length >= 2;
}

class SessionComparison {
  const SessionComparison({required this.first, required this.latest});
  final SessionRecord? first;
  final SessionRecord? latest;
  bool get hasEnoughData => first != null && latest != null && first!.id != latest!.id;
}

class TrendSnapshot {
  const TrendSnapshot({required this.sessions, required this.rom, required this.symmetry, required this.consistency, required this.confidence, required this.validFrameRatio, required this.repetitions, required this.duration, required this.comparison});
  final List<SessionRecord> sessions;
  final MetricTrend rom;
  final MetricTrend symmetry;
  final MetricTrend consistency;
  final MetricTrend confidence;
  final MetricTrend validFrameRatio;
  final MetricTrend repetitions;
  final MetricTrend duration;
  final SessionComparison comparison;
  bool get hasEnoughData => sessions.length >= 2;
}

class TrendAnalysisService {
  TrendSnapshot analyze(Iterable<SessionRecord> input, {String? exerciseId, bool includeDemo = false}) {
    final sessions = input.where((session) => (includeDemo || !session.isDemo) && (exerciseId == null || session.exerciseId == exerciseId)).toList()
      ..sort((first, second) => first.timestamp.compareTo(second.timestamp));
    return TrendSnapshot(
      sessions: List.unmodifiable(sessions),
      rom: _trend('ROM', sessions, (session) => session.metrics.rangeOfMotion),
      symmetry: _trend('Symmetry', sessions, (session) => session.metrics.symmetry),
      consistency: _trend('Consistency', sessions, (session) => session.metrics.consistency),
      confidence: _trend('Confidence', sessions, (session) => session.metrics.dataConfidence),
      validFrameRatio: _trend('Valid frames', sessions, (session) => session.metrics.validFrameRatio),
      repetitions: _trend('Repetitions', sessions, (session) => session.metrics.repetitions.toDouble()),
      duration: _trend('Duration', sessions, (session) => session.metrics.duration.inSeconds.toDouble()),
      comparison: SessionComparison(first: sessions.isEmpty ? null : sessions.first, latest: sessions.isEmpty ? null : sessions.last),
    );
  }

  MetricTrend _trend(String name, List<SessionRecord> sessions, double? Function(SessionRecord) read) {
    final points = sessions.map((session) { final value = read(session); return value == null || !value.isFinite ? null : TrendPoint(timestamp: session.timestamp, value: value); }).whereType<TrendPoint>().toList();
    return MetricTrend(metric: name, points: List.unmodifiable(points), direction: _direction(points));
  }

  TrendDirection _direction(List<TrendPoint> points) {
    if (points.length < 2) return TrendDirection.insufficientData;
    final change = points.last.value - points.first.value;
    if (change.abs() < 0.01) return TrendDirection.stable;
    return change > 0 ? TrendDirection.improving : TrendDirection.reducing;
  }
}