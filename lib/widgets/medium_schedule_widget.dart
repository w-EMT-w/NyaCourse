import 'package:flutter/material.dart';

import '../logic/schedule_status_calculator.dart';
import '../models/course_model.dart';
import 'course_timeline_item.dart';
import 'empty_schedule_card.dart';

class MediumScheduleWidget extends StatelessWidget {
  const MediumScheduleWidget({
    required this.dateLabel,
    required this.status,
    required this.courses,
    required this.courseStates,
    super.key,
  });

  final String dateLabel;
  final ScheduleStatusResult status;
  final List<CourseModel> courses;
  final Map<String, CourseTimelineState> courseStates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (status.status == ScheduleStatusType.holiday) {
      return EmptyScheduleCard(
        title: status.titleText,
        subtitle: '${status.subtitleText} · ${status.timeText}',
        icon: Icons.celebration_outlined,
      );
    }

    if (status.status == ScheduleStatusType.noClass || courses.isEmpty) {
      return const EmptyScheduleCard(
        title: '今天没有课程',
        subtitle: '可以安排自习、运动或休息',
        icon: Icons.weekend_outlined,
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 300, maxWidth: 430),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff15191d) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.16 : 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isDark ? const Color(0xff20bd7a) : null,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.7),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < courses.length; index++) ...[
            CourseTimelineItem(
              course: courses[index],
              state: courseStates[courses[index].id] ??
                  CourseTimelineState.upcoming,
            ),
            if (index != courses.length - 1) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
