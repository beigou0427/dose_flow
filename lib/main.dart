import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_localization.dart';
import 'core/app_theme.dart';
import 'core/pharmacokinetics_engine.dart';
import 'core/haptic_feedback_service.dart';
import 'core/purchase_service.dart';
import 'core/app_persistence.dart';
import 'core/clinical_export_service.dart';
import 'core/food_noise_engine.dart';
import 'core/behavioral_economics_engine.dart';
import 'core/legal_compliance_hub.dart';
import 'core/reminder_service.dart';
import 'core/privacy_security_service.dart';
import 'features/shot_log/shot_log_view.dart';
import 'features/onboarding/onboarding_view.dart';
import 'features/duo/duo_layout_adapter.dart';
import 'features/rotation/body_rotation_map.dart';
import 'features/schedule/reminder_calendar_card.dart';

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
        theme: DoseFlowTheme.darkTheme,
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
  late bool _shotReminderEnabled;
  late int _shotReminderWeekday;
  late int _shotReminderHour;
  late int _shotReminderMinute;
  late bool _needlePrepReminderEnabled;
  late bool _biometricLockEnabled;
  late bool _iCloudBackupEnabled;
  DateTime? _lastICloudSyncAt;
  bool _isPrivacyLocked = false;

  @override
  void initState() {
    super.initState();
    PurchaseService.instance.addListener(_onPurchaseStateChanged);
    PurchaseService.instance.refreshLocalizedPrices();
    PurchaseService.instance.syncCurrentEntitlements();
    final AppStorageSnapshot snapshot = AppPersistence.instance.current;
    _logs = List<InjectionRecord>.from(snapshot.logs);
    _dailyProteinGrams = snapshot.dailyProteinGrams;
    _targetProteinGrams = snapshot.targetProteinGrams;
    _dailyWaterMl = snapshot.dailyWaterMl;
    _targetWaterMl = snapshot.targetWaterMl;
    _bowelCompletedToday = snapshot.bowelCompletedToday;
    _startWeightKg = snapshot.startWeightKg;
    _targetWeightKg = snapshot.targetWeightKg;
    _shotReminderEnabled = snapshot.shotReminderEnabled;
    _shotReminderWeekday = snapshot.shotReminderWeekday;
    _shotReminderHour = snapshot.shotReminderHour;
    _shotReminderMinute = snapshot.shotReminderMinute;
    _needlePrepReminderEnabled = snapshot.needlePrepReminderEnabled;
    _biometricLockEnabled = snapshot.biometricLockEnabled;
    _iCloudBackupEnabled = snapshot.iCloudBackupEnabled;
    _lastICloudSyncAt = snapshot.lastICloudSyncAt;
    _isPrivacyLocked = snapshot.biometricLockEnabled;

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
      logs: _logs,
      dailyProteinGrams: _dailyProteinGrams,
      targetProteinGrams: _targetProteinGrams,
      dailyWaterMl: _dailyWaterMl,
      targetWaterMl: _targetWaterMl,
      bowelCompletedToday: _bowelCompletedToday,
      startWeightKg: _startWeightKg,
      targetWeightKg: _targetWeightKg,
      lastSavedTimestamp: DateTime.now(),
      shotReminderEnabled: _shotReminderEnabled,
      shotReminderWeekday: _shotReminderWeekday,
      shotReminderHour: _shotReminderHour,
      shotReminderMinute: _shotReminderMinute,
      needlePrepReminderEnabled: _needlePrepReminderEnabled,
      biometricLockEnabled: _biometricLockEnabled,
      iCloudBackupEnabled: _iCloudBackupEnabled,
      lastICloudSyncAt: _lastICloudSyncAt,
    ));
    if (_iCloudBackupEnabled) {
      PrivacySecurityService.instance.syncBackupToICloud();
    }
  }

  void _syncRemindersForCurrentLocale(AppLanguage lang) {
    final Glp1Medication activeMed =
        _logs.isNotEmpty ? _logs.first.medication : Glp1Medication.tirzepatide;
    final InjectionSite? lastSite = _logs.isNotEmpty ? _logs.first.site : null;
    final InjectionSite nextSite =
        PharmacokineticsEngine.recommendNextSite(_logs);
    ReminderService.instance.syncReminders(
      shotReminderEnabled: _shotReminderEnabled,
      needlePrepReminderEnabled: _needlePrepReminderEnabled,
      weekday: _shotReminderWeekday,
      hour: _shotReminderHour,
      minute: _shotReminderMinute,
      lang: lang,
      medication: activeMed,
      lastSite: lastSite,
      nextSite: nextSite,
    );
  }

  void _handleAddLog(InjectionRecord record) {
    HapticFeedbackService.heavyImpact();
    setState(() => _logs.insert(0, record));
    _persistCurrentState();
    _syncRemindersForCurrentLocale(context.locale.language);
  }

  void _handleDeleteLog(String recordId) {
    if (_logs.length <= 1) return;
    HapticFeedbackService.lightImpact();
    setState(() => _logs.removeWhere((InjectionRecord r) => r.id == recordId));
    _persistCurrentState();
    _syncRemindersForCurrentLocale(context.locale.language);
  }

  Future<void> _unlockPrivacyGate() async {
    final bool isZh = context.locale.isZh;
    final bool ok = await PrivacySecurityService.instance.authenticate(
      reason: isZh
          ? '請驗證 Face ID 或裝置密碼以檢視您的健康紀錄'
          : 'Authenticate with Face ID or passcode to view your health logs',
    );
    if (ok && mounted) {
      HapticFeedbackService.successPattern();
      setState(() => _isPrivacyLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;
    final DateTime now = DateTime.now();
    final bool isPro = PurchaseService.instance.isProUnlocked;
    final double estimatedCurrentWeight = _logs.isNotEmpty
        ? (_startWeightKg - (_logs.length * 0.45)).clamp(_targetWeightKg, _startWeightKg)
        : _startWeightKg;

    if (_isPrivacyLocked) {
      return Scaffold(
        backgroundColor: DoseFlowColors.bgDeep,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: DoseFlowColors.mint.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DoseFlowColors.mint.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 54,
                      color: DoseFlowColors.mint,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isZh ? 'DoseFlow 隱私保護已鎖定' : 'DoseFlow Privacy Lock Active',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: DoseFlowColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isZh
                        ? '所有健康與注射數據 100% 僅存於本機與個人 iCloud'
                        : 'All health records stay 100% local on your device & private iCloud',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: DoseFlowColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _unlockPrivacyGate,
                    icon: const Icon(Icons.face_rounded),
                    label: Text(isZh ? '使用 Face ID / 密碼解鎖' : 'Unlock with Face ID'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final Widget dashboardPage = HomeDashboardView(
      logs: _logs,
      now: now,
      isProUnlocked: isPro,
      onRequestUnlockPro: () => showDoseFlowPaywallModal(context),
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
      onRequestUnlockPro: () => showDoseFlowPaywallModal(context),
    );

    final List<Widget> pages = [
      dashboardPage,
      ShotLogView(
        logs: _logs,
        onAddLog: _handleAddLog,
        onDeleteLog: _handleDeleteLog,
      ),
      analyticsPage,
      SettingsAndPaywallView(
        isProUnlocked: isPro,
        logs: _logs,
        startWeightKg: _startWeightKg,
        currentWeightKg: estimatedCurrentWeight,
        shotReminderEnabled: _shotReminderEnabled,
        shotReminderWeekday: _shotReminderWeekday,
        shotReminderHour: _shotReminderHour,
        shotReminderMinute: _shotReminderMinute,
        needlePrepReminderEnabled: _needlePrepReminderEnabled,
        biometricLockEnabled: _biometricLockEnabled,
        iCloudBackupEnabled: _iCloudBackupEnabled,
        lastICloudSyncAt: _lastICloudSyncAt,
        onReminderChanged: ({
          bool? shotReminderEnabled,
          int? shotReminderWeekday,
          int? shotReminderHour,
          int? shotReminderMinute,
          bool? needlePrepReminderEnabled,
        }) {
          setState(() {
            if (shotReminderEnabled != null) _shotReminderEnabled = shotReminderEnabled;
            if (shotReminderWeekday != null) _shotReminderWeekday = shotReminderWeekday;
            if (shotReminderHour != null) _shotReminderHour = shotReminderHour;
            if (shotReminderMinute != null) _shotReminderMinute = shotReminderMinute;
            if (needlePrepReminderEnabled != null) _needlePrepReminderEnabled = needlePrepReminderEnabled;
          });
          _persistCurrentState();
          _syncRemindersForCurrentLocale(lang);
        },
        onToggleBiometricLock: (bool enable) async {
          if (enable) {
            final bool ok = await PrivacySecurityService.instance.authenticate(
              reason: isZh
                  ? '啟用 Face ID 保護您的 DoseFlow 健康紀錄'
                  : 'Enable Face ID to protect your DoseFlow logs',
            );
            if (!ok) return;
          }
          if (!mounted) return;
          setState(() => _biometricLockEnabled = enable);
          _persistCurrentState();
        },
        onToggleICloudBackup: (bool enable) async {
          final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
          if (enable) {
            final bool ok = await PrivacySecurityService.instance.syncBackupToICloud();
            if (!mounted) return;
            if (!ok) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    isZh
                        ? '⚠️ iCloud 目前無法使用，您的資料仍安全保存於本機，也可使用下方本機加密備份。'
                        : '⚠️ iCloud is currently unavailable. Your data remains safely stored locally.',
                  ),
                ),
              );
              return;
            }
          }
          if (!mounted) return;
          setState(() {
            _iCloudBackupEnabled = enable;
            if (enable) _lastICloudSyncAt = DateTime.now();
          });
          _persistCurrentState();
        },
        onManualICloudSync: () async {
          final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
          final bool ok = await PrivacySecurityService.instance.syncBackupToICloud();
          if (!mounted) return;
          if (ok) {
            setState(() => _lastICloudSyncAt = DateTime.now());
            _persistCurrentState();
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? (isZh ? '☁️ 已加密同步至您的個人 iCloud 空間！' : '☁️ Synced privately to your iCloud!')
                    : (isZh ? '⚠️ 無法連線 iCloud，請確認裝置已登入 Apple ID。' : '⚠️ Unable to reach iCloud.'),
              ),
            ),
          );
        },
      ),
    ];

    final PreferredSizeWidget topAppBar = AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(s.appTitle, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: DoseFlowColors.textPrimary)),
          Text(s.appSubtitle, style: const TextStyle(fontSize: 11.0, color: DoseFlowColors.textSecondary)),
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

class HomeDashboardView extends StatelessWidget {
  const HomeDashboardView({
    super.key,
    required this.logs,
    required this.now,
    required this.isProUnlocked,
    required this.onRequestUnlockPro,
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
  final VoidCallback onRequestUnlockPro;
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
          color: DoseFlowColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: DoseFlowColors.mint.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DoseFlowColors.mint.withValues(alpha: 0.16),
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    border: Border.all(
                      color: DoseFlowColors.mint.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(Icons.alarm_on_rounded, color: DoseFlowColors.mint, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        s.nextShotCountdownTitle,
                        style: const TextStyle(fontSize: 12.0, color: DoseFlowColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        s.formatDaysHours(daysLeft, hoursLeft),
                        style: const TextStyle(fontSize: 19.0, fontWeight: FontWeight.w900, color: DoseFlowColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.recommendedNextSiteLabel}：${nextSite.label(lang)}',
                        style: const TextStyle(fontSize: 11.5, color: DoseFlowColors.mint, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        DoseConcentrationCard(
          logs: logs,
          now: now,
          isProUnlocked: isProUnlocked,
          onRequestUnlockPro: onRequestUnlockPro,
          onOpenSwiftCodeDialog: kDebugMode
              ? () => SwiftReferenceExporter.showSwiftCodeModal(context)
              : null,
        ),
        const SizedBox(height: 14),
        BodyRotationMapCard(
          logs: logs,
          activeDoseMg: activeDose,
          activeMedication: activeMed,
          onConfirmInjection: (InjectionSite chosenSite) {
            onQuickLogShot(
              InjectionRecord(
                id: 'map_shot_${DateTime.now().millisecondsSinceEpoch}',
                timestamp: DateTime.now(),
                medication: activeMed,
                doseMg: activeDose,
                site: chosenSite,
                painLevel: 1,
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          color: DoseFlowColors.cardSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: DoseFlowColors.cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.fitness_center_rounded, color: DoseFlowColors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.microHabitsSectionTitle,
                        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: DoseFlowColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildHabitRow(
                  title: '${s.proteinRingTitle} ($proteinGrams / ${targetProteinGrams}g)',
                  progress: (proteinGrams / targetProteinGrams).clamp(0.0, 1.0),
                  color: DoseFlowColors.amber,
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
                  color: DoseFlowColors.cyan,
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
                    color: DoseFlowColors.amber.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: DoseFlowColors.amber.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.timer_off_rounded, color: DoseFlowColors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          BehavioralEconomicsEngine.getBeckerHabitLoopNudge(lang),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFFFFE0A6), height: 1.45),
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
                          ? DoseFlowColors.mint.withValues(alpha: 0.15)
                          : DoseFlowColors.cardElevated,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      border: Border.all(
                        color: bowelCompleted ? DoseFlowColors.mint : DoseFlowColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          bowelCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: bowelCompleted ? DoseFlowColors.mint : DoseFlowColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            bowelCompleted ? s.bowelCompletedText : s.bowelPendingText,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: bowelCompleted ? FontWeight.w700 : FontWeight.w500,
                              color: bowelCompleted ? DoseFlowColors.mint : DoseFlowColors.textPrimary,
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
                      color: DoseFlowColors.cyan.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      border: Border.all(color: DoseFlowColors.cyan.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.psychology_rounded, color: DoseFlowColors.cyan, size: 22),
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
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF7BE3FF)),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DoseFlowColors.cyan),
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
        Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DoseFlowColors.textPrimary)),
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

    final Paint gridPaint = Paint()..color = DoseFlowColors.textMuted.withValues(alpha: 0.22)..strokeWidth = 1.0;
    for (int i = 0; i <= 3; i++) {
      final double y = topPad + plotHeight * (i / 3.0);
      final double tickVal = maxVal - (valRange * (i / 3.0));
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: tickVal.toStringAsFixed(0), style: const TextStyle(fontSize: 10.0, color: DoseFlowColors.textSecondary, fontWeight: FontWeight.w600)),
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
      final Color segmentColor = isProUnlocked ? PharmacokineticsEngine.colorForDose(points[i + 1].associatedDoseMg) : DoseFlowColors.mint;
      canvas.drawLine(p1, p2, Paint()..color = segmentColor.withValues(alpha: 0.28)..strokeWidth = 7.0..strokeCap = StrokeCap.round);
      canvas.drawLine(p1, p2, Paint()..color = segmentColor..strokeWidth = 3.2..strokeCap = StrokeCap.round);
    }
    for (int i = 0; i < points.length; i++) {
      final Offset pt = getCoord(i);
      final Color nodeColor = isProUnlocked ? PharmacokineticsEngine.colorForDose(points[i].associatedDoseMg) : DoseFlowColors.mint;
      final bool isDoseUpgrade = i == 0 || points[i].associatedDoseMg > points[i - 1].associatedDoseMg;
      if (isDoseUpgrade) {
        canvas.drawLine(
          Offset(pt.dx, topPad),
          Offset(pt.dx, topPad + plotHeight),
          Paint()..color = nodeColor.withValues(alpha: 0.35)..strokeWidth = 1.2,
        );
      }
      canvas.drawCircle(pt, 5.5, Paint()..color = DoseFlowColors.bgNavy);
      canvas.drawCircle(pt, 4.0, Paint()..color = nodeColor);
      final String label = isDoseUpgrade
          ? '${vals[i].toStringAsFixed(1)} (${points[i].associatedDoseMg.toStringAsFixed(1)}mg)'
          : vals[i].toStringAsFixed(1);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w800, color: nodeColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      final double lx = (pt.dx - tp.width / 2).clamp(leftPad, size.width - tp.width - 4);
      tp.paint(canvas, Offset(lx, pt.dy - 17));
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
          color: DoseFlowColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: DoseFlowColors.mint.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _buildStatColumn(label: isZh ? '起始體重' : 'Start', value: '${startWeightDisplay.toStringAsFixed(1)} ${unit.symbol}', color: DoseFlowColors.textSecondary),
                    Container(width: 1, height: 38, color: DoseFlowColors.cardBorder),
                    _buildStatColumn(label: isZh ? '當前體重' : 'Current', value: '${currentWeightDisplay.toStringAsFixed(1)} ${unit.symbol}', color: DoseFlowColors.cyan),
                    Container(width: 1, height: 38, color: DoseFlowColors.cardBorder),
                    _buildStatColumn(label: isZh ? '累積減重' : 'Lost', value: '-${totalLoss.toStringAsFixed(1)} ${unit.symbol}', color: DoseFlowColors.mint),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: DoseFlowColors.mint.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: DoseFlowColors.mint.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    isZh
                        ? '已記錄 ${math.max(1, logs.length)} 週 ｜ 體重累計減輕 -${totalLoss.toStringAsFixed(1)} ${unit.symbol}'
                        : 'Tracked ${math.max(1, logs.length)} wks | Total Lost -${totalLoss.toStringAsFixed(1)} ${unit.symbol}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: DoseFlowColors.mint),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: DoseFlowColors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(20)), side: BorderSide(color: isProUnlocked ? DoseFlowColors.mint.withValues(alpha: 0.4) : DoseFlowColors.cardBorder)),
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
                          Text(s.analyticsChartTitle, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: DoseFlowColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(isZh ? '每段折線依調劑里程碑著色 (2.5mg 🟢 → 5.0mg 🔺升級)' : 'Segments & pins colored by dose titration (2.5mg → 5.0mg)', style: const TextStyle(fontSize: 11.5, color: DoseFlowColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (!isProUnlocked) ActionChip(avatar: const Icon(Icons.lock_rounded, size: 14), label: Text(isZh ? '解鎖' : 'Pro', style: const TextStyle(fontSize: 11)), onPressed: onRequestUnlockPro),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(height: 195, width: double.infinity, child: CustomPaint(painter: DoseColoredWeightChartPainter(points: mockWeightHistory, isProUnlocked: isProUnlocked, unit: unit))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: DoseFlowColors.cardElevated, borderRadius: BorderRadius.all(Radius.circular(10))),
                  child: Text(
                    isZh
                        ? '💡 折線依您記錄的劑量區間著色（僅供個人趨勢視覺化參考，調整劑量請務必諮詢處方醫師）。'
                        : '💡 Segments are colored by your logged dose tier for visual reference only. Always consult your physician before changing doses.',
                    style: const TextStyle(fontSize: 11.5, color: DoseFlowColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: DoseFlowColors.cardSurface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: DoseFlowColors.cardBorder)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.psychology_rounded, color: DoseFlowColors.purple, size: 22),
                    const SizedBox(width: 8),
                    Expanded(child: Text(isZh ? '打針後第 1～7 天大腦食慾壓制動態' : 'Day 1～7 Food Noise Dynamics', style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: DoseFlowColors.textPrimary))),
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
                  decoration: BoxDecoration(color: DoseFlowColors.purple.withValues(alpha: 0.14), borderRadius: const BorderRadius.all(Radius.circular(12)), border: Border.all(color: DoseFlowColors.purple.withValues(alpha: 0.35))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.event_available_rounded, color: DoseFlowColors.purple, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isZh
                            ? '個人週期紀錄參考：${recommendation.recommendedTimeLabel}\n${recommendation.rationale(lang)}'
                            : 'Personal Cycle Pattern: ${recommendation.recommendedTimeLabel}\n${recommendation.rationale(lang)}',
                          style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w700, color: Color(0xFFD6CCFF), height: 1.45),
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
          color: DoseFlowColors.cardSurface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: DoseFlowColors.cardBorder)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.health_and_safety_rounded, color: DoseFlowColors.mint, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        BehavioralEconomicsEngine.getArrowPhysicianEmpowermentPitch(lang),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: DoseFlowColors.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...BehavioralEconomicsEngine.getArrowClinicalDecisionPillars(lang).map((txt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 16, color: DoseFlowColors.cyan),
                      const SizedBox(width: 8),
                      Expanded(child: Text(txt, style: const TextStyle(fontSize: 12.0, color: DoseFlowColors.textSecondary))),
                    ]
                  ),
                )),
                const Divider(height: 24),
                Text(
                  BehavioralEconomicsEngine.getArrowFdaCertaintyAnchor(lang),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: DoseFlowColors.textMuted),
                ),
                Text(
                  BehavioralEconomicsEngine.getTiroleClinicReferralWatermark(lang),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: DoseFlowColors.mint),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showDoctorExportDialog(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(s.exportDoctorPdfButton),
                    style: FilledButton.styleFrom(backgroundColor: DoseFlowColors.mint, foregroundColor: const Color(0xFF041A18), padding: const EdgeInsets.symmetric(vertical: 14)),
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

class SettingsAndPaywallView extends StatelessWidget {
  const SettingsAndPaywallView({
    super.key,
    required this.isProUnlocked,
    required this.logs,
    required this.startWeightKg,
    required this.currentWeightKg,
    required this.shotReminderEnabled,
    required this.shotReminderWeekday,
    required this.shotReminderHour,
    required this.shotReminderMinute,
    required this.needlePrepReminderEnabled,
    required this.biometricLockEnabled,
    required this.iCloudBackupEnabled,
    required this.lastICloudSyncAt,
    required this.onReminderChanged,
    required this.onToggleBiometricLock,
    required this.onToggleICloudBackup,
    required this.onManualICloudSync,
  });

  final bool isProUnlocked;
  final List<InjectionRecord> logs;
  final double startWeightKg;
  final double currentWeightKg;
  final bool shotReminderEnabled;
  final int shotReminderWeekday;
  final int shotReminderHour;
  final int shotReminderMinute;
  final bool needlePrepReminderEnabled;
  final bool biometricLockEnabled;
  final bool iCloudBackupEnabled;
  final DateTime? lastICloudSyncAt;
  final void Function({
    bool? shotReminderEnabled,
    int? shotReminderWeekday,
    int? shotReminderHour,
    int? shotReminderMinute,
    bool? needlePrepReminderEnabled,
  }) onReminderChanged;
  final ValueChanged<bool> onToggleBiometricLock;
  final ValueChanged<bool> onToggleICloudBackup;
  final VoidCallback onManualICloudSync;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final bool isZh = context.locale.isZh;
    final bool isDuo = DuoDeviceDetector.isLargeScreen(context);
    final AppLanguage lang = context.locale.language;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        // DoseFlow 1.1 智慧週期打卡日曆與本地推播提醒
        ReminderCalendarCard(
          logs: logs,
          shotReminderEnabled: shotReminderEnabled,
          shotReminderWeekday: shotReminderWeekday,
          shotReminderHour: shotReminderHour,
          shotReminderMinute: shotReminderMinute,
          needlePrepReminderEnabled: needlePrepReminderEnabled,
          onChanged: onReminderChanged,
        ),
        const SizedBox(height: 16),

        // DoseFlow 1.1 資料管理與安全樞紐 (Face ID + iCloud + 醫師 PDF 報表)
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF13253B), Color(0xFF0B1626)],
            ),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            border: Border.all(
              color: DoseFlowColors.mint.withValues(alpha: 0.34),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DoseFlowColors.mint.withValues(alpha: 0.16),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: DoseFlowColors.mint,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isZh ? '資料管理與安全' : 'Privacy & Data Security',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: DoseFlowColors.textPrimary,
                          ),
                        ),
                        Text(
                          isZh ? '100% 離線架構 · 零後台追蹤' : '100% Local-First · Zero Tracking',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: DoseFlowColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Face ID / Passcode Lock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: DoseFlowColors.cardElevated,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: DoseFlowColors.cardBorder),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.lock_rounded, color: DoseFlowColors.mint, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            isZh ? 'Face ID / 密碼鎖' : 'Face ID / Passcode Lock',
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w800,
                              color: DoseFlowColors.textPrimary,
                            ),
                          ),
                          Text(
                            isZh ? '啟動 App 時自動生物辨識解鎖' : 'Protect medical logs on launch',
                            style: const TextStyle(
                              fontSize: 11.0,
                              color: DoseFlowColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: biometricLockEnabled,
                      onChanged: onToggleBiometricLock,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // iCloud Automatic Backup
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: DoseFlowColors.cardElevated,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: DoseFlowColors.cardBorder),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.cloud_done_rounded, color: DoseFlowColors.cyan, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            isZh ? 'iCloud 自動雲端備份' : 'iCloud Private Backup',
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w800,
                              color: DoseFlowColors.textPrimary,
                            ),
                          ),
                          Text(
                            iCloudBackupEnabled
                                ? (isZh ? '● 已連結 · 僅存於個人加密 Apple 空間' : '● Connected · Private Apple iCloud')
                                : (isZh ? '僅儲存在本機，開啟可加密同步至個人 iCloud' : 'Local-only; enable for private iCloud sync'),
                            style: TextStyle(
                              fontSize: 11.0,
                              color: iCloudBackupEnabled
                                  ? DoseFlowColors.cyan
                                  : DoseFlowColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (iCloudBackupEnabled)
                      IconButton(
                        tooltip: isZh ? '立即同步' : 'Sync now',
                        onPressed: onManualICloudSync,
                        icon: const Icon(Icons.sync_rounded, color: DoseFlowColors.cyan, size: 20),
                      ),
                    Switch(
                      value: iCloudBackupEnabled,
                      onChanged: onToggleICloudBackup,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Export Doctor PDF Report quick row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: DoseFlowColors.cardElevated,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: DoseFlowColors.cardBorder),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.picture_as_pdf_rounded, color: DoseFlowColors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            isZh ? '匯出回診 PDF 報告' : 'Export Doctor PDF Report',
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w800,
                              color: DoseFlowColors.textPrimary,
                            ),
                          ),
                          Text(
                            isZh ? '一鍵分享或列印完整劑量與體重報表' : '1-tap clinical summary for your physician',
                            style: const TextStyle(
                              fontSize: 11.0,
                              color: DoseFlowColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        HapticFeedbackService.mediumImpact();
                        showDialog<void>(
                          context: context,
                          builder: (_) => ClinicalExportDialog(
                            logs: logs,
                            startWeightKg: startWeightKg,
                            currentWeightKg: currentWeightKg,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(isZh ? '點擊匯出' : 'Export', style: const TextStyle(fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: DoseFlowColors.mint.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: DoseFlowColors.mint.withValues(alpha: 0.24)),
                ),
                child: Text(
                  isZh
                      ? '🛡️ 本 App 絕不蒐集或上傳您的個人健康與醫療數據。'
                      : '🛡️ This app never collects or uploads your personal health records.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA8D8C8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 【工單 8 - 斯蒂格利茨 (Stiglitz) 動態付費牆引流】
        Card(
          elevation: 0,
          color: DoseFlowColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            side: BorderSide(
              color: isProUnlocked ? DoseFlowColors.mint.withValues(alpha: 0.45) : DoseFlowColors.cyan.withValues(alpha: 0.45),
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
                      color: isProUnlocked ? DoseFlowColors.mint : DoseFlowColors.cyan,
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
                                worrySideEffects: true,
                                worryBruising: false,
                                worryMuscle: true,
                                worryConcentration: true,
                                isDuoDevice: isDuo,
                              ),
                        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w800, color: DoseFlowColors.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isProUnlocked
                      ? BehavioralEconomicsEngine.getAkerlofIdentityBadge(lang)
                      : BehavioralEconomicsEngine.getLossAversionSubtext(lang),
                  style: const TextStyle(fontSize: 12.0, color: DoseFlowColors.textSecondary),
                ),
                const SizedBox(height: 14),
                PulsingCtaButton(
                  onPressed: () {
                    HapticFeedbackService.lightImpact();
                    if (!isProUnlocked) {
                      showDoseFlowPaywallModal(context);
                    } else {
                      _showManageSubscriptionDialog(context);
                    }
                  },
                  icon: Icons.bolt_rounded,
                  label: isProUnlocked ? (isZh ? '管理權益方案' : 'Manage Pro Access') : s.unlockProButton,
                  color: isProUnlocked ? DoseFlowColors.mint : DoseFlowColors.cyan,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      HapticFeedbackService.lightImpact();
                      final bool restored = await PurchaseService.instance.restorePurchases();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              restored
                                  ? (isZh ? '✅ 已成功恢復您的 Pro 授權！' : '✅ Pro access restored!')
                                  : (isZh ? '未找到有效歷史購買紀錄。' : 'No active purchases found.'),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.restore_rounded, size: 15),
                    label: Text(
                      isZh ? '恢復購買' : 'Restore Purchases',
                      style: const TextStyle(fontSize: 11.5, color: DoseFlowColors.cyan, fontWeight: FontWeight.w700),
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
          color: DoseFlowColors.cardSurface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: DoseFlowColors.cardBorder)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(BehavioralEconomicsEngine.getAkerlofAntiLemonSignal(lang), style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700, color: DoseFlowColors.textPrimary, height: 1.4)),
                const Divider(height: 24),
                ...BehavioralEconomicsEngine.getAkerlofTrustGuarantees(lang).map((msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded, size: 16, color: DoseFlowColors.mint),
                      const SizedBox(width: 8),
                      Expanded(child: Text(msg, style: const TextStyle(fontSize: 11.5, color: DoseFlowColors.textSecondary))),
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
          color: DoseFlowColors.cardSurface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: DoseFlowColors.cardBorder)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(BehavioralEconomicsEngine.getShillerNarrativeHook(lang), style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w800, color: DoseFlowColors.textPrimary)),
                const SizedBox(height: 10),
                Text(BehavioralEconomicsEngine.getShillerViralWatermark(lang), style: const TextStyle(fontSize: 11.0, color: DoseFlowColors.textSecondary)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final str = BehavioralEconomicsEngine.generateShillerSilenceCardText(
                        lang: lang,
                        startWeight: startWeightKg,
                        currentWeight: currentWeightKg,
                        foodNoiseSilenceScore: 5,
                        proteinGoalHitRate: 100,
                      );
                      Clipboard.setData(ClipboardData(text: str));
                      HapticFeedbackService.successPattern();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isZh ? '✅ 無涉隱私數據 ‧ 進度摘要已複製至剪貼簿！' : '✅ Privacy-safe progress summary copied to clipboard!')));
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(isZh ? '複製隱私安全進度摘要' : 'Copy Privacy-Safe Summary'),
                    style: FilledButton.styleFrom(backgroundColor: DoseFlowColors.cardElevated, foregroundColor: DoseFlowColors.textPrimary, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          elevation: 0,
          color: DoseFlowColors.cardSurface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: DoseFlowColors.cardBorder)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.gavel_rounded, color: DoseFlowColors.mint, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isZh ? '隱私權政策、服務條款與醫療免責' : 'Privacy Policy, Terms & Medical Info',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: DoseFlowColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const LegalComplianceViewerDialog(
                          initialDocType: ComplianceDocType.privacyPolicy,
                        ),
                      ),
                      icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                      label: Text(isZh ? '隱私權政策' : 'Privacy Policy', style: const TextStyle(fontSize: 11.5)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const LegalComplianceViewerDialog(
                          initialDocType: ComplianceDocType.termsOfService,
                        ),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: Text(isZh ? '服務條款 (EULA)' : 'Terms (EULA)', style: const TextStyle(fontSize: 11.5)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const LegalComplianceViewerDialog(
                          initialDocType: ComplianceDocType.fdaCitations,
                        ),
                      ),
                      icon: const Icon(Icons.verified_user_outlined, size: 16),
                      label: Text(isZh ? 'FDA 仿單文獻引用' : 'FDA Citations', style: const TextStyle(fontSize: 11.5)),
                    ),
                  ],
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
      title: Text(isZh ? '匯出本機加密備份 (Zero Cloud)' : 'Export Local Backup'),
      content: SelectableText(backupBase64, maxLines: 5, style: const TextStyle(fontSize: 10.5, fontFamily: 'Consolas')),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: backupBase64));
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isZh ? '✅ 已複製本機備份編碼至剪貼簿！' : '✅ Backup code copied!')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(isZh ? '複製編碼' : 'Copy'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isZh ? '關閉' : 'Close')),
      ],
    ));
  }

  void _showRestoreDialog(BuildContext context) {
    final bool isZh = context.locale.isZh;
    final TextEditingController controller = TextEditingController();
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isZh ? '貼上 Base64 備份還原' : 'Restore from Base64 Backup'),
      content: TextField(
        controller: controller,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: isZh ? '在此貼上先前匯出的 Base64 備份字串...' : 'Paste your exported Base64 backup string...',
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: 11, fontFamily: 'Consolas'),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isZh ? '取消' : 'Cancel')),
        FilledButton(
          onPressed: () async {
            final bool ok = await AppPersistence.instance.importBackupString(controller.text);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? (isZh ? '✅ 備份還原成功！重開 App 即完整載入紀錄。' : '✅ Backup restored successfully!')
                        : (isZh ? '⚠️ 備份編碼格式無效，未更動現有資料。' : '⚠️ Invalid backup code format.'),
                  ),
                ),
              );
            }
          },
          child: Text(isZh ? '驗證並還原' : 'Restore'),
        ),
      ],
    ));
  }

  void _showManageSubscriptionDialog(BuildContext context) {
    final bool isZh = context.locale.isZh;
    final SubscriptionTier tier = PurchaseService.instance.currentEntitlement.tier;
    final ProductItem item = DoseFlowProductCatalog.getByTier(tier);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          isZh ? 'DoseFlow Pro 訂閱權益' : 'DoseFlow Pro Membership',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          isZh
              ? '目前啟用方案：${item.titleZh}\n\n如需變更或取消訂閱，請前往 iPhone「設定」> Apple ID >「訂閱項目」進行管理。'
              : 'Active Plan: ${item.titleEn}\n\nTo manage or cancel your subscription, open iOS Settings > Apple ID > Subscriptions.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isZh ? '關閉' : 'Close'),
          ),
        ],
      ),
    );
  }
}

/// 全域共用 StoreKit 2 付費牆彈窗（所有 Pro 鎖頭與升級按鈕皆必須走此真實內購流程）
void showDoseFlowPaywallModal(BuildContext context) {
  PurchaseService.instance.refreshLocalizedPrices();
  final AppStrings s = context.strings;
  final AppLanguage lang = context.locale.language;
  final bool isZh = lang.isZh;

  Future<void> triggerPurchase(
    BuildContext sheetCtx,
    SubscriptionTier tier,
  ) async {
    HapticFeedbackService.mediumImpact();
    final bool ok = await PurchaseService.instance.purchase(tier);
    if (ok) {
      HapticFeedbackService.successPattern();
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isZh ? '✅ 感謝訂閱！已成功解鎖 DoseFlow Pro 完整功能。' : '✅ Thank you! DoseFlow Pro is now unlocked.',
            ),
          ),
        );
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PurchaseService.instance.lastErrorMessage ??
                (isZh ? '購買未完成或已取消' : 'Purchase cancelled'),
          ),
        ),
      );
    }
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DoseFlowColors.cardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) {
      return ListenableBuilder(
        listenable: PurchaseService.instance,
        builder: (BuildContext ctx, _) {
          final bool isBusy = PurchaseService.instance.status == PurchaseStatus.purchasing ||
              PurchaseService.instance.status == PurchaseStatus.verifying;
          final String annualPrice =
              PurchaseService.instance.displayPriceFor(SubscriptionTier.annual);
          final String monthlyPrice =
              PurchaseService.instance.displayPriceFor(SubscriptionTier.monthly);
          final String lifetimePrice =
              PurchaseService.instance.displayPriceFor(SubscriptionTier.lifetime);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: DoseFlowColors.cardBorder,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.paywallHeadline,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: DoseFlowColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DoseFlowColors.danger.withValues(alpha: 0.16),
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                    ),
                    child: Text(
                      BehavioralEconomicsEngine.getKahnemanLossFramedHeadline(lang),
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isBusy) ...<Widget>[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(color: DoseFlowColors.mint),
                  ],
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    onTap: isBusy
                        ? null
                        : () => triggerPurchase(
                              sheetContext,
                              SubscriptionTier.annual,
                            ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: DoseFlowColors.mint.withValues(alpha: 0.10),
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        border: Border.all(
                          color: DoseFlowColors.mint,
                          width: 1.8,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: DoseFlowColors.mint,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  BehavioralEconomicsEngine.getThalerDefaultNudgeBadge(lang),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: DoseFlowColors.mint,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isZh
                                      ? '年繳 Pro 方案（含 3 天免費試用）'
                                      : 'Annual Pro (3-Day Free Trial)',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: DoseFlowColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$annualPrice / ${isZh ? "年" : "yr"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: DoseFlowColors.mint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    onTap: isBusy
                        ? null
                        : () => triggerPurchase(
                              sheetContext,
                              SubscriptionTier.monthly,
                            ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DoseFlowColors.cardElevated,
                        borderRadius: const BorderRadius.all(Radius.circular(14)),
                        border: Border.all(color: DoseFlowColors.cardBorder),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 20,
                            color: DoseFlowColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isZh ? '月費方案（彈性無綁約）' : 'Monthly Pro (Flexible)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: DoseFlowColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '$monthlyPrice / ${isZh ? "月" : "mo"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: DoseFlowColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    onTap: isBusy
                        ? null
                        : () => triggerPurchase(
                              sheetContext,
                              SubscriptionTier.lifetime,
                            ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DoseFlowColors.cardElevated,
                        borderRadius: const BorderRadius.all(Radius.circular(14)),
                        border: Border.all(
                          color: const Color(0xFFD946EF),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.diamond_rounded,
                            size: 20,
                            color: Color(0xFFE879F9),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  BehavioralEconomicsEngine.getMilgromDecoyLifetimeLabel(lang),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF0ABFC),
                                  ),
                                ),
                                Text(
                                  isZh
                                      ? '一次買斷，永久解鎖全部進階功能'
                                      : 'One-time purchase, lifetime access',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: DoseFlowColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            lifetimePrice,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: DoseFlowColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PulsingCtaButton(
                    onPressed: isBusy
                        ? () {}
                        : () => triggerPurchase(
                              sheetContext,
                              SubscriptionTier.annual,
                            ),
                    icon: Icons.assignment_turned_in_rounded,
                    label: BehavioralEconomicsEngine.getSchellingUlyssesContractPledge(lang),
                    color: DoseFlowColors.mint,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      TextButton(
                        onPressed: isBusy
                            ? null
                            : () async {
                                final bool ok =
                                    await PurchaseService.instance.restorePurchases();
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? (isZh ? '✅ 已恢復訂閱！' : '✅ Restored!')
                                            : (isZh
                                                ? '未偵測到有效訂閱'
                                                : 'No purchases found'),
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          isZh ? '恢復購買' : 'Restore',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const LegalComplianceViewerDialog(
                            initialDocType: ComplianceDocType.privacyPolicy,
                          ),
                        ),
                        child: Text(
                          isZh ? '隱私權政策' : 'Privacy',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const LegalComplianceViewerDialog(
                            initialDocType: ComplianceDocType.termsOfService,
                          ),
                        ),
                        child: Text(
                          isZh ? '服務條款' : 'Terms (EULA)',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isZh
                        ? '年繳/月繳訂閱將於試用或當期結束前 24 小時透過您的 Apple ID 自動續訂扣款，可隨時至 App Store 訂閱設定取消。'
                        : 'Subscriptions auto-renew via Apple ID unless cancelled at least 24h before period ends.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.0,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
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