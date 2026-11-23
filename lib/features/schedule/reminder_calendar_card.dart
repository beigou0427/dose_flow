import 'package:flutter/material.dart';
import '../../core/app_localization.dart';
import '../../core/app_theme.dart';
import '../../core/haptic_feedback_service.dart';
import '../../core/pharmacokinetics_engine.dart';
import '../../core/reminder_service.dart';

/// DoseFlow 1.1 智慧週期打卡日曆與本地推播設定卡片
class ReminderCalendarCard extends StatelessWidget {
  const ReminderCalendarCard({
    super.key,
    required this.logs,
    required this.shotReminderEnabled,
    required this.shotReminderWeekday,
    required this.shotReminderHour,
    required this.shotReminderMinute,
    required this.needlePrepReminderEnabled,
    required this.onChanged,
  });

  final List<InjectionRecord> logs;
  final bool shotReminderEnabled;
  final int shotReminderWeekday;
  final int shotReminderHour;
  final int shotReminderMinute;
  final bool needlePrepReminderEnabled;
  final void Function({
    bool? shotReminderEnabled,
    int? shotReminderWeekday,
    int? shotReminderHour,
    int? shotReminderMinute,
    bool? needlePrepReminderEnabled,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLanguage lang = context.locale.language;
    final bool isZh = lang.isZh;
    final DateTime now = DateTime.now();

    final InjectionRecord? lastLog = logs.isNotEmpty ? logs.first : null;
    final InjectionSite nextSite = PharmacokineticsEngine.recommendNextSite(logs);
    final Glp1Medication activeMed =
        lastLog?.medication ?? Glp1Medication.tirzepatide;

    final ({String title, String body}) notifCopy =
        ReminderService.buildNotificationCopy(
      lang: lang,
      weekday: shotReminderWeekday,
      medication: activeMed,
      lastSite: lastLog?.site,
      nextSite: nextSite,
    );

    // Compute 3-week calendar strip centered around today
    final DateTime startOfCurrentWeek =
        DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday % 7), // Sunday start
    );
    final DateTime gridStart =
        startOfCurrentWeek.subtract(const Duration(days: 7));

    final Set<String> loggedDays = logs
        .map((InjectionRecord r) =>
            '${r.timestamp.year}-${r.timestamp.month}-${r.timestamp.day}')
        .toSet();

    final DateTime nextShotDay = lastLog != null
        ? DateTime(
            lastLog.timestamp.year,
            lastLog.timestamp.month,
            lastLog.timestamp.day,
          ).add(const Duration(days: 7))
        : DateTime(now.year, now.month, now.day);
    final String nextShotKey =
        '${nextShotDay.year}-${nextShotDay.month}-${nextShotDay.day}';

    final List<String> weekdayHeaders = isZh
        ? const <String>['日', '一', '二', '三', '四', '五', '六']
        : const <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF122338), Color(0xFF0B1626)],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: Border.all(
          color: DoseFlowColors.cyan.withValues(alpha: 0.30),
          width: 1.2,
        ),
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
                  color: DoseFlowColors.cyan.withValues(alpha: 0.16),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: DoseFlowColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isZh ? '用藥日曆與智慧推播提醒' : 'Shot Calendar & Smart Reminders',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: DoseFlowColors.textPrimary,
                      ),
                    ),
                    Text(
                      isZh
                          ? '${now.year} 年 ${now.month} 月 · 每週自動追蹤排程'
                          : '${now.year}/${now.month} · Automated weekly schedule',
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
                    color: DoseFlowColors.mint.withValues(alpha: 0.38),
                  ),
                ),
                child: Text(
                  '${ReminderService.shortWeekdayLabel(shotReminderWeekday, lang)} ${ReminderService.formatTime(shotReminderHour, shotReminderMinute)}',
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
          // Frosted iOS-Style Live Notification Preview Banner
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF1A304A).withValues(alpha: 0.85),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(
                color: DoseFlowColors.mint.withValues(alpha: 0.42),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: DoseFlowColors.mint.withValues(alpha: 0.12),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.notifications_active_rounded,
                          size: 15,
                          color: DoseFlowColors.mint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isZh ? '瘦瘦針紀錄 Pro · 推播預覽' : 'DoseFlow · Alert Preview',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: DoseFlowColors.mint,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isZh ? '現在' : 'now',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: DoseFlowColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notifCopy.title,
                  style: const TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w800,
                    color: DoseFlowColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notifCopy.body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: DoseFlowColors.textSecondary,
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 3-Week Medication Calendar Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF08121E),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(color: DoseFlowColors.cardBorder),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: List<Widget>.generate(7, (int col) {
                    final bool isShotCol =
                        (shotReminderWeekday % 7) == col;
                    return Expanded(
                      child: Center(
                        child: Text(
                          weekdayHeaders[col],
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isShotCol
                                ? DoseFlowColors.mint
                                : DoseFlowColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                ...List<Widget>.generate(3, (int row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: List<Widget>.generate(7, (int col) {
                        final DateTime day =
                            gridStart.add(Duration(days: row * 7 + col));
                        final String key =
                            '${day.year}-${day.month}-${day.day}';
                        final bool isDone = loggedDays.contains(key);
                        final bool isNextShot = key == nextShotKey;
                        final bool isScheduledWeekday =
                            day.weekday == shotReminderWeekday &&
                                day.isAfter(now);

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isNextShot
                                  ? DoseFlowColors.mint
                                  : isDone
                                      ? DoseFlowColors.mint
                                          .withValues(alpha: 0.16)
                                      : Colors.transparent,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(10)),
                              border: isDone
                                  ? Border.all(
                                      color: DoseFlowColors.mint
                                          .withValues(alpha: 0.55),
                                    )
                                  : isScheduledWeekday && !isNextShot
                                      ? Border.all(
                                          color: DoseFlowColors.cyan
                                              .withValues(alpha: 0.45),
                                        )
                                      : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isNextShot || isDone
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    color: isNextShot
                                        ? const Color(0xFF041A18)
                                        : DoseFlowColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isNextShot
                                      ? '🎯'
                                      : isDone
                                          ? '🟢'
                                          : isScheduledWeekday
                                              ? '•'
                                              : '',
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    color: isScheduledWeekday
                                        ? DoseFlowColors.cyan
                                        : DoseFlowColors.mint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Weekday selector pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List<Widget>.generate(7, (int idx) {
              final int wd = idx + 1;
              final bool selected = wd == shotReminderWeekday;
              return ChoiceChip(
                label: Text(
                  ReminderService.shortWeekdayLabel(wd, lang),
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? const Color(0xFF041A18)
                        : DoseFlowColors.textSecondary,
                  ),
                ),
                selected: selected,
                selectedColor: DoseFlowColors.mint,
                backgroundColor: DoseFlowColors.cardElevated,
                side: BorderSide(
                  color: selected
                      ? DoseFlowColors.mint
                      : DoseFlowColors.cardBorder,
                ),
                onSelected: (_) {
                  HapticFeedbackService.selectionTick();
                  onChanged(shotReminderWeekday: wd);
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          // Toggle 1: Shot day reminder
          _ReminderSwitchTile(
            icon: Icons.alarm_on_rounded,
            title: isZh
                ? '施打日提醒：${ReminderService.shortWeekdayLabel(shotReminderWeekday, lang)} ${ReminderService.formatTime(shotReminderHour, shotReminderMinute)}'
                : 'Shot Day Alert: ${ReminderService.shortWeekdayLabel(shotReminderWeekday, lang)} ${ReminderService.formatTime(shotReminderHour, shotReminderMinute)}',
            subtitle: isZh
                ? '自動附帶本週建議施打部位與劑量'
                : 'Includes next recommended site & dose',
            value: shotReminderEnabled,
            onTapTitle: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: shotReminderHour,
                  minute: shotReminderMinute,
                ),
              );
              if (picked != null) {
                onChanged(
                  shotReminderHour: picked.hour,
                  shotReminderMinute: picked.minute,
                );
              }
            },
            onChanged: (bool val) {
              HapticFeedbackService.selectionTick();
              onChanged(shotReminderEnabled: val);
            },
          ),
          const SizedBox(height: 8),
          // Toggle 2: Needle & alcohol swab prep reminder
          _ReminderSwitchTile(
            icon: Icons.medical_services_rounded,
            title: isZh ? '更換針頭與消毒提醒' : 'Fresh Needle & Swab Prep Alert',
            subtitle: isZh
                ? '施打前 10 分鐘提醒準備新針頭與酒精棉片'
                : 'Reminds 10 minutes before scheduled shot',
            value: needlePrepReminderEnabled,
            onChanged: (bool val) {
              HapticFeedbackService.selectionTick();
              onChanged(needlePrepReminderEnabled: val);
            },
          ),
        ],
      ),
    );
  }
}

class _ReminderSwitchTile extends StatelessWidget {
  const _ReminderSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTapTitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTapTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DoseFlowColors.cardElevated,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: DoseFlowColors.cardBorder),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: DoseFlowColors.mint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTapTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: DoseFlowColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.0,
                      color: DoseFlowColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
