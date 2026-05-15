import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/exam.dart';
import '../models/grade.dart';

class AcademicDataStore {
  const AcademicDataStore();

  static const _storage = FlutterSecureStorage();
  static const _gradesPrefix = 'nyacourse_cached_grades_v1_';
  static const _examsPrefix = 'nyacourse_cached_exams_v1_';
  static const _gradesUpdatedPrefix = 'nyacourse_cached_grades_updated_v1_';
  static const _examsUpdatedPrefix = 'nyacourse_cached_exams_updated_v1_';

  Future<List<Grade>> readGrades(String termCode) async {
    final raw = await _storage.read(key: '$_gradesPrefix$termCode');
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => _gradeFromJson(Map<String, dynamic>.from(item)))
        .whereType<Grade>()
        .toList();
  }

  Future<void> saveGrades(String termCode, List<Grade> grades) async {
    await _storage.write(
      key: '$_gradesPrefix$termCode',
      value: jsonEncode(grades.map(_gradeToJson).toList()),
    );
    await _storage.write(
      key: '$_gradesUpdatedPrefix$termCode',
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> readGradesUpdatedAt(String termCode) async {
    return DateTime.tryParse(
      await _storage.read(key: '$_gradesUpdatedPrefix$termCode') ?? '',
    );
  }

  Future<List<Exam>> readExams(String termCode) async {
    final raw = await _storage.read(key: '$_examsPrefix$termCode');
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => _examFromJson(Map<String, dynamic>.from(item)))
        .whereType<Exam>()
        .toList();
  }

  Future<void> saveExams(String termCode, List<Exam> exams) async {
    await _storage.write(
      key: '$_examsPrefix$termCode',
      value: jsonEncode(exams.map(_examToJson).toList()),
    );
    await _storage.write(
      key: '$_examsUpdatedPrefix$termCode',
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> readExamsUpdatedAt(String termCode) async {
    return DateTime.tryParse(
      await _storage.read(key: '$_examsUpdatedPrefix$termCode') ?? '',
    );
  }

  static Map<String, dynamic> _gradeToJson(Grade grade) {
    return {
      'courseName': grade.courseName,
      'credit': grade.credit,
      'score': grade.score,
      'gradePoint': grade.gradePoint,
      'academicTerm': grade.academicTerm,
      'hours': grade.hours,
      'courseCategory': grade.courseCategory,
      'courseType': grade.courseType,
      'studyMode': grade.studyMode,
      'examNature': grade.examNature,
      'gradeMode': grade.gradeMode,
      'remark': grade.remark,
    };
  }

  static Grade? _gradeFromJson(Map<String, dynamic> item) {
    final courseName = item['courseName']?.toString().trim() ?? '';
    if (courseName.isEmpty) {
      return null;
    }
    return Grade(
      courseName: courseName,
      credit: _doubleOf(item['credit']) ?? 0,
      score: item['score']?.toString().trim() ?? '',
      gradePoint: _doubleOf(item['gradePoint']) ?? 0,
      academicTerm: item['academicTerm']?.toString().trim() ?? '',
      hours: item['hours']?.toString().trim() ?? '',
      courseCategory: item['courseCategory']?.toString().trim() ?? '',
      courseType: item['courseType']?.toString().trim() ?? '',
      studyMode: item['studyMode']?.toString().trim() ?? '',
      examNature: item['examNature']?.toString().trim() ?? '',
      gradeMode: item['gradeMode']?.toString().trim() ?? '',
      remark: item['remark']?.toString().trim() ?? '',
    );
  }

  static Map<String, dynamic> _examToJson(Exam exam) {
    return {
      'courseName': exam.courseName,
      'time': exam.time.toIso8601String(),
      'location': exam.location,
      'seatNumber': exam.seatNumber,
    };
  }

  static Exam? _examFromJson(Map<String, dynamic> item) {
    final courseName = item['courseName']?.toString().trim() ?? '';
    final time = DateTime.tryParse(item['time']?.toString() ?? '');
    if (courseName.isEmpty || time == null) {
      return null;
    }
    return Exam(
      courseName: courseName,
      time: time,
      location: item['location']?.toString().trim() ?? '',
      seatNumber: item['seatNumber']?.toString().trim() ?? '',
    );
  }

  static double? _doubleOf(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}
