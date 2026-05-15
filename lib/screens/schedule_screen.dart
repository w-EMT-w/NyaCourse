import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/term.dart';
import '../services/gdut_jw_client.dart';
import '../widgets/week_schedule_view.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    required this.client,
    required this.initialTerm,
    super.key,
  });

  final GdutJwClient client;
  final Term initialTerm;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Term _term;
  int _selectedWeek = 1;
  bool _loading = true;
  String? _error;
  List<Course> _courses = const [];

  @override
  void initState() {
    super.initState();
    _term = widget.initialTerm;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final courses = await widget.client.fetchSchedule(_term);
      setState(() {
        _courses = courses;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _changeWeek(int delta) {
    setState(() {
      _selectedWeek = (_selectedWeek + delta).clamp(1, 25).toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCourses =
        _courses.where((course) => course.isActiveInWeek(_selectedWeek));

    return Scaffold(
      appBar: AppBar(
        title: const Text('本周课表'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _term.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '第 $_selectedWeek 周',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '上一周',
                  onPressed: _selectedWeek == 1 ? null : () => _changeWeek(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: '下一周',
                  onPressed: _selectedWeek == 25 ? null : () => _changeWeek(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: WeekScheduleView(
                courses: activeCourses.toList(),
                totalSections: 12,
                term: _term,
                selectedWeek: _selectedWeek,
                courseNotes: const {},
                onCourseTap: (_) {},
                onCourseLongPress: (_) {},
              ),
            ),
        ],
      ),
    );
  }
}
