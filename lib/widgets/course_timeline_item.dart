import 'package:flutter/material.dart';

import '../logic/schedule_status_calculator.dart';
import '../models/course_model.dart';

class CourseTimelineItem extends StatelessWidget {
  const CourseTimelineItem({
    required this.course,
    required this.state,
    super.key,
  });

  final CourseModel course;
  final CourseTimelineState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = state == CourseTimelineState.current;
    final isNext = state == CourseTimelineState.next;
    final isFinished = state == CourseTimelineState.finished;
    final isCancelled = state == CourseTimelineState.cancelled;
    final foreground = isCancelled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.48)
        : isFinished
            ? scheme.onSurface.withValues(alpha: 0.42)
            : scheme.onSurface;
    final highlightColor = isCurrent
        ? course.color.withValues(alpha: 0.18)
        : isNext
            ? course.color.withValues(alpha: 0.13)
            : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: highlightColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCancelled
                      ? scheme.outline
                      : isCurrent || isNext
                          ? course.color
                          : course.color.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            child: Text(
              _clock(course.startTime),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                        decoration:
                            isCancelled ? TextDecoration.lineThrough : null,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_clock(course.startTime)} - ${_clock(course.endTime)}   ${course.classroom}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                        decoration:
                            isCancelled ? TextDecoration.lineThrough : null,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TrailingBadge(state: state, color: course.color),
        ],
      ),
    );
  }

  String _clock(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _TrailingBadge extends StatelessWidget {
  const _TrailingBadge({
    required this.state,
    required this.color,
  });

  final CourseTimelineState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (state) {
      CourseTimelineState.current => Text(
          '进行中',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      CourseTimelineState.next => Icon(
          Icons.play_arrow_rounded,
          color: color,
          size: 22,
        ),
      CourseTimelineState.cancelled => Text(
          '已停课',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
                fontWeight: FontWeight.w800,
              ),
        ),
      _ => const SizedBox(width: 22),
    };
  }
}
