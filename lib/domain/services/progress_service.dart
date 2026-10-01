import '../models/pose_models.dart';

enum TrendStatus { improving, stable, insufficientData }

class BodyRegionCoverage {
  const BodyRegionCoverage({
    required this.lowerBodyRatio,
    required this.upperBodyRatio,
    required this.coreRatio,
    required this.mobilityRatio,
  });
  final double lowerBodyRatio;
  final double upperBodyRatio;
  final double coreRatio;
  final double mobilityRatio;
}

class ProgressSummary {
  const ProgressSummary({
    required this.sessionCount,
    required this.rom,
    required this.symmetry,
    required this.stability,
    required this.consistency,
    required this.repetitions,
    this.first,
    this.latest,
    this.coverage = const BodyRegionCoverage(
      lowerBodyRatio: 0,
      upperBodyRatio: 0,
      coreRatio: 0,
      mobilityRatio: 0,
    ),
  });

  final int sessionCount;
  final List<double> rom;
  final List<double> symmetry;
  final List<double> stability;
  final List<double> consistency;
  final List<int> repetitions;
  final SessionRecord? first;
  final SessionRecord? latest;
  final BodyRegionCoverage coverage;

  TrendStatus trend(List<double> values) {
    if (values.length < 2) return TrendStatus.insufficientData;
    return values.last > values.first ? TrendStatus.improving : TrendStatus.stable;
  }
}

class ProgressService {
  ProgressSummary summarize(Iterable<SessionRecord> sessions) {
    final ordered = sessions.toList()..sort((first, second) => first.timestamp.compareTo(second.timestamp));
    final coverage = calculateRegionCoverage(ordered);

    return ProgressSummary(
      sessionCount: ordered.length,
      rom: ordered.map((session) => session.metrics.rangeOfMotion).toList(),
      symmetry: ordered.map((session) => session.metrics.symmetry).whereType<double>().toList(),
      stability: ordered.map((session) => session.metrics.stability).whereType<double>().toList(),
      consistency: ordered.map((session) => session.metrics.consistency).toList(),
      repetitions: ordered.map((session) => session.metrics.repetitions).toList(),
      first: ordered.isEmpty ? null : ordered.first,
      latest: ordered.isEmpty ? null : ordered.last,
      coverage: coverage,
    );
  }

  BodyRegionCoverage calculateRegionCoverage(List<SessionRecord> sessions) {
    if (sessions.isEmpty) {
      return const BodyRegionCoverage(
        lowerBodyRatio: 0,
        upperBodyRatio: 0,
        coreRatio: 0,
        mobilityRatio: 0,
      );
    }

    var lower = 0;
    var upper = 0;
    var core = 0;
    var mobility = 0;

    for (final s in sessions) {
      final id = s.exerciseId.toLowerCase();
      final name = s.exercise.toLowerCase();
      if (id.contains('squat') || id.contains('lunge') || id.contains('calf') || id.contains('jump') || id.contains('balance') || name.contains('squat')) {
        lower++;
      } else if (id.contains('shoulder') || id.contains('push') || id.contains('elbow') || id.contains('arm')) {
        upper++;
      } else if (id.contains('plank') || id.contains('core') || id.contains('bug') || id.contains('dog')) {
        core++;
      } else {
        mobility++;
      }
    }

    final total = sessions.length.toDouble();
    return BodyRegionCoverage(
      lowerBodyRatio: (lower / total).clamp(0.0, 1.0),
      upperBodyRatio: (upper / total).clamp(0.0, 1.0),
      coreRatio: (core / total).clamp(0.0, 1.0),
      mobilityRatio: (mobility / total).clamp(0.0, 1.0),
    );
  }
}