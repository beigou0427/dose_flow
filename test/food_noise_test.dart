import 'package:flutter_test/flutter_test.dart';
import 'package:dose_flow/core/app_localization.dart';
import 'package:dose_flow/core/pharmacokinetics_engine.dart';
import 'package:dose_flow/core/food_noise_engine.dart';

void main() {
  group('Food Noise & Side Effect Modeling Tests', () {
    test('DailySideEffectLog clamps boundaries and enforces safe defaults', () {
      final DateTime now = DateTime.now();

      // 驗證超界自動收斂至合法範圍
      final Map<String, dynamic> rawMap = <String, dynamic>{
        'id': 'test_se_1',
        'date': now.toIso8601String(),
        'foodNoiseSuppression': 10, // 超標應收斂為 5
        'nauseaLevel': -2, // 負數應收斂為 0
        'fatigueLevel': 8, // 超標應收斂為 5
        'acidRefluxLevel': 3,
        'constipationLevel': 2,
        'notes': 'Slight nausea after meal',
      };

      final DailySideEffectLog log = DailySideEffectLog.fromMap(rawMap);
      expect(log.foodNoiseSuppression, equals(5));
      expect(log.nauseaLevel, equals(0));
      expect(log.fatigueLevel, equals(5));
      expect(log.acidRefluxLevel, equals(3));
      expect(log.constipationLevel, equals(2));
      expect(log.notes, equals('Slight nausea after meal'));
    });

    test('overallSymptomSeverity calculates weighted clinical index correctly', () {
      final DateTime now = DateTime.now();
      // 最高分症狀為 fatigueLevel = 4 (權重 70%)
      // 四項平均為 (1 + 4 + 1 + 2) / 4.0 = 2.0 (權重 30%)
      // 綜合評分為 4 * 0.7 + 2.0 * 0.3 = 2.8 + 0.6 = 3.4
      final DailySideEffectLog log = DailySideEffectLog(
        id: 'test_se_2',
        date: now,
        foodNoiseSuppression: 4,
        nauseaLevel: 1,
        fatigueLevel: 4,
        acidRefluxLevel: 1,
        constipationLevel: 2,
      );

      expect(log.overallSymptomSeverity, equals(3.4));
    });

    test('DailySideEffectLog serialization roundtrip preserves all values', () {
      final DateTime now = DateTime.now();
      final DailySideEffectLog original = DailySideEffectLog(
        id: 'roundtrip_se',
        date: now,
        foodNoiseSuppression: 3,
        nauseaLevel: 2,
        fatigueLevel: 3,
        acidRefluxLevel: 0,
        constipationLevel: 4,
        notes: 'Constipation managed with water',
      );

      final Map<String, dynamic> map = original.toMap();
      final DailySideEffectLog restored = DailySideEffectLog.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.foodNoiseSuppression, equals(original.foodNoiseSuppression));
      expect(restored.nauseaLevel, equals(original.nauseaLevel));
      expect(restored.fatigueLevel, equals(original.fatigueLevel));
      expect(restored.acidRefluxLevel, equals(original.acidRefluxLevel));
      expect(restored.constipationLevel, equals(original.constipationLevel));
      expect(restored.notes, equals(original.notes));
    });
  });

  group('FoodNoiseCorrelationEngine 7-Day Profile Analytics Tests', () {
    test('Cold-start sparse fallback generates standard Bateman clinical curve', () {
      final List<DayCorrelationProfile> profiles =
          FoodNoiseCorrelationEngine.calculate7DayProfile(
        sideEffectLogs: <DailySideEffectLog>[],
        injectionLogs: <InjectionRecord>[],
      );

      expect(profiles.length, equals(7));
      // 驗證 Day 1 達峰壓制 (4.8) 大於 Day 7 半衰期末期 (1.9)
      expect(profiles.first.postShotDay, equals(1));
      expect(profiles.first.avgFoodNoiseSuppression, equals(4.8));
      expect(profiles.last.postShotDay, equals(7));
      expect(profiles.last.avgFoodNoiseSuppression, equals(1.9));
      expect(profiles.first.avgFoodNoiseSuppression,
          greaterThan(profiles.last.avgFoodNoiseSuppression));
    });

    test('Correlating actual logs into 7-day post-shot buckets averages accurately', () {
      final DateTime shotTime = DateTime(2026, 11, 1, 8, 0);
      final List<InjectionRecord> shots = <InjectionRecord>[
        InjectionRecord(
          id: 'shot_base',
          timestamp: shotTime,
          medication: Glp1Medication.tirzepatide,
          doseMg: 5.0,
          site: InjectionSite.rightLowerAbdomen,
        ),
      ];

      // 注入 Day 1 (施打後 6 小時與 12 小時) 兩筆紀錄：雜音 5 與 3 -> 平均應為 4.0
      // 注入 Day 2 (施打後 30 小時) 一筆紀錄：疲勞 4 -> Day 2 疲勞應為 4.0
      final List<DailySideEffectLog> seLogs = <DailySideEffectLog>[
        DailySideEffectLog(
          id: 'se_d1_a',
          date: shotTime.add(const Duration(hours: 6)),
          foodNoiseSuppression: 5,
          nauseaLevel: 2,
        ),
        DailySideEffectLog(
          id: 'se_d1_b',
          date: shotTime.add(const Duration(hours: 12)),
          foodNoiseSuppression: 3,
          nauseaLevel: 0,
        ),
        DailySideEffectLog(
          id: 'se_d2',
          date: shotTime.add(const Duration(hours: 30)),
          foodNoiseSuppression: 4,
          fatigueLevel: 4,
        ),
      ];

      final List<DayCorrelationProfile> profiles =
          FoodNoiseCorrelationEngine.calculate7DayProfile(
        sideEffectLogs: seLogs,
        injectionLogs: shots,
      );

      // Day 1 (index 0)
      expect(profiles[0].sampleCount, equals(2));
      expect(profiles[0].avgFoodNoiseSuppression, equals(4.0));
      expect(profiles[0].avgNausea, equals(1.0));

      // Day 2 (index 1)
      expect(profiles[1].sampleCount, equals(1));
      expect(profiles[1].avgFatigue, equals(4.0));
    });
  });

  group('Optimal Injection Timing Recommendation Tests', () {
    test('Peak symptom on Day 2 recommends Friday evening with bilingual rationale', () {
      final InjectionDayRecommendation recZh =
          FoodNoiseCorrelationEngine.recommendOptimalInjectionTiming(
        sideEffectLogs: <DailySideEffectLog>[],
        injectionLogs: <InjectionRecord>[],
        lang: AppLanguage.zhTW,
      );

      expect(recZh.peakSymptomDayOffset, equals(2));
      expect(recZh.recommendedWeekday, equals(DateTime.friday));
      expect(recZh.recommendedTimeLabel, contains('週五晚間'));
      expect(recZh.rationale(AppLanguage.zhTW), contains('第 2 天'));

      final InjectionDayRecommendation recEn =
          FoodNoiseCorrelationEngine.recommendOptimalInjectionTiming(
        sideEffectLogs: <DailySideEffectLog>[],
        injectionLogs: <InjectionRecord>[],
        lang: AppLanguage.enUS,
      );

      expect(recEn.recommendedTimeLabel, contains('Friday Evening'));
      expect(recEn.rationale(AppLanguage.enUS), contains('Day 2'));
    });

    test('Peak symptom on Day 3 dynamically shifts recommendation to Thursday evening', () {
      final DateTime shotTime = DateTime(2026, 11, 1, 8, 0);
      final List<InjectionRecord> shots = <InjectionRecord>[
        InjectionRecord(
          id: 'shot_d3',
          timestamp: shotTime,
          medication: Glp1Medication.semaglutide,
          doseMg: 1.0,
          site: InjectionSite.leftThigh,
        ),
      ];

      // 施打後 54 小時 (落於 Day 3, index 2) 發生嚴重疲勞 (5分)
      final List<DailySideEffectLog> seLogs = <DailySideEffectLog>[
        DailySideEffectLog(
          id: 'se_d3_peak',
          date: shotTime.add(const Duration(hours: 54)),
          foodNoiseSuppression: 5,
          fatigueLevel: 5,
          nauseaLevel: 4,
        ),
      ];

      final InjectionDayRecommendation rec =
          FoodNoiseCorrelationEngine.recommendOptimalInjectionTiming(
        sideEffectLogs: seLogs,
        injectionLogs: shots,
        lang: AppLanguage.zhTW,
      );

      expect(rec.peakSymptomDayOffset, equals(3));
      expect(rec.recommendedWeekday, equals(DateTime.thursday));
      expect(rec.recommendedTimeLabel, contains('週四晚間'));
    });
  });
}
