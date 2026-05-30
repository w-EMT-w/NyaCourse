import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../models/course.dart';
import '../models/term.dart';
import 'app_settings_store.dart';
import 'course_time.dart';

class ScheduleWidgetService {
  const ScheduleWidgetService();

  static const mediumProviderName = 'ScheduleMediumWidgetProvider';

  Future<void> sync(ScheduleWidgetData data) async {
    final values = data.toMap();
    for (final entry in values.entries) {
      final value = entry.value;
      if (value is int) {
        await HomeWidget.saveWidgetData<int>(entry.key, value);
      } else if (value is bool) {
        await HomeWidget.saveWidgetData<bool>(entry.key, value);
      } else {
        await HomeWidget.saveWidgetData<String>(entry.key, value.toString());
      }
    }
    await HomeWidget.updateWidget(androidName: mediumProviderName);
  }

  ScheduleWidgetData buildData({
    required List<Course> courses,
    required Term term,
    required DateTime now,
    required ThemeMode appThemeMode,
    required ScheduleWidgetAppearanceMode appearanceMode,
    required bool showRoom,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final todayCourses = _coursesForDate(courses, term, today);
    final dateTitle = '今天 · ${_weekdayLabel(now.weekday)}';
    final darkMode = switch (appearanceMode) {
      ScheduleWidgetAppearanceMode.dark => true,
      ScheduleWidgetAppearanceMode.light => false,
      ScheduleWidgetAppearanceMode.paper => false,
      ScheduleWidgetAppearanceMode.system => appThemeMode == ThemeMode.dark,
    };
    final widgetAppearanceMode = switch (appearanceMode) {
      ScheduleWidgetAppearanceMode.dark => 'dark',
      ScheduleWidgetAppearanceMode.light => 'light',
      ScheduleWidgetAppearanceMode.paper => 'paper',
      ScheduleWidgetAppearanceMode.system =>
        appThemeMode == ThemeMode.dark ? 'dark' : 'light',
    };
    final sourceCoursesJson = _sourceCoursesJson(courses);
    final termStartMs = term.startDate.millisecondsSinceEpoch;

    if (todayCourses.isEmpty) {
      final tomorrow = _nextCourseAfter(courses, term, now, sameDayOnly: false);
      return ScheduleWidgetData(
        darkMode: darkMode,
        appearanceMode: widgetAppearanceMode,
        showRoom: showRoom,
        sourceCoursesJson: sourceCoursesJson,
        termStartMs: termStartMs,
        dateTitle: dateTitle,
        stateLabel: '今日无课',
        statusLabel: '今天没课',
        title: tomorrow == null ? '今天没有课程' : tomorrow.course.name,
        subtitle: tomorrow == null
            ? '可以安排自习、运动或休息'
            : '${_futureDayLabel(now, tomorrow.startsAt)} ${_clockLabel(tomorrow.startsAt)}',
        location: showRoom ? (tomorrow?.course.location ?? '') : '',
        timeLabel: tomorrow == null ? '' : _timeRange(tomorrow.course),
        rightPrimary: tomorrow == null ? '--' : _clockLabel(tomorrow.startsAt),
        rightSecondary: tomorrow == null ? '休息一下' : '下一节',
        nextName: tomorrow?.course.name ?? '',
        nextTime: tomorrow == null ? '' : _clockLabel(tomorrow.startsAt),
        footerLeft: '',
        footerRight: '',
        courses: const [],
      );
    }

    for (final item in todayCourses) {
      final endAt = _courseEndsAt(today, item.course);
      if (!now.isBefore(item.startsAt) && now.isBefore(endAt)) {
        final minutes = _ceilMinutes(endAt.difference(now));
        final next = _nextCourseAfter(courses, term, endAt, sameDayOnly: true);
        return ScheduleWidgetData(
          darkMode: darkMode,
          appearanceMode: widgetAppearanceMode,
          showRoom: showRoom,
          sourceCoursesJson: sourceCoursesJson,
          termStartMs: termStartMs,
          dateTitle: dateTitle,
          stateLabel: '上课中',
          statusLabel: '现在',
          title: item.course.name,
          subtitle: _timeRange(item.course),
          location: showRoom ? item.course.location : '',
          timeLabel: _timeRange(item.course),
          rightPrimary: '$minutes',
          rightSecondary: '分钟后下课',
          nextName: next?.course.name ?? '',
          nextTime: next == null ? '' : _clockLabel(next.startsAt),
          footerLeft: _nextFooter(todayCourses, now),
          footerRight: '',
          courses: _widgetCourses(todayCourses, now),
        );
      }
    }

    final nextToday = _nextCourseAfter(courses, term, now, sameDayOnly: true);
    if (nextToday != null) {
      _CourseStart? previous;
      for (final item in todayCourses) {
        if (_courseEndsAt(today, item.course).isBefore(now)) {
          previous = item;
        }
      }
      final minutes = _ceilMinutes(nextToday.startsAt.difference(now));
      final breakTime = previous != null;
      return ScheduleWidgetData(
        darkMode: darkMode,
        appearanceMode: widgetAppearanceMode,
        showRoom: showRoom,
        sourceCoursesJson: sourceCoursesJson,
        termStartMs: termStartMs,
        dateTitle: dateTitle,
        stateLabel: breakTime ? '课间空档' : '今日有课',
        statusLabel: breakTime ? '下节' : '下一节课',
        title: breakTime ? '课间休息' : nextToday.course.name,
        subtitle: breakTime
            ? '下一节课：${nextToday.course.name}'
            : _timeRange(nextToday.course),
        location: showRoom ? nextToday.course.location : '',
        timeLabel: _timeRange(nextToday.course),
        rightPrimary: '$minutes',
        rightSecondary: '分钟后上课',
        nextName: nextToday.course.name,
        nextTime: _clockLabel(nextToday.startsAt),
        footerLeft: _nextFooter(todayCourses, now),
        footerRight: '',
        courses: _widgetCourses(todayCourses, now),
      );
    }

    final tomorrow = _nextCourseAfter(courses, term, now, sameDayOnly: false);
    return ScheduleWidgetData(
      darkMode: darkMode,
      appearanceMode: widgetAppearanceMode,
      showRoom: showRoom,
      sourceCoursesJson: sourceCoursesJson,
      termStartMs: termStartMs,
      dateTitle: dateTitle,
      stateLabel: '已结束',
      statusLabel: '已结束',
      title: '今日课程已结束',
      subtitle: tomorrow == null ? '明天见' : '明天第一节：${tomorrow.course.name}',
      location: showRoom ? (tomorrow?.course.location ?? '') : '',
      timeLabel: tomorrow == null ? '' : _timeRange(tomorrow.course),
      rightPrimary: tomorrow == null ? '✓' : _clockLabel(tomorrow.startsAt),
      rightSecondary: tomorrow == null ? '明天见' : '明天',
      nextName: tomorrow?.course.name ?? '',
      nextTime: tomorrow == null ? '' : _clockLabel(tomorrow.startsAt),
      footerLeft: '',
      footerRight: '',
      courses: _widgetCourses(todayCourses, now),
    );
  }

  List<_CourseStart> _coursesForDate(
    List<Course> courses,
    Term term,
    DateTime date,
  ) {
    final week = term.currentWeek(date);
    final result = <_CourseStart>[];
    for (final course in courses) {
      if (course.dayOfWeek != date.weekday || !course.isActiveInWeek(week)) {
        continue;
      }
      final start = _courseStartsAt(date, course);
      if (start == null) {
        continue;
      }
      result.add(_CourseStart(course, start));
    }
    result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return result;
  }

  _CourseStart? _nextCourseAfter(
    List<Course> courses,
    Term term,
    DateTime now, {
    required bool sameDayOnly,
  }) {
    final limit = sameDayOnly ? 0 : 21;
    for (var offset = 0; offset <= limit; offset++) {
      final date = DateTime(now.year, now.month, now.day + offset);
      for (final item in _coursesForDate(courses, term, date)) {
        if (item.startsAt.isAfter(now)) {
          return item;
        }
      }
    }
    return null;
  }

  List<ScheduleWidgetCourse> _widgetCourses(
    List<_CourseStart> courses,
    DateTime now,
  ) {
    if (courses.isEmpty) {
      return const [];
    }
    final today = DateTime(now.year, now.month, now.day);
    _CourseStart? next;
    for (final item in courses) {
      if (item.startsAt.isAfter(now)) {
        next = item;
        break;
      }
    }
    final visible = _visibleCourseWindow(courses, now, today);
    return [
      for (final item in visible)
        ScheduleWidgetCourse(
          name: item.course.name,
          location: _compactLocation(item.course.location),
          startTime: _clockLabel(item.startsAt),
          time: _timeRange(item.course),
          dotColor: _courseColor(item.course).toARGB32(),
          state: _courseState(item, today, now, next),
        ),
    ];
  }

  List<_CourseStart> _visibleCourseWindow(
    List<_CourseStart> courses,
    DateTime now,
    DateTime today,
  ) {
    if (courses.length <= 3) {
      return courses;
    }

    var firstUsefulIndex = courses.indexWhere(
      (item) => _courseEndsAt(today, item.course).isAfter(now),
    );

    if (firstUsefulIndex == -1) {
      return [courses.last];
    }

    final end = (firstUsefulIndex + 3).clamp(0, courses.length).toInt();
    final window = courses.sublist(firstUsefulIndex, end);
    if (window.length == 3 || firstUsefulIndex == 0) {
      return window;
    }

    final needed = 3 - window.length;
    final start =
        (firstUsefulIndex - needed).clamp(0, firstUsefulIndex).toInt();
    return courses.sublist(start, firstUsefulIndex) + window;
  }

  String _courseState(
    _CourseStart item,
    DateTime today,
    DateTime now,
    _CourseStart? next,
  ) {
    final endAt = _courseEndsAt(today, item.course);
    if (!now.isBefore(item.startsAt) && now.isBefore(endAt)) {
      return 'current';
    }
    if (next?.course.noteKey == item.course.noteKey) {
      return 'next';
    }
    if (endAt.isBefore(now) || endAt.isAtSameMomentAs(now)) {
      return 'done';
    }
    return 'upcoming';
  }

  String _nextFooter(List<_CourseStart> courses, DateTime now) {
    final remaining =
        courses.where((item) => item.startsAt.isAfter(now)).length;
    if (remaining == 0) {
      return '今日课程已完成';
    }
    return '今日还有 $remaining 节课';
  }

  String _compactLocation(String location) {
    var text = location.trim().replaceAll(RegExp(r'\s+'), '');
    text = text.replaceFirst(RegExp(r'^教学楼'), '');
    text = text.replaceFirst(RegExp(r'^教学'), '');
    return text;
  }

  DateTime? _courseStartsAt(DateTime date, Course course) {
    final start = sectionTimes[course.startSection]?.start;
    if (start == null) {
      return null;
    }
    final parts = start.split(':');
    if (parts.length != 2) {
      return null;
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
  }

  DateTime _courseEndsAt(DateTime date, Course course) {
    final end = sectionTimes[course.endSection]?.end ?? '00:00';
    final parts = end.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts.first) ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _timeRange(Course course) {
    return timeRangeForSections(course.startSection, course.endSection).label;
  }

  Color _courseColor(Course course) {
    const colors = [
      Color(0xff3b8df6),
      Color(0xff38c986),
      Color(0xffff8a28),
      Color(0xff9b6cff),
      Color(0xff2bb3a3),
    ];
    return colors[course.name.hashCode.abs() % colors.length];
  }

  int _ceilMinutes(Duration duration) {
    if (duration.inMilliseconds <= 0) {
      return 0;
    }
    return (duration.inSeconds / 60).ceil();
  }

  String _clockLabel(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _futureDayLabel(DateTime now, DateTime date) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final offset = target.difference(today).inDays;
    if (offset == 1) {
      return '明天';
    }
    if (offset == 2) {
      return '后天';
    }
    return '${date.month}月${date.day}日';
  }

  String _weekdayLabel(int day) {
    return '周${const ['一', '二', '三', '四', '五', '六', '日'][day - 1]}';
  }

  String _sourceCoursesJson(List<Course> courses) {
    return jsonEncode([
      for (final course in courses)
        {
          'name': course.name,
          'location': course.location,
          'dayOfWeek': course.dayOfWeek,
          'startSection': course.startSection,
          'endSection': course.endSection,
          'weeks': (course.weeks.toList()..sort()),
        },
    ]);
  }
}

class ScheduleWidgetData {
  const ScheduleWidgetData({
    required this.darkMode,
    required this.appearanceMode,
    required this.showRoom,
    required this.sourceCoursesJson,
    required this.termStartMs,
    required this.dateTitle,
    required this.stateLabel,
    required this.statusLabel,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.timeLabel,
    required this.rightPrimary,
    required this.rightSecondary,
    required this.nextName,
    required this.nextTime,
    required this.footerLeft,
    required this.footerRight,
    required this.courses,
  });

  final bool darkMode;
  final String appearanceMode;
  final bool showRoom;
  final String sourceCoursesJson;
  final int termStartMs;
  final String dateTitle;
  final String stateLabel;
  final String statusLabel;
  final String title;
  final String subtitle;
  final String location;
  final String timeLabel;
  final String rightPrimary;
  final String rightSecondary;
  final String nextName;
  final String nextTime;
  final String footerLeft;
  final String footerRight;
  final List<ScheduleWidgetCourse> courses;

  Map<String, Object> toMap() {
    return {
      'widget_dark_mode': darkMode,
      'widget_appearance_mode': appearanceMode,
      'widget_show_room': showRoom,
      'widget_source_courses_json': sourceCoursesJson,
      'widget_term_start_ms': termStartMs,
      'widget_date_title': dateTitle,
      'widget_state_label': stateLabel,
      'widget_status_label': statusLabel,
      'widget_title': title,
      'widget_subtitle': subtitle,
      'widget_location': location,
      'widget_time_label': timeLabel,
      'widget_right_primary': rightPrimary,
      'widget_right_secondary': rightSecondary,
      'widget_next_name': nextName,
      'widget_next_time': nextTime,
      'widget_footer_left': footerLeft,
      'widget_footer_right': footerRight,
      'widget_course_count': courses.length,
      for (var i = 0; i < 3; i++) ...{
        'widget_course_${i}_name': i < courses.length ? courses[i].name : '',
        'widget_course_${i}_location':
            i < courses.length ? courses[i].location : '',
        'widget_course_${i}_start':
            i < courses.length ? courses[i].startTime : '',
        'widget_course_${i}_time': i < courses.length ? courses[i].time : '',
        'widget_course_${i}_color':
            i < courses.length ? courses[i].dotColor : 0,
        'widget_course_${i}_state': i < courses.length ? courses[i].state : '',
      },
    };
  }
}

class ScheduleWidgetCourse {
  const ScheduleWidgetCourse({
    required this.name,
    required this.location,
    required this.startTime,
    required this.time,
    required this.dotColor,
    required this.state,
  });

  final String name;
  final String location;
  final String startTime;
  final String time;
  final int dotColor;
  final String state;
}

class _CourseStart {
  const _CourseStart(this.course, this.startsAt);

  final Course course;
  final DateTime startsAt;
}
