import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/course.dart';

class ImportedScheduleStore {
  const ImportedScheduleStore();

  static const _storage = FlutterSecureStorage();
  static const _coursesKey = 'nyacourse_imported_courses_v2';
  static const _cachedCoursesKey = 'nyacourse_remote_courses_v2';
  static const _coursesUpdatedKey = 'nyacourse_imported_courses_updated_v1';
  static const _cachedCoursesUpdatedKey = 'nyacourse_remote_courses_updated_v1';

  Future<List<Course>> read() => _read(_coursesKey);

  Future<List<Course>> readCached() => _read(_cachedCoursesKey);

  Future<List<Course>> _read(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => _courseFromJson(Map<String, dynamic>.from(item)))
        .whereType<Course>()
        .toList();
  }

  Future<void> save(List<Course> courses) async {
    await _write(_coursesKey, courses);
    await _writeUpdatedAt(_coursesUpdatedKey);
  }

  Future<void> saveCached(List<Course> courses) async {
    await _write(_cachedCoursesKey, courses);
    await _writeUpdatedAt(_cachedCoursesUpdatedKey);
  }

  Future<void> _write(String key, List<Course> courses) async {
    await _storage.write(
      key: key,
      value: jsonEncode(courses.map(_courseToJson).toList()),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _coursesKey);
    await _storage.delete(key: _coursesUpdatedKey);
  }

  Future<DateTime?> readUpdatedAt() => _readUpdatedAt(_coursesUpdatedKey);

  Future<DateTime?> readCachedUpdatedAt() =>
      _readUpdatedAt(_cachedCoursesUpdatedKey);

  Future<DateTime?> _readUpdatedAt(String key) async {
    return DateTime.tryParse(await _storage.read(key: key) ?? '');
  }

  Future<void> _writeUpdatedAt(String key) async {
    await _storage.write(
      key: key,
      value: DateTime.now().toIso8601String(),
    );
  }

  static Map<String, dynamic> _courseToJson(Course course) {
    return {
      'name': course.name,
      'teacher': course.teacher,
      'location': course.location,
      'dayOfWeek': course.dayOfWeek,
      'startSection': course.startSection,
      'endSection': course.endSection,
      'weeks': course.weeks.toList()..sort(),
      'objective': course.objective,
      'teachingContent': course.teachingContent,
      'date': course.date?.toIso8601String(),
    };
  }

  static Course? _courseFromJson(Map<String, dynamic> item) {
    final day = _intOf(item['dayOfWeek']);
    final start = _intOf(item['startSection']);
    final end = _intOf(item['endSection']);
    final name = item['name']?.toString().trim() ?? '';
    if (name.isEmpty || day == null || start == null || end == null) {
      return null;
    }

    final weeks = item['weeks'] is List
        ? (item['weeks'] as List).map(_intOf).whereType<int>().toSet()
        : <int>{};

    final objective = item['objective']?.toString().trim() ?? '';
    final teachingContent = item['teachingContent']?.toString().trim() ?? '';

    return Course(
      name: name,
      teacher: item['teacher']?.toString().trim() ?? '',
      location: item['location']?.toString().trim() ?? '',
      dayOfWeek: day,
      startSection: start,
      endSection: end,
      weeks: weeks,
      objective: objective.isEmpty ? Course.defaultObjective : objective,
      teachingContent: teachingContent,
      date: _dateOf(item['date']),
    );
  }

  static DateTime? _dateOf(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day);
  }

  static int? _intOf(Object? value) {
    if (value is int) {
      return value;
    }
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }
}
