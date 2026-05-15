import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_settings_store.dart';
import '../widgets/glass_card.dart';

enum _SettingsSection {
  account,
  schedule,
  floatingPet,
  appearance,
  data,
  about,
}

class SettingsScreen extends StatefulWidget {
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

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _githubUrl = 'https://github.com/w-EMT-w/NyaCourse';
  static const _latestReleaseApi =
      'https://api.github.com/repos/w-EMT-w/NyaCourse/releases/latest';
  static const _latestReleasePage =
      'https://github.com/w-EMT-w/NyaCourse/releases/latest';

  static const _themeColors = [
    Color(0xff006b5b),
    Color(0xff2d5be3),
    Color(0xffb43a63),
    Color(0xff7b4fc9),
    Color(0xff3d6b2f),
  ];

  _SettingsSection? _section;
  bool _checkingUpdate = false;

  @override
  Widget build(BuildContext context) {
    final section = _section;
    if (section == null) {
      return _buildHome(context);
    }
    return _buildDetail(context, section);
  }

  Widget _buildHome(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      children: [
        Text(
          '设置',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '管理账号、提醒、外观和应用信息',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.58),
              ),
        ),
        const SizedBox(height: 18),
        _ModuleTile(
          icon: Icons.person_outline,
          title: '账号与同步',
          summary: widget.loggedIn
              ? '已登录'
              : widget.savedUsername == null
                  ? '未登录'
                  : '已保存账号',
          cardStyle: widget.cardStyle,
          themeSeed: widget.themeSeed,
          onTap: () => setState(() => _section = _SettingsSection.account),
        ),
        _ModuleTile(
          icon: Icons.notifications_active_outlined,
          title: '课表与提醒',
          summary:
              widget.reminderMinutes == 0 ? '提醒已关闭' : '提前 ${widget.reminderMinutes} 分钟',
          cardStyle: widget.cardStyle,
          themeSeed: widget.themeSeed,
          onTap: () => setState(() => _section = _SettingsSection.schedule),
        ),
        _ModuleTile(
          icon: Icons.bubble_chart_outlined,
          title: '悬浮球',
          summary: widget.floatingPetEnabled ? '已开启' : '未开启',
          cardStyle: widget.cardStyle,
          themeSeed: widget.themeSeed,
          onTap: () => setState(() => _section = _SettingsSection.floatingPet),
        ),
        _ModuleTile(
          icon: Icons.palette_outlined,
          title: '外观主题',
          summary: _themeModeLabel(widget.themeMode),
          cardStyle: widget.cardStyle,
          themeSeed: widget.themeSeed,
          onTap: () => setState(() => _section = _SettingsSection.appearance),
        ),
        _ModuleTile(
          icon: Icons.storage_outlined,
          title: '数据与缓存',
          summary: widget.importedCourseCount == 0
              ? '暂无本地课表'
              : '课表 ${widget.importedCourseCount} 条',
          cardStyle: widget.cardStyle,
          themeSeed: widget.themeSeed,
          onTap: () => setState(() => _section = _SettingsSection.data),
        ),
        _ModuleTile(
          icon: Icons.info_outline,
          title: '关于',
          summary: '版本 0.2.1+3',
          cardStyle: widget.cardStyle,
          themeSeed: widget.themeSeed,
          onTap: () => setState(() => _section = _SettingsSection.about),
        ),
        const SizedBox(height: 18),
        Text(
          '版本 0.2.1+3 · 隐私说明见 PRIVACY.md',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }

  Widget _buildDetail(BuildContext context, _SettingsSection section) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '返回设置',
              onPressed: () => setState(() => _section = null),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                _sectionTitle(section),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        switch (section) {
          _SettingsSection.account => _accountPage(context),
          _SettingsSection.schedule => _schedulePage(context),
          _SettingsSection.floatingPet => _floatingPetPage(context),
          _SettingsSection.appearance => _appearancePage(context),
          _SettingsSection.data => _dataPage(context),
          _SettingsSection.about => _aboutPage(context),
        },
      ],
    );
  }

  Widget _accountPage(BuildContext context) {
    return GlassCard(
      style: widget.cardStyle,
      themeSeed: widget.themeSeed,
      staticMode: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GroupTitle('账号状态'),
          _InfoRow(
            icon: widget.loggedIn ? Icons.verified_user_outlined : Icons.person_add_alt_1,
            title: widget.loggedIn ? '已登录' : '未登录',
            subtitle: widget.accountError != null
                ? widget.accountError!
                : widget.savedUsername == null
                    ? '登录后会保存账号并自动同步'
                    : '已保存：${widget.savedUsername}',
            error: widget.accountError != null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.loadingAccount ? null : widget.onLogin,
                  icon: const Icon(Icons.login),
                  label: Text(widget.loggedIn ? '重新登录' : '登录'),
                ),
              ),
              if (widget.savedUsername != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed:
                      widget.loadingAccount ? null : widget.onClearAccount,
                  child: const Text('清除账号'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          const _GroupTitle('课表导入'),
          _InfoRow(
            icon: Icons.upload_file_outlined,
            title: '本地导入',
            subtitle: widget.importedCourseCount == 0
                ? '支持 JSON / CSV / TXT / XLSX'
                : '当前课表 ${widget.importedCourseCount} 条，可重新导入覆盖',
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: widget.onImportSchedule,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('导入课表'),
          ),
        ],
      ),
    );
  }

  Widget _schedulePage(BuildContext context) {
    return GlassCard(
      style: widget.cardStyle,
      themeSeed: widget.themeSeed,
      staticMode: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GroupTitle('课表操作'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('左右滑动切换周'),
            subtitle: const Text('关闭后只使用上方左右箭头切换'),
            value: widget.swipeWeekEnabled,
            onChanged: widget.onSwipeWeekEnabledChanged,
          ),
          const SizedBox(height: 12),
          const _GroupTitle('课前提醒'),
          _LabeledSlider(
            title: '提醒时间',
            minLabel: '关闭',
            maxLabel: '60 分钟',
            valueLabel:
                widget.reminderMinutes == 0 ? '关闭' : '${widget.reminderMinutes} 分钟',
            min: 0,
            max: 60,
            divisions: 12,
            value: widget.reminderMinutes.toDouble(),
            onChanged: (value) => widget.onReminderChanged(value.round()),
          ),
        ],
      ),
    );
  }

  Widget _floatingPetPage(BuildContext context) {
    return GlassCard(
      style: widget.cardStyle,
      themeSeed: widget.themeSeed,
      staticMode: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GroupTitle('悬浮球'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用蓝色猫头悬浮球'),
            subtitle: Text(
              widget.floatingPetEnabled
                  ? '显示课程提醒，可拖动吸边'
                  : '首次开启需要手动授予悬浮窗权限',
            ),
            value: widget.floatingPetEnabled,
            onChanged: widget.onFloatingPetEnabledChanged,
          ),
          _LabeledSlider(
            title: '卡片模糊度',
            minLabel: '清晰',
            maxLabel: '模糊',
            valueLabel: '${widget.floatingPetCardBlur.round()}dp',
            min: 0,
            max: 30,
            divisions: 30,
            value: widget.floatingPetCardBlur,
            onChanged: widget.onFloatingPetCardBlurChanged,
          ),
        ],
      ),
    );
  }

  Widget _appearancePage(BuildContext context) {
    return GlassCard(
      style: widget.cardStyle,
      themeSeed: widget.themeSeed,
      staticMode: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _GroupTitle('主题')),
              TextButton.icon(
                onPressed: widget.onResetAppearance,
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
                  selected: color.toARGB32() == widget.themeSeed.toARGB32(),
                  onTap: () => widget.onThemeSeedChanged(color),
                ),
              for (final color in widget.customThemeColors)
                _ColorDot(
                  color: color,
                  selected: color.toARGB32() == widget.themeSeed.toARGB32(),
                  onTap: () => widget.onThemeSeedChanged(color),
                  onDelete: () => widget.onDeleteCustomThemeColor(color),
                ),
              _AddColorDot(
                enabled: widget.customThemeColors.length < 8,
                onTap: () => _showAddThemeColorPicker(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SubTitle('背景图片'),
          const SizedBox(height: 8),
          Text(
            widget.backgroundImagePath == null
                ? '使用默认纯色背景'
                : '已选择图片，上传时按界面比例裁剪',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: widget.onPickBackgroundImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('上传图片'),
                ),
              ),
              if (widget.backgroundImagePath != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: widget.onClearBackgroundImage,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('移除'),
                ),
              ],
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('裁剪适配屏幕'),
            subtitle: const Text('打开后按屏幕铺满显示，关闭则完整显示图片'),
            value: widget.cropBackgroundToScreen,
            onChanged: widget.onCropBackgroundChanged,
          ),
          _LabeledSlider(
            title: '图片透明度',
            minLabel: '0%',
            maxLabel: '100%',
            valueLabel: '${(widget.backgroundOpacity * 100).round()}%',
            min: 0,
            max: 1,
            divisions: 20,
            value: widget.backgroundOpacity,
            onChanged: widget.onBackgroundOpacityChanged,
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
            selected: {widget.themeMode},
            onSelectionChanged: (value) =>
                widget.onThemeModeChanged(value.first),
          ),
          const SizedBox(height: 20),
          const _SubTitle('卡片风格'),
          const SizedBox(height: 8),
          _LabeledSlider(
            title: '卡片透明度',
            minLabel: '5%',
            maxLabel: '35%',
            valueLabel: '${(widget.cardStyle.opacity * 100).round()}%',
            min: 0.05,
            max: 0.35,
            divisions: 30,
            value: widget.cardStyle.opacity,
            onChanged: (value) => _changeCardStyle(opacity: value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TintChip(
                label: '纯白',
                tint: CardTint.pureWhite,
                selected: widget.cardStyle.tint == CardTint.pureWhite,
                onSelected: (value) => _changeCardStyle(tint: value),
              ),
              _TintChip(
                label: '暖白',
                tint: CardTint.warmWhite,
                selected: widget.cardStyle.tint == CardTint.warmWhite,
                onSelected: (value) => _changeCardStyle(tint: value),
              ),
              _TintChip(
                label: '淡紫',
                tint: CardTint.lavender,
                selected: widget.cardStyle.tint == CardTint.lavender,
                onSelected: (value) => _changeCardStyle(tint: value),
              ),
              _TintChip(
                label: '无色',
                tint: CardTint.none,
                selected: widget.cardStyle.tint == CardTint.none,
                onSelected: (value) => _changeCardStyle(tint: value),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('边框发光'),
            subtitle: const Text('开启后使用白色半透明 1px 边框'),
            value: widget.cardStyle.borderGlow,
            onChanged: (value) => _changeCardStyle(borderGlow: value),
          ),
          const _SubTitle('字体颜色'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FontColorChip(
                label: '跟随',
                color: null,
                selected: widget.cardStyle.fontColorValue == null,
                onSelected: _changeFontColor,
              ),
              _FontColorChip(
                label: '深色',
                color: const Color(0xff17201b),
                selected: widget.cardStyle.fontColorValue ==
                    const Color(0xff17201b).toARGB32(),
                onSelected: _changeFontColor,
              ),
              _FontColorChip(
                label: '浅色',
                color: Colors.white,
                selected:
                    widget.cardStyle.fontColorValue == Colors.white.toARGB32(),
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
    );
  }

  Widget _dataPage(BuildContext context) {
    return GlassCard(
      style: widget.cardStyle,
      themeSeed: widget.themeSeed,
      staticMode: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GroupTitle('本地数据'),
          _InfoRow(
            icon: Icons.calendar_month_outlined,
            title: '当前课表',
            subtitle: widget.importedCourseCount == 0
                ? '暂无本地课表数据'
                : '已保留 ${widget.importedCourseCount} 条课程，可离线查看',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.security_outlined,
            title: '账号凭据',
            subtitle: widget.savedUsername == null
                ? '未保存账号'
                : '账号仅保存在系统安全存储中',
          ),
          const SizedBox(height: 10),
          const _InfoRow(
            icon: Icons.image_outlined,
            title: '背景图片缓存',
            subtitle: '原图保留在本地，显示时使用轻量缓存图以减少卡顿。',
          ),
        ],
      ),
    );
  }

  Widget _aboutPage(BuildContext context) {
    return GlassCard(
      style: widget.cardStyle,
      themeSeed: widget.themeSeed,
      staticMode: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GroupTitle('NyaCourse'),
          const Text('版本 0.2.1+3'),
          const SizedBox(height: 6),
          const Text('广东工业大学课表、成绩与考试安排工具。'),
          const SizedBox(height: 16),
          _ActionRow(
            icon: Icons.new_releases_outlined,
            title: '更新内容',
            subtitle: '查看当前版本变更',
            onTap: () => _showChangelogDialog(context),
          ),
          _ActionRow(
            icon: Icons.code,
            title: 'GitHub 仓库',
            subtitle: _githubUrl,
            onTap: () => _openUrl(_githubUrl),
          ),
          _ActionRow(
            icon: Icons.system_update_alt,
            title: '检查更新',
            subtitle: _checkingUpdate ? '正在检查...' : '从 GitHub Releases 获取最新版本',
            onTap: _checkingUpdate ? null : _checkForUpdates,
          ),
          const Divider(height: 24),
          const _InfoRow(
            icon: Icons.privacy_tip_outlined,
            title: '隐私说明',
            subtitle: '账号只保存在系统安全存储中，release 签名文件不进入仓库。',
          ),
        ],
      ),
    );
  }

  void _changeCardStyle({
    double? opacity,
    CardTint? tint,
    bool? borderGlow,
    int? fontColorValue,
    bool clearFontColor = false,
  }) {
    widget.onCardStyleChanged(
      CardStyleSettings(
        blur: widget.cardStyle.blur,
        opacity: opacity ?? widget.cardStyle.opacity,
        tint: tint ?? widget.cardStyle.tint,
        borderGlow: borderGlow ?? widget.cardStyle.borderGlow,
        fontColorValue:
            clearFontColor ? null : fontColorValue ?? widget.cardStyle.fontColorValue,
      ),
    );
  }

  void _changeFontColor(Color? color) {
    _changeCardStyle(
      fontColorValue: color?.toARGB32(),
      clearFontColor: color == null,
    );
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.parse(value);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showSnackBar('无法打开链接');
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http.get(
        Uri.parse(_latestReleaseApi),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 404) {
        _showSnackBar('GitHub 还没有发布 Release');
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Invalid release response');
      }
      final tag = decoded['tag_name']?.toString() ?? '';
      final latest = _normalizeVersion(tag);
      final current = _normalizeVersion(info.version);
      final body = decoded['body']?.toString() ?? '';
      final releaseUrl =
          decoded['html_url']?.toString().isNotEmpty == true
              ? decoded['html_url'].toString()
              : _latestReleasePage;
      if (latest.isNotEmpty && _compareVersion(latest, current) > 0) {
        if (!mounted) {
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('发现新版本 $tag'),
            content: SingleChildScrollView(
              child: Text(body.trim().isEmpty ? '可以前往 GitHub 下载最新版。' : body),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openUrl(releaseUrl);
                },
                child: const Text('前往下载'),
              ),
            ],
          ),
        );
      } else {
        _showSnackBar('已经是最新版本');
      }
    } catch (_) {
      _showSnackBar('检查更新失败，请稍后再试');
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  String _normalizeVersion(String value) {
    return value.trim().replaceFirst(RegExp('^v', caseSensitive: false), '')
        .split('+')
        .first;
  }

  int _compareVersion(String a, String b) {
    final left = a.split('.').map((item) => int.tryParse(item) ?? 0).toList();
    final right = b.split('.').map((item) => int.tryParse(item) ?? 0).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final diff =
          (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
      if (diff != 0) {
        return diff;
      }
    }
    return 0;
  }

  Future<void> _showFontColorPicker(BuildContext context) async {
    var pickerColor = widget.cardStyle.fontColorValue == null
        ? Colors.white
        : Color(widget.cardStyle.fontColorValue!);
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
    var pickerColor = widget.themeSeed;
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
                  widget.onAddCustomThemeColor(pickerColor);
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
                version: '0.2.1+3',
                items: [
                  '课表页顶部新增今天日期',
                  '优化设置页为二级菜单',
                  '关于页新增 GitHub 仓库和检查更新',
                ],
              ),
              SizedBox(height: 14),
              _ChangelogVersion(
                version: '0.2.0+2',
                items: [
                  '新增蓝色猫头悬浮球',
                  '优化启动速度和背景图性能',
                  '完善数据更新时间和离线缓存提示',
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

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _sectionTitle(_SettingsSection section) {
    return switch (section) {
      _SettingsSection.account => '账号与同步',
      _SettingsSection.schedule => '课表与提醒',
      _SettingsSection.floatingPet => '悬浮球',
      _SettingsSection.appearance => '外观主题',
      _SettingsSection.data => '数据与缓存',
      _SettingsSection.about => '关于',
    };
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.summary,
    required this.cardStyle,
    required this.themeSeed,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String summary;
  final CardStyleSettings cardStyle;
  final Color themeSeed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        style: cardStyle,
        themeSeed: themeSeed,
        staticMode: true,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        borderRadius: 10,
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onPrimaryContainer,
              child: Icon(icon, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text(
              summary,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.58),
                  ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
            child: Text('- $item'),
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
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color.withValues(alpha: 0.78)),
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
                      color: color.withValues(alpha: error ? 0.88 : 0.62),
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
