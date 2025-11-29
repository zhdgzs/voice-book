/// 播放进度模型
///
/// 记录音频文件的播放进度，用于恢复播放位置
class PlaybackProgress {
  /// 进度记录 ID
  final int? id;

  /// 音频文件 ID
  final int audioFileId;

  /// 播放位置（毫秒）
  final int position;

  /// 音频总时长（毫秒）
  final int duration;

  /// 播放速度
  final double playbackSpeed;

  /// 更新时间（Unix 时间戳，毫秒）
  final int updatedAt;

  PlaybackProgress({
    this.id,
    required this.audioFileId,
    required this.position,
    required this.duration,
    this.playbackSpeed = 1.0,
    required this.updatedAt,
  });

  /// 从数据库 Map 创建 PlaybackProgress 对象
  factory PlaybackProgress.fromMap(Map<String, dynamic> map) {
    return PlaybackProgress(
      id: map['id'] as int?,
      audioFileId: map['audio_file_id'] as int,
      position: map['position'] as int,
      duration: map['duration'] as int,
      playbackSpeed: map['playback_speed'] as double? ?? 1.0,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'audio_file_id': audioFileId,
      'position': position,
      'duration': duration,
      'playback_speed': playbackSpeed,
      'updated_at': updatedAt,
    };
  }

  /// 复制并修改部分字段
  PlaybackProgress copyWith({
    int? id,
    int? audioFileId,
    int? position,
    int? duration,
    double? playbackSpeed,
    int? updatedAt,
  }) {
    return PlaybackProgress(
      id: id ?? this.id,
      audioFileId: audioFileId ?? this.audioFileId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 获取播放进度百分比（0.0 - 1.0）
  double get progressPercentage {
    if (duration == 0) return 0.0;
    return (position / duration).clamp(0.0, 1.0);
  }

  /// 获取剩余时长（毫秒）
  int get remainingDuration {
    return (duration - position).clamp(0, duration);
  }

  /// 是否已播放完成
  bool get isCompleted {
    return position >= duration;
  }

  /// 获取格式化的播放位置
  String get formattedPosition {
    return _formatDuration(position);
  }

  /// 获取格式化的总时长
  String get formattedDuration {
    return _formatDuration(duration);
  }

  /// 获取格式化的剩余时长
  String get formattedRemainingDuration {
    return _formatDuration(remainingDuration);
  }

  /// 格式化时长
  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  String toString() {
    return 'PlaybackProgress{id: $id, audioFileId: $audioFileId, position: $formattedPosition, duration: $formattedDuration, speed: ${playbackSpeed}x}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PlaybackProgress &&
        other.id == id &&
        other.audioFileId == audioFileId &&
        other.position == position &&
        other.duration == duration &&
        other.playbackSpeed == playbackSpeed &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      audioFileId,
      position,
      duration,
      playbackSpeed,
      updatedAt,
    );
  }
}
