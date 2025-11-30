/// 睡眠定时器模式
enum SleepTimerMode {
  /// 按分钟计时
  minutes,

  /// 按集数计时
  episodes,
}

/// 睡眠定时器配置
class SleepTimer {
  /// 定时器模式
  final SleepTimerMode mode;

  /// 分钟数（当 mode 为 minutes 时使用）
  final int minutes;

  /// 集数（当 mode 为 episodes 时使用）
  final int episodes;

  /// 定时器开始时间
  final DateTime startTime;

  /// 是否激活
  final bool isActive;

  SleepTimer({
    required this.mode,
    this.minutes = 0,
    this.episodes = 0,
    DateTime? startTime,
    this.isActive = false,
  }) : startTime = startTime ?? DateTime.now();

  /// 获取剩余时间（毫秒）
  /// 仅在按分钟模式下有效
  int getRemainingMilliseconds() {
    if (mode != SleepTimerMode.minutes || !isActive) {
      return 0;
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final total = minutes * 60 * 1000;
    final remaining = total - elapsed;

    return remaining > 0 ? remaining : 0;
  }

  /// 是否已过期
  bool get isExpired {
    if (!isActive) return false;

    if (mode == SleepTimerMode.minutes) {
      return getRemainingMilliseconds() <= 0;
    }

    // 按集数模式下，由外部控制过期状态
    return false;
  }

  /// 复制并修改
  SleepTimer copyWith({
    SleepTimerMode? mode,
    int? minutes,
    int? episodes,
    DateTime? startTime,
    bool? isActive,
  }) {
    return SleepTimer(
      mode: mode ?? this.mode,
      minutes: minutes ?? this.minutes,
      episodes: episodes ?? this.episodes,
      startTime: startTime ?? this.startTime,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    if (mode == SleepTimerMode.minutes) {
      return '定时器: $minutes 分钟';
    } else {
      return '定时器: $episodes 集';
    }
  }
}
