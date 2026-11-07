import 'package:flutter/material.dart';
import 'app_localization.dart';

/// 行為經濟學引擎：負責 Paywall 雙曲貼現、定價錨定與諾貝爾大師理論落地
/// 商業指標對齊「絕對獨立開發者模式」：以最強大的退訂心理障礙鎖死 MRR $1,000 門檻！
class BehavioralEconomicsEngine {
  const BehavioralEconomicsEngine._();

  // =========================================================================
  // 【基底演算法】：定價錨定與 iPhone Duo 凡勃倫動態分流
  // =========================================================================

  static double getAnchoredMonthlyPrice(double annualPrice) {
    return annualPrice / 12.0;
  }

  static String getDuoExclusivePaywallHeadline(AppLanguage lang, bool isDuoDevice) {
    if (isDuoDevice) {
      return lang.isZh
          ? '解鎖 iPhone Duo 雙螢幕極致洞察與 90° 懸停模式'
          : 'Unlock iPhone Duo Dual-Pane Analytics & Tabletop Mode';
    }
    return lang.isZh
        ? '解鎖專屬 GLP-1 雙指數代謝模型與抗掉肌肉計畫'
        : 'Unlock Your Personal GLP-1 PK Curve & Anti-Muscle Loss Plan';
  }

  static String getLossAversionSubtext(AppLanguage lang) {
    return lang.isZh
        ? '已有 8,420 位用戶解鎖 Pro，停止盲目猜測你的藥效。'
        : 'Join 8,420+ Pro users. Stop guessing your medication levels.';
  }

  // =========================================================================
  // 【工單 1】：丹尼爾·康納曼 (Daniel Kahneman) 展望理論與損失防禦
  // =========================================================================

  static String getKahnemanLossFramedHeadline(AppLanguage lang) {
    return lang.isZh
        ? '若無精準濃度追蹤，每減 10 公斤中約 4 公斤為珍貴骨骼肌'
        : 'Without tracking active levels, up to 40% of weight lost is lean muscle';
  }

  static String getKahnemanEndowmentWarning(AppLanguage lang) {
    return lang.isZh
        ? '⚡ 您的專屬 Bateman 代謝模型已就緒，退出頁面將銷毀本機計算快取。'
        : '⚡ Your Bateman PK curve is ready. Leaving now discards the local cache.';
  }

  static List<String> getKahnemanDefensiveBenefits(AppLanguage lang) {
    if (lang.isZh) {
      return const <String>[
        '防禦基礎代謝率斷崖：鎖定蛋白質目標，保護核心骨骼肌不流失',
        '阻止半衰期食慾突襲：即時預判波谷衰退點，避開週末暴食陷阱',
        '杜絕重複注射硬塊：8 大輪替防護網，遠離皮下脂肪增生瘀青',
      ];
    }
    return const <String>[
      'Defend metabolic rate: hit daily protein to preserve vital skeletal muscle',
      'Block weekend food noise: forecast decay troughs before cravings strike',
      'Prevent injection knots: 8-quadrant smart rotation stops lipohypertrophy',
    ];
  }

  // =========================================================================
  // 【工單 2】：理查·塞勒 (Richard Thaler) 心理帳戶與預設推力理論
  // =========================================================================

  static double calculateThalerDailyCost(double annualPrice) {
    if (annualPrice <= 0.0 || !annualPrice.isFinite) return 0.0;
    return double.parse((annualPrice / 365.0).toStringAsFixed(2));
  }

  static String getThalerMentalAccountAnchor(AppLanguage lang) {
    return lang.isZh
        ? r'💡 醫療耗材帳戶比價：全年費僅佔單支瘦瘦針藥費 1.1%，每天約 NT$ 2.7（不到半顆水煮蛋）'
        : r'💡 Medical Account Anchor: Just 1.1% of one monthly GLP-1 pen (~$0.11/day, less than a sip of coffee)';
  }

  static String getThalerDefaultNudgeBadge(AppLanguage lang) {
    return lang.isZh
        ? '🔥 88% 減重者預設首選 ‧ 自動鎖定 45% 醫療級年繳折扣'
        : '🔥 Default Choice of 88% Users ‧ Auto-locks 45% Annual Savings';
  }

  // =========================================================================
  // 【工單 3】：喬治·艾克羅夫 (George Akerlof) 檸檬市場對抗與身分經濟學
  // =========================================================================

  static String getAkerlofAntiLemonSignal(AppLanguage lang) {
    return lang.isZh
        ? '🛡️ 反檸檬市場宣言：免費 App 靠出賣您的用藥病歷獲利；DoseFlow 物理拔除雲端伺服器，連我們也無法窺探您的數據。'
        : '🛡️ Anti-Lemon Signal: Free apps monetize your medical logs. DoseFlow operates zero cloud servers—even we cannot see your data.';
  }

  static String getAkerlofIdentityBadge(AppLanguage lang) {
    return lang.isZh
        ? '👑 專為重視絕對隱私與精準代謝的「高自律減重者」打造'
        : '👑 Built for disciplined, privacy-first GLP-1 achievers';
  }

  static List<String> getAkerlofTrustGuarantees(AppLanguage lang) {
    if (lang.isZh) {
      return const <String>[
        '零帳號密碼：免信箱、免手機驗證，徹底杜絕雲端資料庫撞庫外洩',
        '零廣告追蹤 SDK：不向保險公司或數據經紀商傳送任何體重與劑量標籤',
        '100% 離線主權：所有藥動學運算皆於 iPhone 本機晶片獨立完成',
      ];
    }
    return const <String>[
      'Zero Account Required: No email or phone login, immune to cloud data breaches',
      'Zero Ad-Tracker SDKs: Never shares weight or dose tags with data brokers',
      '100% On-Device Sovereignty: All PK math runs locally on your iPhone silicon',
    ];
  }

  // =========================================================================
  // 【工單 4】：肯尼斯·箭 (Kenneth Arrow) 醫療不確定性消除與看診賦能
  // =========================================================================

  static String getArrowPhysicianEmpowermentPitch(AppLanguage lang) {
    return lang.isZh
        ? '🩺 消除看診焦慮：下次回診不再憑記憶回答！一鍵匯出 A4 臨床評估報表遞給主治醫師，30 秒精準呈現您的減重斜率與耐受度。'
        : '🩺 Eliminate Clinic Uncertainty: Hand your physician a 1-page clinical A4 summary. Prove adherence and weight velocity in 30 seconds.';
  }

  static String getArrowFdaCertaintyAnchor(AppLanguage lang) {
    return lang.isZh
        ? '🏛️ 嚴格錨定美國 FDA 官方仿單 (Section 12.3 Pharmacokinetics) 半衰期與 Tmax 參數'
        : '🏛️ Calibrated strictly against official FDA Prescribing Information (Section 12.3 PK parameters)';
  }

  static List<String> getArrowClinicalDecisionPillars(AppLanguage lang) {
    if (lang.isZh) {
      return const <String>[
        '30 天準時施打依從率：向醫師證明您嚴格遵守每週固定時間給藥',
        '8 象限防硬塊輪替合規率：排除皮下脂肪增生導致藥效吸收不良之變數',
        '劑量分色減速斜率：清晰呈現 2.5mg 與 5.0mg 各階段之真實每週減重速率',
      ];
    }
    return const <String>[
      '30-Day On-Time Adherence: Prove strict weekly dosing compliance to your doctor',
      '8-Quadrant Rotation Compliance: Rule out lipohypertrophy absorption issues',
      'Dose-Colored Velocity Slope: Quantify exact weekly loss across 2.5mg & 5.0mg tiers',
    ];
  }

  // =========================================================================
  // 【工單 5】：羅伯·席勒 (Robert Shiller) 敘事經濟學與社交貨幣裂變
  // =========================================================================

  static String getShillerNarrativeHook(AppLanguage lang) {
    return lang.isZh
        ? '✨ 敘事經濟學社交貨幣：不暴露真實體重數字，優雅分享您的「大腦食慾安靜度」與自律里程碑'
        : '✨ De-identified Social Currency: Share your Food Noise Silence % & milestones without revealing actual weight';
  }

  static String generateShillerSilenceCardText({
    required AppLanguage lang,
    required double startWeight,
    required double currentWeight,
    required int foodNoiseSilenceScore,
    required int proteinGoalHitRate,
  }) {
    final double safeStart = startWeight <= 0.0 ? 80.0 : startWeight;
    final double lossPercent =
        (((safeStart - currentWeight) / safeStart) * 100.0).clamp(0.0, 99.9);
    final int silencePercent = (foodNoiseSilenceScore * 20).clamp(20, 100);
    final int safeProteinRate = proteinGoalHitRate.clamp(0, 100);

    if (lang.isZh) {
      return '【DoseFlow ‧ 大腦食慾沉默週報】\n'
          '🧠 食慾噪音安靜度：$silencePercent% (奪回大腦主導權)\n'
          '📉 相對減重里程碑：-${lossPercent.toStringAsFixed(1)}% (真實體重已隱私屏蔽)\n'
          '🛡️ 骨骼肌防禦達標：$safeProteinRate%\n'
          '—— 100% 離線運算 ‧ 瘦瘦針紀錄 Pro';
    }
    return '[DoseFlow ‧ Weekly Food Noise Silence Report]\n'
        '🧠 Mental Chatter Silence: $silencePercent% (In full control)\n'
        '📉 Relative Progress: -${lossPercent.toStringAsFixed(1)}% (Exact weight privacy-shielded)\n'
        '🛡️ Lean Muscle Defense: $safeProteinRate%\n'
        '— Tracked 100% offline via DoseFlow Pro';
  }

  static String getShillerViralWatermark(AppLanguage lang) {
    return lang.isZh
        ? '🔒 已自動隱藏絕對公斤數 ‧ 專為 Threads / 減重社群無壓力分享設計'
        : '🔒 Absolute weight hidden by default ‧ Designed for Reddit & social sharing';
  }

  // =========================================================================
  // 【工單 6】：保羅·米爾格羅姆 (Paul Milgrom) 拍賣機制設計與二級價格歧視
  // =========================================================================

  static String getMilgromDecoyLifetimePrice(AppLanguage lang) {
    return lang.isZh ? r'NT$ 3,990' : r'$119.99';
  }

  static String getMilgromDecoyLifetimeLabel(AppLanguage lang) {
    return lang.isZh
        ? '💎 VIP 菁英終身版 (硬核玩家首選)'
        : '💎 VIP Elite Lifetime (Hardcore Achievers)';
  }

  static String getMilgromPeptideDiscriminationPitch(AppLanguage lang) {
    return lang.isZh
        ? '🔬 胜肽玩家專屬：解鎖雙瓶混水微克級 U-100 針筒換算，告別超量下劑風險。'
        : '🔬 Compounded Peptides Pro: Unlock micro-gram U-100 syringe math. Never miscalculate your reconstituted dose.';
  }

  // =========================================================================
  // 【工單 7】：尚·梯若爾 (Jean Tirole) 雙邊市場網路效應與平台經濟學
  // =========================================================================

  static String getTiroleClinicReferralWatermark(AppLanguage lang) {
    return lang.isZh
        ? '🤝 臨床醫師授權引薦 ‧ DoseFlow 本機 100% 離線隱私確保'
        : '🤝 Recommended by Clinic Physicians ‧ DoseFlow 100% Offline Privacy';
  }

  static String getTiroleMaintenanceLockInPitch(AppLanguage lang) {
    return lang.isZh
        ? '🛑 停針復胖警告：達標後的第一個 90 天為『代謝重置』生死關頭！請務必維持 Pro 數據監控，保護您的減重資產。'
        : '🛑 Rebound Warning: The 90 days post-GLP-1 are critical. Lock-in your metabolic gains by keeping Pro tracking active.';
  }

  // =========================================================================
  // 【工單 8】：約瑟夫·斯蒂格利茨 (Joseph Stiglitz) 資訊甄別與動態路由
  // =========================================================================

  static String getStiglitzDynamicPaywallHeadline({
    required AppLanguage lang,
    required bool worrySideEffects,
    required bool worryBruising,
    required bool worryMuscle,
    required bool worryConcentration,
    required bool isDuoDevice,
  }) {
    if (isDuoDevice) return getDuoExclusivePaywallHeadline(lang, true);
    if (worrySideEffects) return lang.isZh ? '解鎖個人化水分排便雷達與副作用防禦矩陣' : 'Unlock Side-Effect Radar & Gut Defense Matrix';
    if (worryBruising) return lang.isZh ? '啟動 8 大腹部智慧輪替引擎，徹底告別皮下硬塊' : 'Unlock 8-Quadrant Smart Rotation & Prevent Bruising';
    if (worryMuscle) return lang.isZh ? '解鎖每日蛋白質抗掉肌引擎與皮膚鬆弛防護' : 'Unlock Lean Muscle Defense & Skin Elasticity Tracker';
    if (worryConcentration) return lang.isZh ? '解鎖 Bateman 高峰預警與精準防忘針推播' : 'Unlock Live Bateman PK Peaks & Dose Forecasting';
    return getDuoExclusivePaywallHeadline(lang, false);
  }

  // =========================================================================
  // 【工單 9】：蓋瑞·貝克 (Gary Becker) 人力資本論與理性成癮
  // =========================================================================

  static String getBeckerHealthCapitalValuation(AppLanguage lang) {
    return lang.isZh
        ? r'💡 本月堅持蛋白質目標為您守住約 1.8 公斤核心肌肉。醫學上若要練回，至少需半年重訓與預估約 NT$ 48,000 的教練費（替代重置成本估值）'
        : r'💡 Hitting protein targets protected ~4 lbs of lean mass this month. Rebuilding this requires 6 months of heavy training (~$1,500 PT & Gym cost avoided)';
  }

  static String getBeckerHabitLoopNudge(AppLanguage lang) {
    return lang.isZh
        ? '⏳ 忘記追蹤？您珍貴的減重資本正在產生 2% 閒置微損。只需 10 秒標記今天的攝取量，立刻重啟 100% 肌肉代謝保護罩！'
        : '⏳ Forgot to log? Your metabolic gains are leaking 2% velocity. Take 10 secs to log today & instantly restore 100% defense shield!';
  }
  // =========================================================================
  // 【諾貝爾工單 10 落地】：湯瑪斯·謝林 (Thomas Schelling) 尤利西斯合約與預先承諾機制
  // Indie Hacker MRR 防禦線：建立道德與沉沒成本雙重心理鎖，確保首年續訂留存穩站 MRR 1K 門檻！
  // =========================================================================

  /// 謝林尤利西斯合約誓言 (Ulysses Contract Pledge)
  /// 將單純的「付費購買」行為轉化為對未來自己健康承諾的神聖契約，提升首日轉換的意志力賦價
  static String getSchellingUlyssesContractPledge(AppLanguage lang) {
    return lang.isZh
        ? '✍️ 尤利西斯自我承諾：我在此預先綁定這份臨床計畫，不給未來的怠惰留退路。'
        : '✍️ Ulysses Contract: I commit to this clinical plan to block future diet procrastination.';
  }

  /// 謝林沉沒成本留存鎖 (Sunk Cost Retention Lock)
  /// 當用戶意圖退訂或長時間未活躍時，喚醒意志力破產的恐懼與數據付之一炬的痛苦
  static String getSchellingSunkCostLockIn(AppLanguage lang) {
    return lang.isZh
        ? '🛡️ 意志力防線：僅靠意志力瘦身成功率極低！解開追蹤合約將使您的減速預測與代謝快取失去掩護。'
        : '🛡️ Commitment Shield: Willpower alone often fails. Discarding this tracking contract leaves your metabolic models exposed.';
  }}

/// 【模式中斷 (Pattern Interrupt) 微動畫組件 ✕ 中美雙語系自動適配版】
/// 透過微妙的呼吸脈衝動畫打破使用者「橫幅盲點」，按鈕具備強大彈性不設死高度，徹底免疫中英文案長短交替產生的溢出！
class PulsingCtaButton extends StatefulWidget {
  const PulsingCtaButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  State<PulsingCtaButton> createState() => _PulsingCtaButtonState();
}

class _PulsingCtaButtonState extends State<PulsingCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 防呆與抗神經適應：刻意使用非整數的 1.25 秒，避開大腦習慣的秒數節奏
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 18),
          // 支援多行斷句防溢出（特別是美國冗長的行銷用語）
          label: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.0, 
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: widget.color,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}