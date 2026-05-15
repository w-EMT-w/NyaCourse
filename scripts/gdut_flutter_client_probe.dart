// ignore_for_file: avoid_print

import 'package:gdut_class_schedule/models/term.dart';
import 'package:gdut_class_schedule/services/gdut_jw_client.dart';

Future<void> main() async {
  const username = String.fromEnvironment('GDUT_USERNAME');
  const password = String.fromEnvironment('GDUT_PASSWORD');

  if (username.isEmpty || password.isEmpty) {
    throw StateError(
      '请用 --dart-define=GDUT_USERNAME=... '
      '--dart-define=GDUT_PASSWORD=... 传入账号密码。',
    );
  }

  final client = GdutJwClient();
  final term = Term.now(DateTime.now());

  await client.login(username: username, password: password);
  final courses = await client.fetchSchedule(term);

  print('login ok');
  print('term: ${term.gdutTermCode} ${term.displayName}');
  print('courses: ${courses.length}');
  for (final course in courses.take(10)) {
    print(
      [
        course.name,
        '第${course.weeks.first}周',
        '周${course.dayOfWeek}',
        '${course.startSection}-${course.endSection}节',
        course.location,
        course.teacher,
      ].where((part) => part.isNotEmpty).join(' | '),
    );
  }
}
