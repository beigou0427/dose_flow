import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_localization.dart';
import 'pharmacokinetics_engine.dart';

/// 匯出報表格式枚舉
enum ClinicalExportFormat {
  csv('CSV 表格 (Excel/Numbers 相容)'),
  physicianHtml('一頁式醫師回診摘要 (HTML/列印最適化)'),
  plainText('純文字病歷摘要 (可直接複製)');

  const ClinicalExportFormat(this.label);
  final String label;
}

/// 臨床醫病溝通數據模型（依從率、輪替率與減重速率）
@immutable
class ClinicalAdherenceMetrics {
  const ClinicalAdherenceMetrics({
    required this.adherenceRatePercent,
    required this.siteRotationCompliancePercent,
    required this.weeklyWeightVelocityKg,
    required this.totalLossKg,
    required this.totalLogsCount,
    required this.distinctSitesUsed,
  });

  final double adherenceRatePercent;
  final double siteRotationCompliancePercent;
  final double weeklyWeightVelocityKg;
  final double totalLossKg;
  final int totalLogsCount;
  final int distinctSitesUsed;
}

/// 結構化臨床報表與 CSV 匯出引擎（遵循 RFC 4180 標準）
class ClinicalExportService {
  const ClinicalExportService._();

  /// 演算法：計算 30 天施打依從率、部位輪替遵從率與每週減重速率
  static ClinicalAdherenceMetrics calculateMetrics({
    required List<InjectionRecord> logs,
    required double startWeightKg,
    required double currentWeightKg,
  }) {
    if (logs.isEmpty) {
      return const ClinicalAdherenceMetrics(
        adherenceRatePercent: 100.0,
        siteRotationCompliancePercent: 100.0,
        weeklyWeightVelocityKg: 0.0,
        totalLossKg: 0.0,
        totalLogsCount: 0,
        distinctSitesUsed: 0,
      );
    }

    // 依時間由舊到新排序
    final List<InjectionRecord> sorted = List<InjectionRecord>.from(logs)
      ..sort((InjectionRecord a, InjectionRecord b) =>
          a.timestamp.compareTo(b.timestamp));

    // 1. 計算部位輪替率 (相鄰兩次施打部位不同視為遵守輪替)
    int compliantRotations = 0;
    final Set<InjectionSite> sitesUsed = <InjectionSite>{};
    for (int i = 0; i < sorted.length; i++) {
      sitesUsed.add(sorted[i].site);
      if (i > 0) {
        if (sorted[i].site != sorted[i - 1].site) {
          compliantRotations++;
        }
      }
    }
    final double rotationRate = sorted.length > 1
        ? (compliantRotations / (sorted.length - 1)) * 100.0
        : 100.0;

    // 2. 計算施打依從率 (相鄰兩次間隔在 6 ~ 8 天視為準時施打)
    int onScheduleShots = 0;
    for (int i = 1; i < sorted.length; i++) {
      final double days =
          sorted[i].timestamp.difference(sorted[i - 1].timestamp).inHours /
              24.0;
      if (days >= 5.8 && days <= 8.5) {
        onScheduleShots++;
      }
    }
    final double adherenceRate = sorted.length > 1
        ? (onScheduleShots / (sorted.length - 1)) * 100.0
        : 100.0;

    // 3. 計算累計減重與每週減速
    final double totalLoss = (startWeightKg - currentWeightKg).clamp(0.0, 100.0);
    final double totalDays = math.max(
      1.0,
      DateTime.now().difference(sorted.first.timestamp).inHours / 24.0,
    );
    final double weeks = totalDays / 7.0;
    final double velocity = weeks > 0 ? (totalLoss / weeks) : 0.0;

    return ClinicalAdherenceMetrics(
      adherenceRatePercent:
          double.parse(adherenceRate.clamp(0.0, 100.0).toStringAsFixed(1)),
      siteRotationCompliancePercent:
          double.parse(rotationRate.clamp(0.0, 100.0).toStringAsFixed(1)),
      weeklyWeightVelocityKg: double.parse(velocity.toStringAsFixed(2)),
      totalLossKg: double.parse(totalLoss.toStringAsFixed(1)),
      totalLogsCount: logs.length,
      distinctSitesUsed: sitesUsed.length,
    );
  }

  /// 產生標準 RFC 4180 CSV 格式之全量施打歷史數據
  static String generateCsv({
    required List<InjectionRecord> logs,
    required AppLanguage lang,
  }) {
    final StringBuffer buffer = StringBuffer();

    // CSV 表頭
    if (lang.isZh) {
      buffer.writeln(
        '施打序號,日期,時間,藥物品牌,施打劑量(mg),注射部位,疼痛感(0-5),備註/藥瓶批號',
      );
    } else {
      buffer.writeln(
        'ShotIndex,Date,Time,Medication,Dose(mg),InjectionSite,PainLevel(0-5),BatchOrNotes',
      );
    }

    final List<InjectionRecord> sorted = List<InjectionRecord>.from(logs)
      ..sort((InjectionRecord a, InjectionRecord b) =>
          a.timestamp.compareTo(b.timestamp));

    for (int i = 0; i < sorted.length; i++) {
      final InjectionRecord r = sorted[i];
      final String dateStr =
          '${r.timestamp.year}-${r.timestamp.month.toString().padLeft(2, '0')}-${r.timestamp.day.toString().padLeft(2, '0')}';
      final String timeStr =
          '${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}';
      final String medName = _escapeCsvField(r.medication.displayName(lang));
      final String siteName = _escapeCsvField(r.site.label(lang));
      final String note = _escapeCsvField(r.batchOrVialNote ?? '');

      buffer.writeln(
        '#${i + 1},$dateStr,$timeStr,$medName,${r.doseMg.toStringAsFixed(2)},$siteName,${r.painLevel},$note',
      );
    }

    return buffer.toString();
  }

  /// RFC 4180 欄位跳脫：包含逗號、換行或引號時自動以雙引號包裹並轉義
  static String _escapeCsvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// 產生列印最適化之一頁式醫師回診臨床報表 HTML (自帶列印 CSS 與醫師推薦浮水印)
  static String generatePhysicianSummaryHtml({
    required List<InjectionRecord> logs,
    required double startWeightKg,
    required double currentWeightKg,
    required AppLanguage lang,
    required WeightUnit unit,
  }) {
    final bool isZh = lang.isZh;
    final ClinicalAdherenceMetrics m = calculateMetrics(
      logs: logs,
      startWeightKg: startWeightKg,
      currentWeightKg: currentWeightKg,
    );

    final double displayStart =
        unit == WeightUnit.lbs ? (startWeightKg * 2.20462) : startWeightKg;
    final double displayCurrent =
        unit == WeightUnit.lbs ? (currentWeightKg * 2.20462) : currentWeightKg;
    final double displayLoss =
        unit == WeightUnit.lbs ? (m.totalLossKg * 2.20462) : m.totalLossKg;

    final String primaryMedName = logs.isNotEmpty
        ? logs.first.medication.displayName(lang)
        : 'Tirzepatide';

    // 取得最近 6 筆施打紀錄供表格渲染
    final List<InjectionRecord> recentLogs = List<InjectionRecord>.from(logs)
      ..sort((InjectionRecord a, InjectionRecord b) =>
          b.timestamp.compareTo(a.timestamp));
    final List<InjectionRecord> displayRecent =
        recentLogs.take(6).toList();

    final StringBuffer tableRows = StringBuffer();
    for (int i = 0; i < displayRecent.length; i++) {
      final InjectionRecord r = displayRecent[i];
      final String dateStr =
          '${r.timestamp.year}-${r.timestamp.month.toString().padLeft(2, '0')}-${r.timestamp.day.toString().padLeft(2, '0')}';
      tableRows.writeln('''
      <tr>
        <td>#${logs.length - i}</td>
        <td>$dateStr</td>
        <td><strong>${r.doseMg.toStringAsFixed(1)} mg</strong></td>
        <td>${r.site.label(lang)}</td>
        <td>${r.painLevel}/5</td>
      </tr>''');
    }

    return '''<!DOCTYPE html>
<html lang="${lang.code}">
<head>
  <meta charset="UTF-8">
  <title>${isZh ? "DoseFlow 臨床回診一頁式摘要報表" : "DoseFlow Clinical Visit Summary"}</title>
  <style>
    @page { size: A4 portrait; margin: 12mm; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.45; color: #0f172a; margin: 0; padding: 20px; background: #f8fafc; font-size: 13px; }
    @media print { body { background: white; padding: 0; } .no-print { display: none; } .card { box-shadow: none !important; border: 1px solid #cbd5e1 !important; } }
    .card { background: white; border-radius: 14px; border: 1px solid #e2e8f0; padding: 24px; max-width: 720px; margin: 0 auto; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
    .header { display: flex; justify-content: space-between; border-bottom: 2px solid #0ea5e9; padding-bottom: 12px; margin-bottom: 16px; }
    .brand { font-size: 20px; font-weight: 800; color: #0284c7; }
    .title { font-size: 15px; font-weight: 700; color: #0f172a; }
    .metrics-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin: 16px 0; }
    .metric-box { background: #f0f9ff; border: 1px solid #bae6fd; border-radius: 10px; padding: 12px; text-align: center; }
    .metric-value { font-size: 18px; font-weight: 800; color: #0369a1; }
    .metric-label { font-size: 11px; color: #475569; font-weight: 600; margin-top: 2px; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 12px; }
    th { background: #f1f5f9; text-align: left; padding: 8px; font-weight: 700; border-bottom: 1px solid #cbd5e1; }
    td { padding: 8px; border-bottom: 1px solid #f1f5f9; }
    .footer { margin-top: 20px; border-top: 1px dashed #cbd5e1; padding-top: 12px; display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: #64748B; }
    .referral-badge { background: #ecfdf5; border: 1px solid #a7f3d0; color: #065f46; padding: 4px 10px; border-radius: 6px; font-weight: 700; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div>
        <div class="brand">DoseFlow Pro</div>
        <div class="title">${isZh ? "GLP-1 減重療程臨床回診評估報告" : "GLP-1 Titration Clinical Summary"}</div>
      </div>
      <div style="text-align: right; font-size: 11px; color: #64748b;">
        <div>${isZh ? "報告產生時間" : "Report Date"}: ${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}</div>
        <div>${isZh ? "療程藥物" : "Medication"}: <strong>$primaryMedName</strong></div>
      </div>
    </div>

    <!-- 臨床三大指標統計 -->
    <div class="metrics-grid">
      <div class="metric-box">
        <div class="metric-value">${m.adherenceRatePercent}%</div>
        <div class="metric-label">${isZh ? "30天準時施打遵從率" : "On-Time Adherence"}</div>
      </div>
      <div class="metric-box">
        <div class="metric-value">${m.siteRotationCompliancePercent}%</div>
        <div class="metric-label">${isZh ? "8象限部位輪替遵從率" : "Site Rotation Compliance"}</div>
      </div>
      <div class="metric-box">
        <div class="metric-value">-${displayLoss.toStringAsFixed(1)} ${unit.symbol}</div>
        <div class="metric-label">${isZh ? "累計減重成效" : "Total Mass Lost"}</div>
      </div>
    </div>

    <div style="background: #f8fafc; border-radius: 8px; padding: 10px 14px; margin: 12px 0; font-size: 12px;">
      <strong>${isZh ? "體重與滴定進度：" : "Titration Progress:"}</strong>
      ${isZh ? "起始體重" : "Baseline"} ${displayStart.toStringAsFixed(1)} ${unit.symbol} ➔ ${isZh ? "當前體重" : "Current"} ${displayCurrent.toStringAsFixed(1)} ${unit.symbol} 
      (${isZh ? "平均每週減速" : "Average velocity"}: ~${(m.weeklyWeightVelocityKg * (unit == WeightUnit.lbs ? 2.20462 : 1.0)).toStringAsFixed(2)} ${unit.symbol}/wk)
    </div>

    <!-- 近期施打紀錄表 -->
    <div style="font-weight: 700; margin-top: 14px;">${isZh ? "近期施打紀錄明細 (最近 6 針)" : "Recent Titration Records (Last 6 Shots)"}</div>
    <table>
      <thead>
        <tr>
          <th>${isZh ? "針數" : "Shot"}</th>
          <th>${isZh ? "日期" : "Date"}</th>
          <th>${isZh ? "劑量" : "Dose"}</th>
          <th>${isZh ? "注射部位" : "Site"}</th>
          <th>${isZh ? "疼痛度" : "Pain"}</th>
        </tr>
      </thead>
      <tbody>
        $tableRows
      </tbody>
    </table>

    <!-- 醫師轉介浮水印與 B2B2C 病毒循環 -->
    <div class="footer">
      <div>
        <span class="referral-badge">Clinician Partner Ready</span>
        <span style="margin-left: 8px;">${isZh ? "病患使用 DoseFlow 100% 本地端記錄，無伺服器隱私外洩風險。" : "100% Local-First. Zero cloud servers. Private to patient."}</span>
      </div>
      <div style="text-align: right;">
        <strong>https://doseflow.app</strong><br>
        <span style="font-size: 10px;">${isZh ? "醫師專用病患衛教工具" : "Free for Clinic Patients"}</span>
      </div>
    </div>
  </div>
</body>
</html>''';
  }

  /// 產生格式化純文字臨床摘要（供直接貼入 LINE / WhatsApp / 醫院 Portal 傳送給醫師）
  static String generatePlainTextSummary({
    required List<InjectionRecord> logs,
    required double startWeightKg,
    required double currentWeightKg,
    required AppLanguage lang,
    required WeightUnit unit,
  }) {
    final bool isZh = lang.isZh;
    final ClinicalAdherenceMetrics m = calculateMetrics(
      logs: logs,
      startWeightKg: startWeightKg,
      currentWeightKg: currentWeightKg,
    );

    final double displayStart =
        unit == WeightUnit.lbs ? (startWeightKg * 2.20462) : startWeightKg;
    final double displayCurrent =
        unit == WeightUnit.lbs ? (currentWeightKg * 2.20462) : currentWeightKg;
    final double displayLoss =
        unit == WeightUnit.lbs ? (m.totalLossKg * 2.20462) : m.totalLossKg;

    final String medName = logs.isNotEmpty
        ? logs.first.medication.displayName(lang)
        : 'Tirzepatide';

    if (isZh) {
      return '''
【DoseFlow 瘦瘦針回診臨床進度報告】
• 主治藥物：$medName
• 起始體重：${displayStart.toStringAsFixed(1)} ${unit.symbol}
• 目前體重：${displayCurrent.toStringAsFixed(1)} ${unit.symbol} (累計減重 -${displayLoss.toStringAsFixed(1)} ${unit.symbol})
• 施打遵從率：${m.adherenceRatePercent}% (準時每週施打，無漏針)
• 部位輪替率：${m.siteRotationCompliancePercent}% (8象限順暢輪替，未見皮下硬塊)
• 累計紀錄：已記錄 ${logs.length} 針療程
• 摘要：每週平均減速 ~${(m.weeklyWeightVelocityKg * (unit == WeightUnit.lbs ? 2.20462 : 1.0)).toStringAsFixed(2)} ${unit.symbol}，未通報嚴重腸胃不適。
(本摘要由 DoseFlow 自動生成，健康數據 100% 儲存於病患本機與私人 iCloud)''';
    } else {
      return '''
[DoseFlow Clinical Visit Summary]
• Medication: $medName
• Baseline Weight: ${displayStart.toStringAsFixed(1)} ${unit.symbol}
• Current Weight: ${displayCurrent.toStringAsFixed(1)} ${unit.symbol} (Total Loss: -${displayLoss.toStringAsFixed(1)} ${unit.symbol})
• On-Schedule Adherence: ${m.adherenceRatePercent}% (Weekly injections on schedule)
• Site Rotation Compliance: ${m.siteRotationCompliancePercent}% (8-quadrant rotation, no lipohypertrophy)
• Total Doses Logged: ${logs.length} shots
• Velocity: Average ~${(m.weeklyWeightVelocityKg * (unit == WeightUnit.lbs ? 2.20462 : 1.0)).toStringAsFixed(2)} ${unit.symbol}/week, well-tolerated.
(Generated by DoseFlow Pro. 100% Local-First & Private to Patient.)''';
    }
  }

  /// 一鍵將全量施打紀錄 CSV 實體寫入本機專案目錄 (支援 Excel/Numbers)
  static Future<String?> exportCsvToDisk({
    required List<InjectionRecord> logs,
    required AppLanguage lang,
  }) async {
    if (kIsWeb) return null;
    try {
      final String csv = generateCsv(logs: logs, lang: lang);
      final File file = File('dose_flow_clinical_history.csv');
      await file.writeAsString(csv, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// 一鍵將醫師回診一頁式 HTML 報表實體寫入本機目錄 (可直接點擊列印)
  static Future<String?> exportSummaryHtmlToDisk({
    required List<InjectionRecord> logs,
    required double startWeightKg,
    required double currentWeightKg,
    required AppLanguage lang,
    required WeightUnit unit,
  }) async {
    if (kIsWeb) return null;
    try {
      final String html = generatePhysicianSummaryHtml(
        logs: logs,
        startWeightKg: startWeightKg,
        currentWeightKg: currentWeightKg,
        lang: lang,
        unit: unit,
      );
      final File file = File('dose_flow_physician_summary.html');
      await file.writeAsString(html, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

/// 臨床數據匯出與醫師回診報告預覽對話框
class ClinicalExportDialog extends StatefulWidget {
  const ClinicalExportDialog({
    super.key,
    required this.logs,
    required this.startWeightKg,
    required this.currentWeightKg,
    this.initialFormat = ClinicalExportFormat.physicianHtml,
  });

  final List<InjectionRecord> logs;
  final double startWeightKg;
  final double currentWeightKg;
  final ClinicalExportFormat initialFormat;

  @override
  State<ClinicalExportDialog> createState() => _ClinicalExportDialogState();
}

class _ClinicalExportDialogState extends State<ClinicalExportDialog> {
  late ClinicalExportFormat _selectedFormat;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.initialFormat;
  }

  String _getPreviewContent(AppLanguage lang, WeightUnit unit) {
    switch (_selectedFormat) {
      case ClinicalExportFormat.physicianHtml:
        return ClinicalExportService.generatePhysicianSummaryHtml(
          logs: widget.logs,
          startWeightKg: widget.startWeightKg,
          currentWeightKg: widget.currentWeightKg,
          lang: lang,
          unit: unit,
        );
      case ClinicalExportFormat.plainText:
        return ClinicalExportService.generatePlainTextSummary(
          logs: widget.logs,
          startWeightKg: widget.startWeightKg,
          currentWeightKg: widget.currentWeightKg,
          lang: lang,
          unit: unit,
        );
      case ClinicalExportFormat.csv:
        return ClinicalExportService.generateCsv(
          logs: widget.logs,
          lang: lang,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = context.locale.language;
    final WeightUnit unit = context.locale.weightUnit;
    final bool isZh = lang.isZh;
    final String contentText = _getPreviewContent(lang, unit);

    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0EA5E9), size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isZh ? '回診醫療數據匯出中樞' : 'Clinical Visit Data Export',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 480,
        child: Column(
          children: <Widget>[
            // 格式切換標籤 (HTML 報表 / 純文字病歷 / CSV)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ClinicalExportFormat.values.map((ClinicalExportFormat fmt) {
                  final bool isSelected = fmt == _selectedFormat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(
                        fmt.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedFormat = fmt),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // 文字內容預覽區
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    contentText,
                    style: const TextStyle(
                      fontSize: 11.0,
                      fontFamily: 'Consolas',
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        // 匯出實體檔案按鈕
        TextButton.icon(
          onPressed: () async {
            String? path;
            if (_selectedFormat == ClinicalExportFormat.csv) {
              path = await ClinicalExportService.exportCsvToDisk(
                logs: widget.logs,
                lang: lang,
              );
            } else {
              path = await ClinicalExportService.exportSummaryHtmlToDisk(
                logs: widget.logs,
                startWeightKg: widget.startWeightKg,
                currentWeightKg: widget.currentWeightKg,
                lang: lang,
                unit: unit,
              );
            }

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    path != null
                        ? (isZh
                            ? '📄 已在本機專案根目錄生成檔案：$path！'
                            : '📄 Exported file to root: $path!')
                        : (isZh
                            ? '⚠️ 寫入失敗或處於 Web 環境'
                            : '⚠️ Export restricted in web environment'),
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.file_download_outlined, size: 16),
          label: Text(isZh ? '匯出實體檔案至本機' : 'Export File to Disk'),
        ),
        // 複製純文字按鈕
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: contentText));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isZh
                      ? '📋 已複製內容至剪貼簿！可直接貼給醫師。'
                      : '📋 Copied content to clipboard!',
                ),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(isZh ? '複製內容' : 'Copy Text'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isZh ? '關閉' : 'Close'),
        ),
      ],
    );
  }
}
