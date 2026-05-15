import 'package:flutter/material.dart';

import '../models/data_status.dart';
import '../models/grade.dart';
import '../models/term.dart';
import '../services/app_settings_store.dart';
import '../widgets/data_status_header.dart';
import '../widgets/glass_card.dart';

class GradesScreen extends StatelessWidget {
  const GradesScreen({
    required this.grades,
    required this.terms,
    required this.selectedTerm,
    required this.loading,
    required this.status,
    required this.cardStyle,
    required this.themeSeed,
    required this.onTermChanged,
    required this.onRefresh,
    super.key,
  });

  final List<Grade> grades;
  final List<Term> terms;
  final Term selectedTerm;
  final bool loading;
  final DataStatus status;
  final CardStyleSettings cardStyle;
  final Color themeSeed;
  final ValueChanged<Term> onTermChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DataStatusHeader(
                title: '成绩',
                status: status,
                loading: loading,
                cardStyle: cardStyle,
                themeSeed: themeSeed,
                staticGlass: true,
                refreshTooltip: '刷新成绩',
                onRefresh: onRefresh,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedTerm.gdutTermCode,
                decoration: const InputDecoration(
                  labelText: '学年学期',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final term in terms)
                    DropdownMenuItem(
                      value: term.gdutTermCode,
                      child: Text(term.displayName),
                    ),
                ],
                onChanged: (value) {
                  final term = terms.firstWhere(
                    (item) => item.gdutTermCode == value,
                    orElse: () => selectedTerm,
                  );
                  onTermChanged(term);
                },
              ),
            ],
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

    if (grades.isEmpty) {
      return UnifiedEmptyData(
        icon: Icons.school_outlined,
        title: '暂无成绩数据',
        subtitle: '登录后刷新，若学校接口暂未开放会保持为空。',
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        itemCount: grades.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final grade = grades[index];
          return GlassCard(
            style: cardStyle,
            themeSeed: themeSeed,
            staticMode: true,
            onTap: () => _showGradeDetail(context, grade),
            padding: const EdgeInsets.all(14),
            borderRadius: 8,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grade.courseName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text('学分 ${grade.credit.toStringAsFixed(1)}'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      grade.score,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('绩点 ${grade.gradePoint.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showGradeDetail(BuildContext context, Grade grade) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(grade.courseName,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            _GradeLine(label: '总成绩', value: grade.score),
            _GradeLine(
              label: '绩点',
              value: grade.gradePoint.toStringAsFixed(2),
            ),
            _GradeLine(label: '学分', value: grade.credit.toStringAsFixed(1)),
            _GradeLine(label: '学时', value: grade.hours),
            _GradeLine(label: '课程大类', value: grade.courseCategory),
            _GradeLine(label: '课程分类', value: grade.courseType),
            _GradeLine(label: '修读方式', value: grade.studyMode),
            _GradeLine(label: '考试性质', value: grade.examNature),
            _GradeLine(label: '成绩方式', value: grade.gradeMode),
            _GradeLine(label: '备注', value: grade.remark),
          ],
        ),
      ),
    );
  }
}

class _GradeLine extends StatelessWidget {
  const _GradeLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
