import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/body_silhouette_painter.dart';
import '../../core/widgets/sports_glass_card.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/pose_models.dart';
import '../../domain/services/joint_telemetry_service.dart';

class InteractiveBodyMapPage extends StatefulWidget {
  const InteractiveBodyMapPage({super.key});

  @override
  State<InteractiveBodyMapPage> createState() => _InteractiveBodyMapPageState();
}

class _InteractiveBodyMapPageState extends State<InteractiveBodyMapPage> {
  AnatomicalJoint _selectedJoint = AnatomicalJoint.leftKnee;
  List<SessionRecord> _sessions = [];
  bool _isLoading = true;
  bool _isCoachView = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final list = await LocalSessionRepository(prefs).readAll('athlete');
    if (mounted) {
      setState(() {
        _sessions = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jointTelemetry = _getTelemetryForJoint(_selectedJoint);
    final counterpartJoint = _getCounterpart(_selectedJoint);
    final counterpartTelemetry = counterpartJoint != null ? _getTelemetryForJoint(counterpartJoint) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Body Map'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(_isCoachView ? 'Coach View' : 'Athlete View'),
              selected: _isCoachView,
              onSelected: (val) => setState(() => _isCoachView = val),
              selectedColor: AppColors.cyan.withAlpha(40),
              checkmarkColor: AppColors.cyan,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _isCoachView ? AppColors.cyan : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(
                  children: [
                    const SportsChip(label: 'JOINT-BY-JOINT KINEMATICS', color: AppColors.cyan, icon: Icons.accessibility_new),
                    const Spacer(),
                    Text(
                      _isCoachView ? 'PROFESSIONAL TELEMETRY' : 'ATHLETE VIEW',
                      style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select any articulation point on the athletic silhouette to inspect measured kinematic metrics.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Interactive Body Silhouette Viewer
                Container(
                  height: 320,
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(260, 310),
                        painter: BodySilhouettePainter(
                          selectedJoint: _selectedJoint,
                          highlightedJoints: {
                            AnatomicalJoint.leftKnee,
                            AnatomicalJoint.rightKnee,
                            AnatomicalJoint.leftHip,
                            AnatomicalJoint.rightHip,
                            AnatomicalJoint.leftShoulder,
                            AnatomicalJoint.rightShoulder,
                          },
                          jointAngles: {
                            _selectedJoint: jointTelemetry.currentAngle,
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 14,
                        child: Text(
                          jointTelemetry.displayName.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quick selector buttons for major joints
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _JointButton(
                        label: 'Knee',
                        isSelected: _selectedJoint == AnatomicalJoint.leftKnee || _selectedJoint == AnatomicalJoint.rightKnee,
                        onTap: () => setState(() => _selectedJoint = AnatomicalJoint.leftKnee),
                      ),
                      const SizedBox(width: 8),
                      _JointButton(
                        label: 'Hip',
                        isSelected: _selectedJoint == AnatomicalJoint.leftHip || _selectedJoint == AnatomicalJoint.rightHip,
                        onTap: () => setState(() => _selectedJoint = AnatomicalJoint.leftHip),
                      ),
                      const SizedBox(width: 8),
                      _JointButton(
                        label: 'Shoulder',
                        isSelected: _selectedJoint == AnatomicalJoint.leftShoulder || _selectedJoint == AnatomicalJoint.rightShoulder,
                        onTap: () => setState(() => _selectedJoint = AnatomicalJoint.leftShoulder),
                      ),
                      const SizedBox(width: 8),
                      _JointButton(
                        label: 'Elbow',
                        isSelected: _selectedJoint == AnatomicalJoint.leftElbow || _selectedJoint == AnatomicalJoint.rightElbow,
                        onTap: () => setState(() => _selectedJoint = AnatomicalJoint.leftElbow),
                      ),
                      const SizedBox(width: 8),
                      _JointButton(
                        label: 'Ankle',
                        isSelected: _selectedJoint == AnatomicalJoint.leftAnkle || _selectedJoint == AnatomicalJoint.rightAnkle,
                        onTap: () => setState(() => _selectedJoint = AnatomicalJoint.leftAnkle),
                      ),
                      const SizedBox(width: 8),
                      _JointButton(
                        label: 'Trunk / Spine',
                        isSelected: _selectedJoint == AnatomicalJoint.spine,
                        onTap: () => setState(() => _selectedJoint = AnatomicalJoint.spine),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Bilateral Comparison View (Requirement 31)
                if (counterpartTelemetry != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _JointSideCard(
                          title: jointTelemetry.displayName,
                          telemetry: jointTelemetry,
                          isCoachView: _isCoachView,
                          isSelected: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _JointSideCard(
                          title: counterpartTelemetry.displayName,
                          telemetry: counterpartTelemetry,
                          isCoachView: _isCoachView,
                          isSelected: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Bilateral Difference Callout
                  SportsGlassCard(
                    borderColor: (jointTelemetry.bilateralDifference ?? 0) > 18
                        ? AppColors.orange.withAlpha(120)
                        : AppColors.green.withAlpha(120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'BILATERAL SYMMETRY ANALYSIS',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.8),
                            ),
                            const Spacer(),
                            Text(
                              jointTelemetry.bilateralDifference != null
                                  ? '${jointTelemetry.bilateralDifference!.toStringAsFixed(0)}% difference'
                                  : 'Symmetrical envelope',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: (jointTelemetry.bilateralDifference ?? 0) > 18 ? AppColors.orange : AppColors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          jointTelemetry.observation,
                          style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  // Single Joint Details Card
                  SportsGlassCard(
                    borderColor: AppColors.cyan.withAlpha(100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              jointTelemetry.displayName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                            ),
                            const Spacer(),
                            SportsChip(
                              label: jointTelemetry.isAvailable ? jointTelemetry.confidenceLevel : 'UNAVAILABLE',
                              color: jointTelemetry.isAvailable ? AppColors.green : AppColors.muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SportsMetricTile(
                                label: 'Current Angle',
                                value: jointTelemetry.isAvailable ? '${jointTelemetry.currentAngle.toStringAsFixed(0)}°' : 'Unavailable',
                                accentColor: AppColors.cyan,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SportsMetricTile(
                                label: 'Active ROM',
                                value: jointTelemetry.isAvailable ? '${jointTelemetry.rangeOfMotion.toStringAsFixed(0)}°' : 'Unavailable',
                                accentColor: AppColors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          jointTelemetry.observation,
                          style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                const Text(
                  'Movement measurements represent physical camera-derived pose geometry. Not a medical diagnosis or medical clearance.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
                ),
              ],
            ),
    );
  }

  JointTelemetryReport _getTelemetryForJoint(AnatomicalJoint joint) {
    if (_sessions.isNotEmpty) {
      final s = _sessions.first;
      final jb = s.metrics.jointBreakdown;
      final name = _jointDisplayName(joint);
      if (jb.containsKey(name)) {
        final d = jb[name]!;
        return JointTelemetryReport(
          joint: joint,
          displayName: name,
          currentAngle: d.currentAngle,
          rangeOfMotion: d.rangeOfMotion,
          minAngle: d.minAngle,
          maxAngle: d.maxAngle,
          consistency: d.consistency ?? s.metrics.consistency,
          bilateralDifference: d.symmetryDifference,
          confidenceLevel: d.confidenceLevel,
          isAvailable: d.isAvailable,
          observation: d.observation.isNotEmpty ? d.observation : 'Kinematics captured during recent ${s.exercise} assessment.',
        );
      }
    }

    final defaultAngles = <AnatomicalJoint, double>{
      AnatomicalJoint.leftKnee: 168.0,
      AnatomicalJoint.rightKnee: 168.0,
      AnatomicalJoint.leftHip: 172.0,
      AnatomicalJoint.rightHip: 172.0,
      AnatomicalJoint.leftShoulder: 35.0,
      AnatomicalJoint.rightShoulder: 35.0,
      AnatomicalJoint.leftElbow: 165.0,
      AnatomicalJoint.rightElbow: 165.0,
      AnatomicalJoint.leftAnkle: 88.0,
      AnatomicalJoint.rightAnkle: 88.0,
      AnatomicalJoint.spine: 175.0,
      AnatomicalJoint.neck: 160.0,
    };

    return JointTelemetryReport(
      joint: joint,
      displayName: _jointDisplayName(joint),
      currentAngle: defaultAngles[joint] ?? 170.0,
      rangeOfMotion: 0,
      confidenceLevel: 'INSUFFICIENT',
      isAvailable: false,
      observation: 'Complete a movement session to record active dynamic ROM and consistency for this joint.',
    );
  }

  AnatomicalJoint? _getCounterpart(AnatomicalJoint joint) => switch (joint) {
        AnatomicalJoint.leftKnee => AnatomicalJoint.rightKnee,
        AnatomicalJoint.rightKnee => AnatomicalJoint.leftKnee,
        AnatomicalJoint.leftHip => AnatomicalJoint.rightHip,
        AnatomicalJoint.rightHip => AnatomicalJoint.leftHip,
        AnatomicalJoint.leftShoulder => AnatomicalJoint.rightShoulder,
        AnatomicalJoint.rightShoulder => AnatomicalJoint.leftShoulder,
        AnatomicalJoint.leftElbow => AnatomicalJoint.rightElbow,
        AnatomicalJoint.rightElbow => AnatomicalJoint.leftElbow,
        AnatomicalJoint.leftAnkle => AnatomicalJoint.rightAnkle,
        AnatomicalJoint.rightAnkle => AnatomicalJoint.leftAnkle,
        _ => null,
      };

  String _jointDisplayName(AnatomicalJoint joint) => switch (joint) {
        AnatomicalJoint.leftKnee => 'Left Knee',
        AnatomicalJoint.rightKnee => 'Right Knee',
        AnatomicalJoint.leftHip => 'Left Hip',
        AnatomicalJoint.rightHip => 'Right Hip',
        AnatomicalJoint.leftShoulder => 'Left Shoulder',
        AnatomicalJoint.rightShoulder => 'Right Shoulder',
        AnatomicalJoint.leftElbow => 'Left Elbow',
        AnatomicalJoint.rightElbow => 'Right Elbow',
        AnatomicalJoint.leftAnkle => 'Left Ankle',
        AnatomicalJoint.rightAnkle => 'Right Ankle',
        AnatomicalJoint.spine => 'Trunk / Spine',
        AnatomicalJoint.neck => 'Neck',
        AnatomicalJoint.leftWrist => 'Left Wrist',
        AnatomicalJoint.rightWrist => 'Right Wrist',
      };
}

class _JointSideCard extends StatelessWidget {
  const _JointSideCard({
    required this.title,
    required this.telemetry,
    required this.isCoachView,
    required this.isSelected,
  });

  final String title;
  final JointTelemetryReport telemetry;
  final bool isCoachView;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SportsGlassCard(
      padding: const EdgeInsets.all(12),
      borderColor: isSelected ? AppColors.cyan : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isSelected ? AppColors.cyan : AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          if (telemetry.isAvailable) ...[
            Text('ROM: ${telemetry.rangeOfMotion.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.green)),
            const SizedBox(height: 2),
            if (isCoachView) ...[
              Text('Min: ${telemetry.minAngle?.toStringAsFixed(0) ?? '--'}°', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              Text('Max: ${telemetry.maxAngle?.toStringAsFixed(0) ?? '--'}°', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
            const SizedBox(height: 4),
            Text(
              'Confidence: ${telemetry.confidenceLevel}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: telemetry.confidenceLevel == 'HIGH' ? AppColors.green : AppColors.orange,
              ),
            ),
          ] else ...[
            const Text(
              'Unavailable',
              style: TextStyle(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 2),
            const Text('No recent session', style: TextStyle(fontSize: 10, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _JointButton extends StatelessWidget {
  const _JointButton({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.cyan.withAlpha(50),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.cyan : AppColors.text,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
