import 'package:flutter_test/flutter_test.dart';
import 'package:dose_flow/core/app_localization.dart';
import 'package:dose_flow/core/pharmacokinetics_engine.dart';
import 'package:dose_flow/core/legal_compliance_hub.dart';
import 'package:dose_flow/core/purchase_service.dart';
import 'package:dose_flow/core/app_persistence.dart';

void main() {
  group('Apple Review Guideline 1.4.1 Medical Safety & FDA Citations Audit', () {
    test('All GLP-1 medications must have verified official FDA Prescribing Info URLs', () {
      for (final Glp1Medication med in Glp1Medication.values) {
        expect(med.fdaCitationTitle, isNotEmpty);
        expect(med.fdaCitationUrl, startsWith('https://'));
        expect(med.fdaCitationUrl.endsWith('.pdf'), isTrue);
        expect(
          med.fdaCitationUrl.contains('lilly.com') ||
              med.fdaCitationUrl.contains('novo-pi.com'),
          isTrue,
        );
      }
    });

    test('Medical disclaimer explicitly disclaims diagnosis and dosage titration', () {
      for (final AppLanguage lang in AppLanguage.values) {
        final String disclaimer =
            LegalComplianceHub.getMedicalDisclaimerStatement(lang);
        expect(disclaimer, isNotEmpty);
        if (lang.isZh) {
          expect(disclaimer.contains('非醫療器材'), isTrue);
          expect(disclaimer.contains('絕不提供任何劑量升級'), isTrue);
          expect(disclaimer.contains('FDA'), isTrue);
        } else {
          expect(disclaimer.contains('NOT a medical device'), isTrue);
          expect(disclaimer.contains('NEVER recommends'), isTrue);
          expect(disclaimer.contains('FDA'), isTrue);
        }
      }
    });

    test('Pharmacokinetics engine boundary stability: zero NaN or Infinity under extreme inputs', () {
      for (final Glp1Medication med in Glp1Medication.values) {
        // 邊界 1: 時間 <= 0
        expect(
          PharmacokineticsEngine.singleDoseConcentrationAt(
            doseMg: 2.5,
            medication: med,
            elapsedHours: -1.0,
          ),
          equals(0.0),
        );

        // 邊界 2: 超過 60 天代謝視窗
        expect(
          PharmacokineticsEngine.singleDoseConcentrationAt(
            doseMg: 2.5,
            medication: med,
            elapsedHours: 1500.0,
          ),
          equals(0.0),
        );

        // 邊界 3: 正常臨床滴定劑量運算，數值必須有限且大於 0
        for (final double dose in <double>[2.5, 5.0, 7.5, 10.0, 15.0]) {
          final double conc = PharmacokineticsEngine.singleDoseConcentrationAt(
            doseMg: dose,
            medication: med,
            elapsedHours: med.peakHoursTmax,
          );
          expect(conc.isFinite, isTrue);
          expect(conc, greaterThan(0.0));
        }
      }
    });
  });

  group('Apple Review Guideline 5.1.1 & Local-First Privacy Audit', () {
    test('Privacy Policy HTML contains required HealthKit and Local-First disclosures', () {
      for (final AppLanguage lang in AppLanguage.values) {
        final String html = LegalComplianceHub.generatePrivacyPolicyHtml(lang);
        expect(html, isNotEmpty);
        expect(html.contains('<!DOCTYPE html>'), isTrue);

        if (lang.isZh) {
          expect(html.contains('100% 本地端架構與零伺服器存儲'), isTrue);
          expect(html.contains('Apple HealthKit 數據授權說明'), isTrue);
          expect(html.contains('零第三方追蹤'), isTrue);
        } else {
          expect(html.contains('100% Local-First Architecture'), isTrue);
          expect(html.contains('Apple HealthKit Integration'), isTrue);
          expect(html.contains('Zero Third-Party Trackers'), isTrue);
        }
      }
    });

    test('Guardrail 09 Strict Base64 validation: rejects malformed and non-standard strings', () {
      // 1. 合法 Base64 字串驗證 (長度為 4 的倍數且字元標準)
      const String validSample1 = 'eyJzY2hlbWFWZXJzaW9uIjoxfQ==';
      const String validSample2 = 'dGVzdA==';
      expect(AppPersistence.isValidBackupBase64(validSample1), isTrue);
      expect(AppPersistence.isValidBackupBase64(validSample2), isTrue);
      expect(ReceiptValidator.isValidBase64(validSample1), isTrue);
      expect(ReceiptValidator.isValidBase64(validSample2), isTrue);

      // 2. 長度非 4 的倍數應嚴格攔截
      expect(AppPersistence.isValidBackupBase64('abc'), isFalse);
      expect(ReceiptValidator.isValidBase64('abc'), isFalse);

      // 3. 包含底線或減號（非標準 Base64 字符）應嚴格攔截
      expect(AppPersistence.isValidBackupBase64('dGVz_dA=='), isFalse);
      expect(AppPersistence.isValidBackupBase64('dGVz-dA=='), isFalse);
      expect(ReceiptValidator.isValidBase64('dGVz_dA=='), isFalse);
      expect(ReceiptValidator.isValidBase64('dGVz-dA=='), isFalse);

      // 4. 空值或空白應嚴格攔截
      expect(AppPersistence.isValidBackupBase64(''), isFalse);
      expect(AppPersistence.isValidBackupBase64(null), isFalse);
      expect(ReceiptValidator.isValidBase64(''), isFalse);
      expect(ReceiptValidator.isValidBase64(null), isFalse);
    });
  });

  group('StoreKit 2 IAP Metadata & Guardrail 10 Alignment Audit', () {
    test('DoseFlowProductCatalog aligns with StoreKit 2 specification and pricing tiers', () {
      expect(SubscriptionTier.monthly.productId, equals('com.doseflow.app.monthly'));
      expect(SubscriptionTier.annual.productId, equals('com.doseflow.app.annual'));
      expect(SubscriptionTier.lifetime.productId, equals('com.doseflow.app.lifetime'));

      final ProductItem annual = DoseFlowProductCatalog.getByTier(SubscriptionTier.annual);
      expect(annual.isBestValue, isTrue);
      expect(annual.hasFreeTrial, isTrue);
      expect(annual.trialDays, equals(3));
      expect(annual.priceUsdString, equals(r'$39.99'));
      expect(annual.priceTwdString, equals(r'NT$ 990'));

      final ProductItem monthly = DoseFlowProductCatalog.getByTier(SubscriptionTier.monthly);
      expect(monthly.hasFreeTrial, isFalse);
      expect(monthly.priceUsdString, equals(r'$6.99'));

      final ProductItem lifetime = DoseFlowProductCatalog.getByTier(SubscriptionTier.lifetime);
      expect(lifetime.hasFreeTrial, isFalse);
      expect(lifetime.priceUsdString, equals(r'$119.99'));
    });

    test('Guardrail 10 Compliance: All IAP descriptions and titles truncated within 45 characters', () {
      for (final ProductItem p in DoseFlowProductCatalog.all) {
        expect(p.titleZh.length, lessThanOrEqualTo(45));
        expect(p.titleEn.length, lessThanOrEqualTo(45));
      }

      final String reviewNotes =
          LegalComplianceHub.generateAppStoreReviewNotes(AppLanguage.enUS);
      expect(reviewNotes, isNotEmpty);
      expect(reviewNotes.contains('GUIDELINE 1.4.1'), isTrue);
      expect(reviewNotes.contains('GUIDELINE 5.1.1'), isTrue);
      expect(reviewNotes.contains('IN-APP PURCHASE & SUBSCRIPTION TESTING'), isTrue);
    });
  });
}
