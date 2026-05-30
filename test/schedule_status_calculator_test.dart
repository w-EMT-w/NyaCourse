import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdut_class_schedule/logic/schedule_status_calculator.dart';
import 'package:gdut_class_schedule/models/course_model.dart';
import 'package:gdut_class_schedule/models/holiday_model.dart';

void main() {
  const calculator = ScheduleStatusCalculator();

  test('holiday takes priority over courses', () {
    final now = DateTime(2026, 5, 25, 9);
    final result = calculator.calculate(
      now: now,
      todayCourses: [_course(now, 'math', 8, 0, 9, 40)],
      holiday: HolidayModel(
        date: now,
        name: '端午节',
        description: '放假一天',
      ),
    );

    expect(result.status, ScheduleStatusType.holiday);
    expect(result.titleText, '今天放假');
    expect(result.subtitleText, '端午节');
  });

  test('detects current in-class course', () {
    final now = DateTime(2026, 5, 25, 8, 30);
    final result = calculator.calculate(
      now: now,
      todayCourses: [_course(now, 'english', 8, 0, 9, 40)],
    );

    expect(result.status, ScheduleStatusType.inClass);
    expect(result.currentCourse?.id, 'english');
    expect(result.remainingMinutes, 70);
  });

  test('detects break time before next course', () {
    final now = DateTime(2026, 5, 25, 9, 50);
    final result = calculator.calculate(
      now: now,
      todayCourses: [
        _course(now, 'english', 8, 0, 9, 40),
        _course(now, 'math', 10, 0, 11, 40),
      ],
    );

    expect(result.status, ScheduleStatusType.breakTime);
    expect(result.nextCourse?.id, 'math');
    expect(result.remainingMinutes, 10);
  });

  test('marks cancelled course in timeline states', () {
    final now = DateTime(2026, 5, 25, 9);
    final courses = [
      _course(now, 'english', 8, 0, 9, 40).copyWith(isCancelled: true),
      _course(now, 'math', 10, 0, 11, 40),
    ];
    final result = calculator.calculate(now: now, todayCourses: courses);
    final states = calculator.timelineStates(
      now: now,
      todayCourses: courses,
      statusResult: result,
    );

    expect(states['english'], CourseTimelineState.cancelled);
    expect(states['math'], CourseTimelineState.next);
  });
}

CourseModel _course(
  DateTime date,
  String id,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute,
) {
  return CourseModel(
    id: id,
    name: id,
    teacher: 'teacher',
    classroom: 'A101',
    startTime:
        DateTime(date.year, date.month, date.day, startHour, startMinute),
    endTime: DateTime(date.year, date.month, date.day, endHour, endMinute),
    color: Colors.green,
  );
}
