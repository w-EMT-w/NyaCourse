import 'package:flutter/material.dart';

import '../logic/schedule_status_calculator.dart';
import '../models/course_model.dart';
import '../models/holiday_model.dart';

class MockScheduleData {
  MockScheduleData._();

  static DateTime sampleNow() => DateTime(2026, 5, 25, 9, 32);

  static List<CourseModel> todayCourses([DateTime? baseDate]) {
    final date = baseDate ?? sampleNow();
    return [
      CourseModel(
        id: 'english',
        name: '英语',
        teacher: '陈老师',
        classroom: 'B101',
        startTime: _at(date, 8, 0),
        endTime: _at(date, 9, 40),
        color: const Color(0xff3b8df6),
      ),
      CourseModel(
        id: 'math',
        name: '高等数学',
        teacher: '李老师',
        classroom: 'A203',
        startTime: _at(date, 10, 0),
        endTime: _at(date, 11, 40),
        color: const Color(0xff38c986),
      ),
      CourseModel(
        id: 'cs',
        name: '计算机导论',
        teacher: '王老师',
        classroom: 'C301',
        startTime: _at(date, 14, 0),
        endTime: _at(date, 15, 40),
        color: const Color(0xffff8a28),
      ),
      CourseModel(
        id: 'pe',
        name: '体育',
        teacher: '周老师',
        classroom: '体育馆',
        startTime: _at(date, 16, 0),
        endTime: _at(date, 17, 40),
        color: const Color(0xff9b6cff),
      ),
    ];
  }

  static CourseModel tomorrowFirstCourse([DateTime? baseDate]) {
    final date = (baseDate ?? sampleNow()).add(const Duration(days: 1));
    return CourseModel(
      id: 'tomorrow-os',
      name: '操作系统',
      teacher: '刘老师',
      classroom: '教2-207',
      startTime: _at(date, 8, 30),
      endTime: _at(date, 10, 10),
      color: const Color(0xff38c986),
    );
  }

  static HolidayModel holiday([DateTime? baseDate]) {
    final date = baseDate ?? sampleNow();
    return HolidayModel(
      date: DateTime(date.year, date.month, date.day),
      name: '端午节',
      description: '暂无课程安排',
    );
  }

  static ScheduleStatusResult sampleStatus() {
    return const ScheduleStatusCalculator().calculate(
      now: sampleNow(),
      todayCourses: todayCourses(),
      tomorrowFirstCourse: tomorrowFirstCourse(),
    );
  }

  static Map<String, CourseTimelineState> sampleTimelineStates() {
    final now = sampleNow();
    final courses = todayCourses(now);
    const calculator = ScheduleStatusCalculator();
    final result = calculator.calculate(
      now: now,
      todayCourses: courses,
      tomorrowFirstCourse: tomorrowFirstCourse(now),
    );
    return calculator.timelineStates(
      now: now,
      todayCourses: courses,
      statusResult: result,
    );
  }

  static DateTime _at(DateTime date, int hour, int minute) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
