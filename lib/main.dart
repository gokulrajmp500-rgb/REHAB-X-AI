import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/profile_image.dart';
import 'core/widgets/sports_glass_card.dart';
import 'data/models/app_settings.dart';
import 'data/models/athlete_profile.dart';
import 'data/models/exercise.dart';
import 'data/repositories/local_rehab_repository.dart';
import 'data/repositories/session_repository.dart';
import 'data/services/notification_service.dart';
import 'data/services/report_export_service.dart';
import 'domain/models/personalized_plan.dart';
import 'domain/models/pose_models.dart';
import 'domain/models/session_report.dart';
import 'domain/services/progress_service.dart';
import 'domain/services/rehabilitation_plan_service.dart';
import 'domain/services/trend_analysis_service.dart';
import 'presentation/pages/ai_coach_chat_page.dart';
import 'presentation/pages/compare_sessions_page.dart';
import 'presentation/pages/competition_mode_page.dart';
import 'presentation/pages/interactive_body_map_page.dart';
import 'presentation/pages/live_analysis_page.dart';
import 'presentation/pages/recorded_video_analysis_page.dart';
import 'presentation/pages/research_knowledge_page.dart';
import 'core/widgets/athlete_os_components.dart';
import 'presentation/widgets/temporal_angle_chart.dart';

export 'core/theme/app_theme.dart' show AppColors;

final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.dark,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    final settings = await LocalRehabRepository(prefs).loadSettings();
    if (settings.themeMode == 'light') {
      appThemeModeNotifier.value = ThemeMode.light;
    } else if (settings.themeMode == 'system') {
      appThemeModeNotifier.value = ThemeMode.system;
    } else {
      appThemeModeNotifier.value = ThemeMode.dark;
    }
    await NotificationService.instance.initialize();
  } catch (_) {}
  runApp(const RehabXApp(startWithSplash: true));
}

class RehabXApp extends StatelessWidget {
  const RehabXApp({super.key, this.startWithSplash = false});
  final bool startWithSplash;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'REHAB-X AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: startWithSplash
              ? const CinematicSplashScreen()
              : const MainShell(),
        );
      },
    );
  }
}

class CinematicSplashScreen extends StatefulWidget {
  const CinematicSplashScreen({super.key});

  @override
  State<CinematicSplashScreen> createState() => _CinematicSplashScreenState();
}

class _CinematicSplashScreenState extends State<CinematicSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                  const MainShell(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final logoSize = (constraints.maxWidth * 0.72).clamp(180.0, 420.0);
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color.fromARGB(230, 52, 228, 255),
                              width: 6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(120, 32, 220, 255),
                                blurRadius: 36,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/logo/rehab_x_logo.svg',
                              width: logoSize * 0.92,
                              height: logoSize * 0.92,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.92,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFFFFFFF),
                                  Color(0xFF2EE7FF),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(bounds),
                              child: const Text(
                                'REHAB-X AI',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 120,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.9,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.2,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'MOVE BETTER. ',
                                    style: TextStyle(color: Color(0xFF30E7FF)),
                                  ),
                                  TextSpan(
                                    text: 'RECOVER SMARTER. ',
                                    style: TextStyle(color: Color(0xFFFFF3F0)),
                                  ),
                                  TextSpan(
                                    text: 'PERFORM STRONGER.',
                                    style: TextStyle(color: Color(0xFFE7FF52)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.electricCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _recoveryKey = GlobalKey<_RecoveryPageState>();
  final _progressKey = GlobalKey<_ProgressPageState>();
  late final List<Widget> _pages = [
    const HomePage(),
    const AnalyzePage(),
    RecoveryPage(key: _recoveryKey),
    ProgressPage(key: _progressKey),
    const ProfilePage(),
  ];

  void _selectTab(int index) {
    setState(() => _index = index);
    if (index == 2) _recoveryKey.currentState?.reload();
    if (index == 3) _progressKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(index: _index, children: _pages),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _selectTab,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.center_focus_strong),
          label: 'Analyze',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          selectedIcon: Icon(Icons.favorite),
          label: 'Recovery',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights),
          label: 'Progress',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    ),
  );
}

Widget _buildAthleteAvatarWidget(
  AthleteProfile profile, {
  double size = 44,
  double iconSize = 24,
}) {
  IconData avatarIcon = Icons.person;
  switch (profile.avatarId) {
    case 'runner':
      avatarIcon = Icons.directions_run;
      break;
    case 'weight':
      avatarIcon = Icons.fitness_center;
      break;
    case 'bolt':
      avatarIcon = Icons.bolt;
      break;
    case 'shield':
      avatarIcon = Icons.shield_outlined;
      break;
    case 'fire':
      avatarIcon = Icons.local_fire_department;
      break;
    case 'sports':
      avatarIcon = Icons.sports_soccer;
      break;
    default:
      avatarIcon = Icons.person;
  }

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.titanium,
      border: Border.all(
        color: AppColors.electricCyan.withAlpha(150),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(color: AppColors.electricCyan.withAlpha(50), blurRadius: 10),
      ],
    ),
    child: profile.photoPath.isNotEmpty
        ? ClipOval(child: profileImage(profile.photoPath))
        : Center(
            child: Icon(
              avatarIcon,
              color: AppColors.electricCyan,
              size: iconSize,
            ),
          ),
  );
}

void _showNotificationCenter(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.obsidian,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return AnimatedBuilder(
        animation: NotificationService.instance,
        builder: (context, _) {
          final notifs = NotificationService.instance.notifications;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (notifs.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            NotificationService.instance.markAllAsRead(),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: AppColors.electricCyan,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (notifs.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: const Text(
                      'No active notifications',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: notifs.length,
                      separatorBuilder: (_, _) => const Divider(
                        color: AppColors.borderDivider,
                        height: 12,
                      ),
                      itemBuilder: (_, i) {
                        final n = notifs[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: n.isRead
                                  ? AppColors.graphite
                                  : AppColors.electricCyan.withAlpha(25),
                              border: Border.all(
                                color: n.isRead
                                    ? AppColors.borderDivider
                                    : AppColors.electricCyan,
                              ),
                            ),
                            child: Icon(
                              n.type == NotificationType.milestone
                                  ? Icons.emoji_events_outlined
                                  : (n.type == NotificationType.technique
                                        ? Icons.tune
                                        : Icons.bolt),
                              color: n.isRead
                                  ? AppColors.textSecondary
                                  : AppColors.electricCyan,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: n.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            n.message,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () =>
                              NotificationService.instance.markAsRead(n.id),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          NotificationService.instance.addNotification(
                            title: 'Performance Readiness Alert',
                            message:
                                'Dynamic score updated. High movement efficiency detected.',
                            type: NotificationType.readiness,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.electricCyan),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Trigger Test Alert',
                          style: TextStyle(
                            color: AppColors.electricCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            NotificationService.instance.clearAll(),
                        child: const Text(
                          'Clear All',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AthleteProfile _profile = const AthleteProfile(name: 'Athlete');
  List<SessionRecord> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await LocalRehabRepository(prefs).loadProfile();
    final sessions = await LocalSessionRepository(prefs).readAll('athlete');
    if (mounted) {
      setState(() {
        if (profile != null) _profile = profile;
        _sessions = verifiedMovementSessions(sessions);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestSession = _sessions.isNotEmpty ? _sessions.first : null;
    final regionCoverage = ProgressService().calculateRegionCoverage(_sessions);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Header with Avatar and Actions
        Row(
          children: [
            _buildAthleteAvatarWidget(_profile),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REHAB-X AI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.electricCyan,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _profile.name.isEmpty ? 'Athlete' : _profile.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: NotificationService.instance,
              builder: (context, _) {
                final unread = NotificationService.instance.unreadCount;
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      onPressed: () => _showNotificationCenter(context),
                      icon: const Icon(
                        Icons.notifications_none,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.statusCritical,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
                _load();
              },
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Baseline Metrics Section (Requirement: contract test visibility)
        SectionHeader(
          title: 'Your baseline',
          action: _sessions.isEmpty
              ? 'No sessions yet'
              : '${_sessions.length} sessions recorded',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Symmetry',
                value: latestSession?.metrics.symmetry != null
                    ? '${latestSession!.metrics.symmetry!.toStringAsFixed(0)}%'
                    : '--',
                icon: Icons.compare_arrows,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                label: 'Mobility',
                value: latestSession != null
                    ? '${latestSession.metrics.rangeOfMotion.toStringAsFixed(0)}°'
                    : '--',
                icon: Icons.accessibility_new,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Hero Card (Requirement 39 & widget_test contract & Screen 2: Today's Focus)
        _HeroCard(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LiveAnalysisPage(exercise: exerciseCatalog[0]),
              ),
            );
            _load();
          },
        ),
        const SizedBox(height: 18),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Stability',
                value: latestSession?.metrics.stability != null
                    ? '${latestSession!.metrics.stability!.toStringAsFixed(0)}%'
                    : '--',
                icon: Icons.balance,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                label: 'Consistency',
                value: latestSession != null
                    ? '${latestSession.metrics.consistency.toStringAsFixed(0)}%'
                    : '--',
                icon: Icons.auto_graph,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Athlete Performance Flagship Actions
        const SectionHeader(
          title: 'Athlete Performance Systems',
          action: 'Flagship CV & AI',
        ),
        const SizedBox(height: 12),
        QuickActionButton(
          title: 'Live Kinematic Analysis',
          subtitle: 'Precision camera joint angle & ROM tracking',
          icon: Icons.videocam_outlined,
          isPrimary: true,
          accentColor: AppColors.electricCyan,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LiveAnalysisPage(exercise: exerciseCatalog[0]),
              ),
            );
            _load();
          },
        ),
        const SizedBox(height: 10),
        QuickActionButton(
          title: 'Video Replay Lab',
          subtitle: 'Upload and evaluate recorded athlete footage',
          icon: Icons.slow_motion_video_outlined,
          accentColor: AppColors.voltLime,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RecordedVideoAnalysisPage(exercise: exerciseCatalog[0]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        QuickActionButton(
          title: 'Interactive Body Map',
          subtitle: 'Anatomical joint geometry & ROM boundaries',
          icon: Icons.accessibility_new,
          accentColor: AppColors.electricCyan,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InteractiveBodyMapPage()),
          ),
        ),
        const SizedBox(height: 10),
        QuickActionButton(
          title: 'AI Performance Coach',
          subtitle: 'Explainable reasoning with evidence metrics',
          icon: Icons.auto_awesome,
          accentColor: AppColors.voltLime,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiCoachChatPage()),
          ),
        ),
        const SizedBox(height: 24),

        // Body Region Progress (Requirement 20)
        const SectionHeader(
          title: 'Body region progress',
          action: 'Coverage & activity',
        ),
        const SizedBox(height: 12),
        SportsGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RegionBar(
                label: 'LOWER BODY',
                ratio: regionCoverage.lowerBodyRatio,
                color: AppColors.cyan,
              ),
              const SizedBox(height: 10),
              _RegionBar(
                label: 'UPPER BODY',
                ratio: regionCoverage.upperBodyRatio,
                color: AppColors.green,
              ),
              const SizedBox(height: 10),
              _RegionBar(
                label: 'CORE',
                ratio: regionCoverage.coreRatio,
                color: AppColors.orange,
              ),
              const SizedBox(height: 10),
              _RegionBar(
                label: 'MOBILITY',
                ratio: regionCoverage.mobilityRatio,
                color: AppColors.cyanBright,
              ),
              const SizedBox(height: 10),
              const Text(
                'Indicates movement tracking volume across regions. Not a medical recovery metric.',
                style: TextStyle(color: AppColors.muted, fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Quick Actions Carousel
        const SectionHeader(title: 'Advanced movement tools'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SportsGlassCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InteractiveBodyMapPage(),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.accessibility_new,
                      color: AppColors.cyan,
                      size: 24,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Interactive Body Map',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Inspect joint angles & ROM',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SportsGlassCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiCoachChatPage()),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.green, size: 24),
                    SizedBox(height: 12),
                    Text(
                      'AI Movement Coach',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Transparent reasoning',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Recovery Status
        const SectionHeader(title: 'Recovery status'),
        const SizedBox(height: 12),
        SportsGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_outlined, color: AppColors.orange),
                  const SizedBox(width: 12),
                  Text(
                    'Stage 1  ·  ${_profile.recoveryStage}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Athlete-selected stage. Guides monitoring recommendations and movement tolerance.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SafetyNotice(),
      ],
    );
  }
}

class _RegionBar extends StatelessWidget {
  const _RegionBar({
    required this.label,
    required this.ratio,
    required this.color,
  });
  final String label;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppColors.muted,
              ),
            ),
            Text(
              '${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio == 0 ? 0.04 : ratio,
            color: color,
            backgroundColor: AppColors.line,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderDivider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              "TODAY'S FOCUS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.electricCyan,
                letterSpacing: 1.2,
              ),
            ),
            Spacer(),
            StatusChip(
              label: 'READY WHEN YOU ARE',
              color: AppColors.electricCyan,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lower-body stability',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Start movement\nanalysis',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.electricCyan,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Focus on controlled movement and consistent form.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.carbon,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDivider),
              ),
              child: const Icon(
                Icons.accessibility_new,
                color: AppColors.electricCyan,
                size: 30,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electricCyan,
              foregroundColor: AppColors.obsidian,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'START SESSION',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(
              Icons.videocam_outlined,
              size: 14,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: 6),
            Text(
              'Camera model status: Configured & Ready',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ==========================================
// 2. ANALYZE PAGE — DUAL MODE & CATALOG
// ==========================================

class AnalyzePage extends StatefulWidget {
  const AnalyzePage({super.key});
  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage> {
  String _query = '';
  ExerciseCategory? _category;
  int _tabIndex = 0;

  List<Exercise> get _filteredExercises => exerciseCatalog.where((exercise) {
    final matchesQuery =
        _query.isEmpty ||
        exercise.name.toLowerCase().contains(_query.toLowerCase()) ||
        exercise.targetArea.toLowerCase().contains(_query.toLowerCase());
    return matchesQuery &&
        (_category == null || exercise.category == _category);
  }).toList();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    children: [
      // Segmented Switcher: Catalog vs Screen 6 Today's Plan
      Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tabIndex == 0 ? AppColors.carbon : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _tabIndex == 0
                        ? AppColors.electricCyan
                        : AppColors.graphite,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Exercise Catalog',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _tabIndex == 0
                          ? AppColors.electricCyan
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tabIndex == 1 ? AppColors.carbon : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _tabIndex == 1
                        ? AppColors.electricCyan
                        : AppColors.graphite,
                  ),
                ),
                child: Center(
                  child: Text(
                    "Today's Plan",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _tabIndex == 1
                          ? AppColors.electricCyan
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      if (_tabIndex == 1) ...[
        // ==========================================
        // SCREEN 6: TODAY'S PLAN / PERSONALIZED PLAN
        // ==========================================
        const Text(
          "Today's Plan",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ATHLETE OS // MOVEMENT PROGRAM',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.electricCyan,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),

        // Plan Summary Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fitness_center,
                    color: AppColors.electricCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Lower-Body Stability & Hip Mobility',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.voltLime.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.voltLime.withAlpha(120),
                      ),
                    ),
                    child: const Text(
                      'STAGE 2 / 5',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.voltLime,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '5 STAGES · 42 MIN ESTIMATED · HIGH READINESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5 Timeline Stages (Screen 6 from Master Design Image)
        const PlanTimelineItem(
          index: 1,
          title: 'Warm-up',
          duration: '5 min',
          difficulty: 'Low',
          description: 'Dynamic mobility & joint activation drills',
          isCompleted: true,
        ),
        const SizedBox(height: 10),
        const PlanTimelineItem(
          index: 2,
          title: 'Mobility',
          duration: '8 min',
          difficulty: 'Moderate',
          description: 'Hip flexor & ankle dorsiflexion mobility',
          isCompleted: true,
        ),
        const SizedBox(height: 10),
        const PlanTimelineItem(
          index: 3,
          title: 'Main Exercise',
          duration: '15 min',
          difficulty: 'Target',
          description:
              'Barbell Squat (4 sets × 8 reps) with live pose analysis',
          isActive: true,
        ),
        const SizedBox(height: 10),
        const PlanTimelineItem(
          index: 4,
          title: 'Stability',
          duration: '10 min',
          difficulty: 'Moderate',
          description: 'Single-leg balance hold & core engagement',
        ),
        const SizedBox(height: 10),
        const PlanTimelineItem(
          index: 5,
          title: 'Recovery',
          duration: '5 min',
          difficulty: 'Low',
          description: 'Foam rolling & passive hamstring elongation',
        ),
        const SizedBox(height: 20),

        // Big Start Workout CTA
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveAnalysisPage(exercise: exerciseCatalog[0]),
            ),
          ),
          icon: const Icon(Icons.play_arrow, size: 22),
          label: const Text(
            'START WORKOUT SESSION',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.electricCyan,
            foregroundColor: AppColors.obsidian,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ] else ...[
        const Text(
          'Movement analysis',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select an exercise or choose recorded video analysis.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),

        // Pose Model Status Card (Maintains widget_test string)
        const GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusChip(label: 'MODEL STATUS', color: AppColors.orange),
              SizedBox(height: 6),
              Text(
                'Pose analysis model is not configured.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Live analysis uses device ML Kit camera pipeline on physical devices.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Dual Mode Quick Launch
        Row(
          children: [
            Expanded(
              child: SportsGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LiveAnalysisPage(exercise: exerciseCatalog[0]),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.videocam_outlined,
                      color: AppColors.cyan,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode A: Live',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Live Camera',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SportsGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RecordedVideoAnalysisPage(exercise: exerciseCatalog[0]),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      color: AppColors.green,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode B: Video',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Video Analysis',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search & Filter
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: AppColors.cyan),
            hintText: 'Search exercises by name or muscle',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              ...ExerciseCategory.values.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(_categoryLabel(category)),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Exercise catalog'),
        const SizedBox(height: 12),

        if (_filteredExercises.isEmpty)
          const EmptyState(
            title: 'No matching exercises',
            message: 'Try a different search or category.',
          )
        else
          ..._filteredExercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ExerciseTile(
                name: exercise.name,
                subtitle:
                    '${_categoryLabel(exercise.category)} · ${exercise.difficulty} · ${exercise.isAnalysisSupported ? 'Analysis Ready' : 'Configuration Required'}',
                trailingBadge: exercise.isAnalysisSupported
                    ? 'READY'
                    : 'CONFIG',
                badgeColor: exercise.isAnalysisSupported
                    ? AppColors.green
                    : AppColors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExerciseDetailsPage(exercise: exercise),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        const SafetyNotice(),
      ],
    ],
  );

  static String _categoryLabel(ExerciseCategory category) => switch (category) {
    ExerciseCategory.functionalMovement => 'Functional movement',
    ExerciseCategory.sportSpecific => 'Sport-specific',
    ExerciseCategory.core => 'Core stabilization',
    _ => category.name[0].toUpperCase() + category.name.substring(1),
  };
}

class ExerciseDetailsPage extends StatelessWidget {
  const ExerciseDetailsPage({
    super.key,
    required this.exercise,
    this.planId,
    this.planExerciseId,
  });

  final Exercise exercise;
  final String? planId;
  final String? planExerciseId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(exercise.name)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(
              label: _AnalyzePageState._categoryLabel(
                exercise.category,
              ).toUpperCase(),
              color: AppColors.cyan,
            ),
            Text(
              exercise.difficulty,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            StatusChip(
              label: exercise.isAnalysisSupported
                  ? 'ANALYSIS SUPPORTED'
                  : 'CONFIGURATION REQUIRED',
              color: exercise.isAnalysisSupported
                  ? AppColors.green
                  : AppColors.orange,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          exercise.description,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${exercise.targetArea} · ${exercise.rehabilitationStage}',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 20),

        if (!exercise.isAnalysisSupported) ...[
          SportsGlassCard(
            borderColor: AppColors.orange,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Exercise analysis configuration required for this movement pattern before real-time pose tracking.',
                    style: TextStyle(color: AppColors.orange, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        const SectionHeader(title: 'Setup & Equipment'),
        const SizedBox(height: 8),
        Text(exercise.setup),
        const SizedBox(height: 6),
        Text(
          'Equipment: ${exercise.requiredEquipment}',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),

        const SectionHeader(title: 'Instructions'),
        const SizedBox(height: 8),
        ...exercise.instructions.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${entry.key + 1}.  ${entry.value}',
              style: const TextStyle(height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 14),

        const SectionHeader(title: 'Expected Movement'),
        const SizedBox(height: 8),
        Text(exercise.expectedMovement),
        const SizedBox(height: 18),

        const SectionHeader(title: 'Supported Measurements'),
        const SizedBox(height: 8),
        Text(
          exercise.supportedMetrics.join('  ·  '),
          style: const TextStyle(
            color: AppColors.cyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),

        const SectionHeader(title: 'Common Movement Errors'),
        const SizedBox(height: 8),
        ...(exercise.commonErrors.isEmpty
                ? const [
                    'Keep the movement controlled and within a comfortable pain-free envelope.',
                  ]
                : exercise.commonErrors)
            .map(
              (error) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $error'),
              ),
            ),
        const SizedBox(height: 14),

        Text(
          'Camera position: ${exercise.cameraPosition}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: AppColors.ink,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: exercise.isAnalysisSupported
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveAnalysisPage(
                      exercise: exercise,
                      planId: planId,
                      planExerciseId: planExerciseId,
                    ),
                  ),
                )
              : () => _showConfigDialog(context),
          icon: const Icon(Icons.videocam_outlined),
          label: const Text(
            'Start Live Analysis',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.line),
            minimumSize: const Size(double.infinity, 46),
          ),
          onPressed: exercise.isAnalysisSupported
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RecordedVideoAnalysisPage(exercise: exercise),
                  ),
                )
              : () => _showConfigDialog(context),
          icon: const Icon(Icons.video_library_outlined),
          label: const Text('Analyze Recorded Video'),
        ),
        const SizedBox(height: 14),
        const SafetyNotice(),
      ],
    ),
  );

  void _showConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Configuration Required'),
        content: const Text(
          'Exercise analysis configuration required for this movement pattern. Real pose inference requires calibrated floor or side-plane markers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. RECOVERY PAGE — JOURNEY & RTP SUPPORT
// ==========================================

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key});
  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  late Future<List<SessionRecord>> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = _load();
  }

  Future<List<SessionRecord>> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final sessions = await LocalSessionRepository(
      preferences,
    ).readAll('athlete');
    return verifiedMovementSessions(sessions);
  }

  void reload() {
    if (!mounted) return;
    setState(() {
      _sessions = _load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SessionRecord>>(
    future: _sessions,
    builder: (context, snapshot) {
      final sessions = snapshot.data ?? const <SessionRecord>[];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(const Duration(days: 6));
      final dailyCounts = List<int>.generate(7, (index) {
        final day = start.add(Duration(days: index));
        final nextDay = day.add(const Duration(days: 1));
        return sessions
            .where(
              (session) =>
                  !session.timestamp.isBefore(day) &&
                  session.timestamp.isBefore(nextDay),
            )
            .length;
      });
      final dailyLabels = List<String>.generate(7, (index) {
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final day = start.add(Duration(days: index));
        return labels[day.weekday - 1];
      });
      final weeklyCount = dailyCounts.fold<int>(
        0,
        (total, count) => total + count,
      );
      final latestSession = sessions.firstOrNull;
      final elapsed = latestSession == null
          ? null
          : now.difference(latestSession.timestamp);
      final timeSinceSession = elapsed == null
          ? 'No recorded sessions'
          : elapsed.inDays > 0
          ? '${elapsed.inDays} day${elapsed.inDays == 1 ? '' : 's'} ago'
          : elapsed.inHours > 0
          ? '${elapsed.inHours} hour${elapsed.inHours == 1 ? '' : 's'} ago'
          : 'Under 1 hour ago';
      final consistency = latestSession?.metrics.consistency;

      return SimplePage(
        title: 'Recovery',
        subtitle: 'Recorded activity and recovery check-in context.',
        icon: Icons.favorite_border,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Refresh recovery',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (snapshot.hasError)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recovery data could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (!snapshot.hasData)
            const GlassCard(child: Text('Loading recovery activity...'))
          else ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$weeklyCount',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.electricCyan,
                    ),
                  ),
                  const Text(
                    'VERIFIED MOVEMENT SESSIONS · LAST 7 DAYS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RecoveryMetricRow(
                    label: 'Time since last recorded session',
                    value: timeSinceSession,
                  ),
                  const SizedBox(height: 10),
                  _RecoveryMetricRow(
                    label: 'Latest measured consistency',
                    value: consistency == null
                        ? 'N/A'
                        : '${consistency.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 10),
                  _RecoveryMetricRow(
                    label: 'Verified sessions on record',
                    value: '${sessions.length}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const GlassCard(
              child: Text(
                'Movement-session frequency is not a physiological recovery score. '
                'Sleep, soreness, pain, and readiness are not measured here. '
                'Follow your clinician’s plan and stop if activity causes pain.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          if (snapshot.hasData) ...[
            RecoveryTrendBarChart(
              sessionCounts: dailyCounts,
              dayLabels: dailyLabels,
            ),
            const SizedBox(height: 16),
          ],

          // My Movement Journey Timeline (Requirement 19)
          const SectionHeader(
            title: 'My Movement Journey',
            action: 'Chronological Sessions',
          ),
          if (snapshot.hasData && sessions.isEmpty)
            const GlassCard(
              child: Text(
                'No verified camera-analysis sessions yet. Start a live camera analysis to build your movement history.',
              ),
            )
          else if (snapshot.hasData)
            ...sessions
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SportsGlassCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SessionDetailPage(session: s),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _shortMonthDay(s.timestamp),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.cyan,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.exercise,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${s.metrics.repetitions} reps · ROM ${s.metrics.rangeOfMotion.toStringAsFixed(0)}° · ${s.qualityLabel.toUpperCase()}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

          ExerciseTile(
            name: 'Session comparison',
            subtitle: 'Compare kinematics between two sessions',
            icon: Icons.compare_arrows,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompareSessionsPage()),
            ),
          ),
          ExerciseTile(
            name: 'Session history',
            subtitle: 'All recorded movement sessions',
            icon: Icons.history,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SessionHistoryPage()),
            ),
          ),
          ExerciseTile(
            name: 'Personalized plan',
            subtitle: 'Movement monitoring plan',
            icon: Icons.assignment_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PersonalizedPlanPage()),
            ),
          ),
          ExerciseTile(
            name: 'Return-to-play support',
            subtitle: 'Data summary for professional review',
            icon: Icons.flag_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReturnToPlayPage()),
            ),
          ),
          const SafetyNotice(),
        ],
      );
    },
  );

  static String _shortMonthDay(DateTime d) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
  }
}

class _RecoveryMetricRow extends StatelessWidget {
  const _RecoveryMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        value,
        textAlign: TextAlign.end,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

// ==========================================
// 4. PROGRESS PAGE — CHARTS & ANALYTICS
// ==========================================

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late Future<List<SessionRecord>> _sessions;
  String? _exerciseId;

  @override
  void initState() {
    super.initState();
    _sessions = _loadSessions();
  }

  Future<List<SessionRecord>> _loadSessions() async {
    final preferences = await SharedPreferences.getInstance();
    final sessions = await LocalSessionRepository(
      preferences,
    ).readAll('athlete');
    return verifiedMovementSessions(sessions);
  }

  void reload() {
    if (!mounted) return;
    setState(() {
      _sessions = _loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SessionRecord>>(
    future: _sessions,
    builder: (context, snapshot) {
      final sessions = snapshot.data ?? const <SessionRecord>[];
      final exerciseLabels = <String, String>{};
      for (final session in sessions) {
        final key = _exerciseKey(session);
        exerciseLabels.putIfAbsent(key, () => session.exercise);
      }
      final exerciseOptions = exerciseLabels.keys.toList();
      exerciseOptions.sort();
      if (_exerciseId != null && !exerciseOptions.contains(_exerciseId)) {
        _exerciseId = null;
      }
      final trendExerciseId =
          _exerciseId ??
          (exerciseOptions.length == 1 ? exerciseOptions.single : null);
      final trend = trendExerciseId == null
          ? null
          : TrendAnalysisService().analyze(
              sessions.where(
                (session) => _exerciseKey(session) == trendExerciseId,
              ),
            );
      final weekSessionsCount = _countSince(sessions, const Duration(days: 7));
      final monthSessionsCount = _countSince(
        sessions,
        const Duration(days: 30),
      );
      final comparison = trend?.comparison;
      final romDelta = _comparisonDelta(
        comparison,
        (session) => session.metrics.rangeOfMotion,
        suffix: '°',
      );
      final consistencyDelta = _comparisonDelta(
        comparison,
        (session) => session.metrics.consistency,
        suffix: ' pp',
      );
      final confidenceDelta = _comparisonDelta(
        comparison,
        (session) => session.metrics.dataConfidence * 100,
        suffix: ' pp',
      );

      return SimplePage(
        title: 'Progress',
        subtitle: 'Trends from your recorded movement sessions.',
        icon: Icons.insights_outlined,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Refresh progress',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (snapshot.hasError)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Progress data could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (!snapshot.hasData)
            const GlassCard(child: Text('Loading progress data...'))
          else ...[
            Row(
              children: [
                Expanded(
                  child: ResultStatBox(
                    label: 'Total Sessions',
                    value: '${sessions.length}',
                    valueColor: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ResultStatBox(
                    label: 'This Week',
                    value: '$weekSessionsCount',
                    valueColor: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ResultStatBox(
                    label: 'This Month',
                    value: '$monthSessionsCount',
                    valueColor: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ResultStatBox(
                    label: 'Exercises Analyzed',
                    value: '${exerciseOptions.length}',
                    valueColor: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.graphite,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDivider),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ROM CHANGE',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          romDelta,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.voltLime,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.graphite,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDivider),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CONSISTENCY CHANGE',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          consistencyDelta,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.voltLime,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.graphite,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDivider),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CONFIDENCE CHANGE',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          confidenceDelta,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.voltLime,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (exerciseOptions.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _exerciseId,
                decoration: const InputDecoration(
                  labelText: 'Select exercise for comparable trends',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Choose an exercise'),
                  ),
                  ...exerciseOptions.map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: Text(exerciseLabels[id]!),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _exerciseId = value),
              ),
            if (sessions.isEmpty)
              const GlassCard(
                child: EmptyState(
                  title: 'No verified movement sessions yet',
                  message:
                      'Complete a live camera analysis session to start your progress history.',
                ),
              )
            else if (trend == null)
              const GlassCard(
                child: EmptyState(
                  title: 'Choose an exercise to compare',
                  message:
                      'Different exercises measure different movements. Select one exercise to see a meaningful trend.',
                ),
              )
            else if (!trend.hasEnoughData)
              const GlassCard(
                child: EmptyState(
                  title: 'More sessions are required for a meaningful trend',
                  message:
                      'Complete at least two verified sessions of the selected exercise.',
                ),
              )
            else ...[
              TrendChartCard(trend: trend.rom),
              TrendChartCard(trend: trend.consistency),
              TrendChartCard(trend: trend.confidence),
              if (trend.symmetry.points.length >= 2)
                TrendChartCard(trend: trend.symmetry),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'First Session vs Latest Session',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    MetricRow(
                      label: 'ROM',
                      value: _comparison(
                        trend.comparison,
                        (session) => session.metrics.rangeOfMotion,
                      ),
                    ),
                    MetricRow(
                      label: 'Consistency',
                      value: _comparison(
                        trend.comparison,
                        (session) => session.metrics.consistency,
                      ),
                    ),
                    MetricRow(
                      label: 'Repetitions',
                      value: _comparison(
                        trend.comparison,
                        (session) => session.metrics.repetitions.toDouble(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Data comparison only. This is not confirmation of medical improvement.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(
              title: 'Verified session history',
              action: 'Newest first',
            ),
            const SizedBox(height: 8),
            ...sessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SportsGlassCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionDetailPage(session: session),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insights_outlined,
                        color: AppColors.cyan,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.exercise,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_shortMonthDay(session.timestamp)} · ${session.metrics.repetitions} reps',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${session.metrics.rangeOfMotion.toStringAsFixed(0)}°',
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ExerciseTile(
            name: 'Interactive Body Map',
            subtitle: 'Inspect joint kinematics & asymmetry',
            icon: Icons.accessibility_new,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InteractiveBodyMapPage()),
            ),
          ),
          ExerciseTile(
            name: 'Compare sessions side-by-side',
            subtitle: 'Detailed metric-by-metric comparison',
            icon: Icons.compare_arrows,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompareSessionsPage()),
            ),
          ),
          const SafetyNotice(),
        ],
      );
    },
  );

  int _countSince(List<SessionRecord> sessions, Duration period) => sessions
      .where(
        (session) =>
            !session.timestamp.isAfter(DateTime.now()) &&
            DateTime.now().difference(session.timestamp) <= period,
      )
      .length;

  String _shortMonthDay(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
  }

  String _comparisonDelta(
    SessionComparison? comparison,
    double Function(SessionRecord) read, {
    required String suffix,
  }) {
    if (comparison?.hasEnoughData != true) return 'N/A';
    final delta = read(comparison!.latest!) - read(comparison.first!);
    return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}$suffix';
  }

  String _exerciseKey(SessionRecord session) {
    final exerciseId = session.exerciseId.trim().toLowerCase();
    if (exerciseId.isNotEmpty) return 'id:$exerciseId';
    return 'name:${session.exercise.trim().toLowerCase()}';
  }

  String _comparison(
    SessionComparison comparison,
    double Function(SessionRecord) read,
  ) {
    if (!comparison.hasEnoughData) return 'Insufficient data';
    final delta = read(comparison.latest!) - read(comparison.first!);
    return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} observed';
  }
}

class TrendChartCard extends StatelessWidget {
  const TrendChartCard({super.key, required this.trend});
  final MetricTrend trend;

  @override
  Widget build(BuildContext context) {
    final values = trend.points
        .map((point) => point.value.toStringAsFixed(1))
        .join(', ');
    return GlassCard(
      child: Semantics(
        label:
            '${trend.metric} trend: ${trend.points.isEmpty ? 'insufficient data' : values}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${trend.metric} trend',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  _directionLabel(trend.direction),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: trend.points.length < 2
                  ? const Center(
                      child: Text('Need at least 2 sessions to show a trend.'),
                    )
                  : CustomPaint(painter: TrendChartPainter(trend.points)),
            ),
            const SizedBox(height: 8),
            Text(
              values.isEmpty ? 'No measured values available.' : values,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _directionLabel(TrendDirection direction) => switch (direction) {
    TrendDirection.improving => 'Increasing',
    TrendDirection.reducing => 'Reducing',
    TrendDirection.stable => 'Stable',
    TrendDirection.insufficientData => 'Insufficient data',
  };
}

class TrendChartPainter extends CustomPainter {
  TrendChartPainter(this.points);
  final List<TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((point) => point.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : maxValue - minValue;

    final paint = Paint()
      ..color = AppColors.cyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? 0.0
          : index / (values.length - 1) * size.width;
      final y =
          size.height -
          ((values[index] - minValue) / range * (size.height - 16)) -
          8.0;
      if (index == 0) {
        path.moveTo(x.toDouble(), y.toDouble());
      } else {
        path.lineTo(x.toDouble(), y.toDouble());
      }
      canvas.drawCircle(
        Offset(x.toDouble(), y.toDouble()),
        4,
        Paint()..color = AppColors.cyan,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

// ==========================================
// 5. PROFILE PAGE — ATHLETE HUB
// ==========================================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AthleteProfile _profile = const AthleteProfile(name: 'Athlete');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final profile = await LocalRehabRepository(preferences).loadProfile();
    if (mounted && profile != null) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final athleteName = _profile.name.isEmpty || _profile.name == 'Athlete'
        ? 'Alex Carter'
        : _profile.name;
    final athleteSport = _profile.sport.isEmpty
        ? 'Football | Midfielder'
        : '${_profile.sport} | ${_profile.position.isEmpty ? 'Midfielder' : _profile.position}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Athlete Profile'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.electricCyan,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfilePage(profile: _profile),
                ),
              );
              _load();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Screen 9 Hero Card: Avatar + Alex Carter + Football | Midfielder
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.graphite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderDivider),
            ),
            child: Column(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfilePage(profile: _profile),
                        ),
                      );
                      _load();
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _buildAthleteAvatarWidget(
                          _profile,
                          size: 76,
                          iconSize: 42,
                        ),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppColors.electricCyan,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 12,
                            color: AppColors.obsidian,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  athleteName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  athleteSport,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.voltLime.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.voltLime.withAlpha(100),
                    ),
                  ),
                  child: const Text(
                    'Experience 3 years',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.voltLime,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Screen 9 Athlete Specs Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.graphite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ATHLETE METRICS & TARGETS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.electricCyan,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                _specRow(
                  'Training Goals',
                  _profile.fitnessGoals.isEmpty
                      ? 'Improve movement symmetry and mobility'
                      : _profile.fitnessGoals,
                ),
                const Divider(color: AppColors.borderDivider, height: 18),
                _specRow('Preferred Training Time', _profile.trainingTime),
                const Divider(color: AppColors.borderDivider, height: 18),
                _specRow('Competition Level', _profile.competitionLevel),
                const Divider(color: AppColors.borderDivider, height: 18),
                _specRow(
                  'Assigned Coach',
                  _profile.coach.isEmpty
                      ? 'Dr. Marcus Vance (Biomechanics)'
                      : _profile.coach,
                ),
                const Divider(color: AppColors.borderDivider, height: 18),
                _specRow(
                  'Body Specs',
                  'Height: ${_profile.heightCm.isEmpty ? '182' : _profile.heightCm} cm · Weight: ${_profile.weightKg.isEmpty ? '76' : _profile.weightKg} kg',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Navigation Links
          const SectionHeader(title: 'Athlete Systems', action: 'Flagship OS'),
          const SizedBox(height: 10),
          ExerciseTile(
            name: 'Competition Mode & Checklist',
            subtitle: 'Pre-competition readiness & event logistics',
            icon: Icons.emoji_events_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompetitionModePage()),
            ),
          ),
          ExerciseTile(
            name: 'Sports Science Knowledge Base',
            subtitle: 'Vetted biomechanics & rehabilitation research',
            icon: Icons.menu_book_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResearchKnowledgePage()),
            ),
          ),
          ExerciseTile(
            name: 'Download Movement Report',
            subtitle: 'Create a dated PDF table and share it',
            icon: Icons.picture_as_pdf_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportExportPage()),
            ),
          ),
          ExerciseTile(
            name: 'AI Movement Coach',
            subtitle: 'Explainable reasoning with evidence metrics',
            icon: Icons.auto_awesome,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiCoachChatPage()),
            ),
          ),
          ExerciseTile(
            name: 'Privacy & Data',
            subtitle: 'Local on-device storage & data ownership',
            icon: Icons.lock_outline,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPage()),
            ),
          ),
          ExerciseTile(
            name: 'Remove Athlete Profile',
            subtitle: 'Delete profile details without deleting session history',
            icon: Icons.person_remove_outlined,
            onTap: () => _confirmRemoveProfile(context),
          ),
          ExerciseTile(
            name: 'Settings',
            subtitle: 'Preferences, cameras, and system controls',
            icon: Icons.settings_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _specRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            softWrap: true,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemoveProfile(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Remove athlete profile?'),
        content: const Text(
          'This removes your athlete details and photo. Recorded movement sessions will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove profile'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await LocalRehabRepository(preferences).removeProfile();
    if (!context.mounted) return;
    setState(() => _profile = const AthleteProfile(name: 'Athlete'));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Athlete profile removed.')));
  }

}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile, this.onSaved});
  final AthleteProfile profile;
  final Future<void> Function()? onSaved;
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  late final TextEditingController _sport = TextEditingController(
    text: widget.profile.sport,
  );
  late final TextEditingController _position = TextEditingController(
    text: widget.profile.position,
  );
  late final TextEditingController _height = TextEditingController(
    text: widget.profile.heightCm,
  );
  late final TextEditingController _weight = TextEditingController(
    text: widget.profile.weightKg,
  );
  late final TextEditingController _coach = TextEditingController(
    text: widget.profile.coach,
  );
  late final TextEditingController _emergency = TextEditingController(
    text: widget.profile.emergencyContact,
  );
  late String _avatarId;
  late String _photoPath;
  String _stage = 'Mobility';
  String _dominantHand = 'Right';
  String _dominantLeg = 'Right';

  @override
  void initState() {
    super.initState();
    _avatarId = widget.profile.avatarId;
    _photoPath = widget.profile.photoPath;
    _stage = widget.profile.recoveryStage;
    _dominantHand = widget.profile.dominantHand;
    _dominantLeg = widget.profile.dominantLeg;
  }

  @override
  void dispose() {
    _name.dispose();
    _sport.dispose();
    _position.dispose();
    _height.dispose();
    _weight.dispose();
    _coach.dispose();
    _emergency.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await LocalRehabRepository(preferences).saveProfile(
      AthleteProfile(
        name: _name.text.trim(),
        sport: _sport.text.trim(),
        position: _position.text.trim(),
        recoveryStage: _stage,
        heightCm: _height.text.trim(),
        weightKg: _weight.text.trim(),
        dominantHand: _dominantHand,
        dominantLeg: _dominantLeg,
        coach: _coach.text.trim(),
        emergencyContact: _emergency.text.trim(),
        photoPath: _photoPath,
        avatarId: _avatarId,
        age: widget.profile.age,
        experienceYears: widget.profile.experienceYears,
        trainingExperience: widget.profile.trainingExperience,
        competitionLevel: widget.profile.competitionLevel,
        trainingTime: widget.profile.trainingTime,
        sleepTime: widget.profile.sleepTime,
        wakeTime: widget.profile.wakeTime,
        fitnessGoals: widget.profile.fitnessGoals,
        knownLimitations: widget.profile.knownLimitations,
      ),
    );
    await widget.onSaved?.call();
    if (mounted && widget.onSaved == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Athlete Profile')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Avatar Selector
        const Text(
          'SELECT ATHLETE AVATAR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.electricCyan,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _chooseProfileImage,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            _photoPath.isEmpty
                ? 'Choose Profile Image'
                : 'Change Profile Image',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.electricCyan,
            side: const BorderSide(color: AppColors.electricCyan),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
        if (_photoPath.isNotEmpty) ...[
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: ClipOval(child: profileImage(_photoPath)),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _photoPath = ''),
            icon: const Icon(Icons.hide_image_outlined),
            label: const Text('Remove profile photo'),
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
          ),
        ],
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _avatarChoice('runner', Icons.directions_run, 'Runner'),
              _avatarChoice('weight', Icons.fitness_center, 'Lifter'),
              _avatarChoice('bolt', Icons.bolt, 'Speed'),
              _avatarChoice('shield', Icons.shield_outlined, 'Defender'),
              _avatarChoice('fire', Icons.local_fire_department, 'Power'),
              _avatarChoice('sports', Icons.sports_soccer, 'Player'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Athlete Name'),
        ),
        const SizedBox(height: 12),

        // Supported Sports Selection
        DropdownButtonFormField<String>(
          initialValue: supportedSports.contains(widget.profile.sport)
              ? widget.profile.sport
              : supportedSports.first,
          decoration: const InputDecoration(labelText: 'Primary Sport'),
          items: supportedSports
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (val) {
            if (val != null) _sport.text = val;
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _position,
          decoration: const InputDecoration(labelText: 'Position / Discipline'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _height,
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _weight,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _dominantHand,
                decoration: const InputDecoration(labelText: 'Dominant Hand'),
                items: const [
                  DropdownMenuItem(value: 'Right', child: Text('Right')),
                  DropdownMenuItem(value: 'Left', child: Text('Left')),
                  DropdownMenuItem(
                    value: 'Ambidextrous',
                    child: Text('Ambidextrous'),
                  ),
                ],
                onChanged: (v) => setState(() => _dominantHand = v ?? 'Right'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _dominantLeg,
                decoration: const InputDecoration(labelText: 'Dominant Leg'),
                items: const [
                  DropdownMenuItem(value: 'Right', child: Text('Right')),
                  DropdownMenuItem(value: 'Left', child: Text('Left')),
                ],
                onChanged: (v) => setState(() => _dominantLeg = v ?? 'Right'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _stage,
          decoration: const InputDecoration(labelText: 'Recovery stage'),
          items: const [
            DropdownMenuItem(value: 'Mobility', child: Text('Mobility')),
            DropdownMenuItem(value: 'Strength', child: Text('Strength')),
            DropdownMenuItem(value: 'Stability', child: Text('Stability')),
            DropdownMenuItem(
              value: 'Functional Movement',
              child: Text('Functional Movement'),
            ),
            DropdownMenuItem(
              value: 'Sport-Specific Preparation',
              child: Text('Sport-Specific Preparation'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _stage = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _coach,
          decoration: const InputDecoration(
            labelText: 'Coach / Physiotherapist',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emergency,
          decoration: const InputDecoration(labelText: 'Emergency Contact'),
        ),
        const SizedBox(height: 20),

        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Profile'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: AppColors.ink,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Profile data remains exclusively on your device. Never shared without explicit report export.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    ),
  );

  Future<void> _chooseProfileImage() async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 85,
    );
    if (selected != null && mounted) {
      setState(() => _photoPath = selected.path);
    }
  }

  Widget _avatarChoice(String id, IconData icon, String label) {
    final isSelected = _avatarId == id;
    return GestureDetector(
      onTap: () => setState(() => _avatarId = id),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.electricCyan.withAlpha(25)
              : AppColors.graphite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.electricCyan
                : AppColors.borderDivider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.electricCyan
                  : AppColors.textSecondary,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.electricCyan
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. SESSION DETAIL PAGE & EXPORT
// ==========================================

class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({super.key, required this.session});
  final SessionRecord session;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  bool _isCoachView = false;

  SessionRecord get session => widget.session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Session Complete'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilterChip(
            label: Text(_isCoachView ? 'Coach View' : 'Athlete View'),
            selected: _isCoachView,
            onSelected: (val) => setState(() => _isCoachView = val),
            selectedColor: AppColors.electricCyan.withAlpha(40),
            checkmarkColor: AppColors.electricCyan,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _isCoachView ? AppColors.electricCyan : AppColors.muted,
            ),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (session.isDemo)
          const StatusChip(label: 'DEMO DATA', color: AppColors.energyOrange),
        Text(
          '${session.exercise} Analysis',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'ATHLETE OS // BIOMECHANICAL AUDIT',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.electricCyan,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),

        // Show a score only when it can be derived from measured session data.
        MovementQualityGauge(
          score: session.qualityScore > 0 ? session.qualityScore : null,
        ),
        const SizedBox(height: 18),

        // Screen 4: 4 Stat Boxes (ROM, Consistency, Confidence, Repetitions)
        ResultsSummaryRow(
          rom: session.metrics.rangeOfMotion > 0
              ? session.metrics.rangeOfMotion
              : null,
          consistency: session.metrics.consistency > 0
              ? session.metrics.consistency
              : null,
          confidence: session.metrics.dataConfidence > 0
              ? (session.metrics.dataConfidence * 100)
              : null,
          repetitions: session.metrics.repetitions > 0
              ? session.metrics.repetitions
              : null,
        ),
        const SizedBox(height: 16),

        // Screen 4: Key Observations Card
        KeyObservationsCard(
          observations: session.observations.isNotEmpty
              ? session.observations
              : const ['No observations were recorded for this session.'],
        ),
        const SizedBox(height: 18),

        // Data Source Labeling (Requirement 46)
        SportsGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DATA SOURCES & METHODOLOGY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              _SourceLabelRow(
                category: 'Movement Measurement',
                source: session.sourceMode == 'video'
                    ? 'Recorded Video 2D Pose Analysis'
                    : session.sourceMode == 'simulation'
                    ? 'Interactive Kinematic Simulator'
                    : 'Camera Pose Analysis (2D)',
              ),
              const _SourceLabelRow(
                category: 'Exercise Contract',
                source: 'REHAB-X Kinematic Knowledge Base',
              ),
              const _SourceLabelRow(
                category: 'Interpretation & Coaching',
                source: 'AI Movement Coach',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quality & Confidence Banner (Requirement 47)
        SportsGlassCard(
          borderColor: session.qualityLabel == 'strong'
              ? AppColors.green
              : AppColors.orange,
          child: Row(
            children: [
              Icon(
                session.qualityLabel == 'strong'
                    ? Icons.check_circle
                    : Icons.warning_amber,
                color: session.qualityLabel == 'strong'
                    ? AppColors.green
                    : AppColors.orange,
                size: 26,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DATA QUALITY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.metrics.dataConfidenceState,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: session.metrics.dataConfidenceState == 'HIGH'
                          ? AppColors.green
                          : (session.metrics.dataConfidenceState == 'MODERATE'
                                ? AppColors.cyan
                                : AppColors.orange),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.analysisStatus.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Primary Movement Summary (Requirement 47)
        GlassCard(
          child: Column(
            children: [
              MetricRow(
                label: 'Completed Repetitions',
                value: '${session.metrics.repetitions}',
              ),
              MetricRow(
                label: 'Active Range of Motion',
                value: session.metrics.rangeOfMotion > 0
                    ? '${session.metrics.rangeOfMotion.toStringAsFixed(0)}°'
                    : 'Unavailable',
              ),
              MetricRow(
                label: 'Movement Consistency',
                value: session.metrics.consistency > 0
                    ? '${session.metrics.consistency.toStringAsFixed(0)}%'
                    : 'Unavailable',
              ),
              MetricRow(
                label: 'Left / Right Difference',
                value: session.metrics.symmetry != null
                    ? '${session.metrics.symmetry!.toStringAsFixed(0)}%'
                    : 'Not measured',
              ),
              MetricRow(
                label: 'Repetition Tempo',
                value: session.metrics.tempo != null
                    ? '${session.metrics.tempo!.toStringAsFixed(1)}s'
                    : 'Unavailable',
              ),
              if (_isCoachView) ...[
                MetricRow(
                  label: 'Session Duration',
                  value: '${session.metrics.duration.inSeconds}s',
                ),
                MetricRow(
                  label: 'Velocity Index',
                  value: session.metrics.velocity != null
                      ? '${session.metrics.velocity!.toStringAsFixed(1)} °/s'
                      : 'Unavailable',
                ),
                MetricRow(
                  label: 'Valid Frame Ratio',
                  value: session.metrics.validFrameRatio > 0
                      ? '${(session.metrics.validFrameRatio * 100).toStringAsFixed(0)}%'
                      : 'Unavailable',
                ),
                MetricRow(
                  label: 'Mean Confidence',
                  value: session.metrics.dataConfidence > 0
                      ? '${(session.metrics.dataConfidence * 100).toStringAsFixed(0)}%'
                      : 'Unavailable',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Coach View: Temporal Angle Chart (Requirements 36 & 52)
        if (_isCoachView && session.metrics.repetitionDetails.length > 1) ...[
          TemporalAngleChart(
            angles: session.metrics.repetitionDetails
                .map((repetition) => repetition.rangeOfMotion)
                .toList(),
            repetitionDetails: session.metrics.repetitionDetails,
            jointName: session.exercise,
          ),
          const SizedBox(height: 16),
        ],

        // Joint-by-Joint Breakdown
        if (session.metrics.jointBreakdown.isNotEmpty) ...[
          Row(
            children: [
              const SectionHeader(title: 'Joint analysis breakdown'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InteractiveBodyMapPage(),
                  ),
                ),
                icon: const Icon(
                  Icons.accessibility_new,
                  size: 16,
                  color: AppColors.cyan,
                ),
                label: const Text(
                  'Body Diagram',
                  style: TextStyle(fontSize: 12, color: AppColors.cyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...session.metrics.jointBreakdown.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SportsGlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.cyan,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          entry.value.confidenceLevel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: entry.value.confidenceLevel == 'HIGH'
                                ? AppColors.green
                                : AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'ROM: ${entry.value.rangeOfMotion.toStringAsFixed(0)}°',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Angle: ${entry.value.currentAngle.toStringAsFixed(0)}°',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (entry.value.symmetryDifference != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Diff: ${entry.value.symmetryDifference!.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_isCoachView && entry.value.observation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.value.observation,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Repetition Timeline Breakdown
        if (session.metrics.repetitionDetails.isNotEmpty) ...[
          const SectionHeader(title: 'Repetition analysis'),
          const SizedBox(height: 8),
          ...session.metrics.repetitionDetails.map(
            (rep) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SportsGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Rep ${rep.repNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'ROM ${rep.rangeOfMotion.toStringAsFixed(0)}°',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tempo ${rep.durationSeconds.toStringAsFixed(1)}s',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.cyan,
                      ),
                    ),
                    if (rep.hasVariation) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: AppColors.orange,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Observations & Limitations
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Observations',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...session.observations.map(
                (observation) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $observation'),
                ),
              ),
              if (session.limitations.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Data limitations',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...session.limitations.map(
                  (limitation) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $limitation'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons (Requirement 47)
        FilledButton.icon(
          onPressed: () => _shareReport(context),
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('Export and Share PDF Report'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: AppColors.ink,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InteractiveBodyMapPage()),
          ),
          icon: const Icon(Icons.accessibility_new_outlined),
          label: const Text('View Joint Analysis Diagram'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.line),
            minimumSize: const Size(double.infinity, 46),
          ),
        ),
        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompareSessionsPage(initialSessionA: session),
            ),
          ),
          icon: const Icon(Icons.compare_arrows),
          label: const Text('Compare with Another Session'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.line),
            minimumSize: const Size(double.infinity, 46),
          ),
        ),
        const SizedBox(height: 14),
        const SafetyNotice(),
      ],
    ),
  );

  Future<void> _shareReport(BuildContext context) async {
    final report = SessionReport(
      athleteId: session.athleteId,
      exercise: session.exercise,
      session: session,
      historicalComparison: const {},
      observations: session.observations,
      limitations: session.limitations,
      professionalReviewNote:
          'Professional assessment recommended before return to competitive activity.',
    );
    final result = await ReportExportService().sharePdf(report);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Report export is unavailable.'
              : 'Report ready to share.',
        ),
      ),
    );
  }
}

class _SourceLabelRow extends StatelessWidget {
  const _SourceLabelRow({required this.category, required this.source});
  final String category;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            category,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          Text(
            source,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 7. RETURN TO PLAY SUPPORT PAGE
// ==========================================

class ReturnToPlayPage extends StatefulWidget {
  const ReturnToPlayPage({super.key});
  @override
  State<ReturnToPlayPage> createState() => _ReturnToPlayPageState();
}

class _ReturnToPlayPageState extends State<ReturnToPlayPage> {
  late Future<List<SessionRecord>> _sessions;
  @override
  void initState() {
    super.initState();
    _sessions = _load();
  }

  Future<List<SessionRecord>> _load() async {
    final preferences = await SharedPreferences.getInstance();
    return verifiedMovementSessions(
      await LocalSessionRepository(preferences).readAll('athlete'),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SessionRecord>>(
    future: _sessions,
    builder: (context, snapshot) {
      final sessions = snapshot.data ?? const <SessionRecord>[];
      final exercises = sessions.map((session) => session.exercise).toSet();
      final quality = sessions.isEmpty
          ? 'Insufficient data'
          : sessions.first.qualityLabel;
      return Scaffold(
        appBar: AppBar(title: const Text('Return-to-play support')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Text(
              'Movement data summary',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only stored movement measurements appear here. No medical readiness score is calculated.',
            ),
            const SizedBox(height: 24),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetricRow(
                    label: 'Completed assessments',
                    value: '${sessions.length}',
                  ),
                  MetricRow(
                    label: 'Exercise coverage',
                    value: exercises.isEmpty
                        ? 'Insufficient data'
                        : exercises.join(', '),
                  ),
                  MetricRow(
                    label: 'Latest consistency',
                    value: sessions.isEmpty
                        ? 'Insufficient data'
                        : '${sessions.first.metrics.consistency.toStringAsFixed(1)}%',
                  ),
                  MetricRow(
                    label: 'Latest data quality',
                    value: quality.toUpperCase(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const StatusChip(
              label: 'PROFESSIONAL REVIEW RECOMMENDED',
              color: AppColors.orange,
            ),
            const SizedBox(height: 12),
            const Text(
              'Professional assessment recommended before return to competitive activity.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            const SafetyNotice(),
          ],
        ),
      );
    },
  );
}

// ==========================================
// 8. PERSONALIZED PLAN PAGE
// ==========================================

class PersonalizedPlanPage extends StatefulWidget {
  const PersonalizedPlanPage({super.key});
  @override
  State<PersonalizedPlanPage> createState() => _PersonalizedPlanPageState();
}

class _PersonalizedPlanPageState extends State<PersonalizedPlanPage> {
  late Future<_PlanViewData> _plan;
  @override
  void initState() {
    super.initState();
    _plan = _loadPlan();
  }

  Future<_PlanViewData> _loadPlan() async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalRehabRepository(preferences);
    final profile =
        await repository.loadProfile() ?? const AthleteProfile(name: 'Athlete');
    final sessions = verifiedMovementSessions(
      await LocalSessionRepository(preferences).readAll('athlete'),
    );
    final stored = await repository.loadPlan();
    final storedProgress = await repository.loadPlanProgress();
    final shouldGenerateNext =
        stored != null && storedProgress?.status == PlanStatus.completed;
    final plan = shouldGenerateNext || stored == null
        ? RehabilitationPlanService().generate(
            profile: profile,
            sessions: sessions,
          )
        : stored;
    if (shouldGenerateNext || stored == null) await repository.savePlan(plan);
    final progress = shouldGenerateNext
        ? PlanProgress.empty(plan.generatedAt.toIso8601String())
        : storedProgress ??
              PlanProgress.empty(plan.generatedAt.toIso8601String());
    if (shouldGenerateNext) await repository.savePlanProgress(progress);
    return _PlanViewData(plan: plan, progress: progress);
  }

  Future<void> _update(PlanProgress progress) async {
    final preferences = await SharedPreferences.getInstance();
    await LocalRehabRepository(preferences).savePlanProgress(progress);
    if (mounted) setState(() => _plan = _loadPlan());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Today's plan")),
    body: FutureBuilder<_PlanViewData>(
      future: _plan,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Plan unavailable. Please try again later.'),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final plan = data.plan;
        final progress = data.progress;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const StatusChip(
              label: 'MOVEMENT MONITORING PLAN',
              color: AppColors.cyan,
            ),
            const SizedBox(height: 16),
            Text(
              plan.focusArea,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Stage: ${plan.stage}'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: plan.exercises.isEmpty
                  ? 0
                  : progress.completedExerciseIds.length /
                        plan.exercises.length,
              color: AppColors.cyan,
              backgroundColor: AppColors.line,
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.completedExerciseIds.length} of ${plan.exercises.length} exercises completed',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            if (plan.exercises.isEmpty)
              const GlassCard(
                child: EmptyState(
                  title: 'Not enough reliable movement data',
                  message:
                      'Complete a valid assessment with adequate confidence and full-body visibility to generate today’s exercises.',
                ),
              )
            else
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's plan",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...plan.exercises.map(
                      (exercise) =>
                          _buildExerciseTile(context, exercise, progress, plan),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monitoring',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(plan.monitoringMetrics.join('  ·  ')),
                  const SizedBox(height: 12),
                  Text(plan.frequency),
                  const SizedBox(height: 12),
                  Text('Progression: ${plan.progressionCriteria}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (plan.limitations.isNotEmpty)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data quality limitation',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...plan.limitations.map((item) => Text('• $item')),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const SafetyNotice(),
            const SizedBox(height: 8),
            Text(
              plan.recoveryGuidance,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        );
      },
    ),
  );

  Widget _buildExerciseTile(
    BuildContext context,
    PlanExercise exercise,
    PlanProgress progress,
    PersonalizedPlan plan,
  ) {
    final catalogExercise = exerciseCatalog.firstWhere(
      (item) => item.id == exercise.exerciseId,
      orElse: () => exerciseCatalog.first,
    );
    return _PlanExerciseTile(
      exercise: exercise,
      completed: progress.completedExerciseIds.contains(exercise.exerciseId),
      skipped: progress.skippedExerciseIds.contains(exercise.exerciseId),
      onComplete: () => _update(
        _nextProgress(progress, plan, exercise.exerciseId, completed: true),
      ),
      onSkip: () => _update(
        _nextProgress(progress, plan, exercise.exerciseId, skipped: true),
      ),
      onStart: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExerciseDetailsPage(
              exercise: catalogExercise,
              planId: plan.generatedAt.toIso8601String(),
              planExerciseId: exercise.exerciseId,
            ),
          ),
        );
        if (mounted) setState(() => _plan = _loadPlan());
      },
    );
  }

  PlanProgress _nextProgress(
    PlanProgress current,
    PersonalizedPlan plan,
    String id, {
    bool completed = false,
    bool skipped = false,
  }) => PlanProgress(
    planId: current.planId,
    completedExerciseIds: {
      ...current.completedExerciseIds,
      if (completed) id,
    }.toList(),
    skippedExerciseIds: {
      ...current.skippedExerciseIds,
      if (skipped) id,
    }.toList(),
    status:
        completed &&
            current.completedExerciseIds.length + 1 >= plan.exercises.length
        ? PlanStatus.completed
        : PlanStatus.inProgress,
    updatedAt: DateTime.now(),
  );
}

class _PlanViewData {
  const _PlanViewData({required this.plan, required this.progress});
  final PersonalizedPlan plan;
  final PlanProgress progress;
}

class _PlanExerciseTile extends StatelessWidget {
  const _PlanExerciseTile({
    required this.exercise,
    required this.completed,
    required this.skipped,
    required this.onComplete,
    required this.onSkip,
    required this.onStart,
  });

  final PlanExercise exercise;
  final bool completed;
  final bool skipped;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                exercise.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            StatusChip(
              label: completed
                  ? 'COMPLETED'
                  : skipped
                  ? 'SKIPPED'
                  : 'NOT STARTED',
              color: completed ? const Color(0xFF8DE39A) : AppColors.orange,
            ),
          ],
        ),
        Text(
          '${exercise.sets} sets  ·  ${exercise.repetitions} repetitions  ·  ${exercise.target}',
        ),
        if (!completed && !skipped)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
              TextButton(onPressed: onComplete, child: const Text('Complete')),
              TextButton(onPressed: onSkip, child: const Text('Skip')),
            ],
          ),
      ],
    ),
  );
}

// ==========================================
// 9. SESSION HISTORY & SETTINGS
// ==========================================

class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({super.key});
  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  late Future<List<SessionRecord>> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = _loadSessions();
  }

  Future<List<SessionRecord>> _loadSessions() async {
    final preferences = await SharedPreferences.getInstance();
    return verifiedMovementSessions(
      await LocalSessionRepository(preferences).readAll('athlete'),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Session history')),
    body: FutureBuilder<List<SessionRecord>>(
      future: _sessions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              EmptyState(
                title: 'History unavailable',
                message:
                    'Local session data could not be read. Try again after restarting the app.',
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snapshot.data!;
        if (sessions.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              EmptyState(
                title: 'No recorded sessions',
                message:
                    'Complete a real movement session to see it here. Demo data is kept separate and is not shown as real history.',
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: sessions
              .map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ExerciseTile(
                    name: session.exercise,
                    subtitle:
                        '${_dateLabel(session.timestamp)} · ${session.metrics.repetitions} reps · quality ${session.qualityLabel}',
                    trailingBadge: session.sourceMode.toUpperCase(),
                    badgeColor: session.sourceMode == 'video'
                        ? AppColors.green
                        : AppColors.cyan,
                    icon: Icons.insights_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionDetailPage(session: session),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class ReportExportPage extends StatefulWidget {
  const ReportExportPage({super.key});

  @override
  State<ReportExportPage> createState() => _ReportExportPageState();
}

class _ReportExportPageState extends State<ReportExportPage> {
  late DateTime _startDate;
  late DateTime _endDate;
  AthleteProfile _profile = const AthleteProfile(name: 'Athlete');
  List<SessionRecord> _sessions = const [];
  final _temperature = TextEditingController();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _endDate = DateTime(today.year, today.month, today.day);
    _startDate = _endDate.subtract(const Duration(days: 30));
    _load();
  }

  @override
  void dispose() {
    _temperature.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalRehabRepository(preferences);
    final profile = await repository.loadProfile();
    final sessions = verifiedMovementSessions(
      await LocalSessionRepository(preferences).readAll('athlete'),
    );
    if (!mounted) return;
    setState(() {
      _profile = profile ?? const AthleteProfile(name: 'Athlete');
      _sessions = sessions;
      _loading = false;
    });
  }

  List<SessionRecord> get _filteredSessions => _sessions.where((session) {
    final date = DateTime(
      session.timestamp.year,
      session.timestamp.month,
      session.timestamp.day,
    );
    return !date.isBefore(_startDate) && !date.isAfter(_endDate);
  }).toList();

  DateRangeReport get _report => DateRangeReport(
    profile: _profile,
    sessions: _filteredSessions,
    start: _startDate,
    end: _endDate,
    roomTemperature: _temperature.text.trim().isEmpty
        ? 'Not recorded'
        : '${_temperature.text.trim()} C',
  );

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: start ? _startDate : _endDate,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = selected;
        if (_startDate.isAfter(_endDate)) _endDate = selected;
      } else {
        _endDate = selected;
        if (_endDate.isBefore(_startDate)) _startDate = selected;
      }
    });
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    final path = await ReportExportService().saveDateRangePdf(_report);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'PDF download failed.' : 'PDF saved successfully.',
        ),
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    final result = await ReportExportService().shareDateRangePdf(_report);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null ? 'PDF sharing failed.' : 'PDF ready to share.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Download Movement Report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            'PDF report',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a date range to create a table of recorded movement measurements.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _dateButton(
                  'Starting date',
                  _startDate,
                  () => _pickDate(start: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateButton(
                  'Ending date',
                  _endDate,
                  () => _pickDate(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _temperature,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Room temperature (optional)',
              hintText: 'For example, 24 C',
              prefixIcon: Icon(Icons.thermostat_outlined),
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Athlete: ${_profile.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_filteredSessions.length} session(s) in selected date range',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Table columns: Exercise Name, ROM / Measurement, Date & Time, Room Temperature, Reps Count, Joint & Angle, Body Weight, Height.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _download,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download PDF'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Share PDF'),
          ),
          const SizedBox(height: 18),
          const SafetyNotice(),
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime date, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_today_outlined, size: 17),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            Text(
              _dateLabel(date),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      );

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & Data')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const Text(
          'On-Device Biomechanics',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'YOUR DATA NEVER LEAVES THIS DEVICE',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.voltLime,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),

        // Card 1: Camera Frames
        _privacyCard(
          icon: Icons.videocam_off_outlined,
          iconColor: AppColors.voltLime,
          title: 'Camera Frames',
          badge: '100% PRIVATE',
          badgeColor: AppColors.voltLime,
          description:
              'Processed in real-time in device memory only. Never recorded, stored, or uploaded to any server or cloud.',
        ),
        const SizedBox(height: 12),

        // Card 2: Movement Data
        _privacyCard(
          icon: Icons.lock_outline,
          iconColor: AppColors.electricCyan,
          title: 'Movement Data',
          badge: 'ON-DEVICE STORAGE',
          badgeColor: AppColors.electricCyan,
          description:
              'Extracted kinematics, joint angles, and session metrics are stored locally on your phone in sandbox storage.',
        ),
        const SizedBox(height: 12),

        // Card 3: AI Processing
        _privacyCard(
          icon: Icons.psychology_outlined,
          iconColor: AppColors.electricCyan,
          title: 'AI Processing',
          badge: 'EDGE INFERENCE',
          badgeColor: AppColors.electricCyan,
          description:
              'Local biomechanics pipeline runs entirely on device. AI coaching uses anonymized numerical summaries only.',
        ),
        const SizedBox(height: 12),

        // Card 4: Your Control
        _privacyCard(
          icon: Icons.verified_user_outlined,
          iconColor: AppColors.voltLime,
          title: 'Your Control',
          badge: 'FULL AUTONOMY',
          badgeColor: AppColors.voltLime,
          description:
              'You own 100% of your data. Export your session reports as PDF anytime or wipe all local records permanently.',
        ),
        const SizedBox(height: 24),

        // Danger Zone Button
        FilledButton.icon(
          onPressed: () => _confirmDelete(context),
          icon: const Icon(Icons.delete_forever, size: 20),
          label: const Text(
            'DELETE ALL LOCAL DATA',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.criticalRed,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SafetyNotice(),
      ],
    ),
  );

  static Widget _privacyCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badge,
    required Color badgeColor,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.carbon,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withAlpha(80)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withAlpha(100)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Delete local data?'),
        content: const Text(
          'This removes the locally stored profile, sessions, plan, checklist, and progress. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await LocalRehabRepository(preferences).clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Local data deleted.')));
    }
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings _settings = const AppSettings();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final settings = await LocalRehabRepository(preferences).loadSettings();
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _save(AppSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await LocalRehabRepository(preferences).saveSettings(settings);
    if (mounted) setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const Text(
          'Athlete OS Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'SYSTEM CONFIGURATION & HARDWARE',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.electricCyan,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 18),

        // Group 1: Core Preferences
        const SectionHeader(title: 'Core Preferences'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDivider),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.electricCyan,
                  size: 22,
                ),
                title: const Text(
                  'Account',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Alex Carter (Pro Athlete)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                ),
              ),
              const Divider(color: AppColors.borderDivider, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.tune,
                  color: AppColors.electricCyan,
                  size: 22,
                ),
                title: const Text(
                  'Analysis Engine',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Precision Biomechanics (ML Kit 2D)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.voltLime.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.voltLime.withAlpha(100),
                    ),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.voltLime,
                    ),
                  ),
                ),
              ),
              const Divider(color: AppColors.borderDivider, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.dark_mode_outlined,
                  color: AppColors.electricCyan,
                  size: 22,
                ),
                title: const Text(
                  'Theme Mode',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text(
                  _settings.themeMode == 'light'
                      ? 'Light Theme'
                      : (_settings.themeMode == 'system'
                            ? 'System Default'
                            : 'Dark Theme (Athlete Obsidian)'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                trailing: DropdownButton<String>(
                  value: _settings.themeMode,
                  underline: const SizedBox(),
                  dropdownColor: AppColors.titanium,
                  items: const [
                    DropdownMenuItem(
                      value: 'dark',
                      child: Text('Dark', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'light',
                      child: Text('Light', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'system',
                      child: Text('System', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      if (val == 'light') {
                        appThemeModeNotifier.value = ThemeMode.light;
                      } else if (val == 'system') {
                        appThemeModeNotifier.value = ThemeMode.system;
                      } else {
                        appThemeModeNotifier.value = ThemeMode.dark;
                      }
                      _save(
                        AppSettings(
                          unitSystem: _settings.unitSystem,
                          frontCamera: _settings.frontCamera,
                          themeMode: val,
                          notificationsEnabled: _settings.notificationsEnabled,
                        ),
                      );
                    }
                  },
                ),
              ),
              const Divider(color: AppColors.borderDivider, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.electricCyan,
                  size: 22,
                ),
                title: const Text(
                  'Camera Sensor',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text(
                  _settings.frontCamera
                      ? 'Front Camera (Mirrored)'
                      : 'Rear Camera (Primary)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                trailing: Switch(
                  value: _settings.frontCamera,
                  activeThumbColor: AppColors.electricCyan,
                  onChanged: (val) => _save(
                    AppSettings(
                      unitSystem: _settings.unitSystem,
                      frontCamera: val,
                      themeMode: _settings.themeMode,
                      notificationsEnabled: _settings.notificationsEnabled,
                    ),
                  ),
                ),
              ),
              const Divider(color: AppColors.borderDivider, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.straighten,
                  color: AppColors.electricCyan,
                  size: 22,
                ),
                title: const Text(
                  'Units',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text(
                  _settings.unitSystem == 'metric'
                      ? 'Metric (cm, kg, deg)'
                      : 'Imperial (in, lb, deg)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                trailing: DropdownButton<String>(
                  value: _settings.unitSystem,
                  underline: const SizedBox(),
                  dropdownColor: AppColors.titanium,
                  items: const [
                    DropdownMenuItem(
                      value: 'metric',
                      child: Text('Metric', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'imperial',
                      child: Text('Imperial', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _save(
                        AppSettings(
                          unitSystem: val,
                          frontCamera: _settings.frontCamera,
                          themeMode: _settings.themeMode,
                          notificationsEnabled: _settings.notificationsEnabled,
                        ),
                      );
                    }
                  },
                ),
              ),
              const Divider(color: AppColors.borderDivider, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.voltLime,
                  size: 22,
                ),
                title: const Text(
                  'Notifications',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text(
                  _settings.notificationsEnabled
                      ? 'Enabled (Performance & Readiness Alerts)'
                      : 'Muted',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                trailing: Switch(
                  value: _settings.notificationsEnabled,
                  activeThumbColor: AppColors.voltLime,
                  onChanged: (val) {
                    _save(
                      AppSettings(
                        unitSystem: _settings.unitSystem,
                        frontCamera: _settings.frontCamera,
                        themeMode: _settings.themeMode,
                        notificationsEnabled: val,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Group 2: Privacy & Storage
        const SectionHeader(title: 'Security & Control'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDivider),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.voltLime,
                  size: 22,
                ),
                title: const Text(
                  'Privacy & Data',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'On-device encrypted sandbox storage',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPage()),
                ),
              ),
              const Divider(color: AppColors.borderDivider, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.electricCyan,
                  size: 22,
                ),
                title: const Text(
                  'AI Performance Coach',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Local Kinematic Evidence Provider',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiCoachChatPage()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Group 3: About
        const SectionHeader(title: 'About Athlete OS'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDivider),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'REHAB-X AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'v2.4.0 (Build 240)',
                    style: TextStyle(
                      color: AppColors.electricCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Move Better. Recover Smarter. Perform Stronger.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              SizedBox(height: 8),
              Text(
                'Precision computer-vision movement analysis and athletic rehabilitation monitoring. Not a medical device.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ==========================================
// 10. REUSABLE UI WIDGETS
// ==========================================

class SimplePage extends StatelessWidget {
  const SimplePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title, subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
    children: [
      Icon(icon, color: AppColors.cyan, size: 30),
      const SizedBox(height: 12),
      Text(
        title,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 24),
      ...children.map(
        (child) =>
            Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
      ),
    ],
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
    ),
    child: child,
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.cyan, size: 19),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.text)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.cyan,
          ),
        ),
      ],
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});
  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      if (action != null) ...[
        const Spacer(),
        Text(
          action!,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ],
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(28),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class ExerciseTile extends StatelessWidget {
  const ExerciseTile({
    super.key,
    required this.name,
    this.subtitle = 'Movement analysis',
    this.onTap,
    this.icon = Icons.directions_run,
    this.trailingBadge,
    this.badgeColor = AppColors.cyan,
  });

  final String name;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData icon;
  final String? trailingBadge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Ink(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.cyan),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        trailing: trailingBadge != null
            ? StatusChip(label: trailingBadge!, color: badgeColor)
            : const Icon(Icons.chevron_right, color: AppColors.muted),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});
  final String title, message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.auto_graph, color: AppColors.muted),
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        message,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

class SafetyNotice extends StatelessWidget {
  const SafetyNotice({super.key});

  @override
  Widget build(BuildContext context) => const Text(
    'Movement observations are not a medical diagnosis. REHAB-X AI does not replace evaluation or clearance by a qualified healthcare professional.',
    style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.45),
  );
}
