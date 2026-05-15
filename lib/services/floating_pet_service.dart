import 'dart:io';

import 'package:flutter/services.dart';

class FloatingPetCourse {
  const FloatingPetCourse({
    required this.statusText,
    required this.courseName,
    required this.location,
    required this.startTime,
    required this.minutesLeft,
    required this.dayLabel,
    required this.secondaryText,
    required this.urgent,
    required this.themeColorValue,
    required this.cardBlur,
  });

  const FloatingPetCourse.emptyToday()
      : statusText = '今天没有课程',
        courseName = '',
        location = '',
        startTime = '',
        minutesLeft = -1,
        dayLabel = '',
        secondaryText = '',
        urgent = false,
        themeColorValue = 0xff006b5b,
        cardBlur = 20;

  final String statusText;
  final String courseName;
  final String location;
  final String startTime;
  final int minutesLeft;
  final String dayLabel;
  final String secondaryText;
  final bool urgent;
  final int themeColorValue;
  final double cardBlur;

  Map<String, Object?> toJson() {
    return {
      'statusText': statusText,
      'courseName': courseName,
      'location': location,
      'startTime': startTime,
      'minutesLeft': minutesLeft,
      'dayLabel': dayLabel,
      'secondaryText': secondaryText,
      'urgent': urgent,
      'themeColorValue': themeColorValue,
      'cardBlur': cardBlur,
    };
  }
}

class FloatingPetService {
  const FloatingPetService();

  static const _channel = MethodChannel('gdut_pet');

  static void setClickHandler(Future<void> Function()? handler) {
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'petClicked') {
        await handler();
      }
    });
  }

  Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
  }

  Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openOverlaySettings');
  }

  Future<void> show(FloatingPetCourse course) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('showPet', course.toJson());
  }

  Future<void> hide() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('hidePet');
  }

  Future<void> updateCourse(FloatingPetCourse course) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('updateCourse', course.toJson());
  }
}
