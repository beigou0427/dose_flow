import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_localization.dart';
import 'pharmacokinetics_engine.dart';

/// DoseFlow 1.1 本地智慧週期推播排程服務
/// 透過原生 iOS UNUserNotificationCenter MethodChannel 排程，零第三方套件風險，測試沙盒自動絕緣
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const MethodChannel _channel =
      MethodChannel('com.doseflow.app/notifications');

  static bool get _isIsolatedSandbox {
    if (kIsWeb) return true;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
      if (!Platform.isIOS) return true;
    } catch (_) {
      return true;
    }
    return false;
  }

  /// 產生系統通知文案（推播與 App 內即時預覽完全一致）
  static ({String title, String body}) buildNotificationCopy({
    required AppLanguage lang,
    required int weekday,
    required Glp1Medication medication,
    required InjectionSite? lastSite,
    required InjectionSite nextSite,
  }) {
    if (lang.isZh) {
      final String dayName = weekdayLabel(weekday, lang);
      final String medName = switch (medication) {
        Glp1Medication.tirzepatide => '猛健樂',
        Glp1Medication.semaglutide => '週纖達',
        Glp1Medication.liraglutide => '善纖達',
      };
      final String lastSiteLabel =
          lastSite != null ? lastSite.label(lang) : '左大腿';
      return (
        title: '施打提醒：今天$dayName是$medName施打日囉！',
        body: '上週打在「$lastSiteLabel」，今天建議打在「${nextSite.label(lang)}」，點擊記錄劑量。',
      );
    }

    final String dayName = weekdayLabel(weekday, lang);
    final String medName = switch (medication) {
      Glp1Medication.tirzepatide => 'Mounjaro / Zepbound',
      Glp1Medication.semaglutide => 'Wegovy / Ozempic',
      Glp1Medication.liraglutide => 'Saxenda',
    };
    final String lastSiteLabel =
        lastSite != null ? lastSite.label(lang) : 'Left Thigh';
    return (
      title: 'Shot Reminder: Today ($dayName) is $medName day!',
      body:
          'Last shot: $lastSiteLabel. Recommended today: ${nextSite.label(lang)}. Tap to log dose.',
    );
  }

  static String weekdayLabel(int weekday, AppLanguage lang) {
    const List<String> zh = <String>[
      '星期一',
      '星期二',
      '星期三',
      '星期四',
      '星期五',
      '星期六',
      '星期日',
    ];
    const List<String> en = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final int idx = (weekday - 1).clamp(0, 6);
    return lang.isZh ? zh[idx] : en[idx];
  }

  static String shortWeekdayLabel(int weekday, AppLanguage lang) {
    const List<String> zh = <String>['每週一', '每週二', '每週三', '每週四', '每週五', '每週六', '每週日'];
    const List<String> en = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final int idx = (weekday - 1).clamp(0, 6);
    return lang.isZh ? zh[idx] : en[idx];
  }

  static String formatTime(int hour, int minute) {
    final String hh = hour.clamp(0, 23).toString().padLeft(2, '0');
    final String mm = minute.clamp(0, 59).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// 請求本地通知權限並套用每週施打／消毒換針排程
  Future<bool> syncReminders({
    required bool shotReminderEnabled,
    required bool needlePrepReminderEnabled,
    required int weekday,
    required int hour,
    required int minute,
    required AppLanguage lang,
    required Glp1Medication medication,
    required InjectionSite? lastSite,
    required InjectionSite nextSite,
  }) async {
    if (_isIsolatedSandbox) return true;

    try {
      if (!shotReminderEnabled && !needlePrepReminderEnabled) {
        await _channel.invokeMethod<void>('cancelAllReminders');
        return true;
      }

      final bool granted =
          await _channel.invokeMethod<bool>('requestPermission') ?? false;
      if (!granted) return false;

      final ({String title, String body}) copy = buildNotificationCopy(
        lang: lang,
        weekday: weekday,
        medication: medication,
        lastSite: lastSite,
        nextSite: nextSite,
      );

      final String prepTitle = lang.isZh
          ? '🧴 更換針頭與酒精消毒提醒'
          : '🧴 Fresh Needle & Alcohol Prep';
      final String prepBody = lang.isZh
          ? '10 分鐘後為預定施打時間，請準備全新無菌針頭與酒精棉片。'
          : '10 minutes until your scheduled shot. Prepare a new sterile needle and alcohol swab.';

      await _channel.invokeMethod<void>(
        'scheduleWeeklyReminders',
        <String, dynamic>{
          'shotEnabled': shotReminderEnabled,
          'prepEnabled': needlePrepReminderEnabled,
          'weekday': weekday, // Dart 1=Mon..7=Sun
          'hour': hour,
          'minute': minute,
          'shotTitle': copy.title,
          'shotBody': copy.body,
          'prepTitle': prepTitle,
          'prepBody': prepBody,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
