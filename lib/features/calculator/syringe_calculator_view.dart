import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_localization.dart';
import '../../core/pharmacokinetics_engine.dart';

/// 針筒換算器雙模式列舉：
/// 1. premixed: 現成複合藥瓶已標示濃度 (例如 5 mg/mL 或 10 mg/mL)
/// 2. reconstitution: 乾粉藥瓶 (mg) + 自行加入抑菌水 (Bacteriostatic Water, mL)
enum SyringeCalcMode {
  premixed,
  reconstitution,
}

/// Toyota Poka-Yoke 防呆驗證狀態
enum SyringeValidationStatus {
  valid,
  invalidInput,
  exceedsSyringeCapacity,
  microDosePrecisionNotice,
}

/// 針筒單位換算不可變結果模型
@immutable
class SyringeCalculationResult {
  const SyringeCalculationResult({
    required this.status,
    required this.effectiveConcentrationMgPerMl,
    required this.volumeMl,
    required this.u100Units,
    required this.targetDoseMg,
    required this.dosesPerVial,
  });

  final SyringeValidationStatus status;
  final double effectiveConcentrationMgPerMl;
  final double volumeMl;
  final double u100Units;
  final double targetDoseMg;
  final double dosesPerVial;

  bool get isValid =>
      status == SyringeValidationStatus.valid ||
      status == SyringeValidationStatus.microDosePrecisionNotice;
}

/// 常用藥瓶與劑量快速預設組合
@immutable
class VialPreset {
  const VialPreset({
    required this.labelZh,
    required this.labelEn,
    required this.mode,
    required this.vialMassMg,
    required this.waterMl,
    required this.concentrationMgPerMl,
    required this.targetDoseMg,
  });

  final String labelZh;
  final String labelEn;
  final SyringeCalcMode mode;
  final double vialMassMg;
  final double waterMl;
  final double concentrationMgPerMl;
  final double targetDoseMg;

  String label(AppLanguage lang) => lang.isZh ? labelZh : labelEn;
}

/// 核心針筒與複合藥劑防呆計算引擎 (U-100 標準胰島素針筒: 1.0 mL = 100 Units)
class SyringeMathEngine {
  const SyringeMathEngine._();

  static const double maxStandardSyringeMl = 1.0;
  static const double maxStandardUnits = 100.0;

  static const List<VialPreset> commonPresets = <VialPreset>[
    VialPreset(
      labelZh: '5 mg/mL 抽 2.5 mg (50 格)',
      labelEn: '5 mg/mL -> 2.5 mg (50 Units)',
      mode: SyringeCalcMode.premixed,
      vialMassMg: 10.0,
      waterMl: 2.0,
      concentrationMgPerMl: 5.0,
      targetDoseMg: 2.5,
    ),
    VialPreset(
      labelZh: '10 mg/mL 抽 5.0 mg (50 格)',
      labelEn: '10 mg/mL -> 5.0 mg (50 Units)',
      mode: SyringeCalcMode.premixed,
      vialMassMg: 20.0,
      waterMl: 2.0,
      concentrationMgPerMl: 10.0,
      targetDoseMg: 5.0,
    ),
    VialPreset(
      labelZh: '乾粉 10mg + 2mL 水 -> 抽 2.5mg',
      labelEn: '10mg Vial + 2mL BAC -> 2.5mg',
      mode: SyringeCalcMode.reconstitution,
      vialMassMg: 10.0,
      waterMl: 2.0,
      concentrationMgPerMl: 5.0,
      targetDoseMg: 2.5,
    ),
    VialPreset(
      labelZh: '乾粉 15mg + 3mL 水 -> 抽 7.5mg',
      labelEn: '15mg Vial + 3mL BAC -> 7.5mg',
      mode: SyringeCalcMode.reconstitution,
      vialMassMg: 15.0,
      waterMl: 3.0,
      concentrationMgPerMl: 5.0,
      targetDoseMg: 7.5,
    ),
  ];

  /// 執行 U-100 針筒格數計算與 Poka-Yoke 物理邊界檢查
  static SyringeCalculationResult calculate({
    required SyringeCalcMode mode,
    required double concentrationMgPerMl,
    required double vialMassMg,
    required double bacteriostaticWaterMl,
    required double targetDoseMg,
  }) {
    if (targetDoseMg <= 0.0 || !targetDoseMg.isFinite) {
      return const SyringeCalculationResult(
        status: SyringeValidationStatus.invalidInput,
        effectiveConcentrationMgPerMl: 0.0,
        volumeMl: 0.0,
        u100Units: 0.0,
        targetDoseMg: 0.0,
        dosesPerVial: 0.0,
      );
    }

    double effectiveConcentration = 0.0;
    double totalVialMass = vialMassMg;

    if (mode == SyringeCalcMode.premixed) {
      if (concentrationMgPerMl <= 0.0 || !concentrationMgPerMl.isFinite) {
        return const SyringeCalculationResult(
          status: SyringeValidationStatus.invalidInput,
          effectiveConcentrationMgPerMl: 0.0,
          volumeMl: 0.0,
          u100Units: 0.0,
          targetDoseMg: 0.0,
          dosesPerVial: 0.0,
        );
      }
      effectiveConcentration = concentrationMgPerMl;
      totalVialMass = concentrationMgPerMl * 2.0;
    } else {
      if (vialMassMg <= 0.0 ||
          bacteriostaticWaterMl <= 0.0 ||
          !vialMassMg.isFinite ||
          !bacteriostaticWaterMl.isFinite) {
        return const SyringeCalculationResult(
          status: SyringeValidationStatus.invalidInput,
          effectiveConcentrationMgPerMl: 0.0,
          volumeMl: 0.0,
          u100Units: 0.0,
          targetDoseMg: 0.0,
          dosesPerVial: 0.0,
        );
      }
      effectiveConcentration = vialMassMg / bacteriostaticWaterMl;
      totalVialMass = vialMassMg;
    }

    final double volumeMl = targetDoseMg / effectiveConcentration;
    final double u100Units = volumeMl * 100.0;
    final double dosesPerVial = totalVialMass / targetDoseMg;

    if (!volumeMl.isFinite || !u100Units.isFinite || volumeMl <= 0.0) {
      return const SyringeCalculationResult(
        status: SyringeValidationStatus.invalidInput,
        effectiveConcentrationMgPerMl: 0.0,
        volumeMl: 0.0,
        u100Units: 0.0,
        targetDoseMg: 0.0,
        dosesPerVial: 0.0,
      );
    }

    if (u100Units > maxStandardUnits + 1e-6) {
      return SyringeCalculationResult(
        status: SyringeValidationStatus.exceedsSyringeCapacity,
        effectiveConcentrationMgPerMl: effectiveConcentration,
        volumeMl: volumeMl,
        u100Units: u100Units,
        targetDoseMg: targetDoseMg,
        dosesPerVial: dosesPerVial,
      );
    }

    final SyringeValidationStatus status = u100Units < 2.0
        ? SyringeValidationStatus.microDosePrecisionNotice
        : SyringeValidationStatus.valid;

    return SyringeCalculationResult(
      status: status,
      effectiveConcentrationMgPerMl:
          double.parse(effectiveConcentration.toStringAsFixed(3)),
      volumeMl: double.parse(volumeMl.toStringAsFixed(3)),
      u100Units: double.parse(u100Units.toStringAsFixed(1)),
      targetDoseMg: targetDoseMg,
      dosesPerVial: double.parse(dosesPerVial.toStringAsFixed(1)),
    );
  }
}

/// 100 Units (1.0 mL) 標準 U-100 胰島素針筒動態刻度繪圖器
class U100SyringePainter extends CustomPainter {
  const U100SyringePainter({
    required this.units,
    required this.liquidColor,
    required this.isOverCapacity,
  });

  final double units;
  final Color liquidColor;
  final bool isOverCapacity;

  @override
  void paint(Canvas canvas, Size size) {
    final double clampedRatio = (units / 100.0).clamp(0.0, 1.0);
    final Color activeColor =
        isOverCapacity ? const Color(0xFFEF4444) : liquidColor;

    const double needleAreaWidth = 34.0;
    const double plungerGripWidth = 28.0;
    const double barrelLeft = needleAreaWidth; // 校準為 const 修飾符
    final double barrelRight = size.width - plungerGripWidth - 16.0;
    final double barrelWidth = math.max(80.0, barrelRight - barrelLeft);
    final double centerY = size.height / 2.0;
    const double barrelHeight = 46.0;
    final double barrelTop = centerY - barrelHeight / 2.0;
    final double barrelBottom = centerY + barrelHeight / 2.0;

    // 1. 繪製左側針頭與針座 (Needle & Hub)
    final Paint needlePaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    // 校準為動態 Offset(4.0, centerY)，絕不加 const
    canvas.drawLine(
      Offset(4.0, centerY),
      Offset(barrelLeft - 8.0, centerY),
      needlePaint,
    );

    final RRect hubRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barrelLeft - 10.0, centerY - 8.0, 10.0, 16.0),
      const Radius.circular(3.0),
    );
    canvas.drawRRect(
      hubRRect,
      Paint()..color = const Color(0xFFF97316).withValues(alpha: 0.85),
    );

    // 2. 繪製針筒透明外管背景
    final RRect barrelRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barrelLeft, barrelTop, barrelWidth, barrelHeight),
      const Radius.circular(6.0),
    );
    canvas.drawRRect(
      barrelRRect,
      Paint()..color = const Color(0xFFF8FAFC),
    );

    // 3. 繪製抽取的藥液柱 (Liquid Fill)
    final double fillWidth = barrelWidth * clampedRatio;
    if (fillWidth > 0.5) {
      final Rect liquidRect = Rect.fromLTWH(
        barrelLeft,
        barrelTop + 2.0,
        fillWidth,
        barrelHeight - 4.0,
      );
      canvas.drawRect(
        liquidRect,
        Paint()..color = activeColor.withValues(alpha: 0.35),
      );
    }

    // 4. 繪製黑色橡膠活塞頭與推桿 (Plunger Stopper & Rod)
    final double plungerX = barrelLeft + fillWidth;
    final Rect stopperRect = Rect.fromLTWH(
      plungerX,
      barrelTop + 2.0,
      7.0,
      barrelHeight - 4.0,
    );
    canvas.drawRect(
      stopperRect,
      Paint()..color = const Color(0xFF1E293B),
    );

    final Paint rodPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 8.0;
    canvas.drawLine(
      Offset(plungerX + 7.0, centerY),
      Offset(size.width - 8.0, centerY),
      rodPaint,
    );

    // 針筒尾端推柄與手指翼片
    canvas.drawLine(
      Offset(barrelRight, barrelTop - 8.0),
      Offset(barrelRight, barrelBottom + 8.0),
      Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(size.width - 8.0, barrelTop + 4.0),
      Offset(size.width - 8.0, barrelBottom - 4.0),
      Paint()
        ..color = const Color(0xFF475569)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // 5. 繪製 0 ~ 100 Units 精密刻度線與數字
    final Paint tickPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.2;

    for (int u = 0; u <= 100; u += 5) {
      final double x = barrelLeft + (u / 100.0) * barrelWidth;
      final bool isMajor = (u % 10 == 0);
      final double tickLen = isMajor ? 12.0 : 6.5;
      canvas.drawLine(
        Offset(x, barrelTop),
        Offset(x, barrelTop + tickLen),
        tickPaint,
      );

      if (u % 20 == 0 || u == 50) {
        final TextStyle numStyle = u == 50
            ? const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              )
            : const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              );

        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: '$u',
            style: numStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2.0, barrelBottom - 14.0));
      }
    }

    // 6. 繪製針筒外框與高亮目標刻度指示線
    canvas.drawRRect(
      barrelRRect,
      Paint()
        ..color = const Color(0xFF475569)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    if (units > 0) {
      canvas.drawLine(
        Offset(plungerX, barrelTop - 6.0),
        Offset(plungerX, barrelBottom + 6.0),
        Paint()
          ..color = activeColor
          ..strokeWidth = 2.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant U100SyringePainter oldDelegate) {
    return oldDelegate.units != units ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.isOverCapacity != isOverCapacity;
  }
}

/// 人體 8 大注射部位輪替互動選擇器（自動標示上次施打紅點與建議本次綠點）
class BodySiteRotationSelector extends StatelessWidget {
  const BodySiteRotationSelector({
    super.key,
    required this.lastInjectedSite,
    required this.recommendedSite,
    required this.selectedSite,
    required this.onSiteSelected,
  });

  final InjectionSite? lastInjectedSite;
  final InjectionSite recommendedSite;
  final InjectionSite selectedSite;
  final ValueChanged<InjectionSite> onSiteSelected;

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.accessibility_new_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isZh
                        ? '人體部位輪替互動圖（防皮下硬塊與脂肪增生）'
                        : 'Smart Injection Site Rotation Map',
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isZh
                  ? '腹部施打請避開肚臍周圍 5 公分 (2 吋)。紅點為上次部位，綠點為系統推薦本次輪替部位：'
                  : 'Avoid 2 inches (5cm) around the navel. Red = Last Shot, Green = Recommended Next:',
              style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: <Widget>[
                _buildLegendDot(
                  color: const Color(0xFFEF4444),
                  label: isZh ? '上次施打 (避開)' : 'Last Site (Avoid)',
                ),
                _buildLegendDot(
                  color: const Color(0xFF10B981),
                  label: isZh ? '推薦本次 (綠點)' : 'Recommended (Green)',
                ),
                _buildLegendDot(
                  color: const Color(0xFF0EA5E9),
                  label: isZh ? '目前選取' : 'Selected Now',
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.9,
              children: InjectionSite.values.map((InjectionSite site) {
                final bool isLast = site == lastInjectedSite;
                final bool isRec = site == recommendedSite;
                final bool isSelected = site == selectedSite;

                Color dotColor = const Color(0xFF94A3B8);
                if (isLast) dotColor = const Color(0xFFEF4444);
                if (isRec) dotColor = const Color(0xFF10B981);

                return InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onTap: () => onSiteSelected(site),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0EA5E9).withValues(alpha: 0.12)
                          : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0EA5E9)
                            : isRec
                                ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.8 : 1.1,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            site.label(lang),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected || isRec
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

/// Tab 2 完整頁面：施打日誌、人體部位輪替與 U-100 針筒單位換算器
class ShotLogAndCalculatorView extends StatefulWidget {
  const ShotLogAndCalculatorView({
    super.key,
    required this.logs,
    required this.isProUnlocked,
    required this.onAddLog,
    required this.onRequestUnlockPro,
  });

  final List<InjectionRecord> logs;
  final bool isProUnlocked;
  final ValueChanged<InjectionRecord> onAddLog;
  final VoidCallback onRequestUnlockPro;

  @override
  State<ShotLogAndCalculatorView> createState() =>
      _ShotLogAndCalculatorViewState();
}

class _ShotLogAndCalculatorViewState extends State<ShotLogAndCalculatorView> {
  static const List<double> _standardDoses = <double>[
    2.5,
    5.0,
    7.5,
    10.0,
    12.5,
    15.0,
  ];

  SyringeCalcMode _calcMode = SyringeCalcMode.premixed;
  double _concentrationMgPerMl = 5.0;
  double _vialMassMg = 10.0;
  double _bacteriostaticWaterMl = 2.0;
  double _targetDoseMg = 2.5;

  late Glp1Medication _selectedMedication;
  late InjectionSite _selectedSite;
  final int _painLevel = 1;
  int _freeCalcRemaining = 3;

  @override
  void initState() {
    super.initState();
    // 遵循 Apple Guideline 1.4.1：預設僅帶入上一次施打劑量與藥物，絕不主動推薦升劑量
    if (widget.logs.isNotEmpty) {
      _selectedMedication = widget.logs.first.medication;
      _targetDoseMg = widget.logs.first.doseMg;
    } else {
      _selectedMedication = Glp1Medication.tirzepatide;
      _targetDoseMg = 2.5;
    }
    _selectedSite = PharmacokineticsEngine.recommendNextSite(widget.logs);
  }

  void _consumeFreeQuotaIfNeeded() {
    if (!widget.isProUnlocked && _freeCalcRemaining > 0) {
      setState(() {
        _freeCalcRemaining--;
      });
    }
  }

  void _applyPreset(VialPreset preset) {
    if (!widget.isProUnlocked && _freeCalcRemaining <= 0) {
      widget.onRequestUnlockPro();
      return;
    }
    setState(() {
      _calcMode = preset.mode;
      _vialMassMg = preset.vialMassMg;
      _bacteriostaticWaterMl = preset.waterMl;
      _concentrationMgPerMl = preset.concentrationMgPerMl;
      _targetDoseMg = preset.targetDoseMg;
      if (!widget.isProUnlocked && _freeCalcRemaining > 0) {
        _freeCalcRemaining--;
      }
    });
  }

  void _handleRecordShot() {
    final InjectionRecord newRecord = InjectionRecord(
      id: 'shot_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      medication: _selectedMedication,
      doseMg: _targetDoseMg,
      site: _selectedSite,
      painLevel: _painLevel,
    );
    widget.onAddLog(newRecord);
    setState(() {
      _selectedSite = PharmacokineticsEngine.recommendNextSite(
        <InjectionRecord>[newRecord, ...widget.logs],
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.locale.tr(
            '✅ 已新增 ${_targetDoseMg.toStringAsFixed(1)} mg 施打紀錄，體內代謝曲線已即時更新！',
            '✅ Logged ${_targetDoseMg.toStringAsFixed(1)} mg shot! Live PK curve updated.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;

    final SyringeCalculationResult calcResult = SyringeMathEngine.calculate(
      mode: _calcMode,
      concentrationMgPerMl: _concentrationMgPerMl,
      vialMassMg: _vialMassMg,
      bacteriostaticWaterMl: _bacteriostaticWaterMl,
      targetDoseMg: _targetDoseMg,
    );

    final Color doseColor = PharmacokineticsEngine.colorForDose(_targetDoseMg);
    final InjectionSite? lastSite =
        widget.logs.isNotEmpty ? widget.logs.first.site : null;
    final InjectionSite recommendedSite =
        PharmacokineticsEngine.recommendNextSite(widget.logs);
    final bool isCalcLocked = !widget.isProUnlocked && _freeCalcRemaining <= 0;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        // 1. U-100 針筒單位與複合藥劑換算器卡片
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            side: BorderSide(
              color: doseColor.withValues(alpha: 0.35),
              width: 1.3,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: doseColor.withValues(alpha: 0.14),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Icon(
                        Icons.colorize_rounded,
                        color: doseColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.syringeCalcTitle,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            s.syringeCalcSubtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isProUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          borderRadius: const BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text(
                          isZh
                              ? '免費剩餘 $_freeCalcRemaining 次'
                              : '$_freeCalcRemaining Free Left',
                          style: const TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // 常用處方一鍵快選
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: SyringeMathEngine.commonPresets
                      .map((VialPreset preset) {
                    return ActionChip(
                      label: Text(
                        preset.label(lang),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onPressed: () => _applyPreset(preset),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // 模式切換：現成藥液 vs 乾粉泡製
                SegmentedButton<SyringeCalcMode>(
                  segments: <ButtonSegment<SyringeCalcMode>>[
                    ButtonSegment<SyringeCalcMode>(
                      value: SyringeCalcMode.premixed,
                      label: Text(
                        s.calcModePremixed,
                        style: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.liquor_rounded, size: 16),
                    ),
                    ButtonSegment<SyringeCalcMode>(
                      value: SyringeCalcMode.reconstitution,
                      label: Text(
                        s.calcModeReconstitution,
                        style: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.water_drop_rounded, size: 16),
                    ),
                  ],
                  selected: <SyringeCalcMode>{_calcMode},
                  onSelectionChanged: (Set<SyringeCalcMode> next) {
                    _consumeFreeQuotaIfNeeded();
                    setState(() {
                      _calcMode = next.first;
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (isCalcLocked)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(
                        color: doseColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.lock_rounded, color: doseColor, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          isZh
                              ? '免費 3 次針筒換算試用已用完'
                              : '3 Free Syringe Calculations Used',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: widget.onRequestUnlockPro,
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: Text(s.unlockProButton),
                          style: FilledButton.styleFrom(
                            backgroundColor: doseColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...<Widget>[
                  if (_calcMode == SyringeCalcMode.premixed)
                    _buildSliderRow(
                      label: s.inputConcentrationLabel,
                      valueText:
                          '${_concentrationMgPerMl.toStringAsFixed(1)} mg/mL',
                      value: _concentrationMgPerMl,
                      min: 1.0,
                      max: 20.0,
                      divisions: 38,
                      activeColor: doseColor,
                      onChanged: (double v) {
                        setState(() => _concentrationMgPerMl = v);
                      },
                    )
                  else ...<Widget>[
                    _buildSliderRow(
                      label: s.inputVialMassLabel,
                      valueText: '${_vialMassMg.toStringAsFixed(1)} mg',
                      value: _vialMassMg,
                      min: 2.0,
                      max: 30.0,
                      divisions: 28,
                      activeColor: doseColor,
                      onChanged: (double v) {
                        setState(() => _vialMassMg = v);
                      },
                    ),
                    _buildSliderRow(
                      label: s.inputBacteriostaticWaterLabel,
                      valueText:
                          '${_bacteriostaticWaterMl.toStringAsFixed(1)} mL',
                      value: _bacteriostaticWaterMl,
                      min: 0.5,
                      max: 5.0,
                      divisions: 45,
                      activeColor: doseColor,
                      onChanged: (double v) {
                        setState(() => _bacteriostaticWaterMl = v);
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    s.inputTargetDoseLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 劑量顏色標籤系統
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _standardDoses.map((double d) {
                      final Color c = PharmacokineticsEngine.colorForDose(d);
                      final bool selected = (_targetDoseMg - d).abs() < 0.01;
                      return ChoiceChip(
                        label: Text(
                          '${d.toStringAsFixed(1)} mg',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : c,
                          ),
                        ),
                        selected: selected,
                        selectedColor: c,
                        backgroundColor: c.withValues(alpha: 0.1),
                        onSelected: (_) {
                          _consumeFreeQuotaIfNeeded();
                          setState(() => _targetDoseMg = d);
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                // 動態 100 Units 胰島素針筒視覺圖
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    border: Border.all(
                      color: calcResult.status ==
                              SyringeValidationStatus.exceedsSyringeCapacity
                          ? const Color(0xFFEF4444)
                          : doseColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: 76,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: U100SyringePainter(
                            units: calcResult.u100Units,
                            liquidColor: doseColor,
                            isOverCapacity: calcResult.status ==
                                SyringeValidationStatus.exceedsSyringeCapacity,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (calcResult.status ==
                          SyringeValidationStatus.exceedsSyringeCapacity)
                        Text(
                          s.syringeOverCapacityWarning,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        )
                      else if (calcResult.status ==
                          SyringeValidationStatus.invalidInput)
                        Text(
                          s.syringeInvalidInputWarning,
                          style: const TextStyle(
                            fontSize: 12.0,
                            color: Color(0xFFDC2626),
                          ),
                        )
                      else ...<Widget>[
                        Text(
                          s.formatSyringeInstruction(
                            calcResult.u100Units,
                            calcResult.volumeMl,
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w800,
                            color: doseColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isZh
                              ? '折合濃度：${calcResult.effectiveConcentrationMgPerMl} mg/mL ｜ 每瓶約可施打 ${calcResult.dosesPerVial} 次'
                              : 'Effective: ${calcResult.effectiveConcentrationMgPerMl} mg/mL | ~${calcResult.dosesPerVial} doses per vial',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 2. 人體部位輪替互動圖
        BodySiteRotationSelector(
          lastInjectedSite: lastSite,
          recommendedSite: recommendedSite,
          selectedSite: _selectedSite,
          onSiteSelected: (InjectionSite site) {
            setState(() => _selectedSite = site);
          },
        ),
        const SizedBox(height: 16),
        // 3. 立即打卡施打紀錄卡片
        Card(
          elevation: 0,
          color: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isZh ? '新增今日施打紀錄' : 'Log Today\'s Injection',
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Glp1Medication>(
                  initialValue: _selectedMedication,
                  decoration: InputDecoration(
                    labelText: isZh ? '施打藥物品牌' : 'Active GLP-1 Medication',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: Glp1Medication.values.map((Glp1Medication med) {
                    return DropdownMenuItem<Glp1Medication>(
                      value: med,
                      child: Text(
                        med.displayName(lang),
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (Glp1Medication? val) {
                    if (val != null) {
                      setState(() => _selectedMedication = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _handleRecordShot,
                    icon: const Icon(Icons.add_task_rounded),
                    label: Text(
                      isZh
                          ? '確認施打 ${_targetDoseMg.toStringAsFixed(1)} mg 於 ${_selectedSite.label(lang)}'
                          : 'Log ${_targetDoseMg.toStringAsFixed(1)} mg at ${_selectedSite.label(lang)}',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: doseColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w800,
                color: activeColor,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
