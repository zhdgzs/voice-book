import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_file.dart';
import '../models/book.dart';
import '../providers/audio_player_provider.dart';
import '../providers/book_provider.dart';
import '../providers/sleep_timer_provider.dart';
import '../widgets/sleep_timer_dialog.dart';
import '../widgets/skip_settings_dialog.dart';
import '../widgets/bookmark_list_dialog.dart';
import '../models/bookmark.dart';
import '../services/database_service.dart';
import '../utils/helpers.dart';

/// 音频播放器页面
///
/// 显示当前播放的音频文件信息和播放控制
class PlayerScreen extends StatefulWidget {
  final Book? book;
  final AudioFile audioFile;

  const PlayerScreen({
    super.key,
    this.book,
    required this.audioFile,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioPlayer = context.read<AudioPlayerProvider>();
      // 避免重复加载同一音频
      if (audioPlayer.currentAudioFile?.id != widget.audioFile.id) {
        audioPlayer.loadAndPlay(widget.audioFile, bookId: widget.book?.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Consumer<AudioPlayerProvider>(
          builder: (context, audioPlayer, child) {
            // 使用当前播放的音频文件，如果没有则使用传入的
            final currentAudio = audioPlayer.currentAudioFile ?? widget.audioFile;

            return Column(
              children: [
                // 顶部导航栏
                _buildAppBar(context),

                // 主要内容区域（不使用滚动）
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 封面图片（小尺寸）
                        _buildCompactCover(context),

                        // 书籍和音频信息
                        _buildAudioInfo(context, currentAudio),

                        // 进度条和时间
                        Column(
                          children: [
                            _buildProgressBar(context, audioPlayer),
                            const SizedBox(height: 8),
                            _buildTimeDisplay(context, audioPlayer),
                          ],
                        ),

                        // 播放控制按钮
                        _buildPlaybackControls(context, audioPlayer),

                        // 倍速和其他控制
                        _buildAdditionalControls(context, audioPlayer),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建顶部导航栏
  Widget _buildAppBar(BuildContext context) {
    // 检查是否可以返回
    final canPop = Navigator.canPop(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // 返回按钮 - 只在可以 pop 时显示
          if (canPop)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              iconSize: 32,
              onPressed: () => Navigator.pop(context),
            )
          else
            // 占位,保持布局一致
            const SizedBox(width: 48),

          const Spacer(),

          // 更多选项按钮
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
    );
  }

  /// 构建紧凑型封面（小尺寸，圆角）
  Widget _buildCompactCover(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.music_note,
            size: 80,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  /// 构建音频信息
  Widget _buildAudioInfo(BuildContext context, AudioFile currentAudio) {
    final audioPlayer = context.watch<AudioPlayerProvider>();
    final bookProvider = context.watch<BookProvider>();

    // 优先使用传入的 book，否则根据 currentBookId 查找
    final book = widget.book ??
        (audioPlayer.currentBookId != null
            ? bookProvider.books.where((b) => b.id == audioPlayer.currentBookId).firstOrNull
            : null);

    return Column(
      children: [
        // 音频文件标题
        Text(
          currentAudio.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 8),

        // 书籍标题
        if (book != null)
          Text(
            book.title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

        // 作者
        if (book?.author != null && book!.author!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              book.author!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(
      BuildContext context, AudioPlayerProvider audioPlayer) {
    final progress = _isDragging
        ? _dragValue
        : (audioPlayer.duration > 0
            ? audioPlayer.position / audioPlayer.duration
            : 0.0);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        onChanged: (value) {
          setState(() {
            _isDragging = true;
            _dragValue = value;
          });
        },
        onChangeEnd: (value) {
          final position = (value * audioPlayer.duration).toInt();
          audioPlayer.seek(position);
          setState(() {
            _isDragging = false;
          });
        },
      ),
    );
  }

  /// 构建时间显示
  Widget _buildTimeDisplay(
      BuildContext context, AudioPlayerProvider audioPlayer) {
    final currentTime = _isDragging
        ? (_dragValue * audioPlayer.duration).toInt()
        : audioPlayer.position;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            Helpers.formatDuration(currentTime),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            Helpers.formatDuration(audioPlayer.duration),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建播放控制按钮
  Widget _buildPlaybackControls(
      BuildContext context, AudioPlayerProvider audioPlayer) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 快退 10 秒
          IconButton(
            icon: const Icon(Icons.replay_10),
            iconSize: 36,
            onPressed: () => audioPlayer.seekBackward(10),
          ),
          const SizedBox(width: 8),
          // 上一曲
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 42,
            onPressed: () => _playPrevious(context),
          ),
          const SizedBox(width: 8),
          // 播放/暂停按钮
          _buildPlayPauseButton(context, audioPlayer),
          const SizedBox(width: 8),
          // 下一曲
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 42,
            onPressed: () => _playNext(context),
          ),
          const SizedBox(width: 8),
          // 快进 10 秒
          IconButton(
            icon: const Icon(Icons.forward_10),
            iconSize: 36,
            onPressed: () => audioPlayer.seekForward(10),
          ),
        ],
      ),
    );
  }

  /// 构建播放/暂停按钮
  Widget _buildPlayPauseButton(
      BuildContext context, AudioPlayerProvider audioPlayer) {
    // 只在明确的加载状态时显示加载动画
    // 不检查 buffering 状态，因为它可能会持续很久
    final processingState = audioPlayer.playerState.processingState;
    final showLoading = audioPlayer.isLoading &&
                       processingState != ProcessingState.ready &&
                       processingState != ProcessingState.completed;

    if (showLoading) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          audioPlayer.isPlaying ? Icons.pause : Icons.play_arrow,
          size: 36,
        ),
        color: Colors.white,
        onPressed: () {
          if (audioPlayer.isPlaying) {
            audioPlayer.pause();
          } else {
            audioPlayer.play();
          }
        },
      ),
    );
  }

  /// 构建额外控制按钮
  Widget _buildAdditionalControls(
      BuildContext context, AudioPlayerProvider audioPlayer) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 书签按钮
        IconButton(
          icon: const Icon(Icons.bookmark_border),
          iconSize: 26,
          onPressed: () => _addBookmark(context),
        ),

        // 倍速播放按钮
        _buildSpeedButton(context, audioPlayer),

        // 睡眠定时器按钮
        _buildSleepTimerButton(context),
      ],
    );
  }

  /// 构建倍速按钮
  Widget _buildSpeedButton(
      BuildContext context, AudioPlayerProvider audioPlayer) {
    return TextButton(
      onPressed: () => _showSpeedDialog(context, audioPlayer),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        '${audioPlayer.playbackSpeed}x',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  /// 显示倍速选择对话框
  void _showSpeedDialog(
      BuildContext context, AudioPlayerProvider audioPlayer) {
    showDialog(
      context: context,
      builder: (context) {
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
        return AlertDialog(
          title: const Text('播放速度'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: speeds.map((speed) {
              // ignore: deprecated_member_use
              return RadioListTile<double>(
                title: Text('${speed}x'),
                value: speed,
                // ignore: deprecated_member_use
                groupValue: audioPlayer.playbackSpeed,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  if (value != null) {
                    audioPlayer.setPlaybackSpeed(value);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// 显示更多选项
  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_add),
                title: const Text('添加书签'),
                onTap: () {
                  Navigator.pop(context);
                  _addBookmark(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmarks),
                title: const Text('书签列表'),
                onTap: () {
                  Navigator.pop(context);
                  _showBookmarks(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_play),
                title: const Text('播放列表'),
                onTap: () {
                  Navigator.pop(context);
                  _showPlaylist(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.skip_next_outlined),
                title: const Text('跳过设置'),
                subtitle: const Text('设置跳过开头和结尾的时长'),
                onTap: () {
                  Navigator.pop(context);
                  _showSkipSettings(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('音频信息'),
                onTap: () {
                  Navigator.pop(context);
                  _showAudioInfo(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示播放列表
  void _showPlaylist(BuildContext context) {
    if (widget.book == null) return;

    final bookProvider = context.read<BookProvider>();
    final audioPlayer = context.read<AudioPlayerProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<AudioFile>>(
              future: bookProvider.databaseService
                  .getAudioFilesByBookId(widget.book!.id!)
                  .then((maps) => maps.map((map) => AudioFile.fromMap(map)).toList()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final audioFiles = snapshot.data!;

                return Column(
                  children: [
                    // 标题栏
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '播放列表',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          Text(
                            '共 ${audioFiles.length} 个文件',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // 音频文件列表
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: audioFiles.length,
                        itemBuilder: (context, index) {
                          final audio = audioFiles[index];
                          final isPlaying =
                              audioPlayer.currentAudioFile?.id == audio.id;

                          return ListTile(
                            leading: isPlaying
                                ? const Icon(Icons.volume_up,
                                    color: Colors.blue)
                                : Text(
                                    '${index + 1}',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                            title: Text(
                              audio.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isPlaying
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isPlaying ? Colors.blue : null,
                              ),
                            ),
                            subtitle: Text(
                              Helpers.formatDuration(audio.duration),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () {
                              audioPlayer.loadAndPlay(audio);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// 显示音频信息
  void _showAudioInfo(BuildContext context) {
    final audioPlayer = context.read<AudioPlayerProvider>();
    final currentAudio = audioPlayer.currentAudioFile ?? widget.audioFile;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('音频信息'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('标题', currentAudio.title),
              _buildInfoRow('时长',
                  Helpers.formatDuration(currentAudio.duration)),
              _buildInfoRow('文件大小',
                  Helpers.formatFileSize(currentAudio.fileSize)),
              _buildInfoRow('文件路径', currentAudio.filePath),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取当前书籍ID
  int? _getBookId(AudioPlayerProvider audioPlayer) {
    return widget.book?.id ?? audioPlayer.currentBookId;
  }

  /// 播放上一曲
  void _playPrevious(BuildContext context) async {
    final bookProvider = context.read<BookProvider>();
    final audioPlayer = context.read<AudioPlayerProvider>();
    final bookId = _getBookId(audioPlayer);

    if (bookId == null) return;

    final audioFileMaps =
        await bookProvider.databaseService.getAudioFilesByBookId(bookId);
    final audioFiles = audioFileMaps.map((map) => AudioFile.fromMap(map)).toList();

    if (audioFiles.isEmpty) return;

    final currentIndex = audioFiles.indexWhere(
      (audio) => audio.id == audioPlayer.currentAudioFile?.id,
    );

    if (currentIndex > 0) {
      await audioPlayer.loadAndPlay(audioFiles[currentIndex - 1], bookId: bookId);
    } else {
      // ignore: use_build_context_synchronously
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是第一个文件了')),
        );
      }
    }
  }

  /// 播放下一曲
  void _playNext(BuildContext context) async {
    final bookProvider = context.read<BookProvider>();
    final audioPlayer = context.read<AudioPlayerProvider>();
    final bookId = _getBookId(audioPlayer);

    if (bookId == null) return;

    final audioFileMaps =
        await bookProvider.databaseService.getAudioFilesByBookId(bookId);
    final audioFiles = audioFileMaps.map((map) => AudioFile.fromMap(map)).toList();

    if (audioFiles.isEmpty) return;

    final currentIndex = audioFiles.indexWhere(
      (audio) => audio.id == audioPlayer.currentAudioFile?.id,
    );

    if (currentIndex < audioFiles.length - 1) {
      await audioPlayer.loadAndPlay(audioFiles[currentIndex + 1], bookId: bookId);
    } else {
      // ignore: use_build_context_synchronously
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是最后一个文件了')),
        );
      }
    }
  }

  /// 显示跳过设置对话框
  Future<void> _showSkipSettings(BuildContext context) async {
    final audioPlayer = context.read<AudioPlayerProvider>();

    // 获取当前书籍ID
    final currentBookId = audioPlayer.currentBookId ?? widget.book?.id;
    if (currentBookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有播放的书籍')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => SkipSettingsDialog(
        bookId: currentBookId,
        isFromPlayer: true,
      ),
    );
  }

  /// 构建睡眠定时器按钮
  Widget _buildSleepTimerButton(BuildContext context) {
    return Consumer<SleepTimerProvider>(
      builder: (context, sleepTimer, child) {
        final isActive = sleepTimer.isActive;

        return IconButton(
          icon: Icon(
            isActive ? Icons.timer : Icons.timer_outlined,
            color: isActive ? Theme.of(context).colorScheme.primary : null,
          ),
          iconSize: 26,
          onPressed: () => _showSleepTimerDialog(context),
        );
      },
    );
  }

  /// 显示睡眠定时器对话框
  void _showSleepTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SleepTimerDialog(),
    );
  }

  /// 添加书签
  Future<void> _addBookmark(BuildContext context) async {
    final audioPlayer = context.read<AudioPlayerProvider>();
    final currentAudio = audioPlayer.currentAudioFile;

    if (currentAudio == null) return;

    final position = audioPlayer.position;

    showDialog(
      context: context,
      builder: (context) {
        String? title;
        String? note;

        return AlertDialog(
          title: const Text('添加书签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: '书签标题（可选）',
                  hintText: '例如：精彩片段',
                ),
                onChanged: (value) => title = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '添加一些备注信息',
                ),
                maxLines: 2,
                onChanged: (value) => note = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                // 如果用户没有填写标题，使用"音频文件名 - 时间点"作为默认标题
                String? finalTitle = title;
                if (finalTitle == null || finalTitle.trim().isEmpty) {
                  final timeStr = Helpers.formatDuration(position);
                  finalTitle = '${currentAudio.title} - $timeStr';
                }

                final bookmark = Bookmark(
                  audioFileId: currentAudio.id!,
                  position: position,
                  title: finalTitle,
                  note: note?.isEmpty == true ? null : note,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                );

                final db = await DatabaseService().database;
                await db.insert('bookmarks', bookmark.toMap());

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('书签已添加')),
                  );
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  /// 显示书签列表
  void _showBookmarks(BuildContext context) {
    final audioPlayer = context.read<AudioPlayerProvider>();
    final currentAudio = audioPlayer.currentAudioFile;

    if (currentAudio == null) return;

    showDialog(
      context: context,
      builder: (context) => BookmarkListDialog(
        audioFileId: currentAudio.id!,
        onBookmarkTap: (position) {
          audioPlayer.seek(position);
        },
      ),
    );
  }
}
