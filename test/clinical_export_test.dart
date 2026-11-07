import 'package:flutter_test/flutter_test.dart';
import 'package:dose_flow/core/app_localization.dart';
import 'package:dose_flow/core/pharmacokinetics_engine.dart';
import 'package:dose_flow/core/clinical_export_service.dart';

void main() {
  group('Clinical Adherence & Velocity Metrics Calculation Tests', () {
    test('Empty logs baseline produces safe 100% default metrics with zero crashes', () {
      final ClinicalAdherenceMetrics metrics = ClinicalExportService.calculateMetrics(
        logs: <InjectionRecord>[],
        startWeightKg: 85.0,
        currentWeightKg: 80.0,
      );

      expect(metrics.adherenceRatePercent, equals(100.0));
      expect(metrics.siteRotationCompliancePercent, equals(100.0));
      expect(metrics.weeklyWeightVelocityKg, equals(0.0));
      expect(metrics.totalLossKg, equals(0.0));
      expect(metrics.totalLogsCount, equals(0));
      expect(metrics.distinctSitesUsed, equals(0));
    });

    test('Regular 7-day titration with distinct sites yields 100% adherence and rotation', () {
      final DateTime now = DateTime.now();
      final List<InjectionRecord> logs = <InjectionRecord>[
        InjectionRecord(
          id: 'shot_1',
          timestamp: now.subtract(const Duration(days: 35)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftLowerAbdomen,
        ),
        InjectionRecord(
          id: 'shot_2',
          timestamp: now.subtract(const Duration(days: 28)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.rightLowerAbdomen,
        ),
        InjectionRecord(
          id: 'shot_3',
          timestamp: now.subtract(const Duration(days: 21)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftUpperAbdomen,
        ),
        InjectionRecord(
          id: 'shot_4',
          timestamp: now.subtract(const Duration(days: 14)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.rightUpperAbdomen,
        ),
        InjectionRecord(
          id: 'shot_5',
          timestamp: now.subtract(const Duration(days: 7)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 5.0,
          site: InjectionSite.leftThigh,
        ),
        InjectionRecord(
          id: 'shot_6',
          timestamp: now,
          medication: Glp1Medication.tirzepatide,
          doseMg: 5.0,
          site: InjectionSite.rightThigh,
        ),
      ];

      final ClinicalAdherenceMetrics metrics = ClinicalExportService.calculateMetrics(
        logs: logs,
        startWeightKg: 86.5,
        currentWeightKg: 81.6,
      );

      expect(metrics.adherenceRatePercent, equals(100.0));
      expect(metrics.siteRotationCompliancePercent, equals(100.0));
      expect(metrics.distinctSitesUsed, equals(6));
      expect(metrics.totalLogsCount, equals(6));
      expect(metrics.totalLossKg, equals(4.9));
      expect(metrics.weeklyWeightVelocityKg, greaterThan(0.7));
    });
  });

  group('Adherence Violation & Non-compliant Rotation Boundary Tests', () {
    test('Delayed and missed shots properly penalize adherence rate percentage', () {
      final DateTime now = DateTime.now();
      // 6 針產生 5 個間隔：3 個正常(7天)，1 個嚴重延遲(14天)，1 個延遲(12天)
      final List<InjectionRecord> logs = <InjectionRecord>[
        InjectionRecord(
          id: 'v_1',
          timestamp: now.subtract(const Duration(days: 47)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftLowerAbdomen,
        ),
        InjectionRecord(
          id: 'v_2',
          timestamp: now.subtract(const Duration(days: 40)), // 7 天 (合格)
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.rightLowerAbdomen,
        ),
        InjectionRecord(
          id: 'v_3',
          timestamp: now.subtract(const Duration(days: 33)), // 7 天 (合格)
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftUpperAbdomen,
        ),
        InjectionRecord(
          id: 'v_4',
          timestamp: now.subtract(const Duration(days: 19)), // 14 天 (漏針違規!)
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.rightUpperAbdomen,
        ),
        InjectionRecord(
          id: 'v_5',
          timestamp: now.subtract(const Duration(days: 7)), // 12 天 (延遲違規!)
          medication: Glp1Medication.tirzepatide,
          doseMg: 5.0,
          site: InjectionSite.leftThigh,
        ),
        InjectionRecord(
          id: 'v_6',
          timestamp: now, // 7 天 (合格)
          medication: Glp1Medication.tirzepatide,
          doseMg: 5.0,
          site: InjectionSite.rightThigh,
        ),
      ];

      final ClinicalAdherenceMetrics metrics = ClinicalExportService.calculateMetrics(
        logs: logs,
        startWeightKg: 85.0,
        currentWeightKg: 81.0,
      );

      // 5 個間隔中有 3 個合規 -> 3 / 5 = 60.0%
      expect(metrics.adherenceRatePercent, equals(60.0));
      expect(metrics.siteRotationCompliancePercent, equals(100.0));
    });

    test('Repeated consecutive site injections triggers lipohypertrophy rotation penalties', () {
      final DateTime now = DateTime.now();
      // 4 針產生 3 個間隔：2 次連續施打同部位違規，1 次切換合規
      final List<InjectionRecord> logs = <InjectionRecord>[
        InjectionRecord(
          id: 'r_1',
          timestamp: now.subtract(const Duration(days: 21)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftLowerAbdomen,
        ),
        InjectionRecord(
          id: 'r_2',
          timestamp: now.subtract(const Duration(days: 14)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftLowerAbdomen, // 違規重複!
        ),
        InjectionRecord(
          id: 'r_3',
          timestamp: now.subtract(const Duration(days: 7)),
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftLowerAbdomen, // 違規重複!
        ),
        InjectionRecord(
          id: 'r_4',
          timestamp: now,
          medication: Glp1Medication.tirzepatide,
          doseMg: 5.0,
          site: InjectionSite.rightLowerAbdomen, // 合規切換
        ),
      ];

      final ClinicalAdherenceMetrics metrics = ClinicalExportService.calculateMetrics(
        logs: logs,
        startWeightKg: 85.0,
        currentWeightKg: 82.5,
      );

      // 3 次轉移中僅 1 次合規 -> 1 / 3 = 33.3%
      expect(metrics.siteRotationCompliancePercent, equals(33.3));
      expect(metrics.distinctSitesUsed, equals(2));
    });
  });

  group('RFC 4180 CSV & Physician HTML Formatting Tests', () {
    test('generateCsv adheres strictly to RFC 4180 with proper quotation and escaping', () {
      final DateTime now = DateTime.now();
      final List<InjectionRecord> logs = <InjectionRecord>[
        InjectionRecord(
          id: 'c_1',
          timestamp: now,
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftLowerAbdomen,
          painLevel: 1,
          batchOrVialNote: 'Batch #12, "Reconstituted" safely',
        ),
      ];

      // 1. 繁體中文 CSV 測試
      final String csvZh = ClinicalExportService.generateCsv(
        logs: logs,
        lang: AppLanguage.zhTW,
      );
      expect(csvZh, contains('施打序號,日期,時間,藥物品牌,施打劑量(mg),注射部位,疼痛感(0-5),備註/藥瓶批號'));
      // 驗證逗號與雙引號欄位轉義 (RFC 4180 規範)
      expect(csvZh, contains('"Batch #12, ""Reconstituted"" safely"'));

      // 2. 英文 CSV 測試
      final String csvEn = ClinicalExportService.generateCsv(
        logs: logs,
        lang: AppLanguage.enUS,
      );
      expect(csvEn, contains('ShotIndex,Date,Time,Medication,Dose(mg),InjectionSite,PainLevel(0-5),BatchOrNotes'));
      expect(csvEn, contains('Tirzepatide'));
    });

    test('generatePhysicianSummaryHtml outputs print-optimized A4 layout and B2B2C referral watermark', () {
      final DateTime now = DateTime.now();
      final List<InjectionRecord> logs = <InjectionRecord>[
        InjectionRecord(
          id: 'p_1',
          timestamp: now,
          medication: Glp1Medication.tirzepatide,
          doseMg: 5.0,
          site: InjectionSite.rightLowerAbdomen,
          painLevel: 1,
        ),
      ];

      for (final AppLanguage lang in AppLanguage.values) {
        final String html = ClinicalExportService.generatePhysicianSummaryHtml(
          logs: logs,
          startWeightKg: 85.0,
          currentWeightKg: 81.2,
          lang: lang,
          unit: WeightUnit.kg,
        );

        expect(html, contains('<!DOCTYPE html>'));
        expect(html, contains('@page { size: A4 portrait; margin: 12mm; }'));
        expect(html, contains('@media print'));
        expect(html, contains('https://doseflow.app'));
        expect(html, contains('Clinician Partner Ready'));
        expect(html, contains('5.0 mg'));
      }
    });

    test('generatePlainTextSummary formats clean medical progress note for clinic messaging', () {
      final DateTime now = DateTime.now();
      final List<InjectionRecord> logs = <InjectionRecord>[
        InjectionRecord(
          id: 'txt_1',
          timestamp: now,
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftLowerAbdomen,
        ),
      ];

      for (final AppLanguage lang in AppLanguage.values) {
        final String summary = ClinicalExportService.generatePlainTextSummary(
          logs: logs,
          startWeightKg: 85.0,
          currentWeightKg: 82.0,
          lang: lang,
          unit: WeightUnit.kg,
        );

        expect(summary, isNotEmpty);
        if (lang.isZh) {
          expect(summary, contains('【DoseFlow 瘦瘦針回診臨床進度報告】'));
          expect(summary, contains('累計減重 -3.0 kg'));
        } else {
          expect(summary, contains('[DoseFlow Clinical Visit Summary]'));
          expect(summary, contains('Total Loss: -3.0 kg'));
        }
      }
    });
  });
}
