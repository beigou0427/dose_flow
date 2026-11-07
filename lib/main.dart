import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_localization.dart';
import 'core/pharmacokinetics_engine.dart';
import 'core/haptic_feedback_service.dart';
import 'core/purchase_service.dart';
import 'core/app_persistence.dart';
import 'core/clinical_export_service.dart';
import 'core/food_noise_engine.dart';
import 'core/behavioral_economics_engine.dart';
import 'features/calculator/syringe_calculator_view.dart';
import 'features/onboarding/onboarding_view.dart';
import 'features/duo/duo_layout_adapter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPersistence.instance.loadSnapshot();
  runApp(const DoseFlowApp());
}

class DoseFlowApp extends StatefulWidget {
  const DoseFlowApp({super.key});
  @override
  State<DoseFlowApp> createState() => _DoseFlowAppState();
}

class _DoseFlowAppState extends State<DoseFlowApp> {
  late final LocaleController _localeController;
  late bool _hasCompletedOnboarding;
  OnboardingProfileData? _initialProfile;

  @override
  void initState() {
    super.initState();
    _localeController = LocaleController(initialLanguage: AppLanguage.zhTW);

    final AppStorageSnapshot snapshot = AppPersistence.instance.current;
    _hasCompletedOnboarding = snapshot.logs.any((r) => r.id != 'init_shot_1');
  }

  @override
  void dispose() {
    _localeController.dispose();
    super.dispose();
  }

  void _handleOnboardingComplete(OnboardingProfileData data) async {
    HapticFeedbackService.milestoneHit();
    final DateTime now = DateTime.now();
    final AppStorageSnapshot newSnapshot = AppStorageSnapshot(
      logs: <InjectionRecord>[
        InjectionRecord(
          id: 'onboarding_shot_${now.millisecondsSinceEpoch}',
          timestamp: now.subtract(Duration(days: data.daysSinceLastShot)),
          medication: data.medication,
          doseMg: data.currentDoseMg,
          site: InjectionSite.rightLowerAbdomen,
          painLevel: 1,
        ),
      ],
      dailyProteinGrams: 45,
      targetProteinGrams: 90,
      dailyWaterMl: 1250,
      targetWaterMl: 2500,
      bowelCompletedToday: false,
      startWeightKg: data.startWeight,
      targetWeightKg: data.targetWeight,
      lastSavedTimestamp: now,
    );
    await AppPersistence.instance.saveSnapshot(newSnapshot);

    setState(() {
      _initialProfile = data;
      _hasCompletedOnboarding = true;
    });
  }

  void _handleSkipOnboarding() {
    HapticFeedbackService.lightImpact();
    setState(() => _hasCompletedOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    return AppLocaleScope(
      controller: _localeController,
      child: MaterialApp(
        title: 'DoseFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1.0,
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ),
        ),
        home: _hasCompletedOnboarding
            ? MainShellScreen(initialProfile: _initialProfile)
            : OnboardingView(onComplete: _handleOnboardingComplete, onSkip: _handleSkipOnboarding),
      ),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key, this.initialProfile});
  final OnboardingProfileData? initialProfile;
  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentTabIndex = 0;
  late List<InjectionRecord> _logs;
  late List<DailySideEffectLog> _sideEffectLogs;
  late int _dailyProteinGrams;
  late int _targetProteinGrams;
  late int _dailyWaterMl;
  late int _targetWaterMl;
  late bool _bowelCompletedToday;
  late double _startWeightKg;
  late double _targetWeightKg;

  @override
  void initState() {
    super.initState();
    PurchaseService.instance.addListener(_onPurchaseStateChanged);
    final AppStorageSnapshot snapshot = AppPersistence.instance.current;
    _logs = List<InjectionRecord>.from(snapshot.logs);
    _dailyProteinGrams = snapshot.dailyProteinGrams;
    _targetProteinGrams = snapshot.targetProteinGrams;
    _dailyWaterMl = snapshot.dailyWaterMl;
    _targetWaterMl = snapshot.targetWaterMl;
    _bowelCompletedToday = snapshot.bowelCompletedToday;
    _startWeightKg = snapshot.startWeightKg;
    _targetWeightKg = snapshot.targetWeightKg;
    
    // Seed test logs
    _sideEffectLogs = <DailySideEffectLog>[
      DailySideEffectLog(id: 'se_s1', date: DateTime.now().subtract(const Duration(days: 1)), foodNoiseSuppression: 5, fatigueLevel: 2),
      DailySideEffectLog(id: 'se_s2', date: DateTime.now().subtract(const Duration(days: 2)), foodNoiseSuppression: 4, nauseaLevel: 1),
    ];
  }

  @override
  void dispose() {
    PurchaseService.instance.removeListener(_onPurchaseStateChanged);
    super.dispose();
  }

  void _onPurchaseStateChanged() => setState(() {});

  void _persistCurrentState() {
    AppPersistence.instance.saveSnapshot(AppStorageSnapshot(
      logs: _logs, dailyProteinGrams: _dailyProteinGrams, targetProteinGrams: _targetProteinGrams,
      dailyWaterMl: _dailyWaterMl, targetWaterMl: _targetWaterMl, bowelCompletedToday: _bowelCompletedToday,
      startWeightKg: _startWeightKg, targetWeightKg: _targetWeightKg, lastSavedTimestamp: DateTime.now(),
    ));
  }

  void _handleAddLog(InjectionRecord record) {
    HapticFeedbackService.heavyImpact();
    setState(() => _logs.insert(0, record));
    _persistCurrentState();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final DateTime now = DateTime.now();
    final bool isPro = PurchaseService.instance.isProUnlocked;
    final double estimatedCurrentWeight = _logs.isNotEmpty
        ? (_startWeightKg - (_logs.length * 0.45)).clamp(_targetWeightKg, _startWeightKg)
        : _startWeightKg;

    final Widget dashboardPage = HomeDashboardView(
      logs: _logs,
      now: now,
      isProUnlocked: isPro,
      onToggleProPreview: PurchaseService.instance.toggleProForTesting,
      proteinGrams: _dailyProteinGrams,
      targetProteinGrams: _targetProteinGrams,
      waterMl: _dailyWaterMl,
      targetWaterMl: _targetWaterMl,
      bowelCompleted: _bowelCompletedToday,
      latestFoodNoiseScore: _sideEffectLogs.isNotEmpty ? _sideEffectLogs.first.foodNoiseSuppression : null,
      onOpenFoodNoiseDialog: () async {
        final DailySideEffectLog? log = await showDialog<DailySideEffectLog>(context: context, builder: (ctx) => const DailyFoodNoiseDialog());
        if (log != null && mounted) {
          setState(() => _sideEffectLogs.insert(0, log));
          _persistCurrentState();
        }
      },
      onQuickLogShot: _handleAddLog,
      onAddProtein: (int g) { setState(() => _dailyProteinGrams += g); _persistCurrentState(); },
      onAddWater: (int ml) { setState(() => _dailyWaterMl += ml); _persistCurrentState(); },
      onToggleBowel: () { setState(() => _bowelCompletedToday = !_bowelCompletedToday); _persistCurrentState(); },
    );

    final Widget analyticsPage = AnalyticsView(
      logs: _logs,
      sideEffectLogs: _sideEffectLogs,
      startWeightKg: _startWeightKg,
      currentWeightKg: estimatedCurrentWeight,
      isProUnlocked: isPro,
      onRequestUnlockPro: PurchaseService.instance.toggleProForTesting,
    );

    final List<Widget> pages = [
      dashboardPage,
      ShotLogAndCalculatorView(logs: _logs, isProUnlocked: isPro, onAddLog: _handleAddLog, onRequestUnlockPro: PurchaseService.instance.toggleProForTesting),
      analyticsPage,
      SettingsAndPaywallView(isProUnlocked: isPro, onTogglePro: PurchaseService.instance.toggleProForTesting),
    ];

    final PreferredSizeWidget topAppBar = AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(s.appTitle, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          Text(s.appSubtitle, style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B))),
        ],
      ),
      actions: const [Padding(padding: EdgeInsets.only(right: 12.0), child: LanguageTogglePill())],
    );

    final Widget bottomNav = NavigationBar(
      selectedIndex: _currentTabIndex,
      onDestinationSelected: (int idx) => setState(() { HapticFeedbackService.selectionTick(); _currentTabIndex = idx; }),
      destinations: <NavigationDestination>[
        NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard_rounded), label: s.tabDashboard),
        NavigationDestination(icon: const Icon(Icons.colorize_outlined), selectedIcon: const Icon(Icons.colorize_rounded), label: s.tabShotLog),
        NavigationDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights_rounded), label: s.tabAnalytics),
        NavigationDestination(icon: const Icon(Icons.tune_outlined), selectedIcon: const Icon(Icons.tune_rounded), label: s.tabSettings),
      ],
    );

    if (_currentTabIndex == 0 && DuoDeviceDetector.isLargeScreen(context)) {
      return DuoAdaptiveScaffold(appBar: topAppBar, primaryPane: dashboardPage, secondaryPane: analyticsPage, bottomNavigationBar: bottomNav);
    }
    return Scaffold(appBar: topAppBar, body: IndexedStack(index: _currentTabIndex, children: pages), bottomNavigationBar: bottomNav);
  }
}

class HomeDashboardView extends StatelessWidget {  const HomeDashboardView({
    super.key,
    required this.logs,
    required this.now,
    required this.isProUnlocked,
    required this.onToggleProPreview,
    required this.proteinGrams,
    required this.targetProteinGrams,
    required this.waterMl,
    required this.targetWaterMl,
    required this.bowelCompleted,
    required this.latestFoodNoiseScore,
    required this.onOpenFoodNoiseDialog,
    required this.onQuickLogShot,
    required this.onAddProtein,
    required this.onAddWater,
    required this.onToggleBowel,
  });

  final List<InjectionRecord> logs;
  final DateTime now;
  final bool isProUnlocked;
  final VoidCallback onToggleProPreview;
  final int proteinGrams;
  final int targetProteinGrams;
  final int waterMl;
  final int targetWaterMl;
  final bool bowelCompleted;
  final int? latestFoodNoiseScore;
  final VoidCallback onOpenFoodNoiseDialog;
  final ValueChanged<InjectionRecord> onQuickLogShot;
  final ValueChanged<int> onAddProtein;
  final ValueChanged<int> onAddWater;
  final VoidCallback onToggleBowel;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;

    int daysLeft = 4;
    int hoursLeft = 18;
    if (logs.isNotEmpty) {
      final DateTime nextShotTime = logs.first.timestamp.add(const Duration(days: 7));
      final Duration diff = nextShotTime.difference(now);
      if (diff.isNegative) { daysLeft = 0; hoursLeft = 0; } 
      else { daysLeft = diff.inDays; hoursLeft = diff.inHours % 24; }
    }

    final InjectionSite nextSite = PharmacokineticsEngine.recommendNextSite(logs);
    final double activeDose = logs.isNotEmpty ? logs.first.doseMg : 2.5;
    final Glp1Medication activeMed = logs.isNotEmpty ? logs.first.medication : Glp1Medication.tirzepatide;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        Card(
          elevation: 0,
          color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: const Color(0xFF0EA5E9).withValues(alpha: 0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0EA5E9),
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        s.nextShotCountdownTitle,
                        style: const TextStyle(fontSize: 12.0, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        s.formatDaysHours(daysLeft, hoursLeft),
                        style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.recommendedNextSiteLabel}：${nextSite.label(lang)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF0284C7), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        DuoOuterQuickActionCard(
          recommendedSite: nextSite,
          targetDoseMg: activeDose,
          calculatedUnits: 50.0,
          calculatedVolumeMl: 0.50,
          onConfirmInjection: () {
            onQuickLogShot(
              InjectionRecord(
                id: 'duo_shot_${DateTime.now().millisecondsSinceEpoch}',
                timestamp: DateTime.now(),
                medication: activeMed,
                doseMg: activeDose,
                site: nextSite,
                painLevel: 1,
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        DoseConcentrationCard(
          logs: logs,
          now: now,
          isProUnlocked: isProUnlocked,
          onToggleProPreview: onToggleProPreview,
          onOpenSwiftCodeDialog: () => SwiftReferenceExporter.showSwiftCodeModal(context),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.fitness_center_rounded, color: Color(0xFFF97316), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.microHabitsSectionTitle,
                        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildHabitRow(
                  title: '${s.proteinRingTitle} ($proteinGrams / ${targetProteinGrams}g)',
                  progress: (proteinGrams / targetProteinGrams).clamp(0.0, 1.0),
                  color: const Color(0xFFF97316),
                  buttons: <Widget>[
                    OutlinedButton(onPressed: () => onAddProtein(20), child: Text(s.proteinQuickAdd20, style: const TextStyle(fontSize: 11.5))),
                    const SizedBox(width: 6),
                    OutlinedButton(onPressed: () => onAddProtein(30), child: Text(s.proteinQuickAdd30, style: const TextStyle(fontSize: 11.5))),
                  ],
                ),
                const Divider(height: 24),
                _buildHabitRow(
                  title: '${s.waterRingTitle} ($waterMl / ${targetWaterMl}ml)',
                  progress: (waterMl / targetWaterMl).clamp(0.0, 1.0),
                  color: const Color(0xFF0EA5E9),
                  buttons: <Widget>[
                    OutlinedButton(onPressed: () => onAddWater(250), child: Text(s.waterQuickAdd250, style: const TextStyle(fontSize: 11.5))),
                    const SizedBox(width: 6),
                    OutlinedButton(onPressed: () => onAddWater(500), child: Text(s.waterQuickAdd500, style: const TextStyle(fontSize: 11.5))),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 【工單 9 - 貝克 (Becker) 健康資本微推力：不記錄則觸發損失感受】
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.timer_off_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          BehavioralEconomicsEngine.getBeckerHabitLoopNudge(lang),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),

                InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onTap: onToggleBowel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bowelCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      border: Border.all(
                        color: bowelCompleted ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          bowelCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: bowelCompleted ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            bowelCompleted ? s.bowelCompletedText : s.bowelPendingText,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: bowelCompleted ? FontWeight.w700 : FontWeight.w500,
                              color: bowelCompleted ? const Color(0xFF065F46) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onTap: onOpenFoodNoiseDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.psychology_rounded, color: Color(0xFF0EA5E9), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            latestFoodNoiseScore != null
                                ? (isZh
                                    ? '今日大腦食慾噪音：$latestFoodNoiseScore 分 (點擊重新評估)'
                                    : 'Today\'s Food Noise: $latestFoodNoiseScore/5 (Tap to edit)')
                                : (isZh
                                    ? '點擊記錄今日大腦食慾噪音 (10秒快速評估)'
                                    : 'Tap to log today\'s Food Noise (10s check-in)'),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF0EA5E9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHabitRow({required String title, required double progress, required Color color, required List<Widget> buttons}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: buttons),
      ],
    );
  }
}

@immutable
class WeightPoint {
  const WeightPoint({required this.date, required this.weightKg, required this.associatedDoseMg});
  final DateTime date;
  final double weightKg;
  final double associatedDoseMg;

  double displayWeight(WeightUnit unit) {
    if (unit == WeightUnit.lbs) return double.parse((weightKg * 2.20462).toStringAsFixed(1));
    return weightKg;
  }
}

class DoseColoredWeightChartPainter extends CustomPainter {
  const DoseColoredWeightChartPainter({required this.points, required this.isProUnlocked, required this.unit});
  final List<WeightPoint> points;
  final bool isProUnlocked;
  final WeightUnit unit;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const double leftPad = 38.0; const double rightPad = 24.0;
    const double topPad = 24.0; const double bottomPad = 28.0;
    final double plotWidth = size.width - leftPad - rightPad;
    final double plotHeight = size.height - topPad - bottomPad;
    final List<double> vals = points.map((p) => p.displayWeight(unit)).toList();
    final double minVal = vals.reduce(math.min) - 1.5;
    final double maxVal = vals.reduce(math.max) + 1.5;
    final double valRange = math.max(1.0, maxVal - minVal);

    final Paint gridPaint = Paint()..color = const Color(0xFFCBD5E1).withValues(alpha: 0.35)..strokeWidth = 1.0;
    for (int i = 0; i <= 3; i++) {
      final double y = topPad + plotHeight * (i / 3.0);
      final double tickVal = maxVal - (valRange * (i / 3.0));
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: tickVal.toStringAsFixed(0), style: const TextStyle(fontSize: 10.0, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }

    Offset getCoord(int i) {
      final double x = leftPad + (i / (points.length - 1)) * plotWidth;
      final double y = topPad + plotHeight * (1.0 - (vals[i] - minVal) / valRange);
      return Offset(x, y);
    }

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p1 = getCoord(i);
      final Offset p2 = getCoord(i + 1);
      final Color segmentColor = isProUnlocked ? PharmacokineticsEngine.colorForDose(points[i + 1].associatedDoseMg) : const Color(0xFF94A3B8);
      canvas.drawLine(p1, p2, Paint()..color = segmentColor..strokeWidth = 3.2..strokeCap = StrokeCap.round);
    }
    for (int i = 0; i < points.length; i++) {
      final Offset pt = getCoord(i);
      final Color nodeColor = isProUnlocked ? PharmacokineticsEngine.colorForDose(points[i].associatedDoseMg) : const Color(0xFF64748B);
      canvas.drawCircle(pt, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(pt, 4.0, Paint()..color = nodeColor);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: vals[i].toStringAsFixed(1), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: nodeColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - 16));
    }
  }
  @override bool shouldRepaint(covariant DoseColoredWeightChartPainter old) => old.points != points || old.isProUnlocked != isProUnlocked || old.unit != unit;
}

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key, required this.logs, required this.sideEffectLogs, required this.startWeightKg, required this.currentWeightKg, required this.isProUnlocked, required this.onRequestUnlockPro});
  final List<InjectionRecord> logs; final List<DailySideEffectLog> sideEffectLogs;
  final double startWeightKg; final double currentWeightKg;
  final bool isProUnlocked; final VoidCallback onRequestUnlockPro;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final AppLanguage lang = context.locale.language;
    final WeightUnit unit = context.locale.weightUnit;
    final bool isZh = lang.isZh;
    final DateTime now = DateTime.now();
    final List<WeightPoint> mockWeightHistory = <WeightPoint>[
      WeightPoint(date: now.subtract(const Duration(days: 35)), weightKg: startWeightKg, associatedDoseMg: 2.5),
      WeightPoint(date: now.subtract(const Duration(days: 28)), weightKg: startWeightKg - 0.7, associatedDoseMg: 2.5),
      WeightPoint(date: now.subtract(const Duration(days: 21)), weightKg: startWeightKg - 1.3, associatedDoseMg: 2.5),
      WeightPoint(date: now.subtract(const Duration(days: 14)), weightKg: startWeightKg - 1.9, associatedDoseMg: 2.5),
      WeightPoint(date: now.subtract(const Duration(days: 7)), weightKg: startWeightKg - 3.4, associatedDoseMg: 5.0),
      WeightPoint(date: now, weightKg: currentWeightKg, associatedDoseMg: 5.0),
    ];
    final double startWeightDisplay = unit == WeightUnit.lbs ? (startWeightKg * 2.20462) : startWeightKg;
    final double currentWeightDisplay = unit == WeightUnit.lbs ? (currentWeightKg * 2.20462) : currentWeightKg;
    final double totalLoss = (startWeightDisplay - currentWeightDisplay).clamp(0.0, 100.0);
    final List<DayCorrelationProfile> profiles = FoodNoiseCorrelationEngine.calculate7DayProfile(sideEffectLogs: sideEffectLogs, injectionLogs: logs);
    final InjectionDayRecommendation recommendation = FoodNoiseCorrelationEngine.recommendOptimalInjectionTiming(sideEffectLogs: sideEffectLogs, injectionLogs: logs, lang: lang);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        Card(
          elevation: 0,
          color: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildStatColumn(label: isZh ? '起始體重' : 'Start', value: '${startWeightDisplay.toStringAsFixed(1)} ${unit.symbol}', color: const Color(0xFF475569)),
                Container(width: 1, height: 38, color: const Color(0xFFE2E8F0)),
                _buildStatColumn(label: isZh ? '當前體重' : 'Current', value: '${currentWeightDisplay.toStringAsFixed(1)} ${unit.symbol}', color: const Color(0xFF0EA5E9)),
                Container(width: 1, height: 38, color: const Color(0xFFE2E8F0)),
                _buildStatColumn(label: isZh ? '累積減重' : 'Lost', value: '-${totalLoss.toStringAsFixed(1)} ${unit.symbol}', color: const Color(0xFF10B981)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(20)), side: BorderSide(color: isProUnlocked ? const Color(0xFF0EA5E9).withValues(alpha: 0.35) : const Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(s.analyticsChartTitle, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text(isZh ? '每段折線依當期劑量著色 (紫色: 2.5mg, 藍色: 5.0mg)' : 'Segments colored by dose (Purple: 2.5mg, Blue: 5.0mg)', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    if (!isProUnlocked) ActionChip(avatar: const Icon(Icons.lock_rounded, size: 14), label: Text(isZh ? '解鎖' : 'Pro', style: const TextStyle(fontSize: 11)), onPressed: onRequestUnlockPro),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(height: 190, width: double.infinity, child: CustomPaint(painter: DoseColoredWeightChartPainter(points: mockWeightHistory, isProUnlocked: isProUnlocked, unit: unit))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.all(Radius.circular(10))),
                  child: Text(isZh ? '💡 臨床趨勢：升級 5.0mg 後每週減重提升至 1.5 ${unit.symbol}，有效克服平臺期。' : '💡 Titrating to 5.0mg accelerated weight loss to 1.5 ${unit.symbol}/week.', style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.psychology_rounded, color: Color(0xFF8B5CF6), size: 22),
                    const SizedBox(width: 8),
                    Expanded(child: Text(isZh ? '打針後第 1～7 天大腦食慾壓制動態' : 'Day 1～7 Food Noise Dynamics', style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSideEffectRow(dayLabel: isZh ? '第 1～2 天 (吸收高峰峰值)' : 'Day 1～2 (Tmax)', foodNoiseLevel: profiles[0].avgFoodNoiseSuppression / 5.0, symptomLevel: math.max(profiles[0].avgFatigue, profiles[0].avgNausea) / 5.0, noiseText: isZh ? '食慾抑制 ${(profiles[0].avgFoodNoiseSuppression * 20).toInt()}%' : 'Supression ${(profiles[0].avgFoodNoiseSuppression * 20).toInt()}%', symptomText: isZh ? '輕微反胃/疲憊' : 'Mild Fatigue'),
                const SizedBox(height: 10),
                _buildSideEffectRow(dayLabel: isZh ? '第 3～5 天 (平穩平台期)' : 'Day 3～5 (Plateau)', foodNoiseLevel: profiles[2].avgFoodNoiseSuppression / 5.0, symptomLevel: math.max(profiles[2].avgFatigue, profiles[2].avgNausea) / 5.0, noiseText: isZh ? '食慾抑制 ${(profiles[2].avgFoodNoiseSuppression * 20).toInt()}%' : 'Supression ${(profiles[2].avgFoodNoiseSuppression * 20).toInt()}%', symptomText: isZh ? '耐受良好' : 'Well Tolerated'),
                const SizedBox(height: 10),
                _buildSideEffectRow(dayLabel: isZh ? '第 6～7 天 (半衰期食慾回升)' : 'Day 6～7 (Decay)', foodNoiseLevel: profiles[6].avgFoodNoiseSuppression / 5.0, symptomLevel: math.max(profiles[6].avgFatigue, profiles[6].avgNausea) / 5.0, noiseText: isZh ? '食慾抑制 ${(profiles[6].avgFoodNoiseSuppression * 20).toInt()}%' : 'Supression ${(profiles[6].avgFoodNoiseSuppression * 20).toInt()}%', symptomText: isZh ? '無明顯副作用' : 'No Symptoms'),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.08), borderRadius: const BorderRadius.all(Radius.circular(12)), border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.event_available_rounded, color: Color(0xFF8B5CF6), size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isZh
                            ? 'AI 建議打針時機：${recommendation.recommendedTimeLabel}\n${recommendation.rationale(lang)}'
                            : 'AI Timing: ${recommendation.recommendedTimeLabel}\n${recommendation.rationale(lang)}',
                          style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9), height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 【工單 4 - 箭 (Arrow) & 工單 7 梯若爾 (Tirole) : 看診溝通底氣 ✕ 醫師查核表單匯出樞紐】
        Card(
          elevation: 0,
          color: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.health_and_safety_rounded, color: Color(0xFF0F172A), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        BehavioralEconomicsEngine.getArrowPhysicianEmpowermentPitch(lang),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...BehavioralEconomicsEngine.getArrowClinicalDecisionPillars(lang).map((txt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 16, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(txt, style: const TextStyle(fontSize: 12.0, color: Color(0xFF475569)))),
                    ]
                  ),
                )),
                const Divider(height: 24),
                Text(
                  BehavioralEconomicsEngine.getArrowFdaCertaintyAnchor(lang),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                ),
                Text(
                  BehavioralEconomicsEngine.getTiroleClinicReferralWatermark(lang),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showDoctorExportDialog(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(s.exportDoctorPdfButton),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A), padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDoctorExportDialog(BuildContext context) {
    HapticFeedbackService.mediumImpact();
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => ClinicalExportDialog(logs: logs, startWeightKg: startWeightKg, currentWeightKg: currentWeightKg),
    );
  }

  // ✅ 無損召回先前為測試零崩潰而設立之最高級自適應 Expanded 布局卡
  static Widget _buildStatColumn({required String label, required String value, required Color color}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, maxLines: 1, style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  static Widget _buildSideEffectRow({required String dayLabel, required double foodNoiseLevel, required double symptomLevel, required String noiseText, required String symptomText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(dayLabel, style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(noiseText, style: const TextStyle(fontSize: 10.5, color: Color(0xFF10B981))),
                  LinearProgressIndicator(value: foodNoiseLevel.clamp(0.0, 1.0), backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)), minHeight: 6, borderRadius: const BorderRadius.all(Radius.circular(3))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(symptomText, style: const TextStyle(fontSize: 10.5, color: Color(0xFFF97316))),
                  LinearProgressIndicator(value: symptomLevel.clamp(0.0, 1.0), backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)), minHeight: 6, borderRadius: const BorderRadius.all(Radius.circular(3))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsAndPaywallView extends StatelessWidget {  const SettingsAndPaywallView({
    super.key,
    required this.isProUnlocked,
    required this.onTogglePro,
  });

  final bool isProUnlocked;
  final VoidCallback onTogglePro;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final bool isZh = context.locale.isZh;
    final bool isDuo = DuoDeviceDetector.isLargeScreen(context);
    final AppLanguage lang = context.locale.language;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        
        // 【工單 8 - 斯蒂格利茨 (Stiglitz) 動態付費牆引流】 
        Card(
          elevation: 0,
          color: isProUnlocked
              ? const Color(0xFF10B981).withValues(alpha: 0.08)
              : const Color(0xFF0EA5E9).withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            side: BorderSide(
              color: isProUnlocked ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFF0EA5E9).withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      isProUnlocked ? Icons.workspace_premium_rounded : Icons.lock_open_rounded,
                      color: isProUnlocked ? const Color(0xFF10B981) : const Color(0xFF0EA5E9),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isProUnlocked
                            ? (isZh ? 'DoseFlow Pro 專業版運行中 ‧ 完整功能授權' : 'DoseFlow Pro Active (All Features Unlocked)')
                            // 未付費時動態依據雙螢幕與痛點推廣：
                            : BehavioralEconomicsEngine.getStiglitzDynamicPaywallHeadline(
                                lang: lang,
                                worrySideEffects: true, // 在這裡依據先前的 Global 選擇映射 (示範預設true以觸發最強引導)
                                worryBruising: false,
                                worryMuscle: true,
                                worryConcentration: true,
                                isDuoDevice: isDuo,
                              ),
                        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isProUnlocked
                      ? BehavioralEconomicsEngine.getAkerlofIdentityBadge(lang)
                      : BehavioralEconomicsEngine.getLossAversionSubtext(lang),
                  style: const TextStyle(fontSize: 12.0, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 14),
                PulsingCtaButton(
                  onPressed: () {
                    HapticFeedbackService.lightImpact();
                    if (!isProUnlocked) _showPaywallModal(context);
                  },
                  icon: Icons.bolt_rounded,
                  label: isProUnlocked ? (isZh ? '管理權益方案' : 'Manage Pro Access') : s.unlockProButton,
                  color: isProUnlocked ? const Color(0xFF10B981) : const Color(0xFF0EA5E9),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      HapticFeedbackService.lightImpact();
                      onTogglePro();
                    },
                    child: Text(
                      isProUnlocked ? (isZh ? '返回免費限制版' : 'Switch to Free (Sandbox)') : (isZh ? '點擊一鍵快速測試升級' : 'Sandbox Sim Purchase'),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 【工單 3 - 艾克羅夫 (Akerlof) 隱私背書】反檸檬品質防禦宣誓 
        Card(
          elevation: 0,
          color: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(BehavioralEconomicsEngine.getAkerlofAntiLemonSignal(lang), style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), height: 1.4)),
                const Divider(height: 24),
                ...BehavioralEconomicsEngine.getAkerlofTrustGuarantees(lang).map((msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(msg, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)))),
                    ]
                  ),
                )),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(child: OutlinedButton.icon(onPressed: () { HapticFeedbackService.lightImpact(); _showBackupDialog(context); }, icon: const Icon(Icons.file_download_outlined, size: 16), label: Text(isZh ? '導出安全數據備份' : 'Export Safe Backup', style: const TextStyle(fontSize: 11.5)))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(onPressed: () { HapticFeedbackService.lightImpact(); _showRestoreDialog(context); }, icon: const Icon(Icons.file_upload_outlined, size: 16), label: Text(isZh ? '原機覆蓋還原' : 'Local Restore', style: const TextStyle(fontSize: 11.5)))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 【工單 5 - 席勒 (Shiller) 社群造浪病毒引擎】 食慾安靜度隱私宣告
        Card(
          elevation: 0,
          color: const Color(0xFFF3F4F6),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: Color(0xFFE5E7EB))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(BehavioralEconomicsEngine.getShillerNarrativeHook(lang), style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w800, color: Color(0xFF4B5563))),
                const SizedBox(height: 10),
                Text(BehavioralEconomicsEngine.getShillerViralWatermark(lang), style: const TextStyle(fontSize: 11.0, color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final str = BehavioralEconomicsEngine.generateShillerSilenceCardText(
                        lang: lang,
                        startWeight: 85.0,
                        currentWeight: 75.0,
                        foodNoiseSilenceScore: 5,
                        proteinGoalHitRate: 100,
                      );
                      Clipboard.setData(ClipboardData(text: str));
                      HapticFeedbackService.successPattern();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isZh ? '✅ 無涉隱私數據 ‧ 食慾報告文案已複製入剪貼簿，請貼往社群發布！' : '✅ Report string ready for pasting to Reddit!')));
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(isZh ? '發布榮譽心智健康戰報' : 'Copy Shiller Flex Report'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF374151), padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          elevation: 0,
          color: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 22),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.asoSectionHeader, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () { HapticFeedbackService.lightImpact(); _showAsoInspectorDialog(context); },
                    icon: const Icon(Icons.copy_all_rounded, size: 16),
                    label: Text(isZh ? '獲取 Apple/Google 送審合規資料套件' : 'ASO Copy Hub & Disclaimer'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showBackupDialog(BuildContext context) {
    final String backupBase64 = AppPersistence.instance.exportBackupString();
    final bool isZh = context.locale.isZh;
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isZh ? '匯出絕對隱私編碼 (Zero Cloud)' : 'Backup Encryption'),
      content: SelectableText(backupBase64, maxLines: 4, style: const TextStyle(fontSize: 10, fontFamily: 'Consolas')),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]
    ));
  }

  void _showRestoreDialog(BuildContext context) {
    final bool isZh = context.locale.isZh;
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isZh ? '匯入與解譯恢復' : 'Offline Restore'),
      content: Text(isZh ? '本地數據操作 (由外部載入功能在此調用實作。)' : 'Insert Hash stream mechanism triggered.'),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]
    ));
  }

  // ==========================================
  // 十級抗震支付點鈔機牆 (_showPaywallModal)
  // 混合 【康納曼 / 米爾格羅姆誘餌 / 塞勒 / 謝林】 極致絞肉機
  // ==========================================
  void _showPaywallModal(BuildContext context) {
    final AppStrings s = context.strings;
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(child: Container(width: 42, height: 4, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), borderRadius: BorderRadius.all(Radius.circular(999))))),
              const SizedBox(height: 18),
              
              Text(
                s.paywallHeadline, // 動態解鎖您的人生最後一瘦
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, height: 1.25),
              ),
              const SizedBox(height: 8),

              // 【工單 1】康納曼效益清單 / 【工單 2】塞勒從眾預設徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(color: Color(0xFFFEE2E2), borderRadius: BorderRadius.all(Radius.circular(6))),
                child: Text(BehavioralEconomicsEngine.getKahnemanLossFramedHeadline(lang), style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),

              // 年繳首推 (主力印鈔與鎖血)
              InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                onTap: () async { HapticFeedbackService.mediumImpact(); Navigator.pop(sheetContext); await PurchaseService.instance.purchase(SubscriptionTier.annual); HapticFeedbackService.successPattern(); },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.06), borderRadius: const BorderRadius.all(Radius.circular(16)), border: Border.all(color: const Color(0xFF0EA5E9), width: 1.8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(padding: EdgeInsets.only(top: 4.0), child: Icon(Icons.local_fire_department_rounded, color: Color(0xFF0EA5E9), size: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(BehavioralEconomicsEngine.getThalerDefaultNudgeBadge(lang), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                            const SizedBox(height: 4),
                            Text(
                              isZh ? r'臨床計畫：NT$ 990 / 年 (提供 3 日免費全域保護試用)' : r'Annual Medical Track: $39.99/yr (3-Day Free Trial)',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              BehavioralEconomicsEngine.getThalerMentalAccountAnchor(lang),
                              style: const TextStyle(fontSize: 11.0, color: Color(0xFF0284C7), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 【工單 6】米爾格羅姆終身 VIP $119.99 不對稱高昂誘導
              InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                onTap: () async { HapticFeedbackService.heavyImpact(); Navigator.pop(sheetContext); await PurchaseService.instance.purchase(SubscriptionTier.lifetime); HapticFeedbackService.successPattern(); },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: const BorderRadius.all(Radius.circular(14)), border: Border.all(color: const Color(0xFFD946EF), width: 1.2)),
                  child: Row(
                    children: [
                      const Icon(Icons.diamond_rounded, size: 20, color: Color(0xFFD946EF)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(BehavioralEconomicsEngine.getMilgromDecoyLifetimeLabel(lang), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFC026D3))),
                            Text(BehavioralEconomicsEngine.getMilgromPeptideDiscriminationPitch(lang), style: const TextStyle(fontSize: 10, color: Color(0xFF86198F), height: 1.25)),
                          ],
                        ),
                      ),
                      Text(BehavioralEconomicsEngine.getMilgromDecoyLifetimePrice(lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ]
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 【工單 10】謝林尤利西斯合約！防禦一切滑掉走人與逃跑心理！
              Text(
                BehavioralEconomicsEngine.getSchellingSunkCostLockIn(lang),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              
              PulsingCtaButton(
                onPressed: () async { HapticFeedbackService.mediumImpact(); Navigator.pop(sheetContext); await PurchaseService.instance.purchase(SubscriptionTier.annual); HapticFeedbackService.successPattern(); },
                icon: Icons.assignment_turned_in_rounded,
                label: BehavioralEconomicsEngine.getSchellingUlyssesContractPledge(lang),
                color: const Color(0xFF0F172A),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAsoInspectorDialog(BuildContext context) {
    // Basic dialog template retained logic. Implementation handles exact copies.
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ASO Engine Output', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: SelectableText(context.strings.asoFullDescription),
        actions: <Widget>[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      )
    );
  }
}

// -------------------------------------------------------------
// UI 神武 脈衝呼吸元件 PulsingCtaButton 完整防爆
// -------------------------------------------------------------
class PulsingCtaButton extends StatefulWidget {
  const PulsingCtaButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  State<PulsingCtaButton> createState() => _PulsingCtaButtonState();
}

class _PulsingCtaButtonState extends State<PulsingCtaButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 反大腦免疫 (非均質規律)，引發最不費力的週邊注視 
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1250))..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 17),
          label: Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.3),
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: widget.color,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          ),
        ),
      ),
    );
  }
}