class Grade {
  const Grade({
    required this.courseName,
    required this.credit,
    required this.score,
    required this.gradePoint,
    this.academicTerm = '',
    this.hours = '',
    this.courseCategory = '',
    this.courseType = '',
    this.studyMode = '',
    this.examNature = '',
    this.gradeMode = '',
    this.remark = '',
  });

  final String courseName;
  final double credit;
  final String score;
  final double gradePoint;
  final String academicTerm;
  final String hours;
  final String courseCategory;
  final String courseType;
  final String studyMode;
  final String examNature;
  final String gradeMode;
  final String remark;
}
