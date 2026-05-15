import 'package:flutter/material.dart';

import '../models/data_status.dart';
import '../services/app_settings_store.dart';
import 'glass_card.dart';

class DataStatusHeader extends StatelessWidget {
  const DataStatusHeader({
    required this.title,
    required this.status,
    required this.loading,
    required this.cardStyle,
    required this.themeSeed,
    required this.refreshTooltip,
    required this.onRefresh,
    this.staticGlass = false,
    super.key,
  });

  final String title;
  final DataStatus status;
  final bool loading;
  final CardStyleSettings cardStyle;
  final Color themeSeed;
  final String refreshTooltip;
  final VoidCallback onRefresh;
  final bool staticGlass;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: glassForegroundColor(context, cardStyle),
                    ),
              ),
              const SizedBox(height: 2),
              DataStatusText(status: status),
            ],
          ),
        ),
        GlassIconButton(
          style: cardStyle,
          themeSeed: themeSeed,
          staticMode: staticGlass,
          tooltip: refreshTooltip,
          onPressed: loading ? null : onRefresh,
          icon: Icons.refresh,
        ),
      ],
    );
  }
}

class DataStatusText extends StatelessWidget {
  const DataStatusText({required this.status, super.key});

  final DataStatus status;

  @override
  Widget build(BuildContext context) {
    final updatedAt = status.lastUpdated;
    final label = updatedAt == null
        ? '尚未更新'
        : '上次更新：${_two(updatedAt.hour)}:${_two(updatedAt.minute)}';
    final text = status.offlineCache ? '$label · 离线缓存' : label;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
            fontWeight: FontWeight.w600,
          ),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class UnifiedEmptyData extends StatelessWidget {
  const UnifiedEmptyData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.58),
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }
}
