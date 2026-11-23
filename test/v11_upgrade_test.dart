import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_flow/main.dart';
import 'package:dose_flow/core/app_localization.dart';
import 'package:dose_flow/core/app_persistence.dart';
import 'package:dose_flow/core/app_theme.dart';
import 'package:dose_flow/core/pharmacokinetics_engine.dart';
import 'package:dose_flow/core/privacy_security_service.dart';
import 'package:dose_flow/core/reminder_service.dart';
import 'package:dose_flow/features/rotation/body_rotation_map.dart';
import 'package:dose_flow/features/schedule/reminder_calendar_card.dart';

void main() {
  group('DoseFlow v1.1 Persistence & Schema v2 Tests', () {
    test('AppStorageSnapshot v2 serializes and restores reminder & privacy settings', () {
      final DateTime now = DateTime(2026, 11, 23, 21, 0);
      final AppStorageSnapshot original = AppStorageSnapshot(
        logs: AppStorageSnapshot.initial().logs,
        dailyProteinGrams: 70,
        targetProteinGrams: 100,
        dailyWaterMl: 2000,
        targetWaterMl: 2500,
        bowelCompletedToday: true,
        startWeightKg: 82.0,
        targetWeightKg: 70.0,
        lastSavedTimestamp: now,
        shotReminderEnabled: true,
        shotReminderWeekday: DateTime.friday,
        shotReminderHour: 8,
        shotReminderMinute: 30,
        needlePrepReminderEnabled: true,
        biometricLockEnabled: true,
        iCloudBackupEnabled: true,
        lastICloudSyncAt: now,
      );

      final Map<String, dynamic> map = original.toMap();
      final AppStorageSnapshot restored = AppStorageSnapshot.fromMap(map);

      expect(restored.schemaVersion, equals(2));
      expect(restored.shotReminderEnabled, isTrue);
      expect(restored.shotReminderWeekday, equals(DateTime.friday));
      expect(restored.shotReminderHour, equals(8));
      expect(restored.shotReminderMinute, equals(30));
      expect(restored.needlePrepReminderEnabled, isTrue);
      expect(restored.biometricLockEnabled, isTrue);
      expect(restored.iCloudBackupEnabled, isTrue);
      expect(restored.lastICloudSyncAt, equals(now));
    });

    test('AppStorageSnapshot.fromMap remains backward-compatible with v1 snapshots', () {
      final Map<String, dynamic> v1Map = <String, dynamic>{
        'schemaVersion': 1,
        'dailyProteinGrams': 50,
        'targetProteinGrams': 90,
        'dailyWaterMl': 1500,
        'targetWaterMl': 2500,
        'bowelCompletedToday': false,
        'startWeightKg': 85.0,
        'targetWeightKg': 72.0,
      };

      final AppStorageSnapshot restored = AppStorageSnapshot.fromMap(v1Map);
      expect(restored.shotReminderEnabled, isTrue);
      expect(restored.shotReminderWeekday, equals(DateTime.friday));
      expect(restored.biometricLockEnabled, isFalse);
      expect(restored.iCloudBackupEnabled, isFalse);
    });
  });

  group('DoseFlow v1.1 Concentration Gauge, Reminder & Security Services Tests', () {
    test('DoseConcentrationCard computes bounded radial concentration percentage', () {
      final DateTime now = DateTime.now();
      final List<InjectionRecord> logs = <InjectionRecord>[
        InjectionRecord(
          id: 'g_1',
          timestamp: now.subtract(const Duration(hours: 36)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftLowerAbdomen,
        ),
      ];
      final double currentMg = PharmacokineticsEngine.totalConcentrationAt(
        queryTime: now,
        logs: logs,
      );
      final List<ConcentrationPoint> series =
          PharmacokineticsEngine.generateTimelineSeries(logs: logs, now: now);

      final int pct = DoseConcentrationCard.computeConcentrationPercent(
        currentMg: currentMg,
        series: series,
      );
      expect(pct, inInclusiveRange(1, 100));
    });

    test('ReminderService generates personalized zh-TW and en-US notification copy', () {
      final ({String title, String body}) zhCopy =
          ReminderService.buildNotificationCopy(
        lang: AppLanguage.zhTW,
        weekday: DateTime.friday,
        medication: Glp1Medication.tirzepatide,
        lastSite: InjectionSite.leftThigh,
        nextSite: InjectionSite.rightLowerAbdomen,
      );
      expect(zhCopy.title, contains('星期五'));
      expect(zhCopy.title, contains('猛健樂'));
      expect(zhCopy.body, contains('左大腿'));

      final ({String title, String body}) enCopy =
          ReminderService.buildNotificationCopy(
        lang: AppLanguage.enUS,
        weekday: DateTime.friday,
        medication: Glp1Medication.tirzepatide,
        lastSite: InjectionSite.leftThigh,
        nextSite: InjectionSite.rightLowerAbdomen,
      );
      expect(enCopy.title, contains('Friday'));
      expect(enCopy.body, contains('Left Anterior Thigh'));
    });

    test('PrivacySecurityService operates safely inside test sandbox', () async {
      expect(await PrivacySecurityService.instance.isBiometricAvailable(), isTrue);
      expect(
        await PrivacySecurityService.instance.authenticate(reason: 'Test'),
        isTrue,
      );
      expect(await PrivacySecurityService.instance.syncBackupToICloud(), isTrue);
    });
  });

  group('DoseFlow v1.1 Widget & Navigation Integration Tests', () {
    testWidgets('BodyRotationMapCard displays anatomical rotation zones and confirms shot',
        (WidgetTester tester) async {
      InjectionSite? confirmedSite;
      final LocaleController controller =
          LocaleController(initialLanguage: AppLanguage.zhTW);

      await tester.pumpWidget(
        AppLocaleScope(
          controller: controller,
          child: MaterialApp(
            theme: DoseFlowTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: BodyRotationMapCard(
                  logs: AppStorageSnapshot.initial().logs,
                  activeDoseMg: 2.5,
                  activeMedication: Glp1Medication.tirzepatide,
                  onConfirmInjection: (InjectionSite s) => confirmedSite = s,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('部位輪替與視覺導引'), findsOneWidget);
      expect(find.text('確認施打'), findsOneWidget);

      await tester.tap(find.text('右腹部'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('確認施打'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(confirmedSite, equals(InjectionSite.rightLowerAbdomen));
    });

    testWidgets('ReminderCalendarCard renders preview banner and toggles switches',
        (WidgetTester tester) async {
      bool? latestShotEnabled;
      final LocaleController controller =
          LocaleController(initialLanguage: AppLanguage.zhTW);

      await tester.pumpWidget(
        AppLocaleScope(
          controller: controller,
          child: MaterialApp(
            theme: DoseFlowTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReminderCalendarCard(
                  logs: AppStorageSnapshot.initial().logs,
                  shotReminderEnabled: true,
                  shotReminderWeekday: DateTime.friday,
                  shotReminderHour: 8,
                  shotReminderMinute: 30,
                  needlePrepReminderEnabled: true,
                  onChanged: ({
                    bool? shotReminderEnabled,
                    int? shotReminderWeekday,
                    int? shotReminderHour,
                    int? shotReminderMinute,
                    bool? needlePrepReminderEnabled,
                  }) {
                    if (shotReminderEnabled != null) {
                      latestShotEnabled = shotReminderEnabled;
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('用藥日曆與智慧推播提醒'), findsOneWidget);
      expect(find.text('更換針頭與消毒提醒'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(latestShotEnabled, isFalse);
    });

    testWidgets('MainShellScreen v1.1 navigates cleanly to Settings privacy & calendar hub',
        (WidgetTester tester) async {
      await AppPersistence.instance.resetToInitial();
      await tester.pumpWidget(const DoseFlowApp());
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('略過'));
      await tester.pump(const Duration(milliseconds: 250));

      // Navigate to Settings tab (index 3)
      await tester.tap(find.text('小工具與設定'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('用藥日曆與智慧推播提醒'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('資料管理與安全'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('資料管理與安全'), findsOneWidget);
      expect(find.text('Face ID / 密碼鎖'), findsOneWidget);
      expect(find.text('iCloud 自動雲端備份'), findsOneWidget);
    });
  });
}
