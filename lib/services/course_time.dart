class CourseTimeRange {
  const CourseTimeRange(this.start, this.end);

  final String start;
  final String end;

  String get label => '$start-$end';
}

const Map<int, CourseTimeRange> sectionTimes = {
  1: CourseTimeRange('08:30', '09:15'),
  2: CourseTimeRange('09:20', '10:05'),
  3: CourseTimeRange('10:25', '11:10'),
  4: CourseTimeRange('11:15', '12:00'),
  5: CourseTimeRange('13:50', '14:35'),
  6: CourseTimeRange('14:40', '15:25'),
  7: CourseTimeRange('15:30', '16:15'),
  8: CourseTimeRange('16:30', '17:15'),
  9: CourseTimeRange('17:20', '18:05'),
  10: CourseTimeRange('18:30', '19:15'),
  11: CourseTimeRange('19:20', '20:05'),
  12: CourseTimeRange('20:10', '20:55'),
};

CourseTimeRange timeRangeForSections(int startSection, int endSection) {
  final start = sectionTimes[startSection]?.start ?? '--:--';
  final end = sectionTimes[endSection]?.end ?? '--:--';
  return CourseTimeRange(start, end);
}
