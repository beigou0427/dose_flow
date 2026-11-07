import 'package:flutter/material.dart';
import '../../core/app_localization.dart';
import '../../core/pharmacokinetics_engine.dart';

/// iPhone Duo / 折疊設備姿態枚舉
enum DuoDisplayPosture {
  /// 5.4 吋外螢幕閉合狀態 (單手極速操作)
  foldedOuter,

  /// 7.6 吋展開大螢幕狀態 (雙欄並排多工)
  unfoldedDualPane,

  /// 桌面懸停半折 90 度模式 (雙手免持抽藥引導)
  tabletopHalfFold,
}

/// 智慧感知折疊螢幕姿態與寬度之探測器
class DuoDeviceDetector {
  const DuoDeviceDetector._();

  /// 判定閾值：展開內螢幕寬度通常大於 600dp
  static const double unfoldedWidthThreshold = 600.0;

  /// 根據當前 MediaQuery 尺寸動態推算設備姿態
  static DuoDisplayPosture getPosture(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final Orientation orientation = MediaQuery.of(context).orientation;

    // 寬度大於閾值視為展開 7.6 吋大螢幕
    if (size.width >= unfoldedWidthThreshold && (orientation == Orientation.portrait || orientation == Orientation.landscape)) {
      // 若高度與寬度接近且處於橫向/半折狀態，可適配為雙欄
      return DuoDisplayPosture.unfoldedDualPane;
    }

    return DuoDisplayPosture.foldedOuter;
  }

  /// 是否具備展開大螢幕空間
  static bool isLargeScreen(BuildContext context) {
    return getPosture(context) == DuoDisplayPosture.unfoldedDualPane;
  }
}

/// iPhone Duo 雙欄自適應母體容器 (Adaptive Dual-Pane Scaffold)
class DuoAdaptiveScaffold extends StatelessWidget {
  const DuoAdaptiveScaffold({
    super.key,
    required this.primaryPane,
    required this.secondaryPane,
    this.tabletopGuidePane,
    this.appBar,
    this.bottomNavigationBar,
  });

  final Widget primaryPane;
  final Widget secondaryPane;
  final Widget? tabletopGuidePane;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final DuoDisplayPosture posture = DuoDeviceDetector.getPosture(context);

    // 1. 7.6 吋展開大螢幕：呈現左右雙欄黃金對稱佈局
    if (posture == DuoDisplayPosture.unfoldedDualPane) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 左欄：核心曲線與監控
              Expanded(
                flex: 5,
                child: primaryPane,
              ),
              // 中間微分隔線
              Container(
                width: 1.2,
                color: const Color(0xFFE2E8F0),
              ),
              // 右欄：體重趨勢、痛點對照與換算
              Expanded(
                flex: 5,
                child: secondaryPane,
              ),
            ],
          ),
        ),
        bottomNavigationBar: bottomNavigationBar,
      );
    }

    // 2. 5.4 吋閉合外螢幕或標準手機：標準單欄流式佈局
    return Scaffold(
      appBar: appBar,
      body: primaryPane,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// iPhone Duo 桌面半折 90 度懸停專用：免持抽藥與部位引導視圖 (Hands-Free Injection Guide)
class DuoTabletopInjectionGuide extends StatelessWidget {
  const DuoTabletopInjectionGuide({
    super.key,
    required this.recommendedSite,
    required this.targetDoseMg,
    required this.calculatedUnits,
    required this.calculatedVolumeMl,
    required this.onConfirmInjection,
    this.onClose,
  });

  final InjectionSite recommendedSite;
  final double targetDoseMg;
  final double calculatedUnits;
  final double calculatedVolumeMl;
  final VoidCallback onConfirmInjection;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;
    final Color doseColor = PharmacokineticsEngine.colorForDose(targetDoseMg);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // ==========================================
            // 上半屏 (直立懸停視角)：人體部位與無菌操作指引
            // ==========================================
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.all(Radius.circular(999)),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.table_restaurant_rounded, color: Color(0xFF10B981), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                isZh ? 'iPhone Duo 桌面免持模式' : 'Duo Hands-Free Tabletop',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF34D399)),
                              ),
                            ],
                          ),
                        ),
                        if (onClose != null)
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isZh ? '建議本次施打部位' : 'Recommended Injection Target',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendedSite.label(lang),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155).withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF38BDF8), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isZh
                                  ? '腹部注射請避開肚臍周圍 5 公分。已為您避開上次注射點，防止皮下硬塊。'
                              : 'Keep 2 inches (5cm) away from navel. Automatically rotated away from last site.',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1), height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 鉸鏈中心防干擾避讓間距
            const SizedBox(height: 8),

            // ==========================================
            // 下半屏 (桌面平放操作區)：超大高對比針筒刻度與確認按鈕
            // ==========================================
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      isZh ? 'U-100 胰島素針筒請抽取至：' : 'Draw U-100 Syringe Exactly To:',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          calculatedUnits.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: doseColor,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isZh ? '格 (Units)' : 'Units',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: doseColor),
                        ),
                      ],
                    ),
                    Text(
                      '(${calculatedVolumeMl.toStringAsFixed(2)} mL ｜ 劑量: ${targetDoseMg.toStringAsFixed(1)} mg)',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onConfirmInjection,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          isZh ? '已完成施打，記錄今日針次' : 'Injection Complete - Log Shot',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: doseColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iPhone Duo 5.4 吋外螢幕與桌面懸停快速啟動卡片
class DuoOuterQuickActionCard extends StatelessWidget {
  const DuoOuterQuickActionCard({
    super.key,
    required this.recommendedSite,
    required this.targetDoseMg,
    required this.calculatedUnits,
    required this.calculatedVolumeMl,
    required this.onConfirmInjection,
  });

  final InjectionSite recommendedSite;
  final double targetDoseMg;
  final double calculatedUnits;
  final double calculatedVolumeMl;
  final VoidCallback onConfirmInjection;

  void _openTabletopMode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => DuoTabletopInjectionGuide(
          recommendedSite: recommendedSite,
          targetDoseMg: targetDoseMg,
          calculatedUnits: calculatedUnits,
          calculatedVolumeMl: calculatedVolumeMl,
          onConfirmInjection: () {
            Navigator.of(routeContext).pop();
            onConfirmInjection();
          },
          onClose: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isZh = context.locale.isZh;
    final bool isLarge = DuoDeviceDetector.isLargeScreen(context);

    return Card(
      elevation: 0,
      color: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: const Icon(
                Icons.screen_rotation_alt_rounded,
                color: Color(0xFF34D399),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isZh
                        ? (isLarge ? 'iPhone Duo 7.6" 雙欄模式已啟用' : 'iPhone Duo 免持抽藥導引')
                        : (isLarge ? 'iPhone Duo 7.6" Dual-Pane Active' : 'Duo Hands-Free Tabletop Guide'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isZh
                        ? '半折手機立於桌面，雙手免持看清第 ${calculatedUnits.toStringAsFixed(0)} 格刻度'
                        : 'Fold 90° on table for hands-free ${calculatedUnits.toStringAsFixed(0)}-Unit draw guide',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _openTabletopMode(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Text(
                isZh ? '啟動懸停' : 'Launch',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
