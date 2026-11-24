import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/app_localization.dart';
import '../../core/app_theme.dart';
import '../../core/pharmacokinetics_engine.dart';
import '../../core/behavioral_economics_engine.dart';
import '../../core/haptic_feedback_service.dart';
import '../duo/duo_layout_adapter.dart';

/// 療程核心痛點列舉（用於個人化抗掉肌肉與習慣計畫生成）
enum OnboardingPainPoint {
  muscleLoss(
    icon: Icons.fitness_center_rounded,
    titleZh: '擔心肌肉流失與皮膚鬆弛',
    titleEn: 'Fear of muscle loss & loose skin',
    descZh: '需要每日蛋白質目標推播與抗掉肌習慣',
    descEn: 'Requires daily protein tracking to protect lean mass',
  ),
  unknownConcentration(
    icon: Icons.trending_up_rounded,
    titleZh: '不確定體內藥量與下劑最佳時機',
    titleEn: 'Unclear active GLP-1 drug levels',
    descZh: '渴望掌握血中高峰點與半衰期衰退時間點',
    descEn: 'Needs real-time Bateman pharmacokinetics curve',
  ),
  siteBruising(
    icon: Icons.accessibility_new_rounded,
    titleZh: '常忘記打哪裡，導致硬塊或瘀青',
    titleEn: 'Injecting the same spot & bruising',
    descZh: '需要 8 大腹部輪替避開肚臍智慧引導',
    descEn: 'Needs smart rotation map to prevent lipohypertrophy',
  ),
  sideEffects(
    icon: Icons.sick_rounded,
    titleZh: '反胃噁心、胃食道逆流或便秘困擾',
    titleEn: 'Nausea, reflux & severe constipation',
    descZh: '需要水分補給提醒與排便打卡監測',
    descEn: 'Needs daily hydration & bowel movement logger',
  );

  const OnboardingPainPoint({
    required this.icon,
    required this.titleZh,
    required this.titleEn,
    required this.descZh,
    required this.descEn,
  });

  final IconData icon;
  final String titleZh;
  final String titleEn;
  final String descZh;
  final String descEn;

  String title(AppLanguage lang) => lang.isZh ? titleZh : titleEn;
  String desc(AppLanguage lang) => lang.isZh ? descZh : descEn;
}

/// Onboarding 輸出的使用者初始設定檔案
@immutable
class OnboardingProfileData {
  const OnboardingProfileData({
    required this.medication,
    required this.currentDoseMg,
    required this.daysSinceLastShot,
    required this.startWeight,
    required this.targetWeight,
    required this.selectedPainPoints,
  });

  final Glp1Medication medication;
  final double currentDoseMg;
  final int daysSinceLastShot;
  final double startWeight;
  final double targetWeight;
  final Set<OnboardingPainPoint> selectedPainPoints;

  int get estimatedWeeksToGoal {
    final double diff = (startWeight - targetWeight).abs();
    return math.max(4, (diff / 0.75).ceil());
  }
}

/// 首次啟動 5 步高轉換率 Onboarding 導引視圖
class OnboardingView extends StatefulWidget {
  const OnboardingView({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  final ValueChanged<OnboardingProfileData> onComplete;
  final VoidCallback onSkip;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  Glp1Medication _selectedMedication = Glp1Medication.tirzepatide;
  double _currentDoseMg = 2.5;
  int _daysSinceLastShot = 2;
  double _startWeight = 85.0;
  double _targetWeight = 70.0;
  final Set<OnboardingPainPoint> _selectedPainPoints = <OnboardingPainPoint>{
    OnboardingPainPoint.muscleLoss,
    OnboardingPainPoint.unknownConcentration,
  };

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    HapticFeedbackService.selectionTick();
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onComplete(
        OnboardingProfileData(
          medication: _selectedMedication,
          currentDoseMg: _currentDoseMg,
          daysSinceLastShot: _daysSinceLastShot,
          startWeight: _startWeight,
          targetWeight: _targetWeight,
          selectedPainPoints: _selectedPainPoints,
        ),
      );
    }
  }

  void _previousStep() {
    HapticFeedbackService.lightImpact();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = context.strings;
    final AppLanguage lang = context.locale.language;
    final WeightUnit unit = context.locale.weightUnit;
    final bool isZh = lang.isZh;

    return Scaffold(
      backgroundColor: DoseFlowColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: DoseFlowColors.textPrimary),
                onPressed: _previousStep,
              )
            : null,
        title: Row(
          children: List<Widget>.generate(5, (int index) {
            final bool isActive = index <= _currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 4.5,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: isActive
                      ? DoseFlowColors.mint
                      : DoseFlowColors.cardBorder,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
              ),
            );
          }),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: widget.onSkip,
            child: Text(
              isZh ? '略過' : 'Skip',
              style: const TextStyle(color: DoseFlowColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (int p) => setState(() => _currentStep = p),
          children: <Widget>[
            _buildStep1Medication(s, lang),
            _buildStep2DosageAndDate(s, lang),
            _buildStep3WeightGoal(s, lang, unit),
            _buildStep4PainPoints(s, lang),
            _buildStep5PlanRevealAndPaywall(s, lang, unit),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Medication(AppStrings s, AppLanguage lang) {
    final bool isZh = lang.isZh;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(
              isZh ? '步驟 1 / 5 ‧ 療程檔案建立' : 'Step 1 of 5 | Treatment Profile',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isZh ? '您目前正在使用哪種 GLP-1 療程？' : 'Which GLP-1 medication are you taking?',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: DoseFlowColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isZh
                ? '系統將依據該藥物公開 FDA 仿單半衰期參數，為您視覺化個人理論曲線參考：'
                : 'DoseFlow visualizes theoretical reference curves using published FDA half-life parameters:',
            style: const TextStyle(fontSize: 13, color: DoseFlowColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: Glp1Medication.values.map((Glp1Medication med) {
                final bool isSelected = med == _selectedMedication;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    onTap: () {
                      HapticFeedbackService.selectionTick();
                      setState(() => _selectedMedication = med);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DoseFlowColors.mint.withValues(alpha: 0.14)
                            : DoseFlowColors.cardSurface,
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        border: Border.all(
                          color: isSelected
                              ? DoseFlowColors.mint
                              : DoseFlowColors.cardBorder,
                          width: isSelected ? 2.0 : 1.2,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: isSelected
                                ? DoseFlowColors.mint
                                : DoseFlowColors.textMuted,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  med.displayName(lang),
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: DoseFlowColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isZh
                                      ? '消除半衰期 ~${med.halfLifeHours.toInt()} 小時 ‧ 吸收高峰 ~${med.peakHoursTmax.toInt()} 小時'
                                      : 'Half-life ~${med.halfLifeHours.toInt()}h | Peak absorption ~${med.peakHoursTmax.toInt()}h',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: DoseFlowColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _nextStep,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(isZh ? '下一步：設定當前劑量' : 'Next: Set Current Dose'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2DosageAndDate(AppStrings s, AppLanguage lang) {
    final bool isZh = lang.isZh;
    const List<double> standardDoses = <double>[2.5, 5.0, 7.5, 10.0, 12.5, 15.0];
    final Color doseColor = PharmacokineticsEngine.colorForDose(_currentDoseMg);

    final double activeResidualMg =
        PharmacokineticsEngine.singleDoseConcentrationAt(
      doseMg: _currentDoseMg,
      medication: _selectedMedication,
      elapsedHours: _daysSinceLastShot * 24.0,
    );

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(
              isZh ? '步驟 2 / 5 ‧ 體內代謝計算' : 'Step 2 of 5 | Active Pharmacokinetics',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isZh ? '您目前的處方紀錄劑量與上次打針日？' : 'What is your logged dose & last shot?',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: DoseFlowColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isZh
                ? '依您輸入的紀錄繪製理論半衰期視覺參考曲線（不代表實際血液檢測值）：'
                : 'Visualizes a theoretical half-life reference curve from your log (not a blood measurement):',
            style: const TextStyle(fontSize: 13, color: DoseFlowColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: doseColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: doseColor.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.bolt_rounded, color: doseColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isZh ? '雙指數 Bateman 理論模型參考' : 'Theoretical Bateman Model Reference',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: doseColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isZh
                            ? '理論推估參考值：~${activeResidualMg.toStringAsFixed(2)} mg'
                            : 'Theoretical reference estimate: ~${activeResidualMg.toStringAsFixed(2)} mg',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: DoseFlowColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isZh ? '目前處方單次紀錄劑量 (mg)' : 'Logged Prescribed Dose (mg)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DoseFlowColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: standardDoses.map((double d) {
              final bool isSel = (_currentDoseMg - d).abs() < 0.01;
              final Color c = PharmacokineticsEngine.colorForDose(d);
              return ChoiceChip(
                label: Text('${d.toStringAsFixed(1)} mg'),
                selected: isSel,
                selectedColor: c,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : c,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: c.withValues(alpha: 0.1),
                onSelected: (_) {
                  HapticFeedbackService.selectionTick();
                  setState(() => _currentDoseMg = d);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                isZh ? '上次注射距今幾天？' : 'Days Since Last Injection',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                isZh ? '$_daysSinceLastShot 天前' : '$_daysSinceLastShot days ago',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: doseColor),
              ),
            ],
          ),
          Slider(
            value: _daysSinceLastShot.toDouble(),
            min: 0,
            max: 14,
            divisions: 14,
            activeColor: doseColor,
            onChanged: (double v) {
              HapticFeedbackService.selectionTick();
              setState(() => _daysSinceLastShot = v.round());
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _nextStep,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(isZh ? '下一步：設定減重目標' : 'Next: Set Weight Goals'),
              style: FilledButton.styleFrom(
                backgroundColor: doseColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3WeightGoal(AppStrings s, AppLanguage lang, WeightUnit unit) {
    final bool isZh = lang.isZh;
    final double displayStart =
        unit == WeightUnit.lbs ? (_startWeight * 2.20462) : _startWeight;
    final double displayTarget =
        unit == WeightUnit.lbs ? (_targetWeight * 2.20462) : _targetWeight;
    final double weightDiff = (_startWeight - _targetWeight).clamp(0.0, 100.0);
    final double displayDiff =
        unit == WeightUnit.lbs ? (weightDiff * 2.20462) : weightDiff;
    final int estimatedWeeks = math.max(4, (weightDiff / 0.75).ceil());
    final double lossPercentage =
        _startWeight > 0 ? (weightDiff / _startWeight * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(
              isZh ? '步驟 3 / 5 ‧ 減重預測與願景' : 'Step 3 of 5 | Goal & Projection',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isZh ? '您的起始體重與理想目標？' : 'Set your start & target weight',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: DoseFlowColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isZh
                ? '依據一般溫和節奏 (約 0.75 kg/週) 估算個人追蹤參考時程：'
                : 'General pacing reference (~0.75 kg/week) for your personal milestone view:',
            style: const TextStyle(fontSize: 13, color: DoseFlowColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DoseFlowColors.mint.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(
                color: DoseFlowColors.mint.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.track_changes_rounded,
                        color: DoseFlowColors.mint, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isZh
                            ? '個人目標差距：-${displayDiff.toStringAsFixed(1)} ${unit.symbol} (${lossPercentage.toStringAsFixed(1)}%)'
                            : 'Target Goal: -${displayDiff.toStringAsFixed(1)} ${unit.symbol} (${lossPercentage.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: DoseFlowColors.mint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isZh
                      ? '⏱️ 參考追蹤時程：約 $estimatedWeeks 週 (約 ${(estimatedWeeks / 4.3).toStringAsFixed(1)} 個月)\n'
                          '💡 循序漸進記錄每週體重與日常習慣，穩定朝個人健康目標邁進。'
                      : '⏱️ Reference Timeline: ~$estimatedWeeks weeks (~${(estimatedWeeks / 4.3).toStringAsFixed(1)} months)\n'
                          '💡 Consistent weekly tracking helps you stay on course toward your wellness goal.',
                  style: const TextStyle(fontSize: 12.0, color: DoseFlowColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                isZh ? '起始體重' : 'Starting Weight',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                '${displayStart.toStringAsFixed(1)} ${unit.symbol}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0EA5E9),
                ),
              ),
            ],
          ),
          Slider(
            value: _startWeight.clamp(50.0, 160.0),
            min: 50.0,
            max: 160.0,
            divisions: 110,
            activeColor: const Color(0xFF0EA5E9),
            onChanged: (double v) {
              HapticFeedbackService.selectionTick();
              setState(() {
                _startWeight = v;
                if (_targetWeight >= _startWeight) {
                  _targetWeight = _startWeight - 5.0;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                isZh ? '理想目標體重' : 'Target Weight',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                '${displayTarget.toStringAsFixed(1)} ${unit.symbol}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          Slider(
            value: _targetWeight.clamp(40.0, _startWeight),
            min: 40.0,
            max: _startWeight,
            divisions: 120,
            activeColor: const Color(0xFF10B981),
            onChanged: (double v) {
              HapticFeedbackService.selectionTick();
              setState(() => _targetWeight = v);
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _nextStep,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(isZh ? '下一步：勾選療程痛點' : 'Next: Identify Pain Points'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4PainPoints(AppStrings s, AppLanguage lang) {
    final bool isZh = lang.isZh;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(
              isZh ? '步驟 4 / 5 ‧ 療程痛點剖析' : 'Step 4 of 5 | Pain Point Analysis',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isZh ? '療程中最讓您困擾或擔憂的是？' : 'What worries you most during treatment?',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: DoseFlowColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isZh
                ? '可複選。我們將依據您的勾選項目，量身定製微習慣打卡與輪替提醒：'
                : 'Select all that apply. We tailor your micro-habits and rotation reminders accordingly:',
            style: const TextStyle(fontSize: 13, color: DoseFlowColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: OnboardingPainPoint.values.map((OnboardingPainPoint p) {
                final bool isSelected = _selectedPainPoints.contains(p);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    onTap: () {
                      HapticFeedbackService.selectionTick();
                      setState(() {
                        if (isSelected) {
                          _selectedPainPoints.remove(p);
                        } else {
                          _selectedPainPoints.add(p);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DoseFlowColors.mint.withValues(alpha: 0.14)
                            : DoseFlowColors.cardSurface,
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        border: Border.all(
                          color: isSelected
                              ? DoseFlowColors.mint
                              : DoseFlowColors.cardBorder,
                          width: isSelected ? 1.8 : 1.1,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            isSelected
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: isSelected
                                ? DoseFlowColors.mint
                                : DoseFlowColors.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? DoseFlowColors.mint.withValues(alpha: 0.18)
                                  : DoseFlowColors.cardElevated,
                              borderRadius: const BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Icon(
                              p.icon,
                              color: isSelected
                                  ? DoseFlowColors.mint
                                  : DoseFlowColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  p.title(lang),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: DoseFlowColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.desc(lang),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: DoseFlowColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _nextStep,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(isZh ? '下一步：生成個人化計畫' : 'Next: Generate My Plan'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5PlanRevealAndPaywall(
      AppStrings s, AppLanguage lang, WeightUnit unit) {
    final bool isZh = lang.isZh;
    final bool isDuo = DuoDeviceDetector.isLargeScreen(context);
    final double weightDiff = (_startWeight - _targetWeight).clamp(0.0, 100.0);
    final double displayDiff =
        unit == WeightUnit.lbs ? (weightDiff * 2.20462) : weightDiff;
    final int estimatedWeeks = math.max(4, (weightDiff / 0.75).ceil());
    final Color doseColor = PharmacokineticsEngine.colorForDose(_currentDoseMg);

    final DateTime now = DateTime.now();
    final List<InjectionRecord> previewLogs = <InjectionRecord>[
      InjectionRecord(
        id: 'onboarding_preview',
        timestamp: now.subtract(Duration(days: _daysSinceLastShot)),
        medication: _selectedMedication,
        doseMg: _currentDoseMg,
        site: InjectionSite.rightLowerAbdomen,
      ),
    ];
    final List<ConcentrationPoint> series =
        PharmacokineticsEngine.generateTimelineSeries(
      logs: previewLogs,
      now: now,
      pastDays: 7,
      futureDays: 7,
      stepHours: 4,
    );

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(
              isZh ? '步驟 5 / 5 ‧ 個人化專屬計畫生成' : 'Step 5 of 5 | Personalized Plan',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF047857),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            BehavioralEconomicsEngine.getDuoExclusivePaywallHeadline(lang, isDuo),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: DoseFlowColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            BehavioralEconomicsEngine.getLossAversionSubtext(lang),
            style: const TextStyle(fontSize: 12.0, color: DoseFlowColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DoseFlowColors.cardSurface,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(color: doseColor.withValues(alpha: 0.35)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: PharmacokineticsChartPainter(
                        series: series,
                        primaryColor: doseColor,
                        nowLabel: s.nowMarkerLabel,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: DoseFlowColors.cardElevated.withValues(alpha: 0.94),
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(color: doseColor.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.lock_rounded, color: doseColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isZh
                            ? '專屬理論半衰期曲線已就緒'
                            : 'Personal Reference Curve Ready',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: doseColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: <Widget>[
                _buildSummaryBullet(
                  icon: Icons.medication_rounded,
                  color: doseColor,
                  title: isZh ? '當前紀錄藥物' : 'Logged Medication',
                  desc: '${_selectedMedication.displayName(lang)} (${_currentDoseMg.toStringAsFixed(1)} mg)',
                ),
                _buildSummaryBullet(
                  icon: Icons.track_changes_rounded,
                  color: DoseFlowColors.mint,
                  title: isZh ? '個人目標參考時程' : 'Goal Reference Timeline',
                  desc: isZh
                      ? '目標差距 -${displayDiff.toStringAsFixed(1)} ${unit.symbol}，參考約 $estimatedWeeks 週'
                      : 'Target: -${displayDiff.toStringAsFixed(1)} ${unit.symbol} (~$estimatedWeeks weeks)',
                ),
                _buildSummaryBullet(
                  icon: Icons.shield_rounded,
                  color: DoseFlowColors.cyan,
                  title: isZh ? '個人化習慣與部位輪替' : 'Habit Rings & Site Rotation',
                  desc: isZh
                      ? '每日蛋白質與補水目標 ✕ 8 大部位輪替避開肚臍'
                      : 'Daily protein & hydration rings + 8-quadrant smart rotation',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DoseFlowColors.mint.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: DoseFlowColors.mint.withValues(alpha: 0.6), width: 1.4),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.star_rounded, color: DoseFlowColors.mint, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isZh
                            ? '可於主畫面隨時升級 Pro（年繳方案含 3 天免費試用）'
                            : 'Optional Pro Upgrade Available (3-Day Free Trial on Annual)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: DoseFlowColors.textPrimary,
                        ),
                      ),
                      Text(
                        isZh
                            ? '提供月繳、年繳與終身方案，實際價格依 App Store 結帳顯示為準，可隨時取消'
                            : 'Monthly, Annual & Lifetime options available. Exact pricing shown in App Store checkout; cancel anytime.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: DoseFlowColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PulsingCtaButton(
            onPressed: _nextStep,
            icon: Icons.bolt_rounded,
            label: isZh
                ? '完成設定，進入今日儀表板'
                : 'Complete Setup & Enter Dashboard',
            color: DoseFlowColors.mint,
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _nextStep,
              child: Text(
                isZh ? '先以免費版體驗日誌' : 'Continue with Free Version',
                style: const TextStyle(fontSize: 12, color: DoseFlowColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBullet({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: DoseFlowColors.textPrimary,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11.5, color: DoseFlowColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}