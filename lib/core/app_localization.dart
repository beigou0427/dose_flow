import 'package:flutter/material.dart';

/// 支援的美台雙語市場列舉
enum AppLanguage {
  zhTW(
    code: 'zh-TW',
    shortLabel: '繁中',
    fullLabel: '繁體中文 (台灣)',
    flagEmoji: '🇹🇼',
  ),
  enUS(
    code: 'en-US',
    shortLabel: 'EN',
    fullLabel: 'English (US)',
    flagEmoji: '🇺🇸',
  );

  const AppLanguage({
    required this.code,
    required this.shortLabel,
    required this.fullLabel,
    required this.flagEmoji,
  });

  final String code;
  final String shortLabel;
  final String fullLabel;
  final String flagEmoji;

  bool get isZh => this == AppLanguage.zhTW;
  bool get isEn => this == AppLanguage.enUS;
}

/// 體重單位 (台灣預設 kg，美國預設 lbs)
enum WeightUnit {
  kg('kg'),
  lbs('lbs');

  const WeightUnit(this.symbol);
  final String symbol;
}

/// 飲水量單位 (台灣預設 ml，美國預設 oz)
enum WaterUnit {
  ml('ml'),
  oz('oz');

  const WaterUnit(this.symbol);
  final String symbol;
}

/// 全域中英雙語與美台市場狀態控制器
class LocaleController extends ChangeNotifier {
  LocaleController({
    AppLanguage initialLanguage = AppLanguage.zhTW,
  })  : _language = initialLanguage,
        _weightUnit =
            initialLanguage.isZh ? WeightUnit.kg : WeightUnit.lbs,
        _waterUnit =
            initialLanguage.isZh ? WaterUnit.ml : WaterUnit.oz;

  AppLanguage _language;
  WeightUnit _weightUnit;
  WaterUnit _waterUnit;

  AppLanguage get language => _language;
  WeightUnit get weightUnit => _weightUnit;
  WaterUnit get waterUnit => _waterUnit;
  bool get isZh => _language.isZh;

  /// 一鍵切換中英文（並智慧連動美台預設度量衡單位）
  void toggleLanguage() {
    setLanguage(_language.isZh ? AppLanguage.enUS : AppLanguage.zhTW);
  }

  /// 指定目標語系
  void setLanguage(AppLanguage newLanguage, {bool syncUnits = true}) {
    if (_language == newLanguage) return;
    _language = newLanguage;
    if (syncUnits) {
      _weightUnit = newLanguage.isZh ? WeightUnit.kg : WeightUnit.lbs;
      _waterUnit = newLanguage.isZh ? WaterUnit.ml : WaterUnit.oz;
    }
    notifyListeners();
  }

  /// 手動切換體重單位 (kg <-> lbs)
  void setWeightUnit(WeightUnit unit) {
    if (_weightUnit == unit) return;
    _weightUnit = unit;
    notifyListeners();
  }

  /// 手動切換飲水單位 (ml <-> oz)
  void setWaterUnit(WaterUnit unit) {
    if (_waterUnit == unit) return;
    _waterUnit = unit;
    notifyListeners();
  }

  /// 根據當前語系回傳對應字串
  String tr(String zhText, String enText) {
    return _language.isZh ? zhText : enText;
  }
}

/// 強型別雙語詞庫 (支援台灣「瘦瘦針紀錄 Pro」與美國「DoseFlow」雙市場定位)
class AppStrings {
  const AppStrings(this.lang);
  final AppLanguage lang;

  bool get _zh => lang.isZh;

  // --- 品牌與導覽列 (4 Tabs) ---
  String get appTitle => _zh ? '瘦瘦針紀錄 Pro' : 'DoseFlow: GLP-1 Tracker';
  String get appSubtitle => _zh
      ? 'GLP-1 代謝曲線 ＆ 防掉肌微習慣'
      : 'Pharmacokinetics & Peptide Log';

  String get tabDashboard => _zh ? '今日儀表板' : 'Dashboard';
  String get tabShotLog => _zh ? '施打與換算' : 'Shot & Calc';
  String get tabAnalytics => _zh ? '劑量與體重' : 'Analytics';
  String get tabSettings => _zh ? '小工具與設定' : 'Widgets & Pro';

  // --- Tab 1: 首頁今日儀表板 (HomeDashboardView) ---
  String get nextShotCountdownTitle =>
      _zh ? '距離下次施打還有' : 'Next Injection In';
  String formatDaysHours(int days, int hours) => _zh
      ? '$days 天 $hours 小時'
      : '${days}d ${hours}h';

  String get recommendedNextSiteLabel =>
      _zh ? '建議下次部位（防硬塊輪替）' : 'Recommended Next Site';

  String get pkChartCardTitle => _zh
      ? '體內藥物濃度即時曲線 (Bateman 模型)'
      : 'Live Medication Level (Bateman Model)';
  String get pkChartCardSubtitle => _zh
      ? '過去 14 天累積代謝 ＋ 未來 7 天半衰期預測'
      : 'Past 14d Accumulation + Next 7d Half-Life Forecast';

  String formatCurrentConcentration(double mg) => _zh
      ? '目前預估體內殘留：${mg.toStringAsFixed(2)} mg — 處於食慾穩定抑制區間'
      : 'Estimated Active Level: ${mg.toStringAsFixed(2)} mg — Optimal Suppression Zone';

  String get nowMarkerLabel => _zh ? '現在 (Now)' : 'NOW';
  String get pastSolidLegend => _zh ? '歷史累積濃度' : 'Active History';
  String get futureDashedLegend => _zh ? '未來 7 天預測' : '7-Day Forecast';

  // --- 免費用戶高斯模糊鎖頭 (Pro Paywall Gate) ---
  String get proBlurLockTitle => _zh
      ? '已根據您的施打紀錄算出今日體內殘留濃度'
      : 'Your Real-Time GLP-1 Concentration is Ready';
  String get proBlurLockDesc => _zh
      ? '升級 Pro 立即解鎖即時雙指數代謝曲線、波峰預警與未來 7 天殘留預測'
      : 'Upgrade to Pro to unlock live pharmacokinetic curves, peak alerts & 7-day decay forecast.';
  String get unlockProButton =>
      _zh ? '立即解鎖 Pro 代謝曲線' : 'Unlock Pro Curve Now';

  // --- 防掉肌微習慣三環 (Daily Micro-Habits) ---
  String get microHabitsSectionTitle => _zh
      ? '防掉肌與防便祕微習慣三環 (免費開放)'
      : 'Anti-Muscle Loss & Gut Micro-Habits';
  String get proteinRingTitle => _zh ? '每日蛋白質目標' : 'Daily Protein Goal';
  String get proteinQuickAdd20 =>
      _zh ? '+20g (蛋/豆漿)' : '+20g (Eggs/Soy)';
  String get proteinQuickAdd30 =>
      _zh ? '+30g (雞胸/乳清)' : '+30g (Chicken/Whey)';

  String get waterRingTitle => _zh ? '每日飲水代謝目標' : 'Hydration Goal';
  String get waterQuickAdd250 => _zh ? '+250ml' : '+8 oz (250ml)';
  String get waterQuickAdd500 => _zh ? '+500ml' : '+16 oz (500ml)';

  String get bowelCardTitle =>
      _zh ? '腸道順暢打卡' : 'Bowel Movement Check';
  String get bowelCompletedText =>
      _zh ? '今日已順暢排便 ✓' : 'Smooth Bowel Movement Today ✓';
  String get bowelPendingText =>
      _zh ? '點擊記錄今日排便（預防瘦瘦針便祕）' : 'Tap to log bowel movement (Constipation check)';

  // --- 變現定價錨點 (Monetization & Pricing) ---
  String get paywallHeadline => _zh
      ? '解鎖專屬 GLP-1 代謝曲線與防掉肌計畫'
      : 'Unlock Your Personal GLP-1 PK Curve & Pro Tools';
  String get priceMonthlyLabel =>
      _zh ? '月訂閱：NT\$ 150 / 月' : r'Monthly: $6.99 / mo';
  String get priceAnnualLabel => _zh
      ? '年訂閱（主推）：NT\$ 990 / 年（含 3 天免費試用，省下 45%）'
      : r'Annual (Best Value): $39.99 / yr (3-Day Free Trial, Save 45%)';
  String get priceLifetimeLabel =>
      _zh ? '終身買斷：NT\$ 1,990（一次付費永久解鎖）' : r'Lifetime Unlock: $79.99 (One-time purchase)';

  // --- Tab 2: 施打日誌與複合針筒計算機 (ShotLog & Syringe Calculator) ---
  String get syringeCalcTitle => _zh
      ? '針筒單位與複合藥劑換算器 (U-100)'
      : 'Syringe Units & Peptide Calculator (U-100)';
  String get syringeCalcSubtitle => _zh
      ? '輸入藥瓶濃度或乾粉泡製比例，自動畫出 100 Units 胰島素針筒抽取格數'
      : 'Convert vial concentration or reconstituted peptide into exact U-100 insulin syringe units.';

  String get calcModePremixed =>
      _zh ? '現成藥液 (mg/mL)' : 'Pre-mixed Vial (mg/mL)';
  String get calcModeReconstitution =>
      _zh ? '乾粉泡製 (乾粉 mg + 抑菌水 mL)' : 'Reconstitution (Vial mg + BAC Water mL)';

  String get inputVialMassLabel =>
      _zh ? '藥瓶乾粉總量 (mg)' : 'Peptide Vial Mass (mg)';
  String get inputBacteriostaticWaterLabel =>
      _zh ? '加入抑菌水量 (mL)' : 'Bacteriostatic Water Added (mL)';
  String get inputConcentrationLabel =>
      _zh ? '藥瓶標示濃度 (mg/mL)' : 'Vial Concentration (mg/mL)';
  String get inputTargetDoseLabel =>
      _zh ? '預計施打劑量 (mg)' : 'Desired Dose to Inject (mg)';

  String formatSyringeInstruction(double units, double volumeMl) => _zh
      ? '請抽取至第 ${units.toStringAsFixed(1)} 格 (${units.toStringAsFixed(1)} Units / ${volumeMl.toStringAsFixed(2)} mL)'
      : 'Draw to ${units.toStringAsFixed(1)} Units (${volumeMl.toStringAsFixed(2)} mL mark on U-100 syringe)';

  String get syringeOverCapacityWarning => _zh
      ? '⚠️ 警告：所需體積超過單支 100 Units (1.0 mL) 針筒上限！請重新確認藥瓶濃度或諮詢處方醫師，切勿盲目抽取。'
      : '⚠️ Warning: Required volume exceeds a standard 100-Unit (1.0 mL) syringe! Verify vial concentration or consult your prescriber.';

  String get syringeInvalidInputWarning => _zh
      ? '⚠️ 請輸入大於 0 的有效數值（嚴禁除以零或負數劑量）。'
      : '⚠️ Please enter valid positive numbers greater than zero.';

  // --- Tab 3: 體重與劑量染色分析 (Analytics & Export) ---
  String get analyticsChartTitle => _zh
      ? '劑量染色體重趨勢圖 (Dose-Colored Weight)'
      : 'Dose-Colored Weight Trajectory';
  String get sideEffectCorrelationTitle => _zh
      ? '施打後第 1～7 天副作用與食慾抑制分析'
      : 'Post-Shot Day 1–7 Side Effects & Food Noise';
  String get exportDoctorPdfButton => _zh
      ? '匯出回診一頁式醫療報表 (PDF / CSV)'
      : 'Export Physician Visit Summary (PDF / CSV)';

  // --- Apple App Review Guideline 1.4.1 強制醫療免責聲明與 FDA 引用 ---
  String get medicalDisclaimerButtonLabel => _zh
      ? 'ⓘ 醫療資料來源與免責聲明 (FDA 仿單引用)'
      : 'ⓘ Medical Citations & Disclaimer (FDA Prescribing Info)';

  String get medicalDisclaimerTitle => _zh
      ? '醫療免責聲明與藥代動力學文獻引用'
      : 'Medical Disclaimer & Pharmacokinetic Citations';

  String get medicalDisclaimerBody => _zh
      ? '本應用程式（瘦瘦針紀錄 Pro / DoseFlow）僅作為個人健康數據日誌與一般教育資訊參考。所有體內藥物濃度曲線皆為基於公開 FDA 藥品仿單（Section 12.3 Pharmacokinetics）半衰期參數之雙指數理論數學推估（Bateman Function），不代表實際血液檢測濃度。本程式絕不主動推薦或指導任何劑量調整；任何施打劑量變更、針筒抽取確認或副作用處理，請務必諮詢您的處方醫師或專業藥師。'
      : 'DoseFlow is intended solely for personal health logging and educational reference. All medication concentration curves are theoretical mathematical estimates (Bateman Function) derived from published FDA Prescribing Information (Section 12.3 Pharmacokinetics) half-life parameters and do NOT represent actual blood plasma measurements. This app never recommends dose changes. Always consult your prescribing physician or licensed pharmacist before adjusting your dose or drawing medication.';

  String get fdaCitationTirzepatide =>
      '1. Eli Lilly Mounjaro/Zepbound (Tirzepatide) USPI Section 12.3: Mean half-life ~5 days (120 hours), Tmax 8–72 hours.';
  String get fdaCitationSemaglutide =>
      '2. Novo Nordisk Ozempic/Wegovy (Semaglutide) USPI Section 12.3: Elimination half-life ~1 week (168 hours), Tmax 1–3 days.';
  String get fdaCitationLiraglutide =>
      '3. Novo Nordisk Saxenda (Liraglutide) USPI Section 12.3: Elimination half-life ~13 hours, Tmax ~11 hours.';

  String get healthKitUsageDescription => _zh
      ? '用於同步您的體重變化、每日飲水量與蛋白質攝取紀錄，以繪製您的個人減重趨勢圖表，所有健康資料 100% 僅儲存於您的設備與私人 iCloud 中。'
      : 'Used to sync your weight, daily water intake, and dietary protein with Apple Health to chart your weight-loss progress. All data stays 100% private on your device and personal iCloud.';

  // --- 美台雙語 App Store 商店頁完整文案與 5 張截圖標題 (ASO Store Kit) ---
  String get asoSectionHeader => _zh
      ? 'App Store 美台雙語商店頁文案與截圖標題'
      : 'US & Taiwan App Store ASO Copy & Screenshot Headlines';

  String get asoAppName => _zh
      ? '瘦瘦針紀錄 Pro - 猛健樂/週纖達代謝曲線與微習慣'
      : 'DoseFlow: GLP-1 & Shot Tracker';

  String get asoSubtitle => _zh
      ? '即時體內殘留濃度、部位輪替與防掉肌蛋白質追蹤'
      : 'Peptide Calculator, PK Levels & Weight Log';

  List<String> get asoScreenshotHeadlines => _zh
      ? const <String>[
          '圖 1：即時體內藥物濃度曲線 — 掌握每一針半衰期與未來 7 天殘留預測',
          '圖 2：劑量染色體重折線圖 — 一眼看懂 2.5mg 升 5mg 後的減重斜率變化',
          '圖 3：防掉肌蛋白質＆飲水三環 — 瘦身不瘦肌，一鍵打卡預防打針便祕',
          '圖 4：人體部位輪替熱力圖 — 自動避開上次部位，告別肚皮硬塊與瘀青',
          '圖 5：U-100 針筒單位換算器 — 輸入濃度即刻繪出精準抽取格數與回診報表',
        ]
      : const <String>[
          'Shot 1: Live GLP-1 Concentration Curve — Track Half-Life & 7-Day Decay Forecast',
          'Shot 2: Peptides & U-100 Syringe Calculator — Exact Units for Compounded Vials',
          'Shot 3: Dose-Colored Weight Chart — Visualize How Each Titration Drives Progress',
          'Shot 4: Anti-Muscle Loss Habit Rings — Hit Daily Protein, Hydration & Gut Goals',
          'Shot 5: Smart Injection Site Rotation — Prevent Bruising & Export Doctor PDF',
        ];

  String get asoFullDescription => _zh
      ? '正在施打猛健樂 (Mounjaro)、週纖達 (Wegovy) 或善纖達 (Ozempic/Saxenda) 嗎？\n'
          '【瘦瘦針紀錄 Pro】是專為 GLP-1 減重療程打造的 100% 私密本地端健康管家：\n'
          '• 雙指數藥物動力學引擎：採用 Bateman Function 真實模擬打針後前 36-48 小時吸收爬升段與半衰期指數衰減，支援 60 天多劑疊加計算。\n'
          '• 防硬塊部位自動輪替：腹部四象限、大腿、上臂視覺化紀錄，自動推薦下次施打點。\n'
          '• 防掉肌微習慣三環：依據體重自動計算每日蛋白質與飲水目標，內建順暢排便打卡。\n'
          '• 100% 隱私安全：零伺服器上傳，所有紀錄僅保存在您的 iPhone 與私人 iCloud。'
      : 'Taking Mounjaro, Zepbound, Wegovy, Ozempic, or Compounded GLP-1 peptides?\n'
          'DoseFlow is the #1 privacy-first GLP-1 companion built on real pharmacokinetics:\n'
          '• Live Bateman PK Engine: See your real-time absorption peak (Tmax) and half-life decay with 60-day multi-dose superposition.\n'
          '• U-100 Syringe & Peptide Calculator: Effortlessly convert mg/mL or reconstituted vials into exact insulin syringe units.\n'
          '• Dose-Colored Weight Analytics: Correlate your weight-loss slope with 2.5mg, 5mg, 7.5mg+ titrations and food-noise suppression.\n'
          '• 100% Local-First Privacy: Zero external servers. Syncs privately via iCloud & Apple HealthKit.';
}

/// 全域雙語狀態注入器 (InheritedNotifier 架構，切換語系時自動重繪子樹)
class AppLocaleScope extends InheritedNotifier<LocaleController> {
  const AppLocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final AppLocaleScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'No AppLocaleScope found in widget tree.');
    return scope!.notifier!;
  }

  static AppStrings stringsOf(BuildContext context) {
    return AppStrings(of(context).language);
  }
}

/// BuildContext 便捷擴充：讓任一 Widget 可直接呼叫 context.strings 或 context.locale
extension AppLocalizationExtension on BuildContext {
  LocaleController get locale => AppLocaleScope.of(this);
  AppStrings get strings => AppLocaleScope.stringsOf(this);
  bool get isZh => locale.isZh;
}

/// 頂部導覽列專用：一鍵中英切換膠囊按鈕 (🇹🇼 繁中 <-> 🇺🇸 EN)
class LanguageTogglePill extends StatelessWidget {
  const LanguageTogglePill({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final LocaleController controller = context.locale;
    final bool isZh = controller.isZh;

    return Semantics(
      button: true,
      label: isZh ? '切換為英文 (Switch to English)' : 'Switch to Traditional Chinese (切換為繁體中文)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: controller.toggleLanguage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8.0 : 10.0,
              vertical: 5.0,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.38),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildSegment(
                  label: '🇹🇼 繁中',
                  active: isZh,
                ),
                const SizedBox(width: 4),
                _buildSegment(
                  label: '🇺🇸 EN',
                  active: !isZh,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegment({required String label, required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF0EA5E9)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? Colors.white : const Color(0xFF334155),
        ),
      ),
    );
  }
}

/// 美台度量衡快速切換器 (kg <-> lbs / ml <-> oz)
class UnitSwitchBar extends StatelessWidget {
  const UnitSwitchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final LocaleController controller = context.locale;
    final bool isZh = controller.isZh;

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ChoiceChip(
          label: Text(isZh ? '體重: kg (公斤)' : 'Weight: kg'),
          selected: controller.weightUnit == WeightUnit.kg,
          onSelected: (_) => controller.setWeightUnit(WeightUnit.kg),
        ),
        ChoiceChip(
          label: Text(isZh ? '體重: lbs (磅)' : 'Weight: lbs'),
          selected: controller.weightUnit == WeightUnit.lbs,
          onSelected: (_) => controller.setWeightUnit(WeightUnit.lbs),
        ),
        ChoiceChip(
          label: Text(isZh ? '飲水: ml (毫升)' : 'Water: ml'),
          selected: controller.waterUnit == WaterUnit.ml,
          onSelected: (_) => controller.setWaterUnit(WeightUnit.kg == controller.weightUnit ? WaterUnit.ml : WaterUnit.ml),
        ),
        ChoiceChip(
          label: Text(isZh ? '飲水: oz (盎司)' : 'Water: oz'),
          selected: controller.waterUnit == WaterUnit.oz,
          onSelected: (_) => controller.setWaterUnit(WaterUnit.oz),
        ),
      ],
    );
  }
}
