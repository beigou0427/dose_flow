import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_localization.dart';
import 'haptic_feedback_service.dart';
import 'pharmacokinetics_engine.dart';

/// 生理副作用維度枚舉
enum SideEffectType {
  nausea('噁心反胃', 'Nausea'),
  fatigue('全身疲勞', 'Fatigue'),
  acidReflux('胃食道逆流/脹氣', 'Acid Reflux / Bloating'),
  constipation('排便不順/便祕', 'Constipation');

  const SideEffectType(this.labelZh, this.labelEn);
  final String labelZh;
  final String labelEn;

  String label(AppLanguage lang) => lang.isZh ? labelZh : labelEn;
}

/// 每日食慾雜音與副作用主觀紀錄模型 (PRD 第 2.4 節標準模型)
@immutable
class DailySideEffectLog {
  const DailySideEffectLog({
    required this.id,
    required this.date,
    required this.foodNoiseSuppression,
    this.nauseaLevel = 0,
    this.fatigueLevel = 0,
    this.acidRefluxLevel = 0,
    this.constipationLevel = 0,
    this.notes,
  });

  final String id;
  final DateTime date;

  /// 食慾抑制與腦中想吃東西雜音壓制程度：
  /// 5 = 完全安靜 (Optimal / Complete Silence)
  /// 4 = 顯著抑制 (Strongly Suppressed)
  /// 3 = 中度抑制 (Moderate Control)
  /// 2 = 雜音微浮現 (Mild Food Noise Creeping Back)
  /// 1 = 食慾全開/雜音巨大 (Full Food Noise / Breakthrough Hunger)
  final int foodNoiseSuppression;

  /// 生理副作用等級 (0 = 無, 1 = 輕微, 3 = 中度, 5 = 嚴重)
  final int nauseaLevel;
  final int fatigueLevel;
  final int acidRefluxLevel;
  final int constipationLevel;
  final String? notes;

  /// 綜合副作用嚴重度評分 (0 ~ 5)
  double get overallSymptomSeverity {
    final int maxLevel =
        math.max(math.max(nauseaLevel, fatigueLevel), math.max(acidRefluxLevel, constipationLevel));
    final double avg = (nauseaLevel + fatigueLevel + acidRefluxLevel + constipationLevel) / 4.0;
    return double.parse(((maxLevel * 0.7) + (avg * 0.3)).clamp(0.0, 5.0).toStringAsFixed(1));
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'date': date.toIso8601String(),
      'foodNoiseSuppression': foodNoiseSuppression,
      'nauseaLevel': nauseaLevel,
      'fatigueLevel': fatigueLevel,
      'acidRefluxLevel': acidRefluxLevel,
      'constipationLevel': constipationLevel,
      'notes': notes,
    };
  }

  factory DailySideEffectLog.fromMap(Map<String, dynamic> map) {
    return DailySideEffectLog(
      id: map['id'] as String? ?? 'se_${DateTime.now().millisecondsSinceEpoch}',
      date: map['date'] != null
          ? (DateTime.tryParse(map['date'] as String) ?? DateTime.now())
          : DateTime.now(),
      foodNoiseSuppression:
          ((map['foodNoiseSuppression'] as num?)?.toInt() ?? 5).clamp(1, 5),
      nauseaLevel: ((map['nauseaLevel'] as num?)?.toInt() ?? 0).clamp(0, 5),
      fatigueLevel: ((map['fatigueLevel'] as num?)?.toInt() ?? 0).clamp(0, 5),
      acidRefluxLevel:
          ((map['acidRefluxLevel'] as num?)?.toInt() ?? 0).clamp(0, 5),
      constipationLevel:
          ((map['constipationLevel'] as num?)?.toInt() ?? 0).clamp(0, 5),
      notes: map['notes'] as String?,
    );
  }
}

/// 施打後第 1~7 天關聯數據剖面模型
@immutable
class DayCorrelationProfile {
  const DayCorrelationProfile({
    required this.postShotDay,
    required this.avgFoodNoiseSuppression,
    required this.avgNausea,
    required this.avgFatigue,
    required this.avgAcidReflux,
    required this.avgConstipation,
    required this.sampleCount,
  });

  final int postShotDay; // 1 ~ 7
  final double avgFoodNoiseSuppression; // 1.0 ~ 5.0 (5=壓制最強/最安靜)
  final double avgNausea; // 0.0 ~ 5.0
  final double avgFatigue; // 0.0 ~ 5.0
  final double avgAcidReflux; // 0.0 ~ 5.0
  final double avgConstipation; // 0.0 ~ 5.0
  final int sampleCount;
}

/// 最優施打日動態排程建議模型
@immutable
class InjectionDayRecommendation {
  const InjectionDayRecommendation({
    required this.recommendedWeekday,
    required this.recommendedTimeLabel,
    required this.peakSymptomDayOffset,
    required this.rationaleZh,
    required this.rationaleEn,
  });

  final int recommendedWeekday; // 1 (Mon) ~ 7 (Sun)
  final String recommendedTimeLabel; // e.g. "週五 20:00"
  final int peakSymptomDayOffset; // e.g. Day 2
  final String rationaleZh;
  final String rationaleEn;

  String rationale(AppLanguage lang) => lang.isZh ? rationaleZh : rationaleEn;
}

/// 核心食慾雜音關聯分析與最佳施打日排程引擎
class FoodNoiseCorrelationEngine {
  const FoodNoiseCorrelationEngine._();

  /// 計算施打後第 1 ~ 7 天的雜音抑制與副作用平均剖面
  static List<DayCorrelationProfile> calculate7DayProfile({
    required List<DailySideEffectLog> sideEffectLogs,
    required List<InjectionRecord> injectionLogs,
  }) {
    // 依日期排序施打紀錄
    final List<InjectionRecord> sortedShots = List<InjectionRecord>.from(injectionLogs)
      ..sort((InjectionRecord a, InjectionRecord b) =>
          a.timestamp.compareTo(b.timestamp));

    // 建立 7 天的累加貯列
    final List<List<DailySideEffectLog>> dayBuckets =
        List<List<DailySideEffectLog>>.generate(7, (_) => <DailySideEffectLog>[]);

    for (final DailySideEffectLog seLog in sideEffectLogs) {
      // 找出該筆副作用紀錄之前最近的一筆施打
      InjectionRecord? priorShot;
      for (final InjectionRecord shot in sortedShots.reversed) {
        if (shot.timestamp.isBefore(seLog.date) ||
            shot.timestamp.isAtSameMomentAs(seLog.date)) {
          priorShot = shot;
          break;
        }
      }

      if (priorShot != null) {
        final double elapsedDays =
            seLog.date.difference(priorShot.timestamp).inHours / 24.0;
        final int dayIndex = elapsedDays.floor(); // 0 ~ 6 對應 Day 1 ~ 7
        if (dayIndex >= 0 && dayIndex < 7) {
          dayBuckets[dayIndex].add(seLog);
        }
      }
    }

    // 計算每日統計平均 (若無真實樣本，則以臨床 Bateman 藥代基線補齊)
    final List<DayCorrelationProfile> profiles = <DayCorrelationProfile>[];
    for (int d = 0; d < 7; d++) {
      final List<DailySideEffectLog> bucket = dayBuckets[d];
      if (bucket.isNotEmpty) {
        double sumNoise = 0;
        double sumNausea = 0;
        double sumFatigue = 0;
        double sumReflux = 0;
        double sumConstipation = 0;

        for (final DailySideEffectLog item in bucket) {
          sumNoise += item.foodNoiseSuppression;
          sumNausea += item.nauseaLevel;
          sumFatigue += item.fatigueLevel;
          sumReflux += item.acidRefluxLevel;
          sumConstipation += item.constipationLevel;
        }

        final int count = bucket.length;
        profiles.add(
          DayCorrelationProfile(
            postShotDay: d + 1,
            avgFoodNoiseSuppression:
                double.parse((sumNoise / count).toStringAsFixed(1)),
            avgNausea: double.parse((sumNausea / count).toStringAsFixed(1)),
            avgFatigue: double.parse((sumFatigue / count).toStringAsFixed(1)),
            avgAcidReflux: double.parse((sumReflux / count).toStringAsFixed(1)),
            avgConstipation:
                double.parse((sumConstipation / count).toStringAsFixed(1)),
            sampleCount: count,
          ),
        );
      } else {
        // 臨床預設經驗基準線 (Day 1-2 達峰壓制、Day 6-7 雜音回升)
        final List<double> defaultNoise = <double>[4.8, 4.6, 4.2, 3.8, 3.3, 2.6, 1.9];
        final List<double> defaultNausea = <double>[0.3, 0.4, 0.2, 0.1, 0.1, 0.0, 0.0];
        final List<double> defaultFatigue = <double>[0.4, 0.5, 0.3, 0.2, 0.1, 0.1, 0.0];

        profiles.add(
          DayCorrelationProfile(
            postShotDay: d + 1,
            avgFoodNoiseSuppression: defaultNoise[d],
            avgNausea: defaultNausea[d],
            avgFatigue: defaultFatigue[d],
            avgAcidReflux: 0.1,
            avgConstipation: 0.2,
            sampleCount: 0,
          ),
        );
      }
    }

    return profiles;
  }

  /// 智慧排程：依據個人副作用高峰動態推薦最優施打日與時段
  static InjectionDayRecommendation recommendOptimalInjectionTiming({
    required List<DailySideEffectLog> sideEffectLogs,
    required List<InjectionRecord> injectionLogs,
    required AppLanguage lang,
  }) {
    final List<DayCorrelationProfile> profiles = calculate7DayProfile(
      sideEffectLogs: sideEffectLogs,
      injectionLogs: injectionLogs,
    );

    int worstDayOffset = 2; // 預設第 2 天達峰
    double maxSeverity = -1;

    for (final DayCorrelationProfile p in profiles) {
      final double severity =
          math.max(p.avgFatigue, p.avgNausea) * 0.7 +
          (p.avgAcidReflux + p.avgConstipation) * 0.15;
      if (severity > maxSeverity) {
        maxSeverity = severity;
        worstDayOffset = p.postShotDay;
      }
    }

    int recommendedWeekday = DateTime.friday; // 預設週五
    if (worstDayOffset == 3) {
      recommendedWeekday = DateTime.thursday;
    } else if (worstDayOffset == 1) {
      recommendedWeekday = DateTime.friday;
    }

    final String dayNameZh =
        recommendedWeekday == DateTime.friday ? '週五晚間 (20:00)' : '週四晚間 (20:00)';
    final String dayNameEn =
        recommendedWeekday == DateTime.friday ? 'Friday Evening (8:00 PM)' : 'Thursday Evening (8:00 PM)';

    return InjectionDayRecommendation(
      recommendedWeekday: recommendedWeekday,
      recommendedTimeLabel: lang.isZh ? dayNameZh : dayNameEn,
      peakSymptomDayOffset: worstDayOffset,
      rationaleZh:
          '數據分析顯示您的生理副作用與疲勞感在施打後第 $worstDayOffset 天最顯著。建議將施打時間安排於 $dayNameZh，讓不適高峰落在週末睡眠與休息中充分消化。',
      rationaleEn:
          'Personalized analytics detect your peak fatigue and mild nausea around Day $worstDayOffset post-shot. We recommend scheduling injections on $dayNameEn so peak symptoms coincide with weekend recovery.',
    );
  }
}

/// 10 秒快速食慾雜音與副作用主觀評分對話框
class DailyFoodNoiseDialog extends StatefulWidget {
  const DailyFoodNoiseDialog({
    super.key,
    this.initialLog,
  });

  final DailySideEffectLog? initialLog;

  @override
  State<DailyFoodNoiseDialog> createState() => _DailyFoodNoiseDialogState();
}

class _DailyFoodNoiseDialogState extends State<DailyFoodNoiseDialog> {
  int _foodNoiseSuppression = 5;
  int _nausea = 0;
  int _fatigue = 0;
  int _acidReflux = 0;
  int _constipation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialLog != null) {
      _foodNoiseSuppression = widget.initialLog!.foodNoiseSuppression;
      _nausea = widget.initialLog!.nauseaLevel;
      _fatigue = widget.initialLog!.fatigueLevel;
      _acidReflux = widget.initialLog!.acidRefluxLevel;
      _constipation = widget.initialLog!.constipationLevel;
    }
  }

  String _getFoodNoiseDesc(int level, bool isZh) {
    switch (level) {
      case 5:
        return isZh ? '大腦完全安靜 (無想吃零食雜念)' : 'Complete Silence (Zero cravings)';
      case 4:
        return isZh ? '顯著抑制 (食慾穩定受控)' : 'Strong Suppression (Comfortable)';
      case 3:
        return isZh ? '中度抑制 (正餐正常、少雜音)' : 'Moderate Control (Mild appetite)';
      case 2:
        return isZh ? '雜音微浮現 (開始想找東西吃)' : 'Noise Creeping (Cravings returning)';
      default:
        return isZh ? '雜音巨大/食慾全開 (藥效明顯退去)' : 'Breakthrough Hunger (Peak cravings)';
    }
  }

  Color _getFoodNoiseColor(int level) {
    switch (level) {
      case 5:
        return const Color(0xFF10B981);
      case 4:
        return const Color(0xFF0EA5E9);
      case 3:
        return const Color(0xFF8B5CF6);
      case 2:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;
    final Color activeColor = _getFoodNoiseColor(_foodNoiseSuppression);

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Icon(Icons.psychology_rounded, color: activeColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isZh ? '今日大腦食慾雜音評分' : 'Daily Food Noise Check',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                isZh
                    ? '大腦中想吃甜食、零食的念頭壓制程度：'
                    : 'Level of mental chatter and craving suppression:',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: activeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$_foodNoiseSuppression分 — ${_getFoodNoiseDesc(_foodNoiseSuppression, isZh)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: activeColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List<Widget>.generate(5, (int index) {
                  final int score = index + 1;
                  final bool isSelected = score == _foodNoiseSuppression;
                  final Color c = _getFoodNoiseColor(score);
                  return ChoiceChip(
                    label: Text('$score'),
                    selected: isSelected,
                    selectedColor: c,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : c,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) {
                      HapticFeedbackService.selectionTick();
                      setState(() => _foodNoiseSuppression = score);
                    },
                  );
                }),
              ),
              const Divider(height: 24),
              Text(
                isZh ? '伴隨生理反應等級 (0=無 ~ 5=顯著)' : 'Accompanying Symptoms (0-5 Scale):',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _buildSymptomSlider(
                label: isZh ? '噁心反胃' : 'Nausea',
                value: _nausea,
                onChanged: (int v) => setState(() => _nausea = v),
              ),
              _buildSymptomSlider(
                label: isZh ? '全身疲勞' : 'Fatigue',
                value: _fatigue,
                onChanged: (int v) => setState(() => _fatigue = v),
              ),
              _buildSymptomSlider(
                label: isZh ? '胃酸逆流/脹氣' : 'Acid Reflux',
                value: _acidReflux,
                onChanged: (int v) => setState(() => _acidReflux = v),
              ),
              _buildSymptomSlider(
                label: isZh ? '便祕程度' : 'Constipation',
                value: _constipation,
                onChanged: (int v) => setState(() => _constipation = v),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isZh ? '取消' : 'Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            HapticFeedbackService.successPattern();
            final DailySideEffectLog log = DailySideEffectLog(
              id: 'se_${DateTime.now().millisecondsSinceEpoch}',
              date: DateTime.now(),
              foodNoiseSuppression: _foodNoiseSuppression,
              nauseaLevel: _nausea,
              fatigueLevel: _fatigue,
              acidRefluxLevel: _acidReflux,
              constipationLevel: _constipation,
            );
            Navigator.of(context).pop(log);
          },
          icon: const Icon(Icons.check_rounded, size: 16),
          label: Text(isZh ? '保存今日評分' : 'Save Rating'),
          style: FilledButton.styleFrom(
            backgroundColor: activeColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              activeColor: value > 2 ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9),
              onChanged: (double v) {
                HapticFeedbackService.selectionTick();
                onChanged(v.round());
              },
            ),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: value > 2 ? const Color(0xFFEF4444) : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
