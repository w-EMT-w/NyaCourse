import 'dart:convert';

import 'package:excel/excel.dart';

import '../models/course.dart';
import 'schedule_parser.dart';

class ImportedSchedule {
  const ImportedSchedule({
    required this.courses,
    required this.sourceName,
  });

  final List<Course> courses;
  final String sourceName;
}

class ScheduleImporter {
  const ScheduleImporter._();

  static ImportedSchedule parse(
    String content, {
    required String sourceName,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('文件内容为空');
    }

    final courses = trimmed.startsWith('{') || trimmed.startsWith('[')
        ? _parseJson(trimmed)
        : _parseCsv(trimmed);

    if (courses.isEmpty) {
      throw const FormatException('没有识别到课程数据');
    }

    courses.sort((a, b) {
      final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCompare != 0) {
        return dayCompare;
      }
      return a.startSection.compareTo(b.startSection);
    });

    return ImportedSchedule(courses: courses, sourceName: sourceName);
  }

  static ImportedSchedule parseBytes(
    List<int> bytes, {
    required String sourceName,
  }) {
    final lowerName = sourceName.toLowerCase();
    if (lowerName.endsWith('.xlsx')) {
      final courses = _parseXlsx(bytes);
      if (courses.isEmpty) {
        throw const FormatException('没有识别到课程数据');
      }
      courses.sort((a, b) {
        final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return a.startSection.compareTo(b.startSection);
      });
      return ImportedSchedule(courses: courses, sourceName: sourceName);
    }

    return parse(utf8.decode(bytes), sourceName: sourceName);
  }

  static List<Course> _parseJson(String content) {
    final decoded = jsonDecode(content);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final parsed = ScheduleParser.parse(map);
      if (parsed.isNotEmpty) {
        return parsed;
      }

      final items = map['courses'] ?? map['data'] ?? map['items'];
      if (items is List) {
        return _parseObjectList(items);
      }

      final course = _courseFromMap(map);
      return course == null ? const [] : [course];
    }

    if (decoded is List) {
      final parsed = ScheduleParser.parse({'rows': decoded});
      if (parsed.isNotEmpty) {
        return parsed;
      }
      return _parseObjectList(decoded);
    }

    return const [];
  }

  static List<Course> _parseObjectList(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map((item) => _courseFromMap(Map<String, dynamic>.from(item)))
        .whereType<Course>()
        .toList();
  }

  static List<Course> _parseCsv(String content) {
    final rows = _parseCsvRows(content)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList();
    if (rows.length < 2) {
      return const [];
    }

    final headers = rows.first.map(_normalizeKey).toList();
    final courses = <Course>[];
    for (final row in rows.skip(1)) {
      final item = <String, dynamic>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        item[headers[i]] = row[i].trim();
      }
      final course = _courseFromMap(item);
      if (course != null) {
        courses.add(course);
      }
    }
    return courses;
  }

  static List<Course> _parseXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.rows.length < 2) {
        continue;
      }

      final rows = sheet.rows
          .map((row) => row.map((cell) => _cellText(cell?.value)).toList())
          .where((row) => row.any((cell) => cell.trim().isNotEmpty))
          .toList();
      if (rows.length < 2) {
        continue;
      }

      final headers = rows.first.map(_normalizeKey).toList();
      final courses = <Course>[];
      for (final row in rows.skip(1)) {
        final item = <String, dynamic>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          item[headers[i]] = row[i].trim();
        }
        final course = _courseFromMap(item);
        if (course != null) {
          courses.add(course);
        }
      }

      if (courses.isNotEmpty) {
        return courses;
      }
    }
    return const [];
  }

  static String _cellText(CellValue? value) {
    return switch (value) {
      null => '',
      TextCellValue() => value.value.text ?? '',
      FormulaCellValue() => value.formula,
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value ? 'true' : 'false',
      DateCellValue() => value.asDateTimeLocal().toString(),
      TimeCellValue() => value.asDuration().toString(),
      DateTimeCellValue() => value.asDateTimeLocal().toString(),
    };
  }

  static List<List<String>> _parseCsvRows(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (char == ',' && !inQuotes) {
        row.add(buffer.toString());
        buffer.clear();
        continue;
      }

      if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        row.add(buffer.toString());
        buffer.clear();
        rows.add(row);
        row = <String>[];
        continue;
      }

      buffer.write(char);
    }

    row.add(buffer.toString());
    rows.add(row);
    return rows;
  }

  static Course? _courseFromMap(Map<String, dynamic> item) {
    final name = _field(item, const [
      'name',
      'coursename',
      'course',
      '课程名',
      '课程',
      'kcmc',
    ]);
    final day = _parseDay(_field(item, const [
      'dayofweek',
      'weekday',
      'day',
      '星期',
      '周几',
      'xq',
      'xqj',
    ]));
    final sections = _parseSections(item);

    if (name.isEmpty || day == null || sections == null) {
      return null;
    }

    final objective =
        _field(item, const ['objective', 'purpose', '课程目的', '目标']);
    final teachingContent = _field(item, const [
      'teachingcontent',
      'content',
      '授课内容',
      '教学内容',
      'sknrjj',
      'sknr',
      'jxnr',
    ]);

    return Course(
      name: name,
      teacher: _field(
          item, const ['teacher', 'teachers', '教师', '老师', 'teaxms', 'xm']),
      location: _field(
          item, const ['location', 'room', '地点', '教室', 'jxcdmc', 'cdmc']),
      dayOfWeek: day,
      startSection: sections.$1,
      endSection: sections.$2,
      weeks: _parseWeeks(
          _rawField(item, const ['weeks', 'week', '周次', 'zcd', 'zc'])),
      objective: objective.isEmpty ? Course.defaultObjective : objective,
      teachingContent: teachingContent,
    );
  }

  static (int, int)? _parseSections(Map<String, dynamic> item) {
    final start = _parseInt(_rawField(item, const [
      'startsection',
      'start',
      '开始节',
      '起始节',
      'jc',
    ]));
    final end = _parseInt(_rawField(item, const [
      'endsection',
      'end',
      '结束节',
      '结束',
    ]));
    if (start != null && end != null) {
      return (start, end);
    }

    final raw = _field(item, const [
      'sections',
      'section',
      '节次',
      '上课节次',
      'jcs',
      'jcdm',
    ]);
    final numbers = RegExp(r'\d+')
        .allMatches(raw)
        .map((match) => int.parse(match.group(0)!))
        .toList();
    if (numbers.isEmpty && start != null) {
      return (start, start);
    }
    if (numbers.isEmpty) {
      return null;
    }

    if (raw.contains('0102') || raw.contains('0304') || raw.contains('1112')) {
      final compact = raw.replaceAll(RegExp(r'\D'), '');
      if (compact.length.isEven && compact.length > 2) {
        final split = <int>[];
        for (var i = 0; i < compact.length; i += 2) {
          final value = int.tryParse(compact.substring(i, i + 2));
          if (value != null) {
            split.add(value);
          }
        }
        if (split.isNotEmpty) {
          return (split.first, split.last);
        }
      }
    }

    return (numbers.first, numbers.last);
  }

  static Set<int> _parseWeeks(Object? value) {
    if (value is List) {
      return value.map(_parseInt).whereType<int>().toSet();
    }

    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return const {};
    }

    final weeks = <int>{};
    final normalized = raw
        .replaceAll('第', '')
        .replaceAll('周', '')
        .replaceAll('，', ',')
        .replaceAll('、', ',')
        .replaceAll(';', ',')
        .replaceAll('；', ',')
        .replaceAll(' ', '');

    for (final segment in normalized.split(',')) {
      if (segment.isEmpty) {
        continue;
      }

      final odd = segment.contains('单');
      final even = segment.contains('双');
      final numbers = RegExp(r'\d+')
          .allMatches(segment)
          .map((match) => int.parse(match.group(0)!))
          .toList();
      if (numbers.isEmpty) {
        continue;
      }

      if (numbers.length == 1) {
        _addWeek(weeks, numbers.first, odd: odd, even: even);
      } else {
        for (var week = numbers.first; week <= numbers.last; week++) {
          _addWeek(weeks, week, odd: odd, even: even);
        }
      }
    }

    return weeks;
  }

  static void _addWeek(
    Set<int> weeks,
    int week, {
    required bool odd,
    required bool even,
  }) {
    if (odd && week.isEven) {
      return;
    }
    if (even && week.isOdd) {
      return;
    }
    weeks.add(week);
  }

  static int? _parseDay(String value) {
    final text = value.trim();
    final number = _parseInt(text);
    if (number != null && number >= 1 && number <= 7) {
      return number;
    }

    const names = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '日': 7,
      '天': 7,
    };
    for (final entry in names.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  static int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value == null) {
      return null;
    }
    final text = value.toString();
    return int.tryParse(text) ??
        int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '');
  }

  static Object? _rawField(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final normalized = _normalizeKey(key);
      if (item.containsKey(normalized)) {
        return item[normalized];
      }
      if (item.containsKey(key)) {
        return item[key];
      }
    }

    for (final entry in item.entries) {
      final key = _normalizeKey(entry.key);
      if (keys.map(_normalizeKey).contains(key)) {
        return entry.value;
      }
    }
    return null;
  }

  static String _field(Map<String, dynamic> item, List<String> keys) {
    return _rawField(item, keys)?.toString().trim() ?? '';
  }

  static String _normalizeKey(Object? key) {
    return key
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[\s_\-()（）]'), '') ??
        '';
  }
}
