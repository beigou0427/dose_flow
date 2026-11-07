import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_localization.dart';

/// GLP-1 藥物動力學參數與 FDA 仿單文獻定義 (遵循 Apple App Review Guideline 1.4.1)
enum Glp1Medication {
  tirzepatide(
    id: 'tirzepatide',
    displayNameZh: '猛健樂 Mounjaro / Zepbound (Tirzepatide)',
    displayNameEn: 'Tirzepatide (Mounjaro / Zepbound)',
    halfLifeHours: 120.0, // 5 days (120 hrs)
    absorptionRateKa: 0.055, // Tmax ~ 36 hrs
    peakHoursTmax: 36.0,
    fdaCitationTitle:
        'Eli Lilly Mounjaro (Tirzepatide) FDA Prescribing Information - Section 12.3 Pharmacokinetics',
    fdaCitationUrl: 'https://pi.lilly.com/us/mounjaro-uspi.pdf',
  ),
  semaglutide(
    id: 'semaglutide',
    displayNameZh: '週纖達 Wegovy / 善纖達 Ozempic (Semaglutide)',
    displayNameEn: 'Semaglutide (Wegovy / Ozempic)',
    halfLifeHours: 168.0, // 7 days (168 hrs)
    absorptionRateKa: 0.038, // Tmax ~ 48 hrs
    peakHoursTmax: 48.0,
    fdaCitationTitle:
        'Novo Nordisk Ozempic/Wegovy (Semaglutide) FDA Prescribing Information - Section 12.3 Pharmacokinetics',
    fdaCitationUrl: 'https://www.novo-pi.com/ozempic.pdf',
  ),
  liraglutide(
    id: 'liraglutide',
    displayNameZh: '善纖達每日針 Saxenda (Liraglutide)',
    displayNameEn: 'Liraglutide (Saxenda Daily)',
    halfLifeHours: 13.0, // 13 hrs
    absorptionRateKa: 0.22, // Tmax ~ 11 hrs
    peakHoursTmax: 11.0,
    fdaCitationTitle:
        'Novo Nordisk Saxenda (Liraglutide) FDA Prescribing Information - Section 12.3 Pharmacokinetics',
    fdaCitationUrl: 'https://www.novo-pi.com/saxenda.pdf',
  );

  const Glp1Medication({
    required this.id,
    required this.displayNameZh,
    required this.displayNameEn,
    required this.halfLifeHours,
    required this.absorptionRateKa,
    required this.peakHoursTmax,
    required this.fdaCitationTitle,
    required this.fdaCitationUrl,
  });

  final String id;
  final String displayNameZh;
  final String displayNameEn;
  final double halfLifeHours;
  final double absorptionRateKa;
  final double peakHoursTmax;
  final String fdaCitationTitle;
  final String fdaCitationUrl;

  /// 消除速率常數 k_e = ln(2) / t_{1/2}
  double get eliminationRateKe => math.log(2.0) / halfLifeHours;

  /// 依據當前語系回傳藥物名稱
  String displayName(AppLanguage lang) =>
      lang.isZh ? displayNameZh : displayNameEn;
}

/// 施打部位列舉（支援中英雙語與防硬塊自動輪替演算法）
enum InjectionSite {
  leftUpperAbdomen('左上腹 (避開肚臍 5cm)', 'Left Upper Abdomen'),
  leftLowerAbdomen('左下腹 (避開肚臍 5cm)', 'Left Lower Abdomen'),
  rightUpperAbdomen('右上腹 (避開肚臍 5cm)', 'Right Upper Abdomen'),
  rightLowerAbdomen('右下腹 (避開肚臍 5cm)', 'Right Lower Abdomen'),
  leftThigh('左大腿前外側', 'Left Anterior Thigh'),
  rightThigh('右大腿前外側', 'Right Anterior Thigh'),
  leftArm('左上臂後側', 'Left Upper Arm'),
  rightArm('右上臂後側', 'Right Upper Arm');

  const InjectionSite(this.labelZh, this.labelEn);
  final String labelZh;
  final String labelEn;

  String label(AppLanguage lang) => lang.isZh ? labelZh : labelEn;
}

/// 單筆施打紀錄資料模型
@immutable
class InjectionRecord {
  const InjectionRecord({
    required this.id,
    required this.timestamp,
    required this.medication,
    required this.doseMg,
    required this.site,
    this.painLevel = 0,
    this.batchOrVialNote,
  });

  final String id;
  final DateTime timestamp;
  final Glp1Medication medication;
  final double doseMg;
  final InjectionSite site;
  final int painLevel;
  final String? batchOrVialNote;
}

/// 時間序列濃度取樣點（供圖表繪製過去 14 天實線與未來 7 天預測虛線）
@immutable
class ConcentrationPoint {
  const ConcentrationPoint({
    required this.timestamp,
    required this.estimatedMg,
    required this.isFuturePrediction,
    this.triggeredDoseMg,
  });

  final DateTime timestamp;
  final double estimatedMg;
  final bool isFuturePrediction;
  final double? triggeredDoseMg;
}

/// 核心藥物動力學演算引擎 (Bateman Function + Superposition Principle)
class PharmacokineticsEngine {
  const PharmacokineticsEngine._();

  /// 過去回溯有效代謝視窗（60 天 = 1440 小時）
  static const int lookbackWindowHours = 60 * 24;

  /// 依據劑量回傳全 App 統一專屬色票
  static Color colorForDose(double doseMg) {
    if (doseMg <= 2.5) return const Color(0xFF9B87F5); // 2.5mg 薰衣草紫
    if (doseMg <= 5.0) return const Color(0xFF0EA5E9); // 5.0mg 海洋藍
    if (doseMg <= 7.5) return const Color(0xFF10B981); // 7.5mg 翡翠綠
    if (doseMg <= 10.0) return const Color(0xFFF97316); // 10.0mg 珊瑚橘
    if (doseMg <= 12.5) return const Color(0xFFEC4899); // 12.5mg 玫瑰紅
    return const Color(0xFF8B5CF6); // 15.0mg+ 皇家紫
  }

  /// 計算單次施打在經過 elapsedHours 小時後的體內殘留量 C_i(t)
  /// 公式: C_i(t) = D_i * (k_a / (k_a - k_e)) * (exp(-k_e * t) - exp(-k_a * t))
  static double singleDoseConcentrationAt({
    required double doseMg,
    required Glp1Medication medication,
    required double elapsedHours,
  }) {
    if (elapsedHours <= 0.0 ||
        elapsedHours > lookbackWindowHours ||
        doseMg <= 0.0) {
      return 0.0;
    }

    final double ka = medication.absorptionRateKa;
    final double ke = medication.eliminationRateKe;

    if ((ka - ke).abs() < 1e-6) {
      final double fallback =
          doseMg * ka * elapsedHours * math.exp(-ke * elapsedHours);
      return fallback.isFinite && fallback > 0.0 ? fallback : 0.0;
    }

    final double scaling = ka / (ka - ke);
    final double decayDiff =
        math.exp(-ke * elapsedHours) - math.exp(-ka * elapsedHours);
    final double concentration = doseMg * scaling * decayDiff;

    if (!concentration.isFinite || concentration < 0.0) {
      return 0.0;
    }
    return concentration;
  }

  /// 計算任一時間點 queryTime 的多劑疊加總濃度 C_total(T) = \sum C_i(T - t_i)
  static double totalConcentrationAt({
    required DateTime queryTime,
    required List<InjectionRecord> logs,
  }) {
    double totalMg = 0.0;
    for (final InjectionRecord log in logs) {
      final double diffHours =
          queryTime.difference(log.timestamp).inMinutes / 60.0;
      if (diffHours > 0.0 && diffHours <= lookbackWindowHours) {
        totalMg += singleDoseConcentrationAt(
          doseMg: log.doseMg,
          medication: log.medication,
          elapsedHours: diffHours,
        );
      }
    }
    return double.parse(totalMg.toStringAsFixed(4));
  }

  /// 產生過去 pastDays 天至未來 futureDays 天的平滑濃度曲線座標序列
  static List<ConcentrationPoint> generateTimelineSeries({
    required List<InjectionRecord> logs,
    required DateTime now,
    int pastDays = 14,
    int futureDays = 7,
    int stepHours = 3,
  }) {
    final int safeStep = math.max(1, stepHours);
    final DateTime startTime = now.subtract(Duration(days: pastDays));
    final DateTime endTime = now.add(Duration(days: futureDays));
    final int totalHours = endTime.difference(startTime).inHours;

    final List<ConcentrationPoint> series = <ConcentrationPoint>[];
    for (int h = 0; h <= totalHours; h += safeStep) {
      final DateTime pointTime = startTime.add(Duration(hours: h));
      final bool isFuture = pointTime.isAfter(now);
      final double conc = totalConcentrationAt(
        queryTime: pointTime,
        logs: logs,
      );

      double? triggeredDose;
      for (final InjectionRecord log in logs) {
        final double diffHrs =
            (pointTime.difference(log.timestamp).inMinutes / 60.0).abs();
        if (diffHrs < (safeStep / 2.0)) {
          triggeredDose = log.doseMg;
          break;
        }
      }

      series.add(
        ConcentrationPoint(
          timestamp: pointTime,
          estimatedMg: conc,
          isFuturePrediction: isFuture,
          triggeredDoseMg: triggeredDose,
        ),
      );
    }
    return series;
  }

  /// 防硬塊部位自動輪替建議：找出順時針下一順位的建議部位
  static InjectionSite recommendNextSite(List<InjectionRecord> logs) {
    if (logs.isEmpty) {
      return InjectionSite.rightLowerAbdomen;
    }
    final List<InjectionRecord> sorted = List<InjectionRecord>.from(logs)
      ..sort((InjectionRecord a, InjectionRecord b) =>
          b.timestamp.compareTo(a.timestamp));
    final InjectionSite lastSite = sorted.first.site;
    const List<InjectionSite> rotationOrder = InjectionSite.values;
    final int currentIndex = rotationOrder.indexOf(lastSite);
    final int nextIndex = (currentIndex + 1) % rotationOrder.length;
    return rotationOrder[nextIndex];
  }
}

/// 體內藥物濃度即時曲線繪圖器 (模擬 Swift Charts AreaMark + LineMark + RuleMark)
class PharmacokineticsChartPainter extends CustomPainter {
  PharmacokineticsChartPainter({
    required this.series,
    required this.primaryColor,
    required this.nowLabel,
  });

  final List<ConcentrationPoint> series;
  final Color primaryColor;
  final String nowLabel;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;

    const double topPad = 24.0;
    const double bottomPad = 22.0;
    final double chartHeight = math.max(10.0, size.height - topPad - bottomPad);
    final double chartWidth = size.width;

    double maxMg = 0.5;
    for (final ConcentrationPoint pt in series) {
      if (pt.estimatedMg > maxMg) {
        maxMg = pt.estimatedMg;
      }
    }
    maxMg *= 1.18; // 預留頂部呼吸空間

    // 1. 繪製水平參考格線
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.18)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final double y = topPad + chartHeight * (i / 3.0);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    Offset pointToOffset(int index) {
      final double x = (index / (series.length - 1)) * chartWidth;
      final double normalizedY = (series[index].estimatedMg / maxMg).clamp(0.0, 1.0);
      final double y = topPad + chartHeight * (1.0 - normalizedY);
      return Offset(x, y);
    }

    int nowIndex = series.indexWhere((ConcentrationPoint p) => p.isFuturePrediction) - 1;
    if (nowIndex < 0) nowIndex = series.length - 1;

    // 2. 繪製過去 14 天實線與漸層面積 (AreaMark)
    final Path pastLinePath = Path();
    final Path pastAreaPath = Path();
    final double baselineY = topPad + chartHeight;

    for (int i = 0; i <= nowIndex; i++) {
      final Offset pt = pointToOffset(i);
      if (i == 0) {
        pastLinePath.moveTo(pt.dx, pt.dy);
        pastAreaPath.moveTo(pt.dx, baselineY);
        pastAreaPath.lineTo(pt.dx, pt.dy);
      } else {
        final Offset prev = pointToOffset(i - 1);
        final double midX = (prev.dx + pt.dx) / 2.0;
        pastLinePath.cubicTo(midX, prev.dy, midX, pt.dy, pt.dx, pt.dy);
        pastAreaPath.cubicTo(midX, prev.dy, midX, pt.dy, pt.dx, pt.dy);
      }
    }

    final Offset nowOffset = pointToOffset(nowIndex);
    pastAreaPath.lineTo(nowOffset.dx, baselineY);
    pastAreaPath.close();

    final Paint areaPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, topPad),
        Offset(0, baselineY),
        <Color>[
          primaryColor.withValues(alpha: 0.38),
          primaryColor.withValues(alpha: 0.02),
        ],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(pastAreaPath, areaPaint);

    final Paint solidLinePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(pastLinePath, solidLinePaint);

    // 3. 繪製未來 7 天半衰期預測虛線 (Dashed LineMark)
    if (nowIndex < series.length - 1) {
      final Paint dashedPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.65)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;

      for (int i = nowIndex; i < series.length - 1; i++) {
        if (i.isEven) {
          final Offset p1 = pointToOffset(i);
          final Offset p2 = pointToOffset(i + 1);
          canvas.drawLine(p1, p2, dashedPaint);
        }
      }
    }

    // 4. 繪製垂直「Now（現在）」指示線 (RuleMark) 與當下濃度圓點
    final Paint rulePaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.45)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(nowOffset.dx, topPad - 6),
      Offset(nowOffset.dx, baselineY),
      rulePaint,
    );

    canvas.drawCircle(
      nowOffset,
      6.5,
      Paint()..color = primaryColor.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      nowOffset,
      4.0,
      Paint()..color = primaryColor,
    );

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: nowLabel,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double labelX = (nowOffset.dx - tp.width / 2).clamp(4.0, chartWidth - tp.width - 4.0);
    tp.paint(canvas, Offset(labelX, 4.0));
  }

  @override
  bool shouldRepaint(covariant PharmacokineticsChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.nowLabel != nowLabel;
  }
}

/// 首頁核心武器：體內藥物濃度即時曲線卡（含免費版高斯模糊鎖頭 & FDA 1.4.1 免責聲明）
class DoseConcentrationCard extends StatelessWidget {
  const DoseConcentrationCard({
    super.key,
    required this.logs,
    required this.now,
    required this.isProUnlocked,
    required this.onToggleProPreview,
    this.onOpenSwiftCodeDialog,
  });

  final List<InjectionRecord> logs;
  final DateTime now;
  final bool isProUnlocked;
  final VoidCallback onToggleProPreview;
  final VoidCallback? onOpenSwiftCodeDialog;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final double currentMg = PharmacokineticsEngine.totalConcentrationAt(
      queryTime: now,
      logs: logs,
    );
    final List<ConcentrationPoint> series =
        PharmacokineticsEngine.generateTimelineSeries(
      logs: logs,
      now: now,
    );
    final double latestDose = logs.isNotEmpty ? logs.first.doseMg : 5.0;
    final Color themeColor = PharmacokineticsEngine.colorForDose(latestDose);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(
          color: themeColor.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      color: Colors.white,
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
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
                    color: themeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        s.pkChartCardTitle,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        s.pkChartCardSubtitle,
                        style: const TextStyle(
                          fontSize: 12.0,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onOpenSwiftCodeDialog != null)
                  IconButton(
                    tooltip: 'Swift Charts Native Code',
                    onPressed: onOpenSwiftCodeDialog,
                    icon: const Icon(Icons.code_rounded, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                s.formatCurrentConcentration(currentMg),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: themeColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // 圖表區（支援免費用戶高斯模糊鎖頭）
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: isProUnlocked ? 0.0 : 6.5,
                    sigmaY: isProUnlocked ? 0.0 : 6.5,
                  ),
                  child: SizedBox(
                    height: 185,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: PharmacokineticsChartPainter(
                        series: series,
                        primaryColor: themeColor,
                        nowLabel: s.nowMarkerLabel,
                      ),
                    ),
                  ),
                ),
                if (!isProUnlocked)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.lock_rounded, color: themeColor, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          s.proBlurLockTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.proBlurLockDesc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: onToggleProPreview,
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: Text(s.unlockProButton),
                          style: FilledButton.styleFrom(
                            backgroundColor: themeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // 常駐 FDA 1.4.1 醫療文獻引用與免責聲明按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showMedicalCitationsModal(context),
                    icon: const Icon(Icons.verified_user_outlined, size: 16),
                    label: Text(
                      s.medicalDisclaimerButtonLabel,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onToggleProPreview,
                  child: Text(
                    isProUnlocked
                        ? context.locale.tr('切換免費模糊預覽', 'Preview Free Blur')
                        : context.locale.tr('免費預覽 Pro', 'Preview Pro'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMedicalCitationsModal(BuildContext context) {
    final AppStrings s = context.strings;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            s.medicalDisclaimerTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  s.medicalDisclaimerBody,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
                const Divider(height: 24),
                Text(
                  s.fdaCitationTirzepatide,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  s.fdaCitationSemaglutide,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  s.fdaCitationLiraglutide,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.locale.tr('我已了解', 'I Understand')),
            ),
          ],
        );
      },
    );
  }
}

/// 原生 iOS 17 SwiftUI + Swift Charts 完整參考實作匯出器
class SwiftReferenceExporter {
  const SwiftReferenceExporter._();

  static const String swiftChartsSourceCode = r'''
import SwiftUI
import Charts
import SwiftData

enum GLP1MedicationType: String, Codable, CaseIterable {
    case tirzepatide = "tirzepatide"
    case semaglutide = "semaglutide"
    case liraglutide = "liraglutide"

    var halfLifeHours: Double {
        switch self {
        case .tirzepatide: return 120.0 // 5 days
        case .semaglutide: return 168.0 // 7 days
        case .liraglutide: return 13.0  // 13 hours
        }
    }

    var absorptionRateKa: Double {
        switch self {
        case .tirzepatide: return 0.055 // Tmax ~36h
        case .semaglutide: return 0.038 // Tmax ~48h
        case .liraglutide: return 0.220 // Tmax ~11h
        }
    }

    var eliminationRateKe: Double {
        log(2.0) / halfLifeHours
    }
}

@Model
final class InjectionLog {
    var id: UUID
    var timestamp: Date
    var medicationRaw: String
    var doseMg: Double
    var siteRaw: String

    init(timestamp: Date, medication: GLP1MedicationType, doseMg: Double, siteRaw: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.medicationRaw = medication.rawValue
        self.doseMg = doseMg
        self.siteRaw = siteRaw
    }

    var medication: GLP1MedicationType {
        GLP1MedicationType(rawValue: medicationRaw) ?? .tirzepatide
    }
}

struct PKDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let concentrationMg: Double
    let isForecast: Bool
}

struct PharmacokineticsEngine {
    static let lookbackHours: Double = 60.0 * 24.0

    /// Bateman Function: C(t) = D * (ka / (ka - ke)) * (exp(-ke * t) - exp(-ka * t))
    static func singleDoseConcentration(doseMg: Double, med: GLP1MedicationType, elapsedHours t: Double) -> Double {
        guard t > 0, t <= lookbackHours, doseMg > 0 else { return 0.0 }
        let ka = med.absorptionRateKa
        let ke = med.eliminationRateKe
        guard abs(ka - ke) > 1e-6 else {
            return max(0.0, doseMg * ka * t * exp(-ke * t))
        }
        let scale = ka / (ka - ke)
        let level = doseMg * scale * (exp(-ke * t) - exp(-ka * t))
        return max(0.0, level)
    }

    /// Superposition Principle across 60-day window
    static func totalConcentration(at queryDate: Date, logs: [InjectionLog]) -> Double {
        logs.reduce(0.0) { acc, log in
            let elapsedHours = queryDate.timeIntervalSince(log.timestamp) / 3600.0
            return acc + singleDoseConcentration(doseMg: log.doseMg, med: log.medication, elapsedHours: elapsedHours)
        }
    }

    static func generateSeries(logs: [InjectionLog], now: Date = .now) -> [PKDataPoint] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -14, to: now),
              let end = cal.date(byAdding: .day, value: 7, to: now) else { return [] }
        var points: [PKDataPoint] = []
        var cursor = start
        while cursor <= end {
            let level = totalConcentration(at: cursor, logs: logs)
            points.append(PKDataPoint(date: cursor, concentrationMg: level, isForecast: cursor > now))
            cursor = cursor.addingTimeInterval(3 * 3600)
        }
        return points
    }
}

struct ConcentrationChartView: View {
    let logs: [InjectionLog]
    let isProUnlocked: Bool
    @State private var now: Date = .now

    var body: some View {
        let series = PharmacokineticsEngine.generateSeries(logs: logs, now: now)
        let currentMg = PharmacokineticsEngine.totalConcentration(at: now, logs: logs)

        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: "Active GLP-1 Level: %.2f mg", currentMg))
                .font(.headline)

            Chart {
                ForEach(series) { pt in
                    if !pt.isForecast {
                        AreaMark(
                            x: .value("Date", pt.date),
                            y: .value("mg", pt.concentrationMg)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.linearGradient(
                            colors: [.blue.opacity(0.38), .blue.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    }
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("mg", pt.concentrationMg)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: pt.isForecast ? [5, 4] : []))
                    .foregroundStyle(.blue)
                }
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(.primary.opacity(0.5))
                    .annotation(position: .top) {
                        Text("NOW").font(.caption2.bold())
                    }
            }
            .frame(height: 190)
            .blur(radius: isProUnlocked ? 0 : 7)
        }
        .padding()
    }
}
''';

  static void showSwiftCodeModal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: <Widget>[
              const Icon(Icons.apple_rounded, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.locale.tr(
                    'iOS 17 SwiftUI + Swift Charts 原生程式碼',
                    'iOS 17 SwiftUI + Swift Charts Native Code',
                  ),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: const SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                swiftChartsSourceCode,
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11.5,
                  height: 1.38,
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                  const ClipboardData(text: swiftChartsSourceCode),
                );
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.locale.tr(
                        '已複製完整 Swift Charts 程式碼至剪貼簿！',
                        'Copied full Swift Charts code to clipboard!',
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(context.locale.tr('一鍵複製 Swift 代碼', 'Copy Swift Code')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.locale.tr('關閉', 'Close')),
            ),
          ],
        );
      },
    );
  }
}
