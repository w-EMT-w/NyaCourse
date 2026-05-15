class Exam {
  const Exam({
    required this.courseName,
    required this.time,
    required this.location,
    required this.seatNumber,
  });

  final String courseName;
  final DateTime time;
  final String location;
  final String seatNumber;

  String get displaySeatNumber =>
      seatNumber.trim().isEmpty ? '按考场信息就坐' : seatNumber;
}
