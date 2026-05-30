import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/term.dart';

class WeekScheduleView extends StatelessWidget {
  const WeekScheduleView({
    required this.courses,
    required this.totalSections,
    required this.term,
    required this.selectedWeek,
    required this.courseNotes,
    required this.onCourseTap,
    required this.onCourseLongPress,
    super.key,
  });

  final List<Course> courses;
  final int totalSections;
  final Term term;
  final int selectedWeek;
  final Map<String, String> courseNotes;
  final ValueChanged<Course> onCourseTap;
  final ValueChanged<Course> onCourseLongPress;

  static const _days = ['一', '二', '三', '四', '五', '六', '日'];
  static const _timeColumnWidth = 34.0;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final today = DateTime.now();
    final bySlot = {
      for (final course in courses)
        '${course.dayOfWeek}-${course.startSection}': course,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        const headerHeight = 42.0;
        final rowHeight =
            ((constraints.maxHeight - headerHeight - 4) / totalSections)
                .clamp(32.0, 58.0);

        return Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: _timeColumnWidth),
                  for (var day = 1; day <= 7; day++)
                    Expanded(
                      child: Center(
                        child: _DayHeader(
                          dayText: '周${_days[day - 1]}',
                          date: term.dateForWeekday(
                            week: selectedWeek,
                            weekday: day,
                          ),
                          today: today,
                          onSurface: onSurface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: courses.isEmpty
                  ? Center(
                      child: Text(
                        '本周暂无课程',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: onSurface.withValues(alpha: 0.5),
                                ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(3, 0, 5, 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _timeColumnWidth,
                            child: Column(
                              children: [
                                for (var section = 1;
                                    section <= totalSections;
                                    section++)
                                  SizedBox(
                                    height: rowHeight,
                                    child: Center(
                                      child: Text(
                                        '$section',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: onSurface.withValues(
                                                  alpha: 0.45),
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          for (var day = 1; day <= 7; day++)
                            Expanded(
                              child: Stack(
                                children: [
                                  for (var section = 1;
                                      section <= totalSections;
                                      section++)
                                    Positioned(
                                      top: (section - 1) * rowHeight,
                                      left: 2,
                                      right: 2,
                                      height: rowHeight,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              color: onSurface.withValues(
                                                  alpha: 0.07),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  for (final entry in bySlot.entries)
                                    if (entry.value.dayOfWeek == day)
                                      _CourseBlock(
                                        course: entry.value,
                                        rowHeight: rowHeight,
                                        note: courseNotes[entry.value.noteKey],
                                        onTap: () => onCourseTap(entry.value),
                                        onLongPress: () =>
                                            onCourseLongPress(entry.value),
                                      ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.dayText,
    required this.date,
    required this.today,
    required this.onSurface,
  });

  final String dayText;
  final DateTime date;
  final DateTime today;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, today);
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dayText,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isToday ? primary : null,
                fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
              ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isToday) ...[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              '${date.month}/${date.day}',
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        isToday ? primary : onSurface.withValues(alpha: 0.55),
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.course,
    required this.rowHeight,
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  final Course course;
  final double rowHeight;
  final String? note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(course.name.hashCode);
    final top = (course.startSection - 1) * rowHeight + 2;
    final height = course.sectionSpan * rowHeight - 4;
    final compact = rowHeight < 42;
    final veryShort = height < 72;
    final weekLabel = _weekLabel(course.weeks);

    return Positioned(
      top: top,
      left: 3,
      right: 3,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Ink(
            padding: EdgeInsets.all(compact ? 3 : 5),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: 3,
                  child: Text(
                    course.name,
                    maxLines: veryShort ? 1 : (compact ? 2 : 3),
                    overflow: TextOverflow.ellipsis,
                    style: (compact
                            ? Theme.of(context).textTheme.labelSmall
                            : Theme.of(context).textTheme.labelMedium)
                        ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.foreground,
                      height: 1.02,
                    ),
                  ),
                ),
                if (!veryShort && course.location.isNotEmpty)
                  Flexible(
                    flex: 2,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        course.location,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: compact ? 9.5 : 10.5,
                              color: palette.foreground.withValues(alpha: 0.84),
                              height: 1.02,
                            ),
                      ),
                    ),
                  ),
                if (!compact && height >= 96 && weekLabel.isNotEmpty)
                  Text(
                    weekLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9.5,
                          color: palette.foreground.withValues(alpha: 0.68),
                          height: 1.0,
                        ),
                  ),
                if (note != null && note!.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      size: compact ? 10 : 12,
                      color: palette.foreground.withValues(alpha: 0.78),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _weekLabel(Set<int> weeks) {
    if (weeks.isEmpty) {
      return '';
    }
    final sorted = weeks.toList()..sort();
    final ranges = <String>[];
    var start = sorted.first;
    var previous = sorted.first;
    for (final week in sorted.skip(1)) {
      if (week == previous + 1) {
        previous = week;
        continue;
      }
      ranges.add(start == previous ? '$start' : '$start-$previous');
      start = week;
      previous = week;
    }
    ranges.add(start == previous ? '$start' : '$start-$previous');
    return '${ranges.join(',')}周';
  }
}

({Color background, Color border, Color foreground}) _paletteFor(int seed) {
  const colors = [
    Color(0xffd7efe6),
    Color(0xffffe1ce),
    Color(0xffd9e6ff),
    Color(0xffffedb8),
    Color(0xffdff0c9),
    Color(0xffffdbe5),
  ];

  final background = colors[seed.abs() % colors.length];
  final hsl = HSLColor.fromColor(background);
  final border =
      hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
  final foreground =
      hsl.withLightness((hsl.lightness - 0.58).clamp(0.0, 1.0)).toColor();
  return (background: background, border: border, foreground: foreground);
}
