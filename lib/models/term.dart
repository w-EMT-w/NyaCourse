class Term {
  const Term({
    required this.academicYear,
    required this.termCode,
    DateTime? teachingStartDate,
  }) : _teachingStartDate = teachingStartDate;

  static const int maxWeek = 25;

  /// Zhengfang xnm, for example 2025 for academic year 2025-2026.
  final int academicYear;

  /// Zhengfang xqm. Common values: 3 for first term, 12 for second term.
  final String termCode;
  final DateTime? _teachingStartDate;

  /// GDUT current teaching system term code, e.g. 202501 for 2025 autumn
  /// and 202502 for 2026 spring.
  String get gdutTermCode {
    final suffix = termCode == '3' ? '01' : '02';
    return '$academicYear$suffix';
  }

  String get displayName {
    final termName = termCode == '3' ? '秋季' : '春季';
    final displayYear = termCode == '3' ? academicYear : academicYear + 1;
    return '$displayYear$termName';
  }

  DateTime get startDate {
    if (_teachingStartDate != null) {
      return DateTime(
        _teachingStartDate.year,
        _teachingStartDate.month,
        _teachingStartDate.day,
      );
    }
    if (termCode == '3') {
      return _firstMonday(DateTime(academicYear, 9));
    }
    return _firstMonday(DateTime(academicYear + 1, 3))
        .add(const Duration(days: 7));
  }

  int currentWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final diff = normalized.difference(startDate).inDays;
    if (diff < 0) {
      return 1;
    }
    return (diff ~/ 7 + 1).clamp(1, maxWeek).toInt();
  }

  DateTime dateForWeekday({
    required int week,
    required int weekday,
  }) {
    return startDate.add(Duration(days: (week - 1) * 7 + weekday - 1));
  }

  static Term now(DateTime date) {
    if (date.month >= 8) {
      return Term(academicYear: date.year, termCode: '3');
    }
    return Term(academicYear: date.year - 1, termCode: '12');
  }

  static List<Term> recent(DateTime date, {int count = 8}) {
    final current = now(date);
    final terms = <Term>[];
    var year = current.academicYear;
    var termCode = current.termCode;
    for (var i = 0; i < count; i++) {
      terms.add(Term(academicYear: year, termCode: termCode));
      if (termCode == '12') {
        termCode = '3';
      } else {
        termCode = '12';
        year--;
      }
    }
    return terms;
  }

  Term withStartDate(DateTime startDate) {
    return Term(
      academicYear: academicYear,
      termCode: termCode,
      teachingStartDate:
          DateTime(startDate.year, startDate.month, startDate.day),
    );
  }

  static DateTime _firstMonday(DateTime monthStart) {
    final offset = (DateTime.monday - monthStart.weekday) % 7;
    return DateTime(monthStart.year, monthStart.month, monthStart.day + offset);
  }
}
