import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_flow/core/app_localization.dart';
import 'package:dose_flow/core/behavioral_economics_engine.dart';

void main() {
  group('BehavioralEconomicsEngine Anchoring Math Tests', () {
    test('Annual subscription price is accurately divided into equivalent monthly anchor', () {
      final double monthlyEquivalent =
          BehavioralEconomicsEngine.getAnchoredMonthlyPrice(39.99);

      expect(monthlyEquivalent, closeTo(3.3325, 0.001));
      expect(double.parse(monthlyEquivalent.toStringAsFixed(2)), equals(3.33));
    });

    test('Zero or custom pricing handles boundary values without zero division crash', () {
      expect(BehavioralEconomicsEngine.getAnchoredMonthlyPrice(0.0), equals(0.0));
      expect(BehavioralEconomicsEngine.getAnchoredMonthlyPrice(120.0), equals(10.0));
    });
  });

  group('Loss Aversion & Bandwagon Copy Tests', () {
    test('Loss aversion subtext contains social proof metrics in both traditional Chinese and English', () {
      final String copyZh =
          BehavioralEconomicsEngine.getLossAversionSubtext(AppLanguage.zhTW);
      final String copyEn =
          BehavioralEconomicsEngine.getLossAversionSubtext(AppLanguage.enUS);

      expect(copyZh, contains('8,420'));
      expect(copyZh, contains('停止盲目猜測'));

      expect(copyEn, contains('8,420+'));
      expect(copyEn, contains('Stop guessing'));
    });
  });

  group('iPhone Duo Veblen Headline Dynamic Heuristics Tests', () {
    test('Duo large screen triggers premium exclusivity headline in Traditional Chinese', () {
      final String headline =
          BehavioralEconomicsEngine.getDuoExclusivePaywallHeadline(
        AppLanguage.zhTW,
        true,
      );
      expect(headline, contains('iPhone Duo 雙螢幕極致洞察'));
      expect(headline, contains('90° 懸停模式'));
    });

    test('Standard screen falls back to PK curve and muscle loss headline in Traditional Chinese', () {
      final String headline =
          BehavioralEconomicsEngine.getDuoExclusivePaywallHeadline(
        AppLanguage.zhTW,
        false,
      );
      expect(headline, contains('GLP-1 雙指數代謝模型'));
      expect(headline, contains('抗掉肌肉計畫'));
    });

    test('Duo large screen triggers premium exclusivity headline in English', () {
      final String headline =
          BehavioralEconomicsEngine.getDuoExclusivePaywallHeadline(
        AppLanguage.enUS,
        true,
      );
      expect(headline, contains('iPhone Duo Dual-Pane Analytics'));
      expect(headline, contains('Tabletop Mode'));
    });

    test('Standard screen falls back to PK curve and muscle loss headline in English', () {
      final String headline =
          BehavioralEconomicsEngine.getDuoExclusivePaywallHeadline(
        AppLanguage.enUS,
        false,
      );
      expect(headline, contains('Personal GLP-1 PK Curve'));
      expect(headline, contains('Anti-Muscle Loss Plan'));
    });
  });

  group('PulsingCtaButton Micro-Animation & Widget Tests', () {
    testWidgets('PulsingCtaButton renders label, icon, and handles tap callback safely', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingCtaButton(
              label: 'Unlock Pro Now',
              icon: Icons.bolt_rounded,
              onPressed: () => tapped = true,
              color: const Color(0xFF0EA5E9),
            ),
          ),
        ),
      );

      // 1. 驗證標籤與圖示渲染
      expect(find.text('Unlock Pro Now'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      // 2. 驗證點擊回呼觸發（以文字定位確保精確命中 hit test）
      await tester.tap(find.text('Unlock Pro Now'));
      expect(tapped, isTrue);

      // 3. 前進動畫半週期 (625ms)，以 descendant 精確驗證 PulsingCtaButton 內部的 ScaleTransition
      await tester.pump(const Duration(milliseconds: 625));
      expect(
        find.descendant(
          of: find.byType(PulsingCtaButton),
          matching: find.byType(ScaleTransition),
        ),
        findsOneWidget,
      );

      // 4. 再次前進半週期達到完整週期 (1250ms)，驗證反向縮放平穩
      await tester.pump(const Duration(milliseconds: 625));
      expect(
        find.descendant(
          of: find.byType(PulsingCtaButton),
          matching: find.byType(ScaleTransition),
        ),
        findsOneWidget,
      );
    });
  });
}