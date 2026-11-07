import 'package:flutter_test/flutter_test.dart';
import 'package:dose_flow/core/healthkit_service.dart';

void main() {
  group('HealthKit Authorization & Sandbox Isolation Tests', () {
    test('HealthDataType identifiers match official Apple HealthKit constants', () {
      expect(
        HealthDataType.bodyMass.identifier,
        equals('HKQuantityTypeIdentifierBodyMass'),
      );
      expect(
        HealthDataType.dietaryProtein.identifier,
        equals('HKQuantityTypeIdentifierDietaryProtein'),
      );
      expect(
        HealthDataType.dietaryWater.identifier,
        equals('HKQuantityTypeIdentifierDietaryWater'),
      );
      expect(HealthDataType.bodyMass.defaultUnit, equals('kg'));
      expect(HealthDataType.dietaryProtein.defaultUnit, equals('g'));
      expect(HealthDataType.dietaryWater.defaultUnit, equals('mL'));
    });

    test('requestAuthorization operates safely under shielded sandbox without exceptions', () async {
      final HealthAuthStatus status =
          await HealthKitService.instance.requestAuthorization();
      expect(status, equals(HealthAuthStatus.authorized));
      expect(HealthKitService.instance.authStatus, equals(HealthAuthStatus.authorized));
    });
  });

  group('Bi-directional Sync & Micro-Habits Writing Tests', () {
    test('Weight bi-directional write and fetch operates accurately', () async {
      final DateTime now = DateTime.now();
      final bool writeSuccess = await HealthKitService.instance
          .writeWeightSampleKg(82.4, now);
      expect(writeSuccess, isTrue);

      final double? latestWeight =
          await HealthKitService.instance.fetchLatestWeightKg();
      expect(latestWeight, isNotNull);
      expect(latestWeight, equals(82.4));
    });

    test('Protein and water cumulative tracking filters only today samples', () async {
      final DateTime now = DateTime.now();
      final DateTime yesterday = now.subtract(const Duration(days: 1));

      // 1. 寫入昨日數據 (不應計入今日累計)
      await HealthKitService.instance.writeProteinSampleGrams(30, yesterday);
      await HealthKitService.instance.writeWaterSampleMl(500, yesterday);

      // 2. 寫入今日多次打卡數據
      await HealthKitService.instance.writeProteinSampleGrams(25, now);
      await HealthKitService.instance.writeProteinSampleGrams(35, now);
      await HealthKitService.instance.writeWaterSampleMl(300, now);
      await HealthKitService.instance.writeWaterSampleMl(450, now);

      final int todayProtein =
          await HealthKitService.instance.fetchTodayProteinGrams();
      final int todayWater =
          await HealthKitService.instance.fetchTodayWaterMl();

      // 3. 斷言今日累計精確匹配：蛋白質 25 + 35 = 60g，飲水 300 + 450 = 750mL
      expect(todayProtein, equals(60));
      expect(todayWater, equals(750));
    });
  });

  group('HealthSyncController Reactive State & Listener Tests', () {
    test('syncAll pulls latest data, updates cache, and toggles isSyncing cleanly', () async {
      final HealthSyncController controller = HealthSyncController.instance;

      int notifyCount = 0;
      void listener() => notifyCount++;
      controller.addListener(listener);

      try {
        await controller.syncAll();

        expect(controller.isSyncing, isFalse);
        expect(controller.lastSyncTime, isNotNull);
        expect(controller.authStatus, equals(HealthAuthStatus.authorized));
        expect(notifyCount, greaterThanOrEqualTo(2));
      } finally {
        controller.removeListener(listener);
      }
    });

    test('record methods update controller caches and notify UI listeners', () async {
      final HealthSyncController controller = HealthSyncController.instance;

      int listenerTriggered = 0;
      void listener() => listenerTriggered++;
      controller.addListener(listener);

      try {
        final bool weightLogged = await controller.recordWeight(79.5);
        expect(weightLogged, isTrue);
        expect(controller.latestSyncedWeightKg, equals(79.5));

        final int prevWater = controller.todaySyncedWaterMl;
        final bool waterLogged = await controller.recordWater(250);
        expect(waterLogged, isTrue);
        expect(controller.todaySyncedWaterMl, equals(prevWater + 250));

        final int prevProtein = controller.todaySyncedProteinGrams;
        final bool proteinLogged = await controller.recordProtein(20);
        expect(proteinLogged, isTrue);
        expect(controller.todaySyncedProteinGrams, equals(prevProtein + 20));

        expect(listenerTriggered, greaterThanOrEqualTo(3));
      } finally {
        controller.removeListener(listener);
      }
    });
  });
}
