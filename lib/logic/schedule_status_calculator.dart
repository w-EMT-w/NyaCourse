import '../models/course_model.dart';
import '../models/holiday_model.dart';

enum ScheduleStatusType {
  holiday,
  noClass,
  beforeClass,
  inClass,
  breakTime,
  finishedToday,
}

enum CourseTimelineState {
  current,
  next,
  finished,
  upcoming,
  cancelled,
}

class ScheduleStatusResult {
  const ScheduleStatusResult({
    required this.status,
    required this.remainingMinutes,
    required this.titleText,
    required this.subtitleText,
    required this.timeText,
    required this.locationText,
    this.currentCourse,
    this.nextCourse,
  });

  final ScheduleStatusType status;
  final CourseModel? currentCourse;
  final CourseModel? nextCourse;
  final int? remainingMinutes;
  final String titleText;
  final String subtitleText;
  final String timeText;
  final String locationText;
}

class ScheduleStatusCalculator {
  const ScheduleStatusCalculator();

  ScheduleStatusResult calculate({
    required DateTime now,
    required List<CourseModel> todayCourses,
    HolidayModel? holiday,
    List<CourseModel> cancelledCourses = const [],
    CourseModel? tomorrowFirstCourse,
  }) {
    if (holiday != null && _isSameDay(now, holiday.date)) {
      return ScheduleStatusResult(
        status: ScheduleStatusType.holiday,
        remainingMinutes: null,
        titleText: '今天放假',
        subtitleText: holiday.name,
        timeText: '暂无课程安排',
        locationText: holiday.description,
      );
    }

    final courses = _mergeCancelledCourses(todayCourses, cancelledCourses)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final activeCourses =
        courses.where((course) => !course.isCancelled).toList();

    if (activeCourses.isEmpty) {
      return const ScheduleStatusResult(
        status: ScheduleStatusType.noClass,
        remainingMinutes: null,
        titleText: '今天没课',
        subtitleText: '好好休息一下',
        timeText: '今天没有课程',
        locationText: '可以安排自习、运动或休息',
      );
    }

    for (final course in activeCourses) {
      if (_isInRange(now, course.startTime, course.endTime)) {
        final remaining = _ceilMinutes(course.endTime.difference(now));
        return ScheduleStatusResult(
          status: ScheduleStatusType.inClass,
          currentCourse: course,
          nextCourse: _firstCourseAfter(activeCourses, course.endTime),
          remainingMinutes: remaining,
          titleText: '正在上课',
          subtitleText: course.name,
          timeText: '${_formatRange(course)} · ${_remainingText(remaining)}下课',
          locationText: course.classroom,
        );
      }
    }

    final nextCourse = _firstCourseAfter(activeCourses, now);
    if (nextCourse != null) {
      final previousCourse = _lastCourseBefore(activeCourses, now);
      final remaining = _ceilMinutes(nextCourse.startTime.difference(now));
      final isBreakTime = previousCourse != null &&
          now.isAfter(previousCourse.endTime) &&
          _isSameDay(previousCourse.endTime, nextCourse.startTime);

      if (isBreakTime) {
        return ScheduleStatusResult(
          status: ScheduleStatusType.breakTime,
          nextCourse: nextCourse,
          remainingMinutes: remaining,
          titleText: '课间休息',
          subtitleText: '下一节课：${nextCourse.name}',
          timeText: '${_remainingText(remaining)}上课',
          locationText: nextCourse.classroom,
        );
      }

      return ScheduleStatusResult(
        status: ScheduleStatusType.beforeClass,
        nextCourse: nextCourse,
        remainingMinutes: remaining,
        titleText: '下一节课',
        subtitleText: nextCourse.name,
        timeText: _formatRange(nextCourse),
        locationText: nextCourse.classroom,
      );
    }

    return ScheduleStatusResult(
      status: ScheduleStatusType.finishedToday,
      remainingMinutes: null,
      titleText: '今日课程已结束',
      subtitleText: tomorrowFirstCourse == null
          ? '明天见'
          : '明天第一节课：${tomorrowFirstCourse.name}',
      timeText: tomorrowFirstCourse == null
          ? '明天见'
          : '明天 ${_formatClock(tomorrowFirstCourse.startTime)}',
      locationText: tomorrowFirstCourse?.classroom ?? '',
      nextCourse: tomorrowFirstCourse,
    );
  }

  static String remainingText(int remainingMinutes) =>
      _remainingText(remainingMinutes);

  static String formatRange(CourseModel course) => _formatRange(course);

  Map<String, CourseTimelineState> timelineStates({
    required DateTime now,
    required List<CourseModel> todayCourses,
    required ScheduleStatusResult statusResult,
  }) {
    return {
      for (final course in todayCourses)
        course.id: _timelineStateFor(
          now: now,
          course: course,
          statusResult: statusResult,
        ),
    };
  }

  List<CourseModel> _mergeCancelledCourses(
    List<CourseModel> todayCourses,
    List<CourseModel> cancelledCourses,
  ) {
    if (cancelledCourses.isEmpty) {
      return [...todayCourses];
    }
    final cancelledById = {
      for (final course in cancelledCourses) course.id: course,
    };
    return [
      for (final course in todayCourses)
        cancelledById.containsKey(course.id)
            ? course.copyWith(
                isCancelled: true,
                cancelReason: cancelledById[course.id]!.cancelReason,
              )
            : course,
    ];
  }

  static CourseModel? _firstCourseAfter(
    List<CourseModel> courses,
    DateTime time,
  ) {
    for (final course in courses) {
      if (course.startTime.isAfter(time)) {
        return course;
      }
    }
    return null;
  }

  static CourseModel? _lastCourseBefore(
    List<CourseModel> courses,
    DateTime time,
  ) {
    CourseModel? result;
    for (final course in courses) {
      if (course.endTime.isBefore(time) ||
          course.endTime.isAtSameMomentAs(time)) {
        result = course;
      }
    }
    return result;
  }

  static CourseTimelineState _timelineStateFor({
    required DateTime now,
    required CourseModel course,
    required ScheduleStatusResult statusResult,
  }) {
    if (course.isCancelled) {
      return CourseTimelineState.cancelled;
    }
    if (statusResult.currentCourse?.id == course.id) {
      return CourseTimelineState.current;
    }
    if (statusResult.nextCourse?.id == course.id) {
      return CourseTimelineState.next;
    }
    if (course.endTime.isBefore(now) || course.endTime.isAtSameMomentAs(now)) {
      return CourseTimelineState.finished;
    }
    return CourseTimelineState.upcoming;
  }

  static bool _isInRange(DateTime now, DateTime start, DateTime end) {
    return (now.isAtSameMomentAs(start) || now.isAfter(start)) &&
        now.isBefore(end);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int _ceilMinutes(Duration duration) {
    if (duration.inMilliseconds <= 0) {
      return 0;
    }
    return (duration.inSeconds / 60).ceil();
  }

  static String _remainingText(int remainingMinutes) {
    if (remainingMinutes < 1) {
      return '马上开始';
    }
    if (remainingMinutes < 60) {
      return '还有 $remainingMinutes 分钟';
    }
    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;
    return minutes == 0 ? '还有 $hours 小时' : '还有 $hours 小时 $minutes 分钟';
  }

  static String _formatRange(CourseModel course) {
    return '${_formatClock(course.startTime)} - ${_formatClock(course.endTime)}';
  }

  static String _formatClock(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
