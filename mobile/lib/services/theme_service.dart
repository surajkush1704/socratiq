import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeService {
  static const String settingsBoxName = 'app_settings_box';
  static const String themeModeKey = 'app_theme_mode';

  /// Reactive notifier listened to by the root MaterialApp
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Current theme mode value
  static ThemeMode get currentThemeMode => themeModeNotifier.value;

  /// Initialize theme mode from persistent storage
  static Future<void> init() async {
    final box = await Hive.openBox(settingsBoxName);
    final savedMode = box.get(themeModeKey, defaultValue: 'system') as String;
    themeModeNotifier.value = _modeFromString(savedMode);
  }

  /// Update theme mode and persist to Hive
  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final box = Hive.box(settingsBoxName);
    await box.put(themeModeKey, _modeToString(mode));
  }

  /// Whether dark mode is currently active (taking system preference into account)
  static bool isDarkMode(BuildContext context) {
    if (themeModeNotifier.value == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return themeModeNotifier.value == ThemeMode.dark;
  }

  static ThemeMode _modeFromString(String val) {
    switch (val.toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }
}
