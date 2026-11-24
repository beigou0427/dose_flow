import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_localization.dart';
import 'app_theme.dart';

/// 法規合規文件類型枚舉
enum ComplianceDocType {
  privacyPolicy('Privacy Policy', '隱私權政策 (100% Local-First)'),
  termsOfService('Terms of Service', '使用者服務條款與醫療免責'),
  fdaCitations('FDA Prescribing Information', 'FDA 仿單藥代動力學文獻引用'),
  appStoreReviewNotes('App Review Notes', '給 Apple 審核員之專屬合規說明');

  const ComplianceDocType(this.titleEn, this.titleZh);
  final String titleEn;
  final String titleZh;

  String title(AppLanguage lang) => lang.isZh ? titleZh : titleEn;
}

/// 法規文件資料載體
@immutable
class ComplianceDoc {
  const ComplianceDoc({
    required this.type,
    required this.title,
    required this.contentPlainText,
  });

  final ComplianceDocType type;
  final String title;
  final String contentPlainText;
}

/// 醫療法規與隱私權合規中樞（符合 Apple Review Guideline 1.4.1 & 5.1.1）
class LegalComplianceHub {
  const LegalComplianceHub._();

  /// 官方 FDA 仿單 Section 12.3 藥代動力學原文數據庫
  static const String fdaTirzepatideDetails = '''
[DRUG]: Tirzepatide (Mounjaro® / Zepbound® - Eli Lilly and Company)
[FDA SECTION]: Section 12.3 Clinical Pharmacology - Pharmacokinetics
[CITATION]:
• Half-Life: Mean terminal half-life of tirzepatide is approximately 5 days (120 hours).
• Absorption: Absolute bioavailability is approximately 80%. Tmax occurs between 8 to 72 hours (median ~36 hours) post-dose.
• Steady State: Accumulation occurs with once-weekly administration; steady-state plasma concentrations are achieved following 4 weeks of once-weekly administration.
• Elimination: Apparent population clearance is ~0.061 L/h. Primary elimination is via metabolism and urine/feces excretion.
• Official FDA Prescribing Information Link: https://pi.lilly.com/us/mounjaro-uspi.pdf
''';

  static const String fdaSemaglutideDetails = '''
[DRUG]: Semaglutide (Wegovy® / Ozempic® - Novo Nordisk)
[FDA SECTION]: Section 12.3 Clinical Pharmacology - Pharmacokinetics
[CITATION]:
• Half-Life: The elimination half-life of semaglutide is approximately 1 week (168 hours).
• Absorption: Absolute bioavailability is ~89%. Maximum concentration is reached 1 to 3 days post-dose (median ~48 hours).
• Steady State: Steady-state exposure is achieved following 4 to 5 weeks of once-weekly subcutaneous administration.
• Elimination: Clearance of semaglutide in patients with type 2 diabetes or obesity is approximately 0.05 L/h.
• Official FDA Prescribing Information Link: https://www.novo-pi.com/ozempic.pdf
''';

  static const String fdaLiraglutideDetails = '''
[DRUG]: Liraglutide (Saxenda® Daily Injection - Novo Nordisk)
[FDA SECTION]: Section 12.3 Clinical Pharmacology - Pharmacokinetics
[CITATION]:
• Half-Life: The elimination half-life of liraglutide is approximately 13 hours.
• Absorption: Maximum concentrations of liraglutide are achieved approximately 11 hours post-dose.
• Administration: Daily subcutaneous administration is required due to rapid elimination compared to long-acting GLP-1s.
• Official FDA Prescribing Information Link: https://www.novo-pi.com/saxenda.pdf
''';

  /// 醫療免責聲明標準條文（遵循 Guideline 1.4.1 嚴格防禦盾）
  static String getMedicalDisclaimerStatement(AppLanguage lang) {
    if (lang.isZh) {
      return '【醫療免責聲明與法律聲明】\n'
          '1. 本應用程式（DoseFlow / 瘦瘦針紀錄 Pro）僅供個人日常健康日誌記錄與一般衛生教育參考，非醫療器材，亦不提供任何醫療診斷、處方調劑或個別化醫療處方建議。\n'
          '2. 本程式所展示之所有體內藥物濃度曲線、吸收峰值與半衰期衰退時間線，均係基於公開之官方藥品仿單（FDA Prescribing Information - Section 12.3 Pharmacokinetics）理論半衰期常數所進行之雙指數數學推估（Bateman Function），不代表且不能替代實際臨床血液生化或質譜檢測數值。\n'
          '3. 本程式嚴格禁止且絕不提供任何劑量升級、減量或調劑建議。任何藥物使用、劑量變更、注射部位異常硬塊或嚴重副作用處理，請務必諮詢您的處方主治醫師或合格執業藥師。';
    } else {
      return '[MEDICAL DISCLAIMER & REGULATORY NOTICE]\n'
          '1. DoseFlow is an independent health logging and reference tool designed solely for personal tracking and general educational purposes. It is NOT a medical device and does NOT provide medical advice, diagnosis, or prescription treatment plans.\n'
          '2. All active medication concentration curves, absorption peaks (Tmax), and half-life decay trajectories visualized within this application are theoretical mathematical estimations (Bateman Function) calibrated against published FDA Prescribing Information (Section 12.3 Pharmacokinetics). They do NOT reflect actual therapeutic drug monitoring (TDM) or individual blood plasma laboratory measurements.\n'
          '3. This application NEVER recommends or guides medication titration. Always consult your prescribing physician, endocrinologist, or licensed healthcare provider prior to adjusting any dosage, compounding ratio, or injection schedule.';
    }
  }

  /// 產生美台雙語獨立 privacy_policy.html 原始碼（可直接託管於 GitHub Pages / Vercel）
  static String generatePrivacyPolicyHtml(AppLanguage lang) {
    final bool isZh = lang.isZh;
    final String pageTitle = isZh
        ? '瘦瘦針紀錄 Pro - 醫療數據隱私權政策 (100% Local-First)'
        : 'DoseFlow - Privacy Policy (100% Local-First)';

    return '''<!DOCTYPE html>
<html lang="${lang.code}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$pageTitle</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; color: #0f172a; max-width: 740px; margin: 0 auto; padding: 32px 20px; background: #f8fafc; }
    .card { background: #ffffff; padding: 32px; border-radius: 16px; border: 1px solid #e2e8f0; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
    h1 { font-size: 24px; color: #0284c7; margin-top: 0; }
    h2 { font-size: 17px; margin-top: 24px; color: #0f172a; border-left: 4px solid #0ea5e9; padding-left: 10px; }
    p, li { font-size: 14px; color: #334155; }
    .badge { display: inline-block; background: #e0f2fe; color: #0369a1; padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: 700; }
    .footer { margin-top: 32px; font-size: 12px; color: #94a3b8; text-align: center; }
  </style>
</head>
<body>
  <div class="card">
    <span class="badge">Apple App Store Guideline 5.1.1 Compliant</span>
    <h1>$pageTitle</h1>
    <p><em>${isZh ? "生效日期：2026 年 11 月 1 日" : "Effective Date: November 1, 2026"}</em></p>
    
    <h2>${isZh ? "1. 100% 本地端架構與零伺服器存儲" : "1. 100% Local-First Architecture"}</h2>
    <p>${isZh ? "DoseFlow（瘦瘦針紀錄 Pro）堅守最高隱私標準。我們不架設任何外部使用者資料庫，您的體重、施打劑量、部位輪替日誌與微習慣進度，100% 僅保存在您的本機設備與私密 Apple iCloud 中，開發者無法且永遠不會存取您的健康數據。" : "DoseFlow is built on a 100% local-first architecture. We operate zero cloud backend databases. All your health metrics, weight logs, injection records, and micro-habits remain exclusively on your device and private Apple iCloud."}</p>

    <h2>${isZh ? "2. Apple HealthKit 數據授權說明" : "2. Apple HealthKit Integration"}</h2>
    <p>${isZh ? "若您同意授權，本應用程式僅會讀取並同步您的體重（Body Mass）、每日飲水量（Dietary Water）與蛋白質（Dietary Protein），以繪製減重代謝趨勢圖。我們絕不將 HealthKit 資訊用於廣告促銷或第三方數據經紀商（Data Brokers）。" : "With your permission, DoseFlow reads and writes Body Mass, Dietary Water, and Dietary Protein to chart your weight trajectory. In accordance with Apple Developer Guidelines, HealthKit data is never shared with data brokers or used for targeted advertising."}</p>

    <h2>${isZh ? "3. 零第三方追蹤與去中心化備份" : "3. Zero Third-Party Trackers & Offline Backups"}</h2>
    <p>${isZh ? "本程式不包含任何第三方行銷追蹤 SDK。您隨時可使用內建的 Base64 密碼學匯出功能，自行保存本機資料備份，並隨時於 App 內一鍵抹除所有紀錄。" : "DoseFlow contains zero third-party advertising or analytics SDKs. You retain full data ownership and can export your tamper-proof Base64 backup or delete all records with a single tap."}</p>

    <h2>${isZh ? "4. 聯絡與支援" : "4. Contact Information"}</h2>
    <p>${isZh ? "若對本隱私政策有任何疑問，歡迎聯絡官方支援信箱：support@doseflow.app" : "If you have questions regarding this Privacy Policy, please contact our privacy compliance team at: support@doseflow.app"}</p>
  </div>
  <div class="footer">© 2026 DoseFlow Inc. All rights reserved.</div>
</body>
</html>''';
  }

  /// 產生美台雙語使用者服務條款與醫療免責網頁 terms_of_service.html
  static String generateTermsOfServiceHtml(AppLanguage lang) {
    final bool isZh = lang.isZh;
    final String title = isZh
        ? '瘦瘦針紀錄 Pro - 使用者服務條款與醫療免責'
        : 'DoseFlow - Terms of Service & Medical Disclaimer';

    return '''<!DOCTYPE html>
<html lang="${lang.code}">
<head>
  <meta charset="UTF-8">
  <title>$title</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; color: #0f172a; max-width: 740px; margin: 0 auto; padding: 32px 20px; background: #f8fafc; }
    .card { background: #ffffff; padding: 32px; border-radius: 16px; border: 1px solid #e2e8f0; }
    h1 { font-size: 22px; color: #0f172a; }
    h2 { font-size: 16px; color: #dc2626; margin-top: 20px; }
    p { font-size: 13.5px; color: #334155; }
  </style>
</head>
<body>
  <div class="card">
    <h1>$title</h1>
    <h2>${isZh ? "醫療免責重要通知 (Guideline 1.4.1)" : "Medical Disclaimer Notice (Guideline 1.4.1)"}</h2>
    <p>${isZh ? "本程式僅為個人數據日誌，非醫療器材。所有體內藥物濃度推估皆基於 FDA 仿單半衰期數學模型，不代表血液生化實測。本程式絕不主動建議調整劑量，任何療程變更請務必諮詢處方醫師。" : "DoseFlow is a personal health logger, not a medical device. All pharmacokinetic curves are theoretical estimates derived from FDA prescribing information. DoseFlow never recommends dose titration. Always consult your physician."}</p>
    <h2>${isZh ? "訂閱與自動續訂條款" : "Subscription & Billing Terms"}</h2>
    <p>${isZh ? "年度訂閱方案提供 3 天免費試用。試用期結束後將由您的 Apple ID 自動續約計費，您可隨時於 App Store 帳號設定中取消。" : "Annual subscriptions include a 3-day free trial. Billed to your Apple ID upon trial conclusion. Cancel anytime in App Store settings."}</p>
  </div>
</body>
</html>''';
  }

  /// 產生給 App 內使用者閱讀的純文字隱私權政策（非原始 HTML）
  static String generatePrivacyPolicyPlainText(AppLanguage lang) {
    if (lang.isZh) {
      return '''瘦瘦針紀錄 Pro (DoseFlow) 隱私權政策
生效日期：2026 年 11 月 1 日

1. 100% 本地端架構與零外部伺服器
本應用程式堅守最高隱私標準，不架設任何外部使用者資料庫，也不需註冊帳號。您的施打日誌、體重紀錄、微習慣進度與偏好設定皆儲存在您的個人裝置本機中；您可選擇自行使用 Base64 本機備份或個人 Apple iCloud 進行備份。開發者無法且永遠不會存取您的健康數據。

2. 零廣告追蹤與第三方 SDK
本程式不包含任何第三方廣告追蹤或數據分析 SDK，絕不向任何第三方或數據經紀商出售或分享您的個人健康紀錄。

3. 資料控制權與刪除
您擁有完整資料主權，可隨時透過本機備份匯出個人紀錄，或直接刪除 App 以移除裝置上所有本地資料。

4. 聯絡與支援
線上隱私權政策：https://beigou0427.github.io/dose_flow/privacy.html
支援信箱：support@doseflow.app''';
    }
    return '''DoseFlow Privacy Policy
Effective Date: November 1, 2026

1. 100% Local-First Architecture (Zero Cloud Servers)
DoseFlow requires no account registration and operates zero external servers. All injection logs, weight entries, micro-habits, and settings remain exclusively on your personal device (with optional local Base64 backup or private Apple iCloud backup). The developer cannot access your personal health data.

2. Zero Ad Trackers or Third-Party Brokers
DoseFlow includes zero advertising or third-party tracking SDKs and never sells or shares your health records.

3. Data Ownership & Deletion
You retain full ownership of your logs and may export them locally or remove all on-device data at any time by uninstalling the app.

4. Contact & Online Policy
Privacy Policy URL: https://beigou0427.github.io/dose_flow/privacy.html
Support: support@doseflow.app''';
  }

  /// 產生給 App 內使用者閱讀的純文字服務條款、訂閱規範與商標免責
  static String generateTermsOfServicePlainText(AppLanguage lang) {
    if (lang.isZh) {
      return '''瘦瘦針紀錄 Pro (DoseFlow) 服務條款與醫療免責

1. 醫療免責聲明（非醫療器材、無劑量計算功能）
本程式僅供個人健康數據記錄與一般教育參考，非醫療器材，不包含任何藥物劑量計算功能，亦不提供醫療診斷或劑量調整建議。所有理論濃度曲線均依據公開 FDA 仿單（Section 12.3 Pharmacokinetics）半衰期參數以 Bateman 雙指數模型推估，不代表實際血液檢測濃度。任何用藥或劑量變更請務必諮詢您的處方醫師或藥師。

2. 訂閱與自動續訂條款
• 本程式提供月繳、年繳（含 3 天免費試用）與終身買斷方案；實際價格依 App Store 結帳畫面顯示為準。
• 確認購買時費用將由您的 Apple ID 帳號扣款。
• 自動續訂訂閱將於當期或試用期結束前 24 小時自動續訂，您可隨時於 iPhone「設定」> Apple ID >「訂閱項目」中管理或取消。

3. 商標聲明
本程式內提及之藥品名稱與註冊商標（如 Mounjaro、Zepbound、Wegovy、Ozempic、Saxenda 等）均屬原藥廠所有，僅供使用者標記個人處方紀錄之用。本程式為獨立開發工具，與上述任何藥廠均無從屬、合作或授權關係。

4. 標準授權合約 (Apple EULA)
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/''';
    }
    return '''DoseFlow Terms of Use & Medical Disclaimer

1. Medical Disclaimer (Not a Medical Device / No Dosage Calculator)
DoseFlow is intended solely for personal health logging and general educational reference. It is NOT a medical device, contains NO drug dosage calculator, and never provides medical advice, diagnosis, or titration recommendations. All concentration curves are theoretical mathematical visualizations (Bateman Function) based on published FDA Prescribing Information (Section 12.3 Pharmacokinetics) and do not represent actual blood measurements. Always consult your prescribing physician or pharmacist.

2. Subscriptions & Auto-Renewal
• Monthly, Annual (with 3-day free trial), and Lifetime options are available. Exact pricing is displayed in the App Store purchase sheet.
• Payment is charged to your Apple ID account at confirmation of purchase.
• Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period in iOS Settings > Apple ID > Subscriptions.

3. Trademark Notice
All medication brand names and trademarks (including Mounjaro, Zepbound, Wegovy, Ozempic, and Saxenda) are the property of their respective owners and are used solely for personal user logging identification. DoseFlow is an independent app not affiliated with or endorsed by any pharmaceutical manufacturer.

4. Standard Apple EULA
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/''';
  }

  /// 產生給 Apple App Store 審核員的專屬備註（直接貼入 App Store Connect Review Notes）
  static String generateAppStoreReviewNotes(AppLanguage lang) {
    return '''
================================================================================
APP STORE REVIEW NOTES (GUIDELINE 1.4.1 & GUIDELINE 5.1.1 COMPLIANCE)
================================================================================
Dear Apple App Review Team,

Thank you for reviewing DoseFlow! Please note the following regulatory assurances:

1. COMPLIANCE WITH GUIDELINE 1.4.1 & 1.4.2 (MEDICAL SAFETY — NO DOSAGE CALCULATOR):
• DoseFlow is strictly a personal health journal, injection site rotation log, and daily habit tracker for users following a physician-prescribed routine.
• The app contains ZERO drug dosage calculators, syringe unit converters, or reconstitution math tools. Users only record the dose already prescribed by their physician.
• The optional concentration trend visualization uses a theoretical Bateman exponential reference curve derived from published FDA Prescribing Information Section 12.3 (Pharmacokinetics) half-life literature, clearly marked as an educational reference only:
  - Eli Lilly Mounjaro/Zepbound (Tirzepatide): USPI Section 12.3 (Mean half-life ~5 days).
  - Novo Nordisk Wegovy/Ozempic (Semaglutide): USPI Section 12.3 (Half-life ~1 week).
• The app NEVER calculates medical dosages or recommends dose adjustments. Prominent medical citations and disclaimers are anchored permanently on screen.

2. COMPLIANCE WITH GUIDELINE 5.1.1 (DATA PRIVACY & LOCAL-FIRST):
• DoseFlow requires ZERO user registration and operates ZERO external servers.
• All health and injection records are stored 100% locally on the user's device and private iCloud.
• HealthKit data (Body Mass, Dietary Water, Protein) is strictly used for in-app personal charting and never transmitted externally.

3. IN-APP PURCHASE & SUBSCRIPTION TESTING (GUIDELINE 2.1(b) — STOREKIT 2):
• Tier 1: Monthly (com.doseflow.app.monthly)
• Tier 2: Annual with 3-Day Free Trial (com.doseflow.app.annual)
• Tier 3: Lifetime (com.doseflow.app.lifetime)
• Pro features remain locked by default until a verified StoreKit 2 purchase or Restore Purchases transaction succeeds. All "Unlock Pro" CTAs open the native StoreKit 2 paywall modal.

Contact: support@doseflow.app
================================================================================
''';
  }
}

/// App 內互動式法規與提審合規檢視對話框
class LegalComplianceViewerDialog extends StatefulWidget {
  const LegalComplianceViewerDialog({
    super.key,
    this.initialDocType = ComplianceDocType.privacyPolicy,
  });

  final ComplianceDocType initialDocType;

  /// 一鍵將 HTML 檔案實體寫入本機專案目錄（供即時部屬至 GitHub Pages）
  static Future<String?> exportHtmlFilesToDisk(AppLanguage lang) async {
    if (kIsWeb) return null;
    try {
      final String privacyHtml =
          LegalComplianceHub.generatePrivacyPolicyHtml(lang);
      final String termsHtml =
          LegalComplianceHub.generateTermsOfServiceHtml(lang);

      final File privacyFile = File('privacy_policy.html');
      final File termsFile = File('terms_of_service.html');

      await privacyFile.writeAsString(privacyHtml, flush: true);
      await termsFile.writeAsString(termsHtml, flush: true);

      return privacyFile.path;
    } catch (_) {
      return null;
    }
  }

  @override
  State<LegalComplianceViewerDialog> createState() =>
      _LegalComplianceViewerDialogState();
}

class _LegalComplianceViewerDialogState
    extends State<LegalComplianceViewerDialog> {
  static const List<ComplianceDocType> _userVisibleDocTypes =
      <ComplianceDocType>[
    ComplianceDocType.privacyPolicy,
    ComplianceDocType.termsOfService,
    ComplianceDocType.fdaCitations,
  ];

  late ComplianceDocType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = _userVisibleDocTypes.contains(widget.initialDocType)
        ? widget.initialDocType
        : ComplianceDocType.privacyPolicy;
  }

  String _getDocumentBody(AppLanguage lang) {
    switch (_selectedType) {
      case ComplianceDocType.privacyPolicy:
        return LegalComplianceHub.generatePrivacyPolicyPlainText(lang);
      case ComplianceDocType.termsOfService:
        return LegalComplianceHub.generateTermsOfServicePlainText(lang);
      case ComplianceDocType.fdaCitations:
        return '${LegalComplianceHub.getMedicalDisclaimerStatement(lang)}\n\n'
            '${LegalComplianceHub.fdaTirzepatideDetails}\n'
            '${LegalComplianceHub.fdaSemaglutideDetails}\n'
            '${LegalComplianceHub.fdaLiraglutideDetails}';
      case ComplianceDocType.appStoreReviewNotes:
        return LegalComplianceHub.generateTermsOfServicePlainText(lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;
    final String contentText = _getDocumentBody(lang);

    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.gavel_rounded, color: DoseFlowColors.mint, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isZh ? '隱私權、服務條款與醫療文獻' : 'Privacy, Terms & Medical Citations',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DoseFlowColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 440,
        child: Column(
          children: <Widget>[
            // 頂部文件類型切換標籤（僅顯示使用者法規文件）
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _userVisibleDocTypes.map((ComplianceDocType type) {
                  final bool isSelected = type == _selectedType;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(
                        type.title(lang),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedType = type),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // 高對比深色可讀純文字區
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DoseFlowColors.cardElevated,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: DoseFlowColors.cardBorder),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    contentText,
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: DoseFlowColors.textPrimary,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: contentText));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isZh ? '📋 已複製內容至剪貼簿！' : '📋 Copied text to clipboard!',
                ),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(isZh ? '複製條文' : 'Copy Text'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isZh ? '關閉' : 'Close'),
        ),
      ],
    );
  }
}
