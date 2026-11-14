import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dose_flow/core/app_localization.dart';
import 'package:dose_flow/core/app_persistence.dart';
import 'package:dose_flow/core/food_noise_engine.dart';
import 'package:dose_flow/core/pharmacokinetics_engine.dart';
import 'package:dose_flow/core/purchase_service.dart';
import 'package:dose_flow/features/calculator/syringe_calculator_view.dart';
import 'package:dose_flow/features/duo/duo_layout_adapter.dart';
import 'package:dose_flow/main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime.now();
  final List<InjectionRecord> seedLogs = <InjectionRecord>[
    InjectionRecord(
      id: 'cap_6',
      timestamp: now.subtract(const Duration(days: 2, hours: 6)),
      medication: Glp1Medication.tirzepatide,
      doseMg: 5.0,
      site: InjectionSite.rightLowerAbdomen,
      painLevel: 1,
    ),
    InjectionRecord(
      id: 'cap_5',
      timestamp: now.subtract(const Duration(days: 9, hours: 6)),
      medication: Glp1Medication.tirzepatide,
      doseMg: 5.0,
      site: InjectionSite.leftLowerAbdomen,
      painLevel: 1,
    ),
    InjectionRecord(
      id: 'cap_4',
      timestamp: now.subtract(const Duration(days: 16, hours: 6)),
      medication: Glp1Medication.tirzepatide,
      doseMg: 2.5,
      site: InjectionSite.rightUpperAbdomen,
      painLevel: 0,
    ),
    InjectionRecord(
      id: 'cap_3',
      timestamp: now.subtract(const Duration(days: 23, hours: 6)),
      medication: Glp1Medication.tirzepatide,
      doseMg: 2.5,
      site: InjectionSite.leftUpperAbdomen,
      painLevel: 0,
    ),
  ];

  await AppPersistence.instance.saveSnapshot(
    AppStorageSnapshot(
      logs: seedLogs,
      dailyProteinGrams: 75,
      targetProteinGrams: 90,
      dailyWaterMl: 2050,
      targetWaterMl: 2500,
      bowelCompletedToday: true,
      startWeightKg: 86.0,
      targetWeightKg: 70.0,
      lastSavedTimestamp: now,
    ),
  );
  if (!PurchaseService.instance.isProUnlocked) {
    PurchaseService.instance.toggleProForTesting();
  }

  final LocaleController localeCtrl =
      LocaleController(initialLanguage: AppLanguage.zhTW);
  final ValueNotifier<int> sceneNotifier = ValueNotifier<int>(0);

  runApp(
    CaptureShellApp(
      localeController: localeCtrl,
      sceneNotifier: sceneNotifier,
      logs: seedLogs,
      now: now,
    ),
  );

  unawaited(_runCaptureSequence(localeCtrl, sceneNotifier));
}

Future<void> _runCaptureSequence(
  LocaleController localeCtrl,
  ValueNotifier<int> sceneNotifier,
) async {
  await Future<void>.delayed(const Duration(seconds: 2));
  Socket? sock;
  try {
    sock = await Socket.connect('127.0.0.1', 18765);
    final StreamIterator<String> lines = StreamIterator<String>(
      sock.cast<List<int>>().transform(utf8.decoder).transform(
            const LineSplitter(),
          ),
    );

    for (final AppLanguage lang in <AppLanguage>[
      AppLanguage.zhTW,
      AppLanguage.enUS,
    ]) {
      localeCtrl.setLanguage(lang);
      final String code = lang.isZh ? 'zh-Hant' : 'en-US';
      for (int scene = 0; scene < 5; scene++) {
        sceneNotifier.value = scene;
        await Future<void>.delayed(const Duration(milliseconds: 950));
        sock.writeln('SNAP:${code}_${scene + 1}');
        await sock.flush();
        await lines.moveNext();
      }
    }
    sock.writeln('DONE');
    await sock.flush();
  } catch (e) {
    stderr.writeln('Capture socket error: $e');
  } finally {
    await sock?.close();
  }
}

class CaptureShellApp extends StatelessWidget {
  const CaptureShellApp({
    super.key,
    required this.localeController,
    required this.sceneNotifier,
    required this.logs,
    required this.now,
  });

  final LocaleController localeController;
  final ValueNotifier<int> sceneNotifier;
  final List<InjectionRecord> logs;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return AppLocaleScope(
      controller: localeController,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        home: ValueListenableBuilder<int>(
          valueListenable: sceneNotifier,
          builder: (BuildContext ctx, int scene, _) {
            if (scene == 4) {
              return DuoTabletopInjectionGuide(
                recommendedSite: InjectionSite.leftLowerAbdomen,
                targetDoseMg: 5.0,
                calculatedUnits: 50.0,
                calculatedVolumeMl: 0.50,
                onConfirmInjection: () {},
              );
            }
            final AppStrings s = ctx.strings;
            final List<DailySideEffectLog> seLogs = <DailySideEffectLog>[
              DailySideEffectLog(
                id: 'se_1',
                date: now.subtract(const Duration(days: 1)),
                foodNoiseSuppression: 5,
                fatigueLevel: 2,
              ),
              DailySideEffectLog(
                id: 'se_2',
                date: now.subtract(const Duration(days: 2)),
                foodNoiseSuppression: 4,
                nauseaLevel: 1,
              ),
            ];

            final Widget dashboardBody = HomeDashboardView(
              logs: logs,
              now: now,
              isProUnlocked: true,
              onToggleProPreview: () {},
              proteinGrams: 75,
              targetProteinGrams: 90,
              waterMl: 2050,
              targetWaterMl: 2500,
              bowelCompleted: true,
              latestFoodNoiseScore: 5,
              onOpenFoodNoiseDialog: () {},
              onQuickLogShot: (_) {},
              onAddProtein: (_) {},
              onAddWater: (_) {},
              onToggleBowel: () {},
            );

            final Widget analyticsBody = AnalyticsView(
              logs: logs,
              sideEffectLogs: seLogs,
              startWeightKg: 86.0,
              currentWeightKg: 80.8,
              isProUnlocked: true,
              onRequestUnlockPro: () {},
            );

            final PreferredSizeWidget topBar = AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.appTitle,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    s.appSubtitle,
                    style: const TextStyle(
                      fontSize: 11.0,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              actions: const <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: LanguageTogglePill(),
                ),
              ],
            );

            final Widget navBar = NavigationBar(
              selectedIndex: scene,
              onDestinationSelected: (_) {},
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard_rounded),
                  label: s.tabDashboard,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.colorize_outlined),
                  selectedIcon: const Icon(Icons.colorize_rounded),
                  label: s.tabShotLog,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.insights_outlined),
                  selectedIcon: const Icon(Icons.insights_rounded),
                  label: s.tabAnalytics,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.tune_outlined),
                  selectedIcon: const Icon(Icons.tune_rounded),
                  label: s.tabSettings,
                ),
              ],
            );

            if (scene == 0 && DuoDeviceDetector.isLargeScreen(ctx)) {
              return DuoAdaptiveScaffold(
                appBar: topBar,
                primaryPane: dashboardBody,
                secondaryPane: analyticsBody,
                bottomNavigationBar: navBar,
              );
            }

            Widget body = dashboardBody;
            if (scene == 1) {
              body = ShotLogAndCalculatorView(
                logs: logs,
                isProUnlocked: true,
                onAddLog: (_) {},
                onRequestUnlockPro: () {},
              );
            } else if (scene == 2) {
              body = analyticsBody;
            } else if (scene == 3) {
              body = SettingsAndPaywallView(
                isProUnlocked: false,
                onTogglePro: () {},
              );
            }

            return Scaffold(
              appBar: topBar,
              body: body,
              bottomNavigationBar: navBar,
            );
          },
        ),
      ),
    );
  }
}
