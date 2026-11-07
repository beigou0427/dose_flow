import 'package:flutter_test/flutter_test.dart';
import 'package:dose_flow/main.dart';
import 'package:dose_flow/core/pharmacokinetics_engine.dart';
import 'package:dose_flow/features/calculator/syringe_calculator_view.dart';

void main() {
  group('Pharmacokinetics & Bateman PK Engine Tests', () {
    test('Tirzepatide single dose Bateman curve calculates valid non-negative values', () {
      final double c24 = PharmacokineticsEngine.singleDoseConcentrationAt(
        doseMg: 2.5,
        medication: Glp1Medication.tirzepatide,
        elapsedHours: 24.0,
      );
      final double c36 = PharmacokineticsEngine.singleDoseConcentrationAt(
        doseMg: 2.5,
        medication: Glp1Medication.tirzepatide,
        elapsedHours: 36.0,
      );
      final double c168 = PharmacokineticsEngine.singleDoseConcentrationAt(
        doseMg: 2.5,
        medication: Glp1Medication.tirzepatide,
        elapsedHours: 168.0,
      );

      // 驗證濃度大於零且波峰 (36h Tmax) 大於第 7 天波谷 (168h)
      expect(c24, greaterThan(0.0));
      expect(c36, greaterThan(0.0));
      expect(c168, greaterThan(0.0));
      expect(c36, greaterThan(c168));
    });

    test('recommendNextSite rotates through injection sites sequentially', () {
      final DateTime now = DateTime.now();
      final List<InjectionRecord> logs = <InjectionRecord>[
        InjectionRecord(
          id: 'test_1',
          timestamp: now,
          medication: Glp1Medication.tirzepatide,
          doseMg: 2.5,
          site: InjectionSite.leftUpperAbdomen,
        ),
      ];

      final InjectionSite nextSite =
          PharmacokineticsEngine.recommendNextSite(logs);
      expect(nextSite, equals(InjectionSite.leftLowerAbdomen));
    });
  });

  group('SyringeMathEngine & Poka-Yoke Unit Tests', () {
    test('Premixed mode: 5 mg/mL drawing 2.5 mg outputs exactly 50 Units (0.50 mL)', () {
      final SyringeCalculationResult result = SyringeMathEngine.calculate(
        mode: SyringeCalcMode.premixed,
        concentrationMgPerMl: 5.0,
        vialMassMg: 10.0,
        bacteriostaticWaterMl: 2.0,
        targetDoseMg: 2.5,
      );

      expect(result.isValid, isTrue);
      expect(result.status, equals(SyringeValidationStatus.valid));
      expect(result.volumeMl, equals(0.5));
      expect(result.u100Units, equals(50.0));
      expect(result.effectiveConcentrationMgPerMl, equals(5.0));
    });

    test('Reconstitution mode: 10 mg dry vial + 2 mL BAC water outputs 5.0 mg/mL', () {
      final SyringeCalculationResult result = SyringeMathEngine.calculate(
        mode: SyringeCalcMode.reconstitution,
        concentrationMgPerMl: 0.0,
        vialMassMg: 10.0,
        bacteriostaticWaterMl: 2.0,
        targetDoseMg: 2.5,
      );

      expect(result.isValid, isTrue);
      expect(result.effectiveConcentrationMgPerMl, equals(5.0));
      expect(result.u100Units, equals(50.0));
    });

    test('Over-capacity safety: drawing 15 mg from 5 mg/mL exceeds 100-Unit syringe', () {
      final SyringeCalculationResult result = SyringeMathEngine.calculate(
        mode: SyringeCalcMode.premixed,
        concentrationMgPerMl: 5.0,
        vialMassMg: 20.0,
        bacteriostaticWaterMl: 4.0,
        targetDoseMg: 15.0, // 需要 3.0 mL = 300 Units
      );

      expect(result.isValid, isFalse);
      expect(result.status, equals(SyringeValidationStatus.exceedsSyringeCapacity));
      expect(result.u100Units, greaterThan(100.0));
    });

    test('Invalid input safety: zero or negative target dose is safely blocked', () {
      final SyringeCalculationResult result = SyringeMathEngine.calculate(
        mode: SyringeCalcMode.premixed,
        concentrationMgPerMl: 5.0,
        vialMassMg: 10.0,
        bacteriostaticWaterMl: 2.0,
        targetDoseMg: -2.5,
      );

      expect(result.isValid, isFalse);
      expect(result.status, equals(SyringeValidationStatus.invalidInput));
      expect(result.u100Units, equals(0.0));
    });
  });

  group('DoseFlowApp Widget Smoke & Bilingual Toggle Tests', () {
    testWidgets('DoseFlowApp launches with Onboarding, skips to MainShellScreen, and toggles bilingual language smoothly', (WidgetTester tester) async {
      // 1. 裝載 DoseFlowApp
      await tester.pumpWidget(const DoseFlowApp());
      await tester.pumpAndSettle();

      // 2. 驗證首次啟動正確掛載 OnboardingView (包含「略過」按鈕與第 1 步標題)
      expect(find.text('略過'), findsOneWidget);
      expect(find.text('您目前正在使用哪種 GLP-1 療程？'), findsOneWidget);

      // 3. 點擊「略過」導航進入主畫面 MainShellScreen
      await tester.tap(find.text('略過'));
      await tester.pumpAndSettle();

      // 4. 驗證進入主畫面並渲染預設繁體中文標題與語言切換膠囊
      expect(find.text('瘦瘦針紀錄 Pro'), findsOneWidget);
      expect(find.text('🇹🇼 繁中'), findsOneWidget);
      expect(find.text('🇺🇸 EN'), findsOneWidget);

      // 5. 點擊頂部 LanguageTogglePill 中的英文標籤
      await tester.tap(find.text('🇺🇸 EN'));
      await tester.pumpAndSettle();

      // 6. 驗證立即熱切換為美國英文標題與 Tab
      expect(find.text('DoseFlow: GLP-1 Tracker'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}
