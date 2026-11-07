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

  /// 針筒超量/危險數值雙重高危急促警報（抽過 100 Units）
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

/// 針筒專用動態阻尼機械觸感控制器（模擬精密活塞抽動阻尼）
class SyringeHapticEngine {
  SyringeHapticEngine();

  double _lastTrackedUnits = 0.0;
  DateTime _lastHapticTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// 節流防抖閥（防止手勢滑動過快造成 Taptic Engine 佇列阻塞）
  static const int _throttleIntervalMs = 28;

  /// 重設內部追蹤刻度
  void reset(double currentUnits) {
    _lastTrackedUnits = currentUnits;
    _lastHapticTime = DateTime.now();
  }

  /// 當針筒抽取格數發生變化時呼叫，自動映射對應觸覺阻尼
  void onUnitsChanged(double newUnits) {
    if (!HapticFeedbackService.isHapticsEnabled) return;

    final DateTime now = DateTime.now();
    if (now.difference(_lastHapticTime).inMilliseconds < _throttleIntervalMs) {
      return;
    }

    final int prevFloor = _lastTrackedUnits.floor();
    final int newFloor = newUnits.floor();

    // 1. 100 Units 超量物理極限警報（抽過滿管）
    if (_lastTrackedUnits <= 100.0 && newUnits > 100.0) {
      _lastHapticTime = now;
      _lastTrackedUnits = newUnits;
      HapticFeedbackService.warningPattern();
      return;
    }

    // 2. 50 Units 黃金里程碑磁吸感（跨越 50 格關鍵標線）
    if ((_lastTrackedUnits < 50.0 && newUnits >= 50.0) ||
        (_lastTrackedUnits > 50.0 && newUnits <= 50.0)) {
      _lastHapticTime = now;
      _lastTrackedUnits = newUnits;
      HapticFeedbackService.milestoneHit();
      return;
    }

    // 3. 10 Units 整數主刻度頓挫
    if (newFloor ~/ 10 != prevFloor ~/ 10) {
      _lastHapticTime = now;
      _lastTrackedUnits = newUnits;
      HapticFeedbackService.lightImpact();
      return;
    }

    // 4. 5 Units 次刻度微齒輪滴答
    if (newFloor ~/ 5 != prevFloor ~/ 5) {
      _lastHapticTime = now;
      _lastTrackedUnits = newUnits;
      HapticFeedbackService.selectionTick();
      return;
    }

    _lastTrackedUnits = newUnits;
  }

  /// 選擇標準劑量標籤時的機械觸感 (2.5mg, 5.0mg...)
  void onDoseSelected(double doseMg) {
    if (!HapticFeedbackService.isHapticsEnabled) return;
    HapticFeedbackService.lightImpact();
  }

  /// 成功打卡一筆施打紀錄時的深度確認感
  void onShotLogged() {
    if (!HapticFeedbackService.isHapticsEnabled) return;
    HapticFeedbackService.heavyImpact();
  }

  /// 完成蛋白質/飲水/順暢排便打卡時的成就雙脈衝
  void onHabitCompleted() {
    if (!HapticFeedbackService.isHapticsEnabled) return;
    HapticFeedbackService.successPattern();
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
