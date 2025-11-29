import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置管理 Provider
///
/// 负责管理应用的设置和偏好，包括：
/// - 主题模式（明暗主题）
/// - 播放设置（默认播放速度、自动播放等）
/// - 其他用户偏好设置
class SettingsProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyDefaultPlaybackSpeed = 'default_playback_speed';
  static const String _keyAutoPlay = 'auto_play';
  static const String _keySleepTimerDuration = 'sleep_timer_duration';

  SharedPreferences? _prefs;

  /// 主题模式
  ThemeMode _themeMode = ThemeMode.system;

  /// 默认播放速度
  double _defaultPlaybackSpeed = 1.0;

  /// 是否自动播放
  bool _autoPlay = false;

  /// 睡眠定时器时长（分钟）
  int _sleepTimerDuration = 30;

  // Getters
  ThemeMode get themeMode => _themeMode;
  double get defaultPlaybackSpeed => _defaultPlaybackSpeed;
  bool get autoPlay => _autoPlay;
  int get sleepTimerDuration => _sleepTimerDuration;

  /// 是否为暗色主题
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// 初始化设置
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    // 加载主题模式
    final themeModeIndex = _prefs!.getInt(_keyThemeMode);
    if (themeModeIndex != null) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    // 加载默认播放速度
    _defaultPlaybackSpeed =
        _prefs!.getDouble(_keyDefaultPlaybackSpeed) ?? 1.0;

    // 加载自动播放设置
    _autoPlay = _prefs!.getBool(_keyAutoPlay) ?? false;

    // 加载睡眠定时器时长
    _sleepTimerDuration = _prefs!.getInt(_keySleepTimerDuration) ?? 30;

    notifyListeners();
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt(_keyThemeMode, mode.index);
    notifyListeners();
  }

  /// 切换主题模式
  Future<void> toggleThemeMode() async {
    final newMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : _themeMode == ThemeMode.dark
            ? ThemeMode.system
            : ThemeMode.light;
    await setThemeMode(newMode);
  }

  /// 设置默认播放速度
  Future<void> setDefaultPlaybackSpeed(double speed) async {
    _defaultPlaybackSpeed = speed;
    await _prefs?.setDouble(_keyDefaultPlaybackSpeed, speed);
    notifyListeners();
  }

  /// 设置自动播放
  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
    await _prefs?.setBool(_keyAutoPlay, value);
    notifyListeners();
  }

  /// 设置睡眠定时器时长
  Future<void> setSleepTimerDuration(int minutes) async {
    _sleepTimerDuration = minutes;
    await _prefs?.setInt(_keySleepTimerDuration, minutes);
    notifyListeners();
  }

  /// 重置所有设置
  Future<void> resetSettings() async {
    _themeMode = ThemeMode.system;
    _defaultPlaybackSpeed = 1.0;
    _autoPlay = false;
    _sleepTimerDuration = 30;

    await _prefs?.clear();
    notifyListeners();
  }

  /// 获取主题模式显示名称
  String getThemeModeName() {
    switch (_themeMode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  /// 获取播放速度选项列表
  static List<double> get playbackSpeedOptions => [
        0.5,
        0.75,
        1.0,
        1.25,
        1.5,
        1.75,
        2.0,
      ];

  /// 获取睡眠定时器时长选项列表（分钟）
  static List<int> get sleepTimerDurationOptions => [
        5,
        10,
        15,
        20,
        30,
        45,
        60,
        90,
        120,
      ];
}
