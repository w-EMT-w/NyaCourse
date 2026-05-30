import 'package:flutter/material.dart';

class CourseModel {
  const CourseModel({
    required this.id,
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.isCancelled = false,
    this.cancelReason,
  });

  final String id;
  final String name;
  final String teacher;
  final String classroom;
  final DateTime startTime;
  final DateTime endTime;
  final Color color;
  final bool isCancelled;
  final String? cancelReason;

  CourseModel copyWith({
    String? id,
    String? name,
    String? teacher,
    String? classroom,
    DateTime? startTime,
    DateTime? endTime,
    Color? color,
    bool? isCancelled,
    String? cancelReason,
  }) {
    return CourseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      classroom: classroom ?? this.classroom,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }
}
