import 'package:flutter/material.dart';
import '../../core/app_localization.dart';
import '../../core/app_theme.dart';
import '../../core/haptic_feedback_service.dart';
import '../../core/pharmacokinetics_engine.dart';
import '../rotation/body_rotation_map.dart';

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
      color: DoseFlowColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(
          color: DoseFlowColors.mint.withValues(alpha: 0.30),
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
                  color: DoseFlowColors.mint,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isZh
                        ? '人體 8 大注射部位輪替清單'
                        : '8-Zone Injection Site Rotation Selector',
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w800,
                      color: DoseFlowColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isZh
                  ? '腹部施打請避開肚臍周圍 5 公分 (2 吋)。紅點為上次部位，綠點為系統建議本次輪替部位：'
                  : 'Avoid 2 inches (5cm) around the navel. Red = Last Shot, Green = Suggested Next:',
              style: const TextStyle(
                fontSize: 12.0,
                color: DoseFlowColors.textSecondary,
              ),
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
                  color: DoseFlowColors.mint,
                  label: isZh ? '建議本次 (綠點)' : 'Suggested (Green)',
                ),
                _buildLegendDot(
                  color: DoseFlowColors.cyan,
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
              childAspectRatio: 2.8,
              children: InjectionSite.values.map((InjectionSite site) {
                final bool isLast = site == lastInjectedSite;
                final bool isRec = site == recommendedSite;
                final bool isSelected = site == selectedSite;

                Color dotColor = DoseFlowColors.textMuted;
                if (isLast) dotColor = const Color(0xFFEF4444);
                if (isRec) dotColor = DoseFlowColors.mint;

                return InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onTap: () {
                    HapticFeedbackService.selectionTick();
                    onSiteSelected(site);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? DoseFlowColors.cyan.withValues(alpha: 0.16)
                          : DoseFlowColors.cardElevated,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      border: Border.all(
                        color: isSelected
                            ? DoseFlowColors.cyan
                            : isRec
                                ? DoseFlowColors.mint.withValues(alpha: 0.55)
                                : DoseFlowColors.cardBorder,
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
                              color: DoseFlowColors.textPrimary,
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
            color: DoseFlowColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Tab 2 完整頁面：個人施打日誌、視覺化部位輪替與歷史紀錄（純記錄工具，無劑量計算功能）
class ShotLogView extends StatefulWidget {
  const ShotLogView({
    super.key,
    required this.logs,
    required this.onAddLog,
    this.onDeleteLog,
  });

  final List<InjectionRecord> logs;
  final ValueChanged<InjectionRecord> onAddLog;
  final ValueChanged<String>? onDeleteLog;

  @override
  State<ShotLogView> createState() => _ShotLogViewState();
}

class _ShotLogViewState extends State<ShotLogView> {
  static const List<double> _commonPrescribedDoses = <double>[
    0.25,
    0.5,
    1.0,
    1.7,
    2.4,
    2.5,
    5.0,
    7.5,
    10.0,
    12.5,
    15.0,
  ];

  late Glp1Medication _selectedMedication;
  late double _loggedDoseMg;
  late InjectionSite _selectedSite;
  int _painLevel = 1;

  @override
  void initState() {
    super.initState();
    // 預設僅帶入使用者上一次自行記錄的藥物與劑量，絕不推薦或計算劑量
    if (widget.logs.isNotEmpty) {
      _selectedMedication = widget.logs.first.medication;
      _loggedDoseMg = widget.logs.first.doseMg;
    } else {
      _selectedMedication = Glp1Medication.tirzepatide;
      _loggedDoseMg = 2.5;
    }
    _selectedSite = PharmacokineticsEngine.recommendNextSite(widget.logs);
  }

  void _handleRecordShot() {
    final InjectionRecord newRecord = InjectionRecord(
      id: 'shot_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      medication: _selectedMedication,
      doseMg: _loggedDoseMg,
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
            '✅ 已新增 ${_loggedDoseMg.toStringAsFixed(_loggedDoseMg % 1 == 0 ? 1 : 2)} mg 施打紀錄，個人週期曲線已即時更新！',
            '✅ Logged ${_loggedDoseMg.toStringAsFixed(_loggedDoseMg % 1 == 0 ? 1 : 2)} mg injection! Timeline updated.',
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final String y = dt.year.toString();
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  String _formatDose(double dose) {
    return dose == dose.roundToDouble() || (dose * 10) == (dose * 10).roundToDouble()
        ? dose.toStringAsFixed(1)
        : dose.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;
    final Color doseColor = PharmacokineticsEngine.colorForDose(_loggedDoseMg);
    final InjectionSite? lastSite =
        widget.logs.isNotEmpty ? widget.logs.first.site : null;
    final InjectionSite recommendedSite =
        PharmacokineticsEngine.recommendNextSite(widget.logs);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        // 1. 視覺化人體施打部位輪替地圖
        BodyRotationMapCard(
          logs: widget.logs,
          activeDoseMg: _loggedDoseMg,
          activeMedication: _selectedMedication,
          onConfirmInjection: (InjectionSite site) {
            setState(() => _selectedSite = site);
            _handleRecordShot();
          },
        ),
        const SizedBox(height: 16),
        // 2. 新增今日施打紀錄卡片（僅供記錄醫師處方劑量與部位）
        Card(
          elevation: 0,
          color: DoseFlowColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            side: BorderSide(
              color: doseColor.withValues(alpha: 0.35),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: doseColor.withValues(alpha: 0.14),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Icon(
                        Icons.edit_calendar_rounded,
                        color: doseColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            isZh ? '新增今日施打紀錄' : 'Log Today\'s Injection',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: DoseFlowColors.textPrimary,
                            ),
                          ),
                          Text(
                            isZh
                                ? '僅記錄醫師處方劑量與施打部位，本程式不計算或建議劑量'
                                : 'Log your prescribed dose & site only — no dosage calculations',
                            style: const TextStyle(
                              fontSize: 11.0,
                              color: DoseFlowColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<Glp1Medication>(
                  initialValue: _selectedMedication,
                  decoration: InputDecoration(
                    labelText: isZh ? '記錄藥物類型' : 'Logged Medication',
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
                      HapticFeedbackService.selectionTick();
                      setState(() => _selectedMedication = val);
                    }
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  isZh ? '處方標籤劑量 (mg)' : 'Prescribed Dose Label (mg)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: DoseFlowColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonPrescribedDoses.map((double d) {
                    final Color c = PharmacokineticsEngine.colorForDose(d);
                    final bool selected = (_loggedDoseMg - d).abs() < 0.001;
                    return ChoiceChip(
                      label: Text(
                        '${_formatDose(d)} mg',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.0,
                          color: selected ? Colors.white : c,
                        ),
                      ),
                      selected: selected,
                      selectedColor: c,
                      backgroundColor: c.withValues(alpha: 0.12),
                      onSelected: (_) {
                        HapticFeedbackService.selectionTick();
                        setState(() => _loggedDoseMg = d);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      isZh ? '施打不適感記錄 (0 無感 ~ 5 明顯)' : 'Comfort / Pain Log (0-5)',
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: DoseFlowColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$_painLevel / 5',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: doseColor,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _painLevel.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  activeColor: doseColor,
                  onChanged: (double v) {
                    HapticFeedbackService.selectionTick();
                    setState(() => _painLevel = v.round());
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _handleRecordShot,
                    icon: const Icon(Icons.add_task_rounded),
                    label: Text(
                      isZh
                          ? '確認記錄 ${_formatDose(_loggedDoseMg)} mg 於 ${_selectedSite.label(lang)}'
                          : 'Log ${_formatDose(_loggedDoseMg)} mg at ${_selectedSite.label(lang)}',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: doseColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 3. 8 大部位輪替互動清單
        BodySiteRotationSelector(
          lastInjectedSite: lastSite,
          recommendedSite: recommendedSite,
          selectedSite: _selectedSite,
          onSiteSelected: (InjectionSite site) {
            setState(() => _selectedSite = site);
          },
        ),
        const SizedBox(height: 16),
        // 4. 近期施打歷史紀錄列表
        Card(
          elevation: 0,
          color: DoseFlowColors.cardSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: DoseFlowColors.cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.history_rounded,
                      color: DoseFlowColors.cyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isZh
                            ? '近期施打歷史紀錄 (${widget.logs.length} 筆)'
                            : 'Recent Injection History (${widget.logs.length})',
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w800,
                          color: DoseFlowColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.logs.isEmpty)
                  Text(
                    isZh ? '尚無施打紀錄。' : 'No injections logged yet.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: DoseFlowColors.textSecondary,
                    ),
                  )
                else
                  ...widget.logs.take(10).map((InjectionRecord log) {
                    final Color itemColor =
                        PharmacokineticsEngine.colorForDose(log.doseMg);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: DoseFlowColors.cardElevated,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(14)),
                        border: Border.all(color: DoseFlowColors.cardBorder),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.16),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(10)),
                              border: Border.all(
                                color: itemColor.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              '${_formatDose(log.doseMg)} mg',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w800,
                                color: itemColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  log.site.label(lang),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: DoseFlowColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatDate(log.timestamp)} · ${log.medication.displayName(lang)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.0,
                                    color: DoseFlowColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.onDeleteLog != null &&
                              widget.logs.length > 1)
                            IconButton(
                              tooltip: isZh ? '刪除此紀錄' : 'Delete log',
                              onPressed: () => widget.onDeleteLog!(log.id),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: DoseFlowColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
