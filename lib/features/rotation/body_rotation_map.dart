import 'package:flutter/material.dart';
import '../../core/app_localization.dart';
import '../../core/app_theme.dart';
import '../../core/haptic_feedback_service.dart';
import '../../core/pharmacokinetics_engine.dart';

/// 四大主要視覺輪替區域（與 8 部位引擎自動映射）
enum BodyZoneQuadrant {
  leftAbdomen(InjectionSite.leftLowerAbdomen, '左腹部', 'Left Abdomen'),
  rightAbdomen(InjectionSite.rightLowerAbdomen, '右腹部', 'Right Abdomen'),
  leftThigh(InjectionSite.leftThigh, '左大腿', 'Left Thigh'),
  rightThigh(InjectionSite.rightThigh, '右大腿', 'Right Thigh');

  const BodyZoneQuadrant(this.primarySite, this.labelZh, this.labelEn);

  final InjectionSite primarySite;
  final String labelZh;
  final String labelEn;

  String label(AppLanguage lang) => lang.isZh ? labelZh : labelEn;

  static BodyZoneQuadrant fromSite(InjectionSite site) {
    switch (site) {
      case InjectionSite.leftUpperAbdomen:
      case InjectionSite.leftLowerAbdomen:
      case InjectionSite.leftArm:
        return BodyZoneQuadrant.leftAbdomen;
      case InjectionSite.rightUpperAbdomen:
      case InjectionSite.rightLowerAbdomen:
      case InjectionSite.rightArm:
        return BodyZoneQuadrant.rightAbdomen;
      case InjectionSite.leftThigh:
        return BodyZoneQuadrant.leftThigh;
      case InjectionSite.rightThigh:
        return BodyZoneQuadrant.rightThigh;
    }
  }
}

/// DoseFlow 1.1 視覺化人體施打部位輪替卡片
class BodyRotationMapCard extends StatefulWidget {
  const BodyRotationMapCard({
    super.key,
    required this.logs,
    required this.activeDoseMg,
    required this.activeMedication,
    required this.onConfirmInjection,
  });

  final List<InjectionRecord> logs;
  final double activeDoseMg;
  final Glp1Medication activeMedication;
  final ValueChanged<InjectionSite> onConfirmInjection;

  @override
  State<BodyRotationMapCard> createState() => _BodyRotationMapCardState();
}

class _BodyRotationMapCardState extends State<BodyRotationMapCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  BodyZoneQuadrant? _manualOverride;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;

    final InjectionSite recommendedSite =
        PharmacokineticsEngine.recommendNextSite(widget.logs);
    final BodyZoneQuadrant recommendedZone =
        BodyZoneQuadrant.fromSite(recommendedSite);
    final BodyZoneQuadrant targetZone = _manualOverride ?? recommendedZone;
    final InjectionSite targetSite = _manualOverride != null
        ? _manualOverride!.primarySite
        : recommendedSite;

    final InjectionRecord? lastLog =
        widget.logs.isNotEmpty ? widget.logs.first : null;
    final BodyZoneQuadrant? lastZone =
        lastLog != null ? BodyZoneQuadrant.fromSite(lastLog.site) : null;

    final String lastDateStr = lastLog != null
        ? '${lastLog.timestamp.month}/${lastLog.timestamp.day}'
        : '--/--';
    final double volumeMl = ((widget.activeDoseMg / 5.0)).clamp(0.05, 1.5);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF13243B), Color(0xFF0C1829)],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: Border.all(
          color: DoseFlowColors.mint.withValues(alpha: 0.30),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: DoseFlowColors.mint.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DoseFlowColors.mint.withValues(alpha: 0.14),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(
                  Icons.accessibility_new_rounded,
                  color: DoseFlowColors.mint,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isZh ? '部位輪替與視覺導引' : 'Visual Site Rotation Map',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: DoseFlowColors.textPrimary,
                      ),
                    ),
                    Text(
                      isZh
                          ? '點擊任一部位可切換目標，自動避開上次區域'
                          : 'Tap any zone to select; auto-rotates away from last site',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: DoseFlowColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: DoseFlowColors.mint.withValues(alpha: 0.14),
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  border: Border.all(
                    color: DoseFlowColors.mint.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isZh ? '第 ${widget.logs.length + 1} 次' : 'Shot #${widget.logs.length + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: DoseFlowColors.mint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Anatomical Torso & Thighs Interactive Canvas
          Container(
            height: 270,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF08121E),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              border: Border.all(color: DoseFlowColors.cardBorder),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double w = constraints.maxWidth;
                final double h = constraints.maxHeight;
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (BuildContext context, _) {
                    return Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _AnatomicalBodyPainter(
                              lastZone: lastZone,
                              targetZone: targetZone,
                              pulseValue: _pulseController.value,
                              navelNote: isZh ? '避開肚臍 5cm' : 'Avoid 5cm navel',
                            ),
                          ),
                        ),
                        // Left Abdomen Tap & Status Pill
                        Positioned(
                          left: 10,
                          top: h * 0.30,
                          child: _ZoneStatusChip(
                            zone: BodyZoneQuadrant.leftAbdomen,
                            isTarget:
                                targetZone == BodyZoneQuadrant.leftAbdomen,
                            isLast: lastZone == BodyZoneQuadrant.leftAbdomen,
                            lastDateStr: lastDateStr,
                            lang: lang,
                            onTap: () {
                              HapticFeedbackService.selectionTick();
                              setState(() => _manualOverride =
                                  BodyZoneQuadrant.leftAbdomen);
                            },
                          ),
                        ),
                        // Right Abdomen Tap & Status Pill
                        Positioned(
                          right: 10,
                          top: h * 0.30,
                          child: _ZoneStatusChip(
                            zone: BodyZoneQuadrant.rightAbdomen,
                            isTarget:
                                targetZone == BodyZoneQuadrant.rightAbdomen,
                            isLast: lastZone == BodyZoneQuadrant.rightAbdomen,
                            lastDateStr: lastDateStr,
                            lang: lang,
                            onTap: () {
                              HapticFeedbackService.selectionTick();
                              setState(() => _manualOverride =
                                  BodyZoneQuadrant.rightAbdomen);
                            },
                          ),
                        ),
                        // Left Thigh Tap & Status Pill
                        Positioned(
                          left: 10,
                          bottom: 14,
                          child: _ZoneStatusChip(
                            zone: BodyZoneQuadrant.leftThigh,
                            isTarget: targetZone == BodyZoneQuadrant.leftThigh,
                            isLast: lastZone == BodyZoneQuadrant.leftThigh,
                            lastDateStr: lastDateStr,
                            lang: lang,
                            onTap: () {
                              HapticFeedbackService.selectionTick();
                              setState(() =>
                                  _manualOverride = BodyZoneQuadrant.leftThigh);
                            },
                          ),
                        ),
                        // Right Thigh Tap & Status Pill
                        Positioned(
                          right: 10,
                          bottom: 14,
                          child: _ZoneStatusChip(
                            zone: BodyZoneQuadrant.rightThigh,
                            isTarget: targetZone == BodyZoneQuadrant.rightThigh,
                            isLast: lastZone == BodyZoneQuadrant.rightThigh,
                            lastDateStr: lastDateStr,
                            lang: lang,
                            onTap: () {
                              HapticFeedbackService.selectionTick();
                              setState(() => _manualOverride =
                                  BodyZoneQuadrant.rightThigh);
                            },
                          ),
                        ),
                        // Top-right recommended highlight callout
                        Positioned(
                          top: 10,
                          left: w * 0.5 - 64,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: DoseFlowColors.mint,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(999)),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: DoseFlowColors.mint
                                      .withValues(alpha: 0.45),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              isZh
                                  ? '本週建議：${targetZone.label(lang)} 🎯'
                                  : 'Target: ${targetZone.label(lang)} 🎯',
                              style: const TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF041A18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Bottom Action Bar matching Screenshot 1
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: DoseFlowColors.cardElevated,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(
                color: DoseFlowColors.mint.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isZh
                            ? '上次施打：${lastZone?.label(lang) ?? "尚未紀錄"} (${volumeMl.toStringAsFixed(2)} mL)'
                            : 'Last: ${lastZone?.label(lang) ?? "None"} (${volumeMl.toStringAsFixed(2)} mL)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: DoseFlowColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isZh
                            ? '本次目標：${targetZone.label(lang)} (${widget.activeDoseMg.toStringAsFixed(1)} mg)'
                            : 'Next: ${targetZone.label(lang)} (${widget.activeDoseMg.toStringAsFixed(1)} mg)',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: DoseFlowColors.mint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedbackService.heavyImpact();
                    widget.onConfirmInjection(targetSite);
                    setState(() => _manualOverride = null);
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 17),
                  label: Text(isZh ? '確認施打' : 'Confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DoseFlowColors.mint,
                    foregroundColor: const Color(0xFF041A18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneStatusChip extends StatelessWidget {
  const _ZoneStatusChip({
    required this.zone,
    required this.isTarget,
    required this.isLast,
    required this.lastDateStr,
    required this.lang,
    required this.onTap,
  });

  final BodyZoneQuadrant zone;
  final bool isTarget;
  final bool isLast;
  final String lastDateStr;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isZh = lang.isZh;
    final String statusText = isTarget
        ? (isZh ? '本週建議 🎯' : 'Target 🎯')
        : isLast
            ? (isZh ? '✕ 已施打 $lastDateStr' : '✕ Done $lastDateStr')
            : (isZh ? '可施打' : 'Ready');

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isTarget
              ? DoseFlowColors.mint.withValues(alpha: 0.20)
              : DoseFlowColors.cardSurface.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: isTarget
                ? DoseFlowColors.mint
                : isLast
                    ? DoseFlowColors.textMuted
                    : DoseFlowColors.cardBorder,
            width: isTarget ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              zone.label(lang),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isTarget
                    ? DoseFlowColors.mint
                    : DoseFlowColors.textPrimary,
              ),
            ),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.w700,
                color: isTarget
                    ? DoseFlowColors.mint
                    : DoseFlowColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnatomicalBodyPainter extends CustomPainter {
  const _AnatomicalBodyPainter({
    required this.lastZone,
    required this.targetZone,
    required this.pulseValue,
    required this.navelNote,
  });

  final BodyZoneQuadrant? lastZone;
  final BodyZoneQuadrant targetZone;
  final double pulseValue;
  final String navelNote;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    const double top = 40;
    final double bottom = size.height - 14;
    final double h = bottom - top;

    // Centerline
    final Paint centerPaint = Paint()
      ..color = DoseFlowColors.textMuted.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx, top), Offset(cx, bottom), centerPaint);

    // Torso & Upper Thighs Silhouette
    final Path bodyPath = Path()
      ..moveTo(cx - 46, top + h * 0.02)
      ..cubicTo(
        cx - 64,
        top + h * 0.14,
        cx - 58,
        top + h * 0.30,
        cx - 52,
        top + h * 0.44,
      )
      ..cubicTo(
        cx - 60,
        top + h * 0.56,
        cx - 66,
        top + h * 0.72,
        cx - 62,
        bottom,
      )
      ..lineTo(cx - 14, bottom)
      ..lineTo(cx - 6, top + h * 0.68)
      ..quadraticBezierTo(cx, top + h * 0.65, cx + 6, top + h * 0.68)
      ..lineTo(cx + 14, bottom)
      ..lineTo(cx + 62, bottom)
      ..cubicTo(
        cx + 66,
        top + h * 0.72,
        cx + 60,
        top + h * 0.56,
        cx + 52,
        top + h * 0.44,
      )
      ..cubicTo(
        cx + 58,
        top + h * 0.30,
        cx + 64,
        top + h * 0.14,
        cx + 46,
        top + h * 0.02,
      );

    canvas.drawPath(
      bodyPath,
      Paint()..color = const Color(0xFF1A314C).withValues(alpha: 0.45),
    );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = DoseFlowColors.textSecondary.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Navel 5cm Safe Zone
    final Offset navel = Offset(cx, top + h * 0.40);
    canvas.drawCircle(
      navel,
      14,
      Paint()
        ..color = DoseFlowColors.textMuted.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      navel,
      3.0,
      Paint()..color = DoseFlowColors.textMuted.withValues(alpha: 0.7),
    );

    final TextPainter navelTp = TextPainter(
      text: TextSpan(
        text: navelNote,
        style: TextStyle(
          fontSize: 9.0,
          fontWeight: FontWeight.w600,
          color: DoseFlowColors.textMuted.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    navelTp.paint(canvas, Offset(cx - navelTp.width / 2, navel.dy + 17));

    final Map<BodyZoneQuadrant, Offset> coords = <BodyZoneQuadrant, Offset>{
      BodyZoneQuadrant.leftAbdomen: Offset(cx - 32, top + h * 0.38),
      BodyZoneQuadrant.rightAbdomen: Offset(cx + 32, top + h * 0.38),
      BodyZoneQuadrant.leftThigh: Offset(cx - 34, top + h * 0.80),
      BodyZoneQuadrant.rightThigh: Offset(cx + 34, top + h * 0.80),
    };

    for (final MapEntry<BodyZoneQuadrant, Offset> entry in coords.entries) {
      final BodyZoneQuadrant zone = entry.key;
      final Offset pt = entry.value;
      final bool isTarget = zone == targetZone;
      final bool isLast = zone == lastZone;

      if (isTarget) {
        final double glowR = 22 + (pulseValue * 10);
        canvas.drawCircle(
          pt,
          glowR,
          Paint()
            ..color =
                DoseFlowColors.mint.withValues(alpha: 0.28 - (pulseValue * 0.14)),
        );
        canvas.drawCircle(
          pt,
          17,
          Paint()..color = DoseFlowColors.mint.withValues(alpha: 0.25),
        );
        canvas.drawCircle(
          pt,
          17,
          Paint()
            ..color = DoseFlowColors.mint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
        canvas.drawCircle(pt, 6, Paint()..color = DoseFlowColors.mint);
        canvas.drawCircle(pt, 2.5, Paint()..color = Colors.white);
      } else if (isLast) {
        canvas.drawCircle(
          pt,
          15,
          Paint()..color = DoseFlowColors.textMuted.withValues(alpha: 0.18),
        );
        canvas.drawCircle(
          pt,
          15,
          Paint()
            ..color = DoseFlowColors.textSecondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        final Paint xPaint = Paint()
          ..color = DoseFlowColors.textSecondary
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(pt.translate(-5, -5), pt.translate(5, 5), xPaint);
        canvas.drawLine(pt.translate(5, -5), pt.translate(-5, 5), xPaint);
      } else {
        canvas.drawCircle(
          pt,
          14,
          Paint()..color = DoseFlowColors.textMuted.withValues(alpha: 0.10),
        );
        canvas.drawCircle(
          pt,
          14,
          Paint()
            ..color = DoseFlowColors.textMuted.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        canvas.drawCircle(
          pt,
          3.5,
          Paint()..color = DoseFlowColors.textMuted.withValues(alpha: 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnatomicalBodyPainter old) {
    return old.lastZone != lastZone ||
        old.targetZone != targetZone ||
        old.pulseValue != pulseValue ||
        old.navelNote != navelNote;
  }
}
