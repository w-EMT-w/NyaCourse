import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:gdut_class_schedule/main.dart';
import 'package:gdut_class_schedule/models/term.dart';
import 'package:gdut_class_schedule/services/schedule_parser.dart';

void main() {
  testWidgets('shows schedule home', (WidgetTester tester) async {
    await tester.pumpWidget(const GdutScheduleApp());

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            RegExp(r'^\d{4}(春季|秋季)  第 \d+ 周$').hasMatch(widget.data!),
      ),
      findsOneWidget,
    );
    expect(find.text('课表'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  test('official weekly schedule rows override raw week ranges', () {
    final courses = ScheduleParser.parse({
      'rows': [
        {
          'kcmc': '操作系统实验',
          'teaxms': '王老师',
          'jxcdmc': '实验楼',
          'xq': 3,
          'jcdm': '050607',
          'zcd': '1-16周',
          'nyacourseWeek': 12,
        },
        {
          'kcmc': '操作系统实验',
          'teaxms': '王老师',
          'jxcdmc': '实验楼',
          'xq': 3,
          'jcdm': '050607',
          'zcd': '1-16周',
          'nyacourseWeek': 14,
        },
      ],
    });

    expect(courses, hasLength(1));
    expect(courses.single.weeks, {12, 14});
    expect(courses.single.isActiveInWeek(13), isFalse);
  });

  test('spring 2026 week dates match GDUT pkrq calendar', () {
    final term = Term.now(DateTime(2026, 5, 13));

    expect(term.currentWeek(DateTime(2026, 5, 13)), 10);
    expect(term.dateForWeekday(week: 10, weekday: 3), DateTime(2026, 5, 13));
    expect(term.dateForWeekday(week: 11, weekday: 3), DateTime(2026, 5, 20));
  });
}
