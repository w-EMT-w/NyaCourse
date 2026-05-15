import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/data_status.dart';
import '../models/exam.dart';
import '../services/app_settings_store.dart';
import '../widgets/data_status_header.dart';
import '../widgets/glass_card.dart';

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({
    required this.exams,
    required this.loading,
    required this.status,
    required this.onRefresh,
    required this.cardStyle,
    required this.themeSeed,
    super.key,
  });

  final List<Exam> exams;
  final bool loading;
  final DataStatus status;
  final VoidCallback onRefresh;
  final CardStyleSettings cardStyle;
  final Color themeSeed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: DataStatusHeader(
            title: '考试安排',
            status: status,
            loading: loading,
            cardStyle: cardStyle,
            themeSeed: themeSeed,
            staticGlass: true,
            refreshTooltip: '刷新考试安排',
            onRefresh: onRefresh,
          ),
        ),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (exams.isEmpty) {
      return UnifiedEmptyData(
        icon: Icons.event_note_outlined,
        title: '暂无考试安排',
        subtitle: '登录后刷新，考试周公布后可在这里查看地点和座位号。',
        onRefresh: onRefresh,
      );
    }

    final formatter = DateFormat('M月d日 HH:mm');
    final sortedExams = _sortedByNearest(exams);
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        itemCount: sortedExams.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final exam = sortedExams[index];
          return GlassCard(
            style: cardStyle,
            themeSeed: themeSeed,
            staticMode: true,
            padding: const EdgeInsets.all(14),
            borderRadius: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _InfoLine(
                  icon: Icons.schedule,
                  text: formatter.format(exam.time),
                ),
                _InfoLine(
                  icon: Icons.hourglass_bottom_outlined,
                  text: _countdownLabel(exam.time),
                ),
                _InfoLine(icon: Icons.place_outlined, text: exam.location),
                _InfoLine(
                  icon: Icons.event_seat_outlined,
                  text: '座位号 ${exam.displaySeatNumber}',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _countdownLabel(DateTime time) {
    final today = DateTime.now();
    final current = DateTime(today.year, today.month, today.day);
    final examDay = DateTime(time.year, time.month, time.day);
    final days = examDay.difference(current).inDays;
    if (days > 0) {
      return '距离考试还有 $days 天';
    }
    if (days == 0) {
      return '今天考试';
    }
    return '考试已结束';
  }

  List<Exam> _sortedByNearest(List<Exam> exams) {
    final now = DateTime.now();
    final sorted = [...exams];
    sorted.sort((a, b) {
      final aEnded = a.time.isBefore(now);
      final bEnded = b.time.isBefore(now);
      if (aEnded != bEnded) {
        return aEnded ? 1 : -1;
      }
      return aEnded ? b.time.compareTo(a.time) : a.time.compareTo(b.time);
    });
    return sorted;
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
