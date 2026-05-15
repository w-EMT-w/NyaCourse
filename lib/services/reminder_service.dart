import 'package:flutter/services.dart';

import '../models/course.dart';
import '../models/term.dart';
import 'course_time.dart';

class ReminderService {
  const ReminderService();

  static const MethodChannel _channel = MethodChannel('gdut_jw');

  Future<void> schedule({
    required List<Course> courses,
    required Term term,
    required int reminderMinutes,
  }) async {
    final now = DateTime.now();
    final items = <Map<String, Object?>>[];

    for (final course in courses) {
      for (final week in course.weeks) {
        final date = term.dateForWeekday(
          week: week,
          weekday: course.dayOfWeek,
        );
        final time = timeRangeForSections(
          course.startSection,
          course.endSection,
        );
        final parts = time.start.split(':');
        if (parts.length != 2) {
          continue;
        }
        final startsAt = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (startsAt.isBefore(now)) {
          continue;
        }
        items.add({
          'id': course.name.hashCode ^ startsAt.millisecondsSinceEpoch,
          'title': course.name,
          'location': course.location,
          'time': time.label,
          'startsAt': startsAt.millisecondsSinceEpoch,
        });
      }
    }

    await _channel.invokeMethod<void>('scheduleCourseReminders', {
      'reminderMinutes': reminderMinutes,
      'courses': items,
    });
  }
}
