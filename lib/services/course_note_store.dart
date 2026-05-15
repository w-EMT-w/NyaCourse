import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CourseNoteStore {
  const CourseNoteStore();

  static const _storage = FlutterSecureStorage();
  static const _notesKey = 'gdut_course_notes';

  Future<Map<String, String>> read() async {
    final raw = await _storage.read(key: _notesKey);
    if (raw == null || raw.isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const {};
    }

    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  Future<void> save(Map<String, String> notes) async {
    await _storage.write(key: _notesKey, value: jsonEncode(notes));
  }
}
