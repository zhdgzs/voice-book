import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sleep_timer.dart';

/// 睡眠定时器 Provider
///
/// 负责管理睡眠定时器的所有状态和操作，包括：
/// - 按分钟定时
/// - 按集数定时
/// - 定时器倒计时
/// - 定时器到期回调
class SleepTimerProvider extends ChangeNotifier {
  /// 当前定时器配置
  SleepTimer? _sleepTimer;

  /// 定时器（用于按分钟模式的倒计时）
  Timer? _countdownTimer;

  /// 剩余集数（用于按集数模式）
  int _remainingEpisodes = 0;

  /// 定时器到期回调
  VoidCallback? _onTimerExpired;

  // Getters
  SleepTimer? get sleepTimer => _sleepTimer;
  bool get isActive => _sleepTimer?.isActive ?? false;
  SleepTimerMode? get mode => _sleepTimer?.mode;
  int get remainingEpisodes => _remainingEpisodes;

  /// 获取剩余时间（毫秒）
  /// 仅在按分钟模式下有效
  int get remainingMilliseconds {
    if (_sleepTimer == null || !_sleepTimer!.isActive) {
      return 0;
    }
    return _sleepTimer!.getRemainingMilliseconds();
  }

  /// 获取剩余时间的格式化字符串
  String get remainingTimeString {
    if (_sleepTimer == null || !_sleepTimer!.isActive) {
      return '';
    }

    if (_sleepTimer!.mode == SleepTimerMode.minutes) {
      final remaining = remainingMilliseconds;
      final minutes = (remaining / 60000).floor();
      final seconds = ((remaining % 60000) / 1000).floor();
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$_remainingEpisodes 集';
    }
  }

  /// 设置定时器到期回调
  void setOnTimerExpired(VoidCallback callback) {
    _onTimerExpired = callback;
  }

  /// 启动定时器（按分钟）
  void startMinutesTimer(int minutes) {
    // 取消现有定时器
    cancelTimer();

    // 创建新定时器
    _sleepTimer = SleepTimer(
      mode: SleepTimerMode.minutes,
      minutes: minutes,
      startTime: DateTime.now(),
      isActive: true,
    );

    // 启动倒计时
    _startCountdown();

    debugPrint('✅ 睡眠定时器已启动: $minutes 分钟');
    notifyListeners();
  }

  /// 启动定时器（按集数）
  void startEpisodesTimer(int episodes) {
    // 取消现有定时器
    cancelTimer();

    // 创建新定时器
    _sleepTimer = SleepTimer(
      mode: SleepTimerMode.episodes,
      episodes: episodes,
      startTime: DateTime.now(),
      isActive: true,
    );

    _remainingEpisodes = episodes;

    debugPrint('✅ 睡眠定时器已启动: $episodes 集');
    notifyListeners();
  }

  /// 启动倒计时（仅用于按分钟模式）
  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimer == null || !_sleepTimer!.isActive) {
        timer.cancel();
        return;
      }

      // 检查是否到期
      if (_sleepTimer!.isExpired) {
        debugPrint('⏰ 睡眠定时器到期');
        _onTimerExpiredInternal();
        timer.cancel();
        return;
      }

      notifyListeners();
    });
  }

  /// 减少剩余集数（用于按集数模式）
  /// 当播放完一集时调用
  void decrementEpisode() {
    if (_sleepTimer == null ||
        !_sleepTimer!.isActive ||
        _sleepTimer!.mode != SleepTimerMode.episodes) {
      return;
    }

    _remainingEpisodes--;
    debugPrint('📉 剩余集数: $_remainingEpisodes');

    if (_remainingEpisodes <= 0) {
      debugPrint('⏰ 睡眠定时器到期（集数已完成）');
      _onTimerExpiredInternal();
    }

    notifyListeners();
  }

  /// 定时器到期的内部处理
  void _onTimerExpiredInternal() {
    // 取消定时器
    _countdownTimer?.cancel();
    _countdownTimer = null;

    // 调用回调（在重置状态之前）
    _onTimerExpired?.call();

    // 重置定时器状态
    _sleepTimer = null;
    _remainingEpisodes = 0;

    debugPrint('✅ 睡眠定时器已重置');
    notifyListeners();
  }

  /// 取消定时器
  void cancelTimer() {
    if (_sleepTimer == null || !_sleepTimer!.isActive) {
      return;
    }

    _countdownTimer?.cancel();
    _countdownTimer = null;

    // 完全重置定时器状态
    _sleepTimer = null;
    _remainingEpisodes = 0;

    debugPrint('❌ 睡眠定时器已取消并重置');
    notifyListeners();
  }

  /// 延长定时器（仅用于按分钟模式）
  void extendTimer(int additionalMinutes) {
    if (_sleepTimer == null ||
        !_sleepTimer!.isActive ||
        _sleepTimer!.mode != SleepTimerMode.minutes) {
      return;
    }

    final newMinutes = _sleepTimer!.minutes + additionalMinutes;
    _sleepTimer = _sleepTimer!.copyWith(minutes: newMinutes);

    debugPrint('⏰ 睡眠定时器已延长 $additionalMinutes 分钟，总计 $newMinutes 分钟');
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
