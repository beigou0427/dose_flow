import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 觸感反饋類型枚舉
enum HapticFeedbackType {
  selection,
  light,
  medium,
  heavy,
  milestone,
  success,
  warning,
  error,
}

/// 醫療級微觸感反饋服務（模擬精密儀器齒輪機械手感）
class HapticFeedbackService {
  const HapticFeedbackService._();

  /// 全域開關（供使用者於設定頁自由開啟/關閉震動）
  static bool isHapticsEnabled = true;

  /// 十大防雷鐵律 06：測試沙盒與 Web 環境物理絕緣保護盾
  static bool get _isShielded {
    if (kIsWeb) return true;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
    } catch (_) {
      return true;
    }
    return false;
  }

  /// 輕微齒輪滴答感（用於滑桿每一格、單位微調）
  static Future<void> selectionTick() async {
    if (!isHapticsEnabled || _isShielded) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// 輕度機械頓挫（用於常用處方標籤切換）
  static Future<void> lightImpact() async {
    if (!isHapticsEnabled || _isShielded) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// 中度頓挫（用於模式切換：現成藥液 <-> 乾粉泡製）
  static Future<void> mediumImpact() async {
    if (!isHapticsEnabled || _isShielded) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// 深度機械鎖定（用於打卡成功、劑量大檔位確認）
  static Future<void> heavyImpact() async {
    if (!isHapticsEnabled || _isShielded) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// 50 Units 黃金里程碑共振（雙脈衝複合觸感）
  static Future<void> milestoneHit() async {
    if (!isHapticsEnabled || _isShielded) return;
    try {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 65));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// 達成打卡成功觸覺回饋（蛋白質/飲水/順暢排便完成）
  static Future<void> successPattern() async {
    if (!isHapticsEnabled || _isShielded) return;
    try {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 75));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// 警告提示觸覺回饋
  static Future<void> warningPattern() async {
    if (!isHapticsEnabled || _isShielded) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}

/// 全域觸覺回饋設定控制器（繼承 ChangeNotifier，可與 UI 開關即時連動）
class HapticSettingsController extends ChangeNotifier {
  HapticSettingsController._();

  static final HapticSettingsController instance =
      HapticSettingsController._();

  bool get isEnabled => HapticFeedbackService.isHapticsEnabled;

  set isEnabled(bool value) {
    if (HapticFeedbackService.isHapticsEnabled == value) return;
    HapticFeedbackService.isHapticsEnabled = value;
    notifyListeners();
  }

  void toggle() {
    isEnabled = !isEnabled;
  }

  /// 觸感展示自檢方法（供設定頁面讓使用者試按試震）
  Future<void> previewHaptic(HapticFeedbackType type) async {
    switch (type) {
      case HapticFeedbackType.selection:
        await HapticFeedbackService.selectionTick();
      case HapticFeedbackType.light:
        await HapticFeedbackService.lightImpact();
      case HapticFeedbackType.medium:
        await HapticFeedbackService.mediumImpact();
      case HapticFeedbackType.heavy:
        await HapticFeedbackService.heavyImpact();
      case HapticFeedbackType.milestone:
        await HapticFeedbackService.milestoneHit();
      case HapticFeedbackType.success:
        await HapticFeedbackService.successPattern();
      case HapticFeedbackType.warning:
      case HapticFeedbackType.error:
        await HapticFeedbackService.warningPattern();
    }
  }
}
