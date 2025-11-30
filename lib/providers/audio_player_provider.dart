import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_file.dart';
import '../models/playback_progress.dart';
import '../services/database_service.dart';
import 'package:sqflite/sqflite.dart';

/// 音频播放器 Provider
///
/// 负责管理音频播放的所有状态和操作，包括：
/// - 播放/暂停/停止控制
/// - 播放进度管理
/// - 倍速播放
/// - 播放进度的保存和恢复
/// - 跳过开头/结尾
class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DatabaseService _databaseService = DatabaseService();

  /// 设置 Provider（用于获取跳过时长配置）
  dynamic _settingsProvider;

  /// 当前播放的音频文件
  AudioFile? _currentAudioFile;

  /// 当前播放的书籍ID
  int? _currentBookId;

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

  /// 是否已触发播放完成处理（防止重复触发）
  bool _hasTriggeredCompletion = false;

  // Getters
  AudioFile? get currentAudioFile => _currentAudioFile;
  int? get currentBookId => _currentBookId;
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
    _restoreLastPlayback();
  }

  /// 设置 SettingsProvider（用于获取跳过时长配置）
  void setSettingsProvider(dynamic settingsProvider) {
    _settingsProvider = settingsProvider;
  }

  /// 获取跳过开头时长（秒）
  int get _skipStartSeconds {
    if (_settingsProvider == null) return 0;
    try {
      return _settingsProvider.skipStartSeconds as int;
    } catch (e) {
      return 0;
    }
  }

  /// 获取跳过结尾时长（秒）
  int get _skipEndSeconds {
    if (_settingsProvider == null) return 0;
    try {
      return _settingsProvider.skipEndSeconds as int;
    } catch (e) {
      return 0;
    }
  }

  /// 恢复上次播放的音频（仅恢复状态，不自动播放）
  Future<void> _restoreLastPlayback() async {
    try {
      final db = await _databaseService.database;
      final result = await db.rawQuery('''
        SELECT af.*, pp.position, pp.playback_speed, b.id as book_id
        FROM playback_progress pp
        JOIN audio_files af ON pp.audio_file_id = af.id
        JOIN books b ON af.book_id = b.id
        ORDER BY pp.updated_at DESC
        LIMIT 1
      ''');

      if (result.isNotEmpty) {
        final audioFile = AudioFile.fromMap(result.first);
        // 验证文件是否存在
        final file = io.File(audioFile.filePath);
        if (await file.exists()) {
          _currentAudioFile = audioFile;
          _currentBookId = result.first['book_id'] as int?;

          // 加载音频到播放器（但不播放）
          await _audioPlayer.setFilePath(audioFile.filePath);
          await _restoreProgress();

          notifyListeners();
        } else {
          // 文件不存在，清理无效的播放进度
          await db.delete('playback_progress', where: 'audio_file_id = ?', whereArgs: [audioFile.id]);
          debugPrint('上次播放的文件已不存在，已清理记录');
        }
      }
    } catch (e) {
      debugPrint('恢复上次播放失败: $e');
    }
  }

  /// 初始化播放器
  void _initializePlayer() {
    // 监听播放状态变化
    _audioPlayer.playerStateStream.listen((state) {
      _playerState = state;

      // 调试：打印播放状态变化
      debugPrint('🎵 播放状态变化: ${state.processingState}, playing: ${state.playing}, hasTriggered: $_hasTriggeredCompletion');

      // 当播放器准备好或开始播放时，重置加载状态
      if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.completed ||
          state.playing) {
        _isLoading = false;
      }

      // 当播放完成时，检查是否需要自动播放下一个
      if (state.processingState == ProcessingState.completed && !_hasTriggeredCompletion) {
        debugPrint('✅ 检测到播放完成，准备触发自动播放');
        _hasTriggeredCompletion = true;
        _onPlaybackCompleted();
      }

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

      // 检查是否接近结尾，需要跳过
      if (_skipEndSeconds > 0 && _duration > 0 && !_hasTriggeredCompletion) {
        final remainingMilliseconds = _duration - _position;
        final skipEndMilliseconds = _skipEndSeconds * 1000;

        // 如果剩余时间小于等于跳过结尾时长，且正在播放，则触发播放完成处理
        if (remainingMilliseconds <= skipEndMilliseconds && _playerState.playing) {
          debugPrint('接近结尾 $_skipEndSeconds 秒，触发播放完成处理');
          _hasTriggeredCompletion = true;
          // 先暂停当前播放
          pause();
          // 触发播放完成处理（会检查是否自动播放下一个）
          _onPlaybackCompleted();
        }
      }
    });

    // 监听时长变化
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration.inMilliseconds;
        // 如果数据库中时长为0，用播放器获取的时长回写
        if (_currentAudioFile != null && _currentAudioFile!.duration == 0 && _duration > 0) {
          _updateAudioFileDuration(_currentAudioFile!.id!, _duration);
        }
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
  Future<void> loadAndPlay(AudioFile audioFile, {int? bookId}) async {
    try {
      // 如果是同一个文件，直接播放
      if (_currentAudioFile?.id == audioFile.id) {
        await play();
        return;
      }

      // 重置播放完成标志
      _hasTriggeredCompletion = false;

      // 设置加载状态
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // 保存当前进度后再停止（不使用 stop，直接暂停并重置）
      await _saveProgress();

      // 设置当前音频文件和书籍ID
      _currentAudioFile = audioFile;
      _currentBookId = bookId ?? audioFile.bookId;

      // 更新书籍的当前音频文件ID
      if (_currentBookId != null) {
        await _updateBookCurrentAudio(_currentBookId!, audioFile.id!);
      }

      // 使用 setAudioSource 替代 setFilePath，并设置初始位置
      await _audioPlayer.setFilePath(audioFile.filePath);

      // 恢复播放进度
      await _restoreProgress();

      // 应用跳过开头逻辑：如果当前位置在跳过范围内，则跳到跳过开头的位置
      if (_skipStartSeconds > 0 && _position < _skipStartSeconds * 1000) {
        debugPrint('跳过开头 ${_skipStartSeconds}秒');
        await seek(_skipStartSeconds * 1000);
      }

      // 开始播放
      await play();
    } on PlayerInterruptedException {
      // 加载被中断（用户快速切换），忽略此错误
      debugPrint('音频加载被中断，用户切换了音频');
    } catch (e) {
      _errorMessage = '加载音频文件失败: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新书籍的当前音频文件ID
  Future<void> _updateBookCurrentAudio(int bookId, int audioFileId) async {
    try {
      final db = await _databaseService.database;
      await db.update(
        'books',
        {'current_audio_file_id': audioFileId, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    } catch (e) {
      debugPrint('更新书籍当前音频失败: $e');
    }
  }

  /// 播放
  Future<void> play() async {
    // 检查播放器是否已加载音频
    if (_playerState.processingState == ProcessingState.idle) {
      debugPrint('播放器未加载音频，忽略播放请求');
      return;
    }
    try {
      await _audioPlayer.play();
    } on PlayerInterruptedException {
      // 忽略中断异常
    } catch (e) {
      _errorMessage = '播放失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  /// 暂停
  Future<void> pause() async {
    // 检查播放器是否已加载音频
    if (_playerState.processingState == ProcessingState.idle) {
      return;
    }
    try {
      await _audioPlayer.pause();
      await _saveProgress();
    } on PlayerInterruptedException {
      // 忽略中断异常
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
    } on PlayerInterruptedException {
      // 忽略中断异常
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

  /// 更新音频文件时长到数据库
  Future<void> _updateAudioFileDuration(int audioFileId, int duration) async {
    try {
      final db = await _databaseService.database;
      await db.update('audio_files', {'duration': duration}, where: 'id = ?', whereArgs: [audioFileId]);
    } catch (e) {
      debugPrint('更新音频时长失败: $e');
    }
  }

  /// 播放完成时的处理
  Future<void> _onPlaybackCompleted() async {
    debugPrint('========== 音频播放完成 ==========');
    debugPrint('当前音频: ${_currentAudioFile?.fileName}');
    debugPrint('当前书籍ID: $_currentBookId');

    // 保存进度
    await _saveProgress();

    // 检查是否启用自动播放下一个
    if (_settingsProvider == null) {
      debugPrint('❌ SettingsProvider 为 null');
      return;
    }

    bool autoPlay = false;
    try {
      autoPlay = _settingsProvider.autoPlay as bool;
      debugPrint('自动播放设置: $autoPlay');
    } catch (e) {
      debugPrint('❌ 获取自动播放设置失败: $e');
      return;
    }

    if (!autoPlay) {
      debugPrint('⏸️ 自动播放已禁用');
      return;
    }

    // 获取下一个音频文件
    debugPrint('🔍 正在查找下一个音频文件...');
    final nextAudio = await _getNextAudioFile();
    if (nextAudio != null) {
      debugPrint('✅ 找到下一个音频: ${nextAudio.fileName}');
      debugPrint('🎵 开始自动播放下一个...');
      await loadAndPlay(nextAudio, bookId: _currentBookId);
    } else {
      debugPrint('⚠️ 没有下一个音频文件（已是最后一个）');
    }
    debugPrint('========================================');
  }

  /// 获取下一个音频文件
  Future<AudioFile?> _getNextAudioFile() async {
    if (_currentAudioFile == null || _currentBookId == null) {
      debugPrint('❌ 当前音频或书籍ID为空');
      return null;
    }

    try {
      final db = await _databaseService.database;
      final audioFileMaps = await db.query(
        'audio_files',
        where: 'book_id = ?',
        whereArgs: [_currentBookId],
        orderBy: 'sort_order ASC, file_name ASC',
      );

      debugPrint('📚 书籍中共有 ${audioFileMaps.length} 个音频文件');

      if (audioFileMaps.isEmpty) {
        debugPrint('❌ 书籍中没有音频文件');
        return null;
      }

      final audioFiles = audioFileMaps.map((map) => AudioFile.fromMap(map)).toList();

      // 找到当前音频的索引
      final currentIndex = audioFiles.indexWhere(
        (audio) => audio.id == _currentAudioFile!.id,
      );

      debugPrint('📍 当前音频索引: $currentIndex / ${audioFiles.length}');

      // 如果找到当前音频且不是最后一个，返回下一个
      if (currentIndex >= 0 && currentIndex < audioFiles.length - 1) {
        final nextAudio = audioFiles[currentIndex + 1];
        debugPrint('➡️ 下一个音频: ${nextAudio.fileName} (索引: ${currentIndex + 1})');
        return nextAudio;
      }

      debugPrint('⚠️ 已是最后一个音频文件');
      return null;
    } catch (e) {
      debugPrint('❌ 获取下一个音频文件失败: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _audioPlayer.dispose();
    super.dispose();
  }
}
