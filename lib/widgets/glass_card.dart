import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/app_settings_store.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.style,
    required this.themeSeed,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 14,
    this.staticMode = false,
    this.onTap,
    super.key,
  });

  final CardStyleSettings style;
  final Color themeSeed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool staticMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = glassForegroundColor(context, style);
    final content = DefaultTextStyle.merge(
      style: TextStyle(color: foreground),
      child: IconTheme.merge(
        data: IconThemeData(color: foreground),
        child: Padding(padding: padding, child: child),
      ),
    );

    final material = Material(
      color: _cardColor(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: style.borderGlow
            ? BorderSide(color: Colors.white.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              child: content,
            ),
    );
    if (staticMode || style.blur <= 0) {
      return material;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: style.blur, sigmaY: style.blur),
        child: material,
      ),
    );
  }

  Color _cardColor() {
    final baseAlpha = style.tint == CardTint.none ? 0.08 : style.opacity;
    final alpha = staticMode ? (baseAlpha + 0.08).clamp(0.10, 0.38) : baseAlpha;
    return _tintColor().withValues(alpha: alpha);
  }

  Color _tintColor() {
    return switch (style.tint) {
      CardTint.pureWhite => Colors.white,
      CardTint.warmWhite => Color.lerp(Colors.white, Colors.yellow, 0.05)!,
      CardTint.lavender =>
        Color.lerp(const Color(0xfff0e8ff), themeSeed, 0.12)!,
      CardTint.none => Colors.transparent,
    };
  }
}

Color glassForegroundColor(BuildContext context, CardStyleSettings style) {
  final value = style.fontColorValue;
  if (value != null) {
    return Color(value);
  }
  return Theme.of(context).colorScheme.onSurface;
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.style,
    required this.themeSeed,
    required this.icon,
    required this.tooltip,
    this.staticMode = false,
    this.onPressed,
    super.key,
  });

  final CardStyleSettings style;
  final Color themeSeed;
  final IconData icon;
  final String tooltip;
  final bool staticMode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = glassForegroundColor(context, style);
    final material = Material(
      color: _cardColor(),
      shape: CircleBorder(
        side: style.borderGlow
            ? BorderSide(color: Colors.white.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        color: foreground,
        disabledColor: foreground.withValues(alpha: 0.32),
        iconSize: 20,
        icon: Icon(icon),
      ),
    );
    final button = SizedBox(
      width: 38,
      height: 38,
      child: staticMode || style.blur <= 0
          ? material
          : ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: style.blur, sigmaY: style.blur),
                child: material,
              ),
          ),
    );
    return Tooltip(
      message: tooltip,
      child: button,
    );
  }

  Color _cardColor() {
    final baseAlpha = style.tint == CardTint.none ? 0.08 : style.opacity;
    final alpha = staticMode ? (baseAlpha + 0.08).clamp(0.10, 0.38) : baseAlpha;
    return _tintColor().withValues(alpha: alpha);
  }

  Color _tintColor() {
    return switch (style.tint) {
      CardTint.pureWhite => Colors.white,
      CardTint.warmWhite => Color.lerp(Colors.white, Colors.yellow, 0.05)!,
      CardTint.lavender =>
        Color.lerp(const Color(0xfff0e8ff), themeSeed, 0.12)!,
      CardTint.none => Colors.transparent,
    };
  }
}
