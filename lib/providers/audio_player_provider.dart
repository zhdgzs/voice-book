import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:voice_book/providers/settings_provider.dart';
import 'package:voice_book/providers/sleep_timer_provider.dart';
import '../models/audio_file.dart';
import '../models/book.dart';
import '../models/playback_progress.dart';
import '../services/database_service.dart';
import '../services/audio_handler.dart';
import '../main.dart' show audioHandler;
import '../services/wma_audio_service.dart';
import 'package:sqflite/sqflite.dart';

/// 音频播放器 Provider
///
/// 负责管理音频播放的所有状态和操作
class AudioPlayerProvider extends ChangeNotifier implements AudioControlCallback {
  AudioPlayer get _audioPlayer => audioHandler.player;
  final DatabaseService _databaseService = DatabaseService();

  /// 设置 Provider（用于获取自动播放设置）
  SettingsProvider? _settingsProvider;

  /// 睡眠定时器 Provider
  SleepTimerProvider? _sleepTimerProvider;

  /// 当前播放的音频文件
  AudioFile? _currentAudioFile;

  /// 当前播放的书籍ID
  int? _currentBookId;

  /// 当前书籍对象（用于获取跳过设置）
  Book? _currentBook;

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

  /// 是否已初始化（恢复上次播放）
  bool _isInitialized = false;

  AudioPlayerProvider() {
    debugPrint('🔧 AudioPlayerProvider 构造函数，设置回调');
    audioHandler.setCallback(this);
    _initializeAudioSession();
    _initializePlayer();
    // 不在构造函数中访问数据库，避免与其他 Provider 的数据库访问冲突
    // WMA 支持延迟初始化，避免阻塞应用启动
    _initializeWmaSupportAsync();
  }

  /// 初始化 WMA 音频支持（异步，不阻塞构造函数）
  void _initializeWmaSupportAsync() {
    Future.microtask(() async {
      try {
        await WmaAudioService().initialize();
        debugPrint('✅ WMA 音频支持已初始化');
      } catch (e) {
        debugPrint('⚠️ WMA 支持初始化失败（不影响其他格式播放）: $e');
      }
    });
  }

  /// 确保已初始化（懒加载）
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _restoreLastPlayback();
  }

  /// 初始化音频会话（用于后台播放和通知栏控制）
  Future<void> _initializeAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      debugPrint('音频会话初始化成功');
    } catch (e) {
      debugPrint('音频会话初始化失败: $e');
    }
  }

  /// 设置 SettingsProvider（用于获取自动播放设置）
  void setSettingsProvider(SettingsProvider settingsProvider) {
    _settingsProvider = settingsProvider;
    _playbackSpeed = _settingsProvider!.defaultPlaybackSpeed;
  }

  /// 设置 SleepTimerProvider（用于睡眠定时器功能）
  void setSleepTimerProvider(SleepTimerProvider sleepTimerProvider) {
    _sleepTimerProvider = sleepTimerProvider;
    // 设置定时器到期回调
    if (_sleepTimerProvider != null) {
      try {
        _sleepTimerProvider!.setOnTimerExpired(_onSleepTimerExpired);
      } catch (e) {
        debugPrint('设置睡眠定时器回调失败: $e');
      }
    }
  }

  /// 获取跳过开头时长（秒）- 从当前书籍获取
  int get _skipStartSeconds {
    return _currentBook?.skipStartSeconds ?? 0;
  }

  /// 获取跳过结尾时长（秒）- 从当前书籍获取
  int get _skipEndSeconds {
    return _currentBook?.skipEndSeconds ?? 0;
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

          // 加载书籍信息（用于获取跳过设置）
          if (_currentBookId != null) {
            await _loadBookInfo(_currentBookId!);

            // 加载书籍的所有音频文件作为播放列表
            await _loadBookPlaylist(audioFile, _currentBookId!);
          }

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

      // 加载书籍信息（用于获取跳过设置）
      await _loadBookInfo(_currentBookId!);

      // 加载书籍的所有音频文件作为播放列表（支持通知栏按钮）
      // 必须等待完成，确保通知栏 MediaItem 立即更新
      await _loadBookPlaylist(audioFile, _currentBookId!);
      notifyListeners(); // 立即通知监听器，更新通知栏
      // 处理 WMA 文件转码
      String filePath = audioFile.filePath;
      if (audioFile.filePath.toLowerCase().endsWith('.wma')) {
        debugPrint('🔄 检测到 WMA 文件，开始转码...');
        _errorMessage = '正在转换 WMA 格式，请稍候...';
        notifyListeners();

        try {
          // 确保 WMA 服务已初始化
          if (!WmaAudioService().isInitialized) {
            await WmaAudioService().initialize();
          }

          // 转码，设置 30 秒超时
          filePath = await WmaAudioService()
              .transcodeWmaToWav(audioFile.filePath)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  throw Exception('WMA 转码超时（30秒）');
                },
              );
          _errorMessage = null;
          debugPrint('✅ WMA 转码完成: $filePath');
        } catch (e) {
          _errorMessage = 'WMA 转码失败: $e\n\n请尝试使用其他格式的音频文件';
          _isLoading = false;
          notifyListeners();
          debugPrint('❌ WMA 转码失败: $e');
          rethrow;
        }
      }

      // 加载音频文件
      await _audioPlayer.setFilePath(filePath);

      // 恢复播放进度
      await _restoreProgress();

      // 应用跳过开头逻辑：如果当前位置在跳过范围内，则跳到跳过开头的位置
      if (_skipStartSeconds > 0 && _position < _skipStartSeconds * 1000) {
        debugPrint('跳过开头 $_skipStartSeconds秒');
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
    try {
      // 如果播放器处于 idle 状态，需要先加载音频源
      if (_playerState.processingState == ProcessingState.idle && _currentAudioFile != null && _currentBookId != null) {
        debugPrint('播放器处于 idle 状态，重新加载播放列表');
        await _loadBookPlaylist(_currentAudioFile!, _currentBookId!);
      }

     ，play() 会等到播放完成才返回
      _audioPlayer.play();

      // 更新书籍的当前音频文件ID
      if (_currentBookId != null && _currentAudioFile?.id != null) {
        _updateBookCurrentAudio(_currentBookId!, _currentAudioFile!.id!);
      }
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
    // 检查播放器是否已暂停
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

    // 检查睡眠定时器（按集数模式）
    if (_sleepTimerProvider != null) {
      try {
        final mode = _sleepTimerProvider!.mode;
        if (mode != null && mode.toString().contains('episodes')) {
          debugPrint('📉 减少睡眠定时器剩余集数');
          _sleepTimerProvider!.decrementEpisode();
          // 如果定时器已到期，不继续播放
          if (!(_sleepTimerProvider!.isActive)) {
            debugPrint('⏰ 睡眠定时器已到期，停止播放');
            return;
          }
        }
      } catch (e) {
        debugPrint('❌ 处理睡眠定时器失败: $e');
      }
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

  /// 睡眠定时器到期回调
  Future<void> _onSleepTimerExpired() async {
    debugPrint('⏰ 睡眠定时器到期，停止播放并保存进度');
    // 暂停播放
    await pause();
    // 保存进度
    await _saveProgress();
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

  /// 获取上一个音频文件
  Future<AudioFile?> _getPreviousAudioFile() async {
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

      if (audioFileMaps.isEmpty) return null;

      final audioFiles = audioFileMaps.map((map) => AudioFile.fromMap(map)).toList();
      final currentIndex = audioFiles.indexWhere((audio) => audio.id == _currentAudioFile!.id);

      if (currentIndex > 0) {
        return audioFiles[currentIndex - 1];
      }

      return null;
    } catch (e) {
      debugPrint('❌ 获取上一个音频文件失败: $e');
      return null;
    }
  }

  /// 播放下一首
  Future<void> playNext() async {
    final nextAudio = await _getNextAudioFile();
    if (nextAudio != null) {
      await loadAndPlay(nextAudio, bookId: _currentBookId);
    }
  }

  /// 播放上一首
  Future<void> playPrevious() async {
    final previousAudio = await _getPreviousAudioFile();
    if (previousAudio != null) {
      await loadAndPlay(previousAudio, bookId: _currentBookId);
    }
  }

  /// 加载书籍信息（用于获取跳过设置等）
  Future<void> _loadBookInfo(int bookId) async {
    try {
      final db = await _databaseService.database;
      final result = await db.query(
        'books',
        where: 'id = ?',
        whereArgs: [bookId],
      );

      if (result.isNotEmpty) {
        _currentBook = Book.fromMap(result.first);
        debugPrint('✅ 已加载书籍信息: ${_currentBook!.title}, 跳过开头: ${_currentBook!.skipStartSeconds}秒, 跳过结尾: ${_currentBook!.skipEndSeconds}秒');
        notifyListeners(); // 通知监听器更新 UI
      } else {
        _currentBook = null;
        debugPrint('⚠️ 未找到书籍信息: bookId=$bookId');
      }
    } catch (e) {
      debugPrint('❌ 加载书籍信息失败: $e');
      _currentBook = null;
    }
  }

  /// 查询书籍最后一次播放的音频文件（仅返回数据，不修改播放器）
  Future<AudioFile?> _fetchLastPlayedAudio(int bookId) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery('''
      SELECT af.*, pp.position, pp.playback_speed, b.id as book_id
      FROM playback_progress pp
      JOIN audio_files af ON pp.audio_file_id = af.id
      JOIN books b ON af.book_id = b.id
      WHERE b.id = ?
      ORDER BY pp.updated_at DESC
      LIMIT 1
    ''', [bookId]);

    if (result.isEmpty) {
      debugPrint('书籍 $bookId 没有播放进度记录');
      return null;
    }

    final audioFile = AudioFile.fromMap(result.first);

    // 验证文件是否存在
    final file = io.File(audioFile.filePath);
    if (!await file.exists()) {
      debugPrint('音频文件不存在: ${audioFile.filePath}');
      // 清理无效的播放进度
      await db.delete('playback_progress', where: 'audio_file_id = ?', whereArgs: [audioFile.id]);
      return null;
    }

    return audioFile;
  }

  /// 加载指定书籍的上次播放进度
  ///
  /// [loadToPlayer] 为 false 时，仅返回音频信息用于 UI 定位，不会修改播放器状态
  Future<AudioFile?> loadBookProgress(int bookId, {bool loadToPlayer = true}) async {
    try {
      final audioFile = await _fetchLastPlayedAudio(bookId);
      if (audioFile == null) {
        // 即使没有播放进度，也需要刷新当前书籍信息（更新跳过设置等）
        await _loadBookInfo(bookId);
        notifyListeners();
        return null;
      }

      if (!loadToPlayer) {
        return audioFile;
      }

      // 如果当前已经加载了这个音频文件，不需要重新加载
      if (_currentAudioFile?.id == audioFile.id && _currentBookId == bookId) {
        debugPrint('当前已加载该书籍的播放进度，无需重复加载，仅刷新书籍信息');
        await _loadBookInfo(bookId); // 跳过设置更新时需要重新获取书籍数据
        return audioFile;
      }

      // 保存当前进度
      await _saveProgress();

      // 设置当前音频文件和书籍ID
      _currentAudioFile = audioFile;
      _currentBookId = bookId;

      // 加载书籍信息（用于获取跳过设置）
      await _loadBookInfo(bookId);

      // 加载书籍的所有音频文件作为播放列表（支持通知栏按钮）
      await _loadBookPlaylist(audioFile, bookId);

      // 恢复播放进度
      await _restoreProgress();

      debugPrint('✅ 已加载书籍 $bookId 的播放进度: ${audioFile.fileName}, 位置: ${_position}ms');
      notifyListeners();
      return audioFile;
    } catch (e) {
      debugPrint('加载书籍播放进度失败: $e');
      return null;
    }
  }

  /// 加载书籍的所有音频作为播放列表（支持通知栏的上一个/下一个按钮）
  Future<void> _loadBookPlaylist(AudioFile currentAudio, int bookId) async {
    try {
      final db = await _databaseService.database;
      final audioFileMaps = await db.query(
        'audio_files',
        where: 'book_id = ?',
        whereArgs: [bookId],
        orderBy: 'sort_order ASC, file_name ASC',
      );

      if (audioFileMaps.isEmpty) {
        debugPrint('❌ 书籍中没有音频文件，加载单个音频, bookId: $bookId');
        await audioHandler.setAudioSource(_createAudioSource(currentAudio));
        audioHandler.updateQueueWithIndex([_createMediaItem(currentAudio, _currentBook)], 0);
        return;
      }

      final audioFiles = audioFileMaps.map((map) => AudioFile.fromMap(map)).toList();
      final playlist = audioFiles.map((audio) => _createAudioSource(audio)).toList();
      final mediaItems = audioFiles.map((audio) => _createMediaItem(audio, _currentBook)).toList();
      final currentIndex = audioFiles.indexWhere((audio) => audio.id == currentAudio.id);

      debugPrint('📚 加载播放列表: ${audioFiles.length} 个音频，当前索引: $currentIndex');

      await audioHandler.setAudioSources(playlist, initialIndex: currentIndex >= 0 ? currentIndex : 0);
      audioHandler.updateQueueWithIndex(mediaItems, currentIndex >= 0 ? currentIndex : 0);
    } catch (e) {
      debugPrint('❌ 加载播放列表失败: $e');
      await audioHandler.setAudioSource(_createAudioSource(currentAudio));
      audioHandler.updateQueueWithIndex([_createMediaItem(currentAudio, _currentBook)], 0);
    }
  }

  /// 创建 AudioSource
  AudioSource _createAudioSource(AudioFile audioFile) {
    return AudioSource.uri(Uri.file(audioFile.filePath));
  }

  /// 创建 MediaItem（用于通知栏和锁屏页显示）
  MediaItem _createMediaItem(AudioFile audioFile, Book? book) {
    return MediaItem(
      id: audioFile.id.toString(),
      title: audioFile.fileName,
      album: book?.title ?? '未知书籍',
      artUri: book?.coverPath != null && book!.coverPath!.isNotEmpty
          ? Uri.file(book.coverPath!)
          : null,
      duration: audioFile.duration > 0
          ? Duration(milliseconds: audioFile.duration)
          : null,
    );
  }

  // AudioControlCallback 接口实现（通知栏控制回调）
  // 注意：不使用 await，避免与 audio_service 回调形成死锁
  @override
  Future<void> onPlay() async {
    debugPrint('🎵 onPlay 回调被调用');
    play();
  }

  @override
  Future<void> onPause() async {
    debugPrint('⏸️ onPause 回调被调用');
    pause();
  }

  @override
  Future<void> onStop() async {
    debugPrint('⏹️ onStop 回调被调用');
    stop();
  }

  @override
  Future<void> onSeek(int milliseconds) async {
    debugPrint('⏩ onSeek 回调被调用: $milliseconds ms');
    seek(milliseconds);
  }

  @override
  Future<void> onSkipToNext() async {
    debugPrint('⏭️ onSkipToNext 回调被调用');
    playNext();
  }

  @override
  Future<void> onSkipToPrevious() async {
    debugPrint('⏮️ onSkipToPrevious 回调被调用');
    playPrevious();
  }

  @override
  void dispose() {
    _saveProgress();
    _audioPlayer.dispose();
    super.dispose();
  }
}
