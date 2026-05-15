import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../services/app_settings_store.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.loggedIn,
    required this.savedUsername,
    required this.loadingAccount,
    required this.accountError,
    required this.onLogin,
    required this.onClearAccount,
    required this.importedCourseCount,
    required this.onImportSchedule,
    required this.reminderMinutes,
    required this.onReminderChanged,
    required this.themeSeed,
    required this.onThemeSeedChanged,
    required this.customThemeColors,
    required this.onAddCustomThemeColor,
    required this.onDeleteCustomThemeColor,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.cropBackgroundToScreen,
    required this.swipeWeekEnabled,
    required this.floatingPetEnabled,
    required this.onFloatingPetEnabledChanged,
    required this.floatingPetCardBlur,
    required this.onFloatingPetCardBlurChanged,
    required this.cardStyle,
    required this.onPickBackgroundImage,
    required this.onClearBackgroundImage,
    required this.onCropBackgroundChanged,
    required this.onBackgroundOpacityChanged,
    required this.onSwipeWeekEnabledChanged,
    required this.onCardStyleChanged,
    required this.onResetAppearance,
    super.key,
  });

  final bool loggedIn;
  final String? savedUsername;
  final bool loadingAccount;
  final String? accountError;
  final VoidCallback onLogin;
  final VoidCallback onClearAccount;
  final int importedCourseCount;
  final VoidCallback onImportSchedule;
  final int reminderMinutes;
  final ValueChanged<int> onReminderChanged;
  final Color themeSeed;
  final ValueChanged<Color> onThemeSeedChanged;
  final List<Color> customThemeColors;
  final ValueChanged<Color> onAddCustomThemeColor;
  final ValueChanged<Color> onDeleteCustomThemeColor;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final bool cropBackgroundToScreen;
  final bool swipeWeekEnabled;
  final bool floatingPetEnabled;
  final ValueChanged<bool> onFloatingPetEnabledChanged;
  final double floatingPetCardBlur;
  final ValueChanged<double> onFloatingPetCardBlurChanged;
  final CardStyleSettings cardStyle;
  final VoidCallback onPickBackgroundImage;
  final VoidCallback onClearBackgroundImage;
  final ValueChanged<bool> onCropBackgroundChanged;
  final ValueChanged<double> onBackgroundOpacityChanged;
  final ValueChanged<bool> onSwipeWeekEnabledChanged;
  final ValueChanged<CardStyleSettings> onCardStyleChanged;
  final VoidCallback onResetAppearance;

  static const _themeColors = [
    Color(0xff006b5b),
    Color(0xff2d5be3),
    Color(0xffb43a63),
    Color(0xff7b4fc9),
    Color(0xff3d6b2f),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      children: [
        Text(
          '设置',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader('账号与同步'),
        const SizedBox(height: 10),
        GlassCard(
          style: cardStyle,
          themeSeed: themeSeed,
          staticMode: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GroupTitle('课表操作'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('左右滑动切换周'),
                subtitle: const Text('关闭后只使用上方左右箭头切换'),
                value: swipeWeekEnabled,
                onChanged: onSwipeWeekEnabledChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          style: cardStyle,
          themeSeed: themeSeed,
          staticMode: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GroupTitle('悬浮球'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用蓝色猫头悬浮球'),
                subtitle: Text(
                  floatingPetEnabled
                      ? '显示课程提醒，可拖动吸边'
                      : '首次开启需要手动授予悬浮窗权限',
                ),
                value: floatingPetEnabled,
                onChanged: onFloatingPetEnabledChanged,
              ),
              _LabeledSlider(
                title: '卡片模糊度',
                minLabel: '清晰',
                maxLabel: '模糊',
                valueLabel: '${floatingPetCardBlur.round()}dp',
                min: 0,
                max: 30,
                divisions: 30,
                value: floatingPetCardBlur,
                onChanged: onFloatingPetCardBlurChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          style: cardStyle,
          themeSeed: themeSeed,
          staticMode: true,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                child: Icon(loggedIn ? Icons.person : Icons.person_add_alt_1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _GroupTitle('账号管理'),
                    Text(
                      accountError != null
                          ? accountError!
                          : loggedIn
                              ? '已同步：${savedUsername ?? ''}'
                              : savedUsername == null
                                  ? '登录后会保存账号并自动同步'
                                  : '已保存：$savedUsername',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: accountError == null
                          ? null
                          : TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: loadingAccount ? null : onLogin,
                    child: Text(loggedIn ? '重新登录' : '登录'),
                  ),
                  if (savedUsername != null)
                    TextButton(
                      onPressed: loadingAccount ? null : onClearAccount,
                      child: const Text('清除'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader('课表与提醒'),
        const SizedBox(height: 10),
        GlassCard(
          style: cardStyle,
          themeSeed: themeSeed,
          staticMode: true,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
                child: const Icon(Icons.upload_file_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _GroupTitle('课表导入'),
                    Text(
                      importedCourseCount == 0
                          ? '支持 JSON / CSV / TXT / XLSX，需包含课程名、星期、节次'
                          : '本地课表 $importedCourseCount 条，可重新导入覆盖',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onImportSchedule,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('导入'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          style: cardStyle,
          themeSeed: themeSeed,
          staticMode: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GroupTitle('课前提醒'),
              _LabeledSlider(
                title: '提醒时间',
                minLabel: '关闭',
                maxLabel: '60 分钟',
                valueLabel: reminderMinutes == 0 ? '关闭' : '$reminderMinutes 分钟',
                min: 0,
                max: 60,
                divisions: 12,
                value: reminderMinutes.toDouble(),
                onChanged: (value) => onReminderChanged(value.round()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader('外观主题'),
        const SizedBox(height: 10),
        GlassCard(
          style: cardStyle,
          themeSeed: themeSeed,
          staticMode: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _GroupTitle('主题')),
                  TextButton.icon(
                    onPressed: onResetAppearance,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('恢复默认'),
                  ),
                ],
              ),
              const _SubTitle('主题色'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final color in _themeColors)
                    _ColorDot(
                      color: color,
                      selected: color.toARGB32() == themeSeed.toARGB32(),
                      onTap: () => onThemeSeedChanged(color),
                    ),
                  for (final color in customThemeColors)
                    _ColorDot(
                      color: color,
                      selected: color.toARGB32() == themeSeed.toARGB32(),
                      onTap: () => onThemeSeedChanged(color),
                      onDelete: () => onDeleteCustomThemeColor(color),
                    ),
                  _AddColorDot(
                    enabled: customThemeColors.length < 8,
                    onTap: () => _showAddThemeColorPicker(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SubTitle('背景图片'),
              const SizedBox(height: 8),
              Text(
                backgroundImagePath == null ? '使用默认纯色背景' : '已选择图片，上传时按界面比例裁剪',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onPickBackgroundImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('上传图片'),
                    ),
                  ),
                  if (backgroundImagePath != null) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: onClearBackgroundImage,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('移除'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('裁剪适配屏幕'),
                subtitle: const Text('打开后按屏幕铺满显示，关闭则完整显示图片'),
                value: cropBackgroundToScreen,
                onChanged: onCropBackgroundChanged,
              ),
              _LabeledSlider(
                title: '图片透明度',
                minLabel: '0%',
                maxLabel: '100%',
                valueLabel: '${(backgroundOpacity * 100).round()}%',
                min: 0,
                max: 1,
                divisions: 20,
                value: backgroundOpacity,
                onChanged: onBackgroundOpacityChanged,
              ),
              const SizedBox(height: 20),
              const _SubTitle('显示模式'),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('跟随'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('浅色'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('深色'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (value) => onThemeModeChanged(value.first),
              ),
              const SizedBox(height: 20),
              const _SubTitle('卡片风格'),
              const SizedBox(height: 8),
              _LabeledSlider(
                title: '卡片透明度',
                minLabel: '5%',
                maxLabel: '35%',
                valueLabel: '${(cardStyle.opacity * 100).round()}%',
                min: 0.05,
                max: 0.35,
                divisions: 30,
                value: cardStyle.opacity,
                onChanged: (value) => onCardStyleChanged(
                  CardStyleSettings(
                    blur: cardStyle.blur,
                    opacity: value,
                    tint: cardStyle.tint,
                    borderGlow: cardStyle.borderGlow,
                    fontColorValue: cardStyle.fontColorValue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TintChip(
                    label: '纯白',
                    tint: CardTint.pureWhite,
                    selected: cardStyle.tint == CardTint.pureWhite,
                    onSelected: _changeTint,
                  ),
                  _TintChip(
                    label: '暖白',
                    tint: CardTint.warmWhite,
                    selected: cardStyle.tint == CardTint.warmWhite,
                    onSelected: _changeTint,
                  ),
                  _TintChip(
                    label: '淡紫',
                    tint: CardTint.lavender,
                    selected: cardStyle.tint == CardTint.lavender,
                    onSelected: _changeTint,
                  ),
                  _TintChip(
                    label: '无色',
                    tint: CardTint.none,
                    selected: cardStyle.tint == CardTint.none,
                    onSelected: _changeTint,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('边框发光'),
                subtitle: const Text('开启后使用白色半透明 1px 边框'),
                value: cardStyle.borderGlow,
                onChanged: (value) => onCardStyleChanged(
                  CardStyleSettings(
                    blur: cardStyle.blur,
                    opacity: cardStyle.opacity,
                    tint: cardStyle.tint,
                    borderGlow: value,
                    fontColorValue: cardStyle.fontColorValue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const _SubTitle('字体颜色'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FontColorChip(
                    label: '跟随',
                    color: null,
                    selected: cardStyle.fontColorValue == null,
                    onSelected: _changeFontColor,
                  ),
                  _FontColorChip(
                    label: '深色',
                    color: const Color(0xff17201b),
                    selected: cardStyle.fontColorValue ==
                        const Color(0xff17201b).toARGB32(),
                    onSelected: _changeFontColor,
                  ),
                  _FontColorChip(
                    label: '浅色',
                    color: Colors.white,
                    selected:
                        cardStyle.fontColorValue == Colors.white.toARGB32(),
                    onSelected: _changeFontColor,
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showFontColorPicker(context),
                    icon: const Icon(Icons.format_color_text),
                    label: const Text('自定义'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader('数据与缓存'),
        const SizedBox(height: 10),
        GlassCard(
          style: cardStyle,
          themeSeed: themeSeed,
          staticMode: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GroupTitle('本地数据'),
              _InfoRow(
                icon: Icons.calendar_month_outlined,
                title: '当前课表',
                subtitle: importedCourseCount == 0
                    ? '暂无本地课表数据'
                    : '已保留 $importedCourseCount 条课程，可离线查看',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.security_outlined,
                title: '账号凭据',
                subtitle: savedUsername == null
                    ? '未保存账号'
                    : '账号仅保存在系统安全存储中',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader('关于'),
        const SizedBox(height: 10),
        GlassCard(
          style: cardStyle,
          themeSeed: themeSeed,
          staticMode: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GroupTitle('NyaCourse'),
              const Text('版本 0.2.0+2'),
              const SizedBox(height: 6),
              const Text('广东工业大学课表、成绩与考试安排工具。'),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _showChangelogDialog(context),
                icon: const Icon(Icons.new_releases_outlined),
                label: const Text('更新内容'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _changeTint(CardTint tint) {
    onCardStyleChanged(
      CardStyleSettings(
        blur: cardStyle.blur,
        opacity: cardStyle.opacity,
        tint: tint,
        borderGlow: cardStyle.borderGlow,
        fontColorValue: cardStyle.fontColorValue,
      ),
    );
  }

  void _changeFontColor(Color? color) {
    onCardStyleChanged(
      CardStyleSettings(
        blur: cardStyle.blur,
        opacity: cardStyle.opacity,
        tint: cardStyle.tint,
        borderGlow: cardStyle.borderGlow,
        fontColorValue: color?.toARGB32(),
      ),
    );
  }

  Future<void> _showFontColorPicker(BuildContext context) async {
    var pickerColor = cardStyle.fontColorValue == null
        ? Colors.white
        : Color(cardStyle.fontColorValue!);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('自定义字体颜色'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pickerColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (color) =>
                      setDialogState(() => pickerColor = color),
                  enableAlpha: true,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                  hexInputBar: true,
                  portraitOnly: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  _changeFontColor(pickerColor);
                  Navigator.of(context).pop();
                },
                child: const Text('应用'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddThemeColorPicker(BuildContext context) async {
    var pickerColor = themeSeed;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('添加主题色'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pickerColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (color) =>
                      setDialogState(() => pickerColor = color),
                  enableAlpha: true,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithHue,
                  hexInputBar: true,
                  portraitOnly: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  onAddCustomThemeColor(pickerColor);
                  Navigator.of(context).pop();
                },
                child: const Text('添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showChangelogDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更新内容'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChangelogVersion(
                version: '0.2.0+2',
                items: [
                  '新增蓝色猫头悬浮球',
                  '悬浮球点击查看课程提醒',
                  '考试安排按最近考试优先显示',
                  '优化数据更新时间和离线缓存提示',
                ],
              ),
              SizedBox(height: 14),
              _ChangelogVersion(
                version: '0.1.0+1',
                items: [
                  '课表、成绩、考试基础功能',
                  '本地课表导入和缓存',
                  '主题、背景图和课前提醒设置',
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _ChangelogVersion extends StatelessWidget {
  const _ChangelogVersion({
    required this.version,
    required this.items,
  });

  final String version;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          version,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $item'),
          ),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.62),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.title,
    required this.minLabel,
    required this.maxLabel,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String minLabel;
  final String maxLabel;
  final String valueLabel;
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(minLabel, style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            Text(valueLabel, style: Theme.of(context).textTheme.labelMedium),
            const Spacer(),
            Text(maxLabel, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        Slider(
          min: min,
          max: max,
          divisions: divisions,
          value: value.clamp(min, max),
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TintChip extends StatelessWidget {
  const _TintChip({
    required this.label,
    required this.tint,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final CardTint tint;
  final bool selected;
  final ValueChanged<CardTint> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(tint),
    );
  }
}

class _FontColorChip extends StatelessWidget {
  const _FontColorChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final Color? color;
  final bool selected;
  final ValueChanged<Color?> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: color == null
          ? const Icon(Icons.auto_awesome, size: 18)
          : CircleAvatar(backgroundColor: color),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(color),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '切换主题色',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: InkResponse(
                onTap: onTap,
                radius: 26,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  scale: selected ? 1.08 : 1,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        width: selected ? 3 : 1,
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.28),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),
            if (onDelete != null)
              Positioned(
                top: -2,
                right: -2,
                child: InkResponse(
                  onTap: onDelete,
                  radius: 12,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.error,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddColorDot extends StatelessWidget {
  const _AddColorDot({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? '添加自定义主题色' : '最多添加 8 个自定义颜色',
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 26,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: enabled ? 1 : 0.45),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
            ),
          ),
          child: Icon(
            Icons.add,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: enabled ? 0.8 : 0.32),
          ),
        ),
      ),
    );
  }
}
