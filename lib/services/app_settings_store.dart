import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum CardTint { pureWhite, warmWhite, lavender, none }

enum ScheduleWidgetAppearanceMode { system, light, dark, paper }

class CardStyleSettings {
  const CardStyleSettings({
    required this.blur,
    required this.opacity,
    required this.tint,
    required this.borderGlow,
    this.fontColorValue,
  });

  static const defaults = CardStyleSettings(
    blur: 16,
    opacity: 0.12,
    tint: CardTint.pureWhite,
    borderGlow: true,
  );

  final double blur;
  final double opacity;
  final CardTint tint;
  final bool borderGlow;
  final int? fontColorValue;
}

class SavedAppSettings {
  const SavedAppSettings({
    this.backgroundImagePath,
    this.backgroundDisplayImagePath,
    this.backgroundOpacity,
    this.cropBackgroundToScreen,
    this.swipeWeekEnabled,
    this.floatingPetEnabled,
    this.floatingPetCardBlur,
    this.scheduleWidgetShowRoom,
    this.scheduleWidgetAppearanceMode,
    this.cardStyle,
    this.customThemeColorValues,
    this.themeSeedValue,
  });

  final String? backgroundImagePath;
  final String? backgroundDisplayImagePath;
  final double? backgroundOpacity;
  final bool? cropBackgroundToScreen;
  final bool? swipeWeekEnabled;
  final bool? floatingPetEnabled;
  final double? floatingPetCardBlur;
  final bool? scheduleWidgetShowRoom;
  final ScheduleWidgetAppearanceMode? scheduleWidgetAppearanceMode;
  final CardStyleSettings? cardStyle;
  final List<int>? customThemeColorValues;
  final int? themeSeedValue;
}

class AppSettingsStore {
  const AppSettingsStore();

  static const _storage = FlutterSecureStorage();
  static const _settingsKey = 'nyacourse_app_settings';

  Future<SavedAppSettings> read() async {
    final raw = await _storage.read(key: _settingsKey);
    if (raw == null || raw.isEmpty) {
      return const SavedAppSettings();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const SavedAppSettings();
    }

    return SavedAppSettings(
      backgroundImagePath: decoded['backgroundImagePath']?.toString(),
      backgroundDisplayImagePath:
          decoded['backgroundDisplayImagePath']?.toString(),
      backgroundOpacity: _doubleOf(decoded['backgroundOpacity']),
      cropBackgroundToScreen: decoded['cropBackgroundToScreen'] as bool?,
      swipeWeekEnabled: decoded['swipeWeekEnabled'] as bool?,
      floatingPetEnabled: decoded['floatingPetEnabled'] as bool?,
      floatingPetCardBlur: _doubleOf(decoded['floatingPetCardBlur']),
      scheduleWidgetShowRoom: decoded['scheduleWidgetShowRoom'] as bool?,
      scheduleWidgetAppearanceMode: _scheduleWidgetAppearanceModeOf(
        decoded['scheduleWidgetAppearanceMode'],
      ),
      cardStyle: _cardStyleOf(decoded['cardStyle']),
      customThemeColorValues: _intListOf(decoded['customThemeColorValues']),
      themeSeedValue: _intOf(decoded['themeSeedValue']),
    );
  }

  Future<void> save({
    required String? backgroundImagePath,
    String? backgroundDisplayImagePath,
    required double backgroundOpacity,
    required bool cropBackgroundToScreen,
    required bool swipeWeekEnabled,
    required bool floatingPetEnabled,
    required double floatingPetCardBlur,
    required bool scheduleWidgetShowRoom,
    required ScheduleWidgetAppearanceMode scheduleWidgetAppearanceMode,
    required CardStyleSettings cardStyle,
    required List<int> customThemeColorValues,
    required int themeSeedValue,
  }) async {
    await _storage.write(
      key: _settingsKey,
      value: jsonEncode({
        'backgroundImagePath': backgroundImagePath,
        'backgroundDisplayImagePath': backgroundDisplayImagePath,
        'backgroundOpacity': backgroundOpacity,
        'cropBackgroundToScreen': cropBackgroundToScreen,
        'swipeWeekEnabled': swipeWeekEnabled,
        'floatingPetEnabled': floatingPetEnabled,
        'floatingPetCardBlur': floatingPetCardBlur,
        'scheduleWidgetShowRoom': scheduleWidgetShowRoom,
        'scheduleWidgetAppearanceMode': scheduleWidgetAppearanceMode.name,
        'customThemeColorValues': customThemeColorValues,
        'themeSeedValue': themeSeedValue,
        'cardStyle': {
          'blur': cardStyle.blur,
          'opacity': cardStyle.opacity,
          'tint': cardStyle.tint.name,
          'borderGlow': cardStyle.borderGlow,
          'fontColorValue': cardStyle.fontColorValue,
        },
      }),
    );
  }

  static CardStyleSettings? _cardStyleOf(Object? value) {
    if (value is! Map) {
      return null;
    }
    final tintName = value['tint']?.toString();
    return CardStyleSettings(
      blur: (_doubleOf(value['blur']) ?? CardStyleSettings.defaults.blur)
          .clamp(0, 24)
          .toDouble(),
      opacity:
          (_doubleOf(value['opacity']) ?? CardStyleSettings.defaults.opacity)
              .clamp(0.05, 0.35)
              .toDouble(),
      tint: CardTint.values.firstWhere(
        (item) => item.name == tintName,
        orElse: () => CardStyleSettings.defaults.tint,
      ),
      borderGlow:
          value['borderGlow'] as bool? ?? CardStyleSettings.defaults.borderGlow,
      fontColorValue: _intOf(value['fontColorValue']),
    );
  }

  static ScheduleWidgetAppearanceMode? _scheduleWidgetAppearanceModeOf(
    Object? value,
  ) {
    final name = value?.toString();
    for (final mode in ScheduleWidgetAppearanceMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return null;
  }

  static double? _doubleOf(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _intOf(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static List<int>? _intListOf(Object? value) {
    if (value is! List) {
      return null;
    }
    return value.map(_intOf).whereType<int>().toList();
  }
}
