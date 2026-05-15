import '../models/course.dart';

class ScheduleParser {
  static List<Course> parse(Map<String, dynamic> payload) {
    final rawItems = payload['rows'] ?? payload['kbList'];
    if (rawItems is! List) {
      return const [];
    }

    final courses = rawItems
        .whereType<Map>()
        .map((item) => _parseCourse(Map<String, dynamic>.from(item)))
        .whereType<Course>()
        .toList();

    return _mergeDuplicateCourses(courses)..sort(_compareCourses);
  }

  static Course? _parseCourse(Map<String, dynamic> item) {
    final isLegacyZfPayload =
        item.containsKey('xqj') || item.containsKey('jcs');
    if (!isLegacyZfPayload) {
      return _parseGdutCourse(item);
    }

    final day = _intOf(item['xqj']);
    final start = _intOf(item['jc']);
    final sections = _parseSections(item['jcs'].toString(), start);

    if (day == null || sections == null) {
      return null;
    }

    return Course(
      name: _text(item['kcmc']),
      teacher: _text(item['xm']),
      location: _text(item['cdmc']),
      dayOfWeek: day,
      startSection: sections.$1,
      endSection: sections.$2,
      weeks: _parseWeeks(_text(item['zcd'])),
      teachingContent: _teachingContent(item),
      date: _parseDate(item['pkrq']),
    );
  }

  static Course? _parseGdutCourse(Map<String, dynamic> item) {
    final day = _intOf(item['xq']);
    final sections = _parseGdutSections(_text(item['jcdm']));

    if (day == null || sections == null) {
      return null;
    }

    return Course(
      name: _text(item['kcmc']),
      teacher: _text(item['teaxms']),
      location: _text(item['jxcdmc']),
      dayOfWeek: day,
      startSection: sections.$1,
      endSection: sections.$2,
      weeks: _parseCourseWeeks(item),
      teachingContent: _teachingContent(item),
      date: _parseDate(item['pkrq']),
    );
  }

  static String _teachingContent(Map<String, dynamic> item) {
    return _text(
      item['sknrjj'] ??
          item['sknr'] ??
          item['jxnr'] ??
          item['teachingContent'] ??
          item['授课内容'],
    );
  }

  static List<Course> _mergeDuplicateCourses(List<Course> courses) {
    final merged = <String, Course>{};
    for (final course in courses) {
      final key = [
        course.name,
        course.teacher,
        course.location,
        course.dayOfWeek,
        course.startSection,
        course.endSection,
        course.teachingContent,
      ].join('|');
      final existing = merged[key];
      if (existing == null) {
        merged[key] = course;
      } else {
        merged[key] = existing.copyWith(
          weeks: {...existing.weeks, ...course.weeks},
          date: existing.date ?? course.date,
        );
      }
    }
    return merged.values.toList();
  }

  static int _compareCourses(Course a, Course b) {
    final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
    if (dayCompare != 0) {
      return dayCompare;
    }
    return a.startSection.compareTo(b.startSection);
  }

  static Set<int> _parseCourseWeeks(Map<String, dynamic> item) {
    final officialWeek = _intOf(item['nyacourseWeek']);
    if (officialWeek != null) {
      return {officialWeek};
    }

    final rawValues = [
      item['zc'],
      item['zcd'],
      item['skzc'],
      item['skzcm'],
      item['qsjsz'],
    ].where((value) => value != null && _text(value).isNotEmpty);

    final weeks = <int>{};
    for (final value in rawValues) {
      if (value is int) {
        weeks.add(value);
        continue;
      }
      weeks.addAll(_parseWeeks(value.toString()));
    }
    return weeks;
  }

  static (int, int)? _parseSections(String raw, int? fallbackStart) {
    final matches = RegExp(r'\d+').allMatches(raw).toList();
    if (matches.isNotEmpty) {
      final numbers = matches.map((m) => int.parse(m.group(0)!)).toList();
      return (numbers.first, numbers.last);
    }

    if (fallbackStart == null) {
      return null;
    }
    return (fallbackStart, fallbackStart);
  }

  static (int, int)? _parseGdutSections(String raw) {
    if (raw.isEmpty) {
      return null;
    }

    final compact = raw.replaceAll(RegExp(r'\D'), '');
    final numbers = <int>[];
    if (compact.length.isEven && compact.length > 2) {
      for (var i = 0; i < compact.length; i += 2) {
        final value = int.tryParse(compact.substring(i, i + 2));
        if (value != null) {
          numbers.add(value);
        }
      }
    } else {
      numbers.addAll(
        RegExp(r'\d+')
            .allMatches(raw)
            .map((match) => int.parse(match.group(0)!)),
      );
    }

    if (numbers.isEmpty) {
      return null;
    }
    return (numbers.first, numbers.last);
  }

  static Set<int> _parseWeeks(String raw) {
    final normalized = raw
        .replaceAll('周', '')
        .replaceAll('第', '')
        .replaceAll(' ', '')
        .replaceAll('，', ',');
    final weeks = <int>{};

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
        if (odd || even) {
          for (var week = 1; week <= 25; week++) {
            _addWeek(weeks, week, odd: odd, even: even);
          }
        }
        continue;
      }

      if (numbers.length == 1) {
        _addWeek(weeks, numbers.first, odd: odd, even: even);
        continue;
      }

      for (var week = numbers.first; week <= numbers.last; week++) {
        _addWeek(weeks, week, odd: odd, even: even);
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

  static int? _intOf(Object? value) {
    if (value is int) {
      return value;
    }
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(Object? value) {
    final text = _text(value);
    if (text.isEmpty) {
      return null;
    }
    final date = DateTime.tryParse(text);
    if (date == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day);
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';
}
