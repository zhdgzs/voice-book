import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// 通知栏控制回调接口
abstract class AudioControlCallback {
  Future<void> onPlay();
  Future<void> onPause();
  Future<void> onStop();
  Future<void> onSeek(int milliseconds);
  Future<void> onSkipToNext();
  Future<void> onSkipToPrevious();
}

/// AudioService 处理器，负责通知栏和锁屏控制
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  AudioControlCallback? _callback;

  AudioPlayer get player => _player;

  void setCallback(AudioControlCallback callback) {
    _callback = callback;
  }

  AudioPlayerHandler() {
    // 监听播放状态变化，更新通知栏
    _player.playerStateStream.listen((_) => _broadcastState());
    _player.currentIndexStream.listen((index) {
      _broadcastState();
    });
    // 初始化时广播初始状态
    _broadcastState();
  }

  void _broadcastState() {
    // 保持 v1.0.4 的服务生命周期，避免 idle 通知触发 audio_service 停止服务。
    final processingState = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.ready,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    ));
  }

  @override
  Future<void> play() async {
    debugPrint('🔊 AudioHandler.play() 被调用, callback=${_callback != null}');
    if (_callback != null) {
      await _callback!.onPlay();
    } else {
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    debugPrint('🔇 AudioHandler.pause() 被调用');
    if (_callback != null) {
      await _callback!.onPause();
    } else {
      await _player.pause();
    }
  }

  @override
  Future<void> stop() => _callback?.onStop() ?? _player.stop();

  @override
  Future<void> seek(Duration position) =>
      _callback?.onSeek(position.inMilliseconds) ?? _player.seek(position);

  @override
  Future<void> skipToNext() => _callback?.onSkipToNext() ?? _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _callback?.onSkipToPrevious() ?? _player.seekToPrevious();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  // 确保服务不会被系统杀死后无法恢复
  @override
  Future<void> onTaskRemoved() async {
    debugPrint('🔴 onTaskRemoved 被调用');
    // 不停止播放，保持服务运行
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    debugPrint('🎵 playMediaItem 被调用: ${mediaItem.title}');
    await play();
  }

  /// 设置播放列表
  Future<void> setAudioSources(List<AudioSource> sources, {int initialIndex = 0}) async {
    await _player.setAudioSources(sources, initialIndex: initialIndex, preload: true);
  }

  /// 设置单个音频源
  Future<void> setAudioSource(AudioSource source) async {
    await _player.setAudioSource(source);
  }

  /// 按音频 ID 同步通知栏信息，避免单文件模式的播放器索引与队列索引不一致。
  void updateCurrentMediaItem(String mediaId) {
    final items = queue.value;
    final index = items.indexWhere((item) => item.id == mediaId);
    if (index >= 0) {
      mediaItem.add(items[index]);
    }
  }

  /// 更新队列和当前媒体项
  void updateQueueWithIndex(List<MediaItem> items, int currentIndex) {
    queue.add(items);
    if (currentIndex >= 0 && currentIndex < items.length) {
      mediaItem.add(items[currentIndex]);
    }
  }
}
