import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_file.dart';
import '../models/playback_progress.dart';
import '../services/database_service.dart';

/// 音频播放器 Provider
///
/// 负责管理音频播放的所有状态和操作，包括：
/// - 播放/暂停/停止控制
/// - 播放进度管理
/// - 倍速播放
/// - 播放进度的保存和恢复
class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DatabaseService _databaseService = DatabaseService();

  /// 当前播放的音频文件
  AudioFile? _currentAudioFile;

  /// 播放状态
  PlayerState _playerState = PlayerState(false, ProcessingState.idle);

  /// 当前播放位置（毫秒）
  int _position = 0;

  /// 音频总时长（毫秒）
  int _duration = 0;

  /// 播放速度
  double _playbackSpeed = 1.0;

  /// 是否正在加载
  bool _isLoading = false;

  /// 错误信息
  String? _errorMessage;

  // Getters
  AudioFile? get currentAudioFile => _currentAudioFile;
  PlayerState get playerState => _playerState;
  int get position => _position;
  int get duration => _duration;
  double get playbackSpeed => _playbackSpeed;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 是否正在播放
  bool get isPlaying => _playerState.playing;

  /// 播放进度百分比（0.0 - 1.0）
  double get progress {
    if (_duration == 0) return 0.0;
    return (_position / _duration).clamp(0.0, 1.0);
  }

  AudioPlayerProvider() {
    _initializePlayer();
  }

  /// 初始化播放器
  void _initializePlayer() {
    // 监听播放状态变化
    _audioPlayer.playerStateStream.listen((state) {
      _playerState = state;
      notifyListeners();
    });

    // 监听播放位置变化
    _audioPlayer.positionStream.listen((position) {
      _position = position.inMilliseconds;
      notifyListeners();

      // 每 5 秒自动保存一次进度
      if (_position % 5000 < 100 && _currentAudioFile != null) {
        _saveProgress();
      }
    });

    // 监听时长变化
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration.inMilliseconds;
        notifyListeners();
      }
    });

    // 监听播放速度变化
    _audioPlayer.speedStream.listen((speed) {
      _playbackSpeed = speed;
      notifyListeners();
    });
  }

  /// 加载并播放音频文件
  Future<void> loadAndPlay(AudioFile audioFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 如果是同一个文件，直接播放
      if (_currentAudioFile?.id == audioFile.id) {
        await play();
        return;
      }

      // 停止当前播放
      await stop();

      // 设置当前音频文件
      _currentAudioFile = audioFile;

      // 加载音频文件
      await _audioPlayer.setFilePath(audioFile.filePath);

      // 恢复播放进度
      await _restoreProgress();

      // 开始播放
      await play();
    } catch (e) {
      _errorMessage = '加载音频文件失败: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 播放
  Future<void> play() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      _errorMessage = '播放失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  /// 暂停
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      await _saveProgress();
    } catch (e) {
      _errorMessage = '暂停失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  /// 停止
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      await _saveProgress();
    } catch (e) {
      _errorMessage = '停止失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  /// 跳转到指定位置
  Future<void> seek(int milliseconds) async {
    try {
      await _audioPlayer.seek(Duration(milliseconds: milliseconds));
      _position = milliseconds;
      notifyListeners();
    } catch (e) {
      _errorMessage = '跳转失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  /// 快进（默认 10 秒）
  Future<void> seekForward([int seconds = 10]) async {
    final newPosition = (_position + seconds * 1000).clamp(0, _duration);
    await seek(newPosition);
  }

  /// 快退（默认 10 秒）
  Future<void> seekBackward([int seconds = 10]) async {
    final newPosition = (_position - seconds * 1000).clamp(0, _duration);
    await seek(newPosition);
  }

  /// 设置播放速度
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
      _playbackSpeed = speed;
      notifyListeners();
    } catch (e) {
      _errorMessage = '设置播放速度失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  /// 保存播放进度
  Future<void> _saveProgress() async {
    if (_currentAudioFile == null) return;

    try {
      final db = await _databaseService.database;
      final progress = PlaybackProgress(
        audioFileId: _currentAudioFile!.id!,
        position: _position,
        duration: _duration,
        playbackSpeed: _playbackSpeed,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await db.insert(
        'playback_progress',
        progress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('保存播放进度失败: $e');
    }
  }

  /// 恢复播放进度
  Future<void> _restoreProgress() async {
    if (_currentAudioFile == null) return;

    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'playback_progress',
        where: 'audio_file_id = ?',
        whereArgs: [_currentAudioFile!.id],
      );

      if (maps.isNotEmpty) {
        final progress = PlaybackProgress.fromMap(maps.first);
        await seek(progress.position);
        await setPlaybackSpeed(progress.playbackSpeed);
      }
    } catch (e) {
      debugPrint('恢复播放进度失败: $e');
    }
  }

  /// 清空错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _saveProgress();
    _audioPlayer.dispose();
    super.dispose();
  }
}
