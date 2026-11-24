import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_flow/main.dart';
import 'package:dose_flow/core/app_persistence.dart';
import 'package:dose_flow/core/pharmacokinetics_engine.dart';
import 'package:dose_flow/core/purchase_service.dart';

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

  group('App Review Guideline 2.1(b) & 1.4.2 Compliance Widget Tests', () {
    setUp(() async {
      PurchaseService.instance.resetToFreeForTesting();
      await AppPersistence.instance.resetToInitial();
    });

    testWidgets('Pro status stays locked by default and Unlock CTA opens StoreKit paywall without auto-unlocking', (WidgetTester tester) async {
      await tester.pumpWidget(const DoseFlowApp());
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('略過'));
      await tester.pump(const Duration(milliseconds: 250));

      // Verify Pro starts locked and no free preview bypass button exists
      expect(PurchaseService.instance.isProUnlocked, isFalse);
      expect(find.text('免費預覽 Pro'), findsNothing);
      expect(find.text('Preview Pro'), findsNothing);

      // Tap Dashboard Unlock Pro button -> must open paywall, NOT auto-unlock
      final Finder unlockBtn = find.text('立即解鎖 Pro 代謝曲線');
      await tester.scrollUntilVisible(
        unlockBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(unlockBtn, findsOneWidget);
      await tester.tap(unlockBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(PurchaseService.instance.isProUnlocked, isFalse);
      expect(find.text('年繳 Pro 方案（含 3 天免費試用）'), findsOneWidget);
      expect(find.text('月費方案（彈性無綁約）'), findsOneWidget);
    });

    testWidgets('Shot Log tab provides injection logging and site rotation with zero dosage calculator UI', (WidgetTester tester) async {
      await tester.pumpWidget(const DoseFlowApp());
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('略過'));
      await tester.pump(const Duration(milliseconds: 250));

      // Navigate to Tab 2 (施打紀錄)
      await tester.tap(find.text('施打紀錄'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('部位輪替與視覺導引'), findsOneWidget);
      expect(find.textContaining('U-100'), findsNothing);
      expect(find.textContaining('乾粉泡製'), findsNothing);
      expect(find.textContaining('針筒'), findsNothing);
      expect(find.textContaining('mL'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('新增今日施打紀錄'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('新增今日施打紀錄'), findsOneWidget);
    });

    testWidgets('Settings tab omits developer ASO/Google tools and renders readable plain-text legal policies', (WidgetTester tester) async {
      await tester.pumpWidget(const DoseFlowApp());
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('略過'));
      await tester.pump(const Duration(milliseconds: 250));

      // Navigate to Settings tab
      await tester.tap(find.text('小工具與設定'));
      await tester.pump(const Duration(milliseconds: 250));

      // Scroll to bottom legal card
      await tester.scrollUntilVisible(
        find.text('隱私權政策、服務條款與醫療免責'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Ensure no developer ASO or third-party platform (Google) references exist
      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('ASO'), findsNothing);

      // Tap Privacy Policy -> must show clean readable text, NOT raw HTML or App Review Notes
      await tester.tap(find.text('隱私權政策'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.textContaining('<!DOCTYPE html>'), findsNothing);
      expect(find.textContaining('給 Apple 審核員之專屬合規說明'), findsNothing);
      expect(find.textContaining('100% 本地端架構'), findsOneWidget);
    });
  });

  group('DoseFlowApp Widget Smoke & Bilingual Toggle Tests', () {
    setUp(() async {
      PurchaseService.instance.resetToFreeForTesting();
      await AppPersistence.instance.resetToInitial();
    });

    testWidgets('DoseFlowApp launches with Onboarding, skips to MainShellScreen, and toggles bilingual language smoothly', (WidgetTester tester) async {
      // 1. 裝載 DoseFlowApp
      await tester.pumpWidget(const DoseFlowApp());
      await tester.pump(const Duration(milliseconds: 250));

      // 2. 驗證首次啟動正確掛載 OnboardingView (包含「略過」按鈕與第 1 步標題)
      expect(find.text('略過'), findsOneWidget);
      expect(find.text('您目前正在使用哪種 GLP-1 療程？'), findsOneWidget);

      // 3. 點擊「略過」導航進入主畫面 MainShellScreen
      await tester.tap(find.text('略過'));
      await tester.pump(const Duration(milliseconds: 250));

      // 4. 驗證進入主畫面並渲染預設繁體中文標題與語言切換膠囊
      expect(find.text('瘦瘦針紀錄 Pro'), findsOneWidget);
      expect(find.text('🇹🇼 繁中'), findsOneWidget);
      expect(find.text('🇺🇸 EN'), findsOneWidget);

      // 5. 點擊頂部 LanguageTogglePill 中的英文標籤
      await tester.tap(find.text('🇺🇸 EN'));
      await tester.pump(const Duration(milliseconds: 250));

      // 6. 驗證立即熱切換為美國英文標題與 Tab
      expect(find.text('DoseFlow: GLP-1 Tracker'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Shot Log'), findsOneWidget);
    });
  });
}
