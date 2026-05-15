class Course {
  const Course({
    required this.name,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.weeks,
    this.objective = defaultObjective,
    this.teachingContent = '',
    this.date,
  });

  static const defaultObjective = '按培养方案教学安排，完成本课程对应知识点与实践训练。';

  final String name;
  final String teacher;
  final String location;

  /// Monday is 1 and Sunday is 7, matching DateTime.weekday.
  final int dayOfWeek;
  final int startSection;
  final int endSection;
  final Set<int> weeks;
  final String objective;
  final String teachingContent;
  final DateTime? date;

  int get sectionSpan => endSection - startSection + 1;

  bool isActiveInWeek(int week) => weeks.isEmpty || weeks.contains(week);

  String get noteKey => [
        name,
        teacher,
        location,
        dayOfWeek,
        startSection,
        endSection,
      ].join('|');

  Course copyWith({
    String? name,
    String? teacher,
    String? location,
    int? dayOfWeek,
    int? startSection,
    int? endSection,
    Set<int>? weeks,
    String? objective,
    String? teachingContent,
    DateTime? date,
  }) {
    return Course(
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      weeks: weeks ?? this.weeks,
      objective: objective ?? this.objective,
      teachingContent: teachingContent ?? this.teachingContent,
      date: date ?? this.date,
    );
  }
}
