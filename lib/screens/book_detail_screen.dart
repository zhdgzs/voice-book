import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/audio_file.dart';
import '../providers/book_provider.dart';
import '../providers/audio_player_provider.dart';
import '../widgets/mini_player.dart';
import '../main.dart';

/// 书籍详情页面
///
/// 显示书籍的音频文件列表，支持：
/// - 查看所有音频文件
/// - 播放/暂停音频
/// - 自动定位到当前播放的音频
/// - 编辑、删除书籍等操作
class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({
    super.key,
    required this.book,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  int? _lastScrolledAudioId; // 记录上次滚动到的音频ID
  bool _isInitialized = false; // 标记是否已初始化

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<BookProvider>().setCurrentBook(widget.book);

      // 加载该书籍的上次播放进度（如果有且不会打断当前播放）
      if (widget.book.id != null) {
        final audioPlayer = context.read<AudioPlayerProvider>();
        final isPlayingOtherBook = audioPlayer.isPlaying &&
            audioPlayer.currentBookId != null &&
            audioPlayer.currentBookId != widget.book.id;

        if (isPlayingOtherBook) {
          debugPrint('⚠️ 正在播放其他书籍，进入详情页时不加载播放进度');
        } else {
          await audioPlayer.loadBookProgress(widget.book.id!);
        }
      }

      _isInitialized = true;
      if (mounted) {
        // 延迟一帧，确保列表完全渲染
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) _scrollToCurrentAudio();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 只有在初始化完成后才响应依赖变化
    if (!_isInitialized) return;

    // 每次依赖变化时检查是否需要重新定位
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final audioPlayerProvider = context.read<AudioPlayerProvider>();
        final currentAudioId = audioPlayerProvider.currentAudioFile?.id;

        // 如果当前音频ID变化了，重新定位
        if (currentAudioId != null && currentAudioId != _lastScrolledAudioId) {
          _scrollToCurrentAudio();
        }
      }
    });
  }

  /// 滚动到当前播放的音频（基于索引计算）
  void _scrollToCurrentAudio() {
    final bookProvider = context.read<BookProvider>();
    final audioPlayerProvider = context.read<AudioPlayerProvider>();

    // 使用 AudioPlayerProvider 的当前音频ID
    final currentAudioId = audioPlayerProvider.currentAudioFile?.id;

    if (currentAudioId == null) {
      debugPrint('⚠️ 当前音频ID为空，无法定位');
      return;
    }

    // 确保音频列表已加载
    final audioFiles = bookProvider.currentBookAudioFiles;
    if (audioFiles.isEmpty) {
      debugPrint('⚠️ 音频列表为空，无法定位');
      return;
    }

    final index = audioFiles.indexWhere((f) => f.id == currentAudioId);
    if (index < 0) {
      debugPrint('⚠️ 未找到当前音频，ID: $currentAudioId');
      return;
    }

    // 如果是第一个音频，不需要滚动
    if (index == 0) {
      debugPrint('✅ 当前音频是第一个，无需滚动');
      _lastScrolledAudioId = currentAudioId;
      return;
    }

    // 记录已滚动到的音频ID
    _lastScrolledAudioId = currentAudioId;

    // 确保 ScrollController 已附加到滚动视图
    if (!_scrollController.hasClients) {
      debugPrint('⚠️ ScrollController 未附加，延迟滚动');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _performScroll(index);
        }
      });
      return;
    }

    _performScroll(index);
  }

  /// 执行滚动操作
  void _performScroll(int index) {
    // itemExtent 固定为 72
    const itemHeight = 72.0;
    final expectedOffset = index * itemHeight;
    final maxOffset = _scrollController.position.maxScrollExtent;

    debugPrint('📍 准备滚动到索引 $index，期望偏移: $expectedOffset, 最大偏移: $maxOffset');

    // 如果最大偏移量明显小于期望偏移量，说明列表还没完全渲染
    // 延迟重试
    if (maxOffset < expectedOffset * 0.5 && maxOffset < 1000) {
      debugPrint('⚠️ 列表未完全渲染，延迟滚动');
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _scrollController.hasClients) {
          _performScroll(index);
        }
      });
      return;
    }

    final targetOffset = expectedOffset.clamp(0.0, maxOffset);
    debugPrint('✅ 执行滚动到索引 $index，目标偏移: $targetOffset');

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 显示跳过设置对话框
  Future<void> _showSkipSettingsDialog() async {
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.books.firstWhere((b) => b.id == widget.book.id);

    int skipStartSeconds = book.skipStartSeconds;
    int skipEndSeconds = book.skipEndSeconds;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('跳过设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '为这本书设置跳过开头和结尾的时长',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                // 跳过开头
                Text(
                  '跳过开头: ${skipStartSeconds == 0 ? '不跳过' : '$skipStartSeconds 秒'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: skipStartSeconds.toDouble(),
                  min: 0,
                  max: 120,
                  divisions: 120,
                  label: skipStartSeconds == 0 ? '不跳过' : '$skipStartSeconds秒',
                  onChanged: (value) {
                    setState(() {
                      skipStartSeconds = value.toInt();
                    });
                  },
                ),
                const SizedBox(height: 16),
                // 跳过结尾
                Text(
                  '跳过结尾: ${skipEndSeconds == 0 ? '不跳过' : '$skipEndSeconds 秒'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: skipEndSeconds.toDouble(),
                  min: 0,
                  max: 120,
                  divisions: 120,
                  label: skipEndSeconds == 0 ? '不跳过' : '$skipEndSeconds秒',
                  onChanged: (value) {
                    setState(() {
                      skipEndSeconds = value.toInt();
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final updatedBook = book.copyWith(
        skipStartSeconds: skipStartSeconds,
        skipEndSeconds: skipEndSeconds,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final success = await bookProvider.updateBook(updatedBook);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('跳过设置已更新')),
        );
        // 如果当前正在播放这本书，重新加载书籍信息
        final audioPlayer = context.read<AudioPlayerProvider>();
        if (audioPlayer.currentBookId == widget.book.id) {
          await audioPlayer.loadBookProgress(widget.book.id!);
        }
      }
    }
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除《${widget.book.title}》吗？\n此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await context.read<BookProvider>().deleteBook(widget.book.id!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书籍已删除')),
        );
        Navigator.pop(context);
      }
    }
  }

  /// 显示编辑对话框
  Future<void> _showEditDialog() async {
    final titleController = TextEditingController(text: widget.book.title);
    final authorController = TextEditingController(text: widget.book.author);
    final descriptionController =
        TextEditingController(text: widget.book.description);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑书籍'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: authorController,
                decoration: const InputDecoration(
                  labelText: '作者',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final updatedBook = widget.book.copyWith(
        title: titleController.text,
        author: authorController.text.isEmpty ? null : authorController.text,
        description: descriptionController.text.isEmpty
            ? null
            : descriptionController.text,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final success = await context.read<BookProvider>().updateBook(updatedBook);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书籍信息已更新')),
        );
        setState(() {});
      }
    }

    titleController.dispose();
    authorController.dispose();
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          // 收藏按钮
          Consumer<BookProvider>(
            builder: (context, bookProvider, child) {
              final book = bookProvider.books
                  .firstWhere((b) => b.id == widget.book.id);
              return IconButton(
                icon: Icon(
                  book.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: book.isFavorite ? Colors.red : null,
                ),
                onPressed: () {
                  bookProvider.toggleFavorite(book.id!);
                },
              );
            },
          ),
          // 更多菜单
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'skip_settings':
                  _showSkipSettingsDialog();
                  break;
                case 'edit':
                  _showEditDialog();
                  break;
                case 'delete':
                  _showDeleteConfirmDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'skip_settings',
                child: Row(
                  children: [
                    Icon(Icons.skip_next),
                    SizedBox(width: 8),
                    Text('跳过设置'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('编辑'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('删除', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // 音频文件列表
          Consumer<BookProvider>(
            builder: (context, bookProvider, child) {
              final audioFiles = bookProvider.currentBookAudioFiles;

              if (bookProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (audioFiles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.audio_file,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无音频文件',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                itemExtent: 72,
                itemCount: audioFiles.length,
                itemBuilder: (context, index) {
                  return _buildAudioFileItem(audioFiles[index], index);
                },
              );
            },
          ),
          // 迷你播放器
          const Positioned(
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }

  /// 构建音频文件项
  Widget _buildAudioFileItem(AudioFile audioFile, int index) {
    return Consumer2<AudioPlayerProvider, BookProvider>(
      builder: (context, playerProvider, bookProvider, child) {
        // 判断是否是正在播放的音频
        final isCurrentPlaying = playerProvider.currentAudioFile?.id == audioFile.id;
        final isPlaying = isCurrentPlaying && playerProvider.isPlaying;

        return Container(
          color: isCurrentPlaying ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCurrentPlaying
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primaryContainer,
              child: isCurrentPlaying
                ? Icon(
                    isPlaying ? Icons.play_arrow : Icons.pause,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
            title: Text(
              audioFile.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isCurrentPlaying ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text(
              '${audioFile.formattedDuration} • ${audioFile.formattedFileSize}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: IconButton(
              icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle_outline),
              onPressed: () {
                final audioPlayer = context.read<AudioPlayerProvider>();
                if (isPlaying) {
                  audioPlayer.pause();
                } else {
                  audioPlayer.loadAndPlay(audioFile, bookId: widget.book.id);
                }
              },
            ),
            onTap: () {
              MainScreen.openPlayer(
                context,
                book: widget.book,
                audioFile: audioFile,
              );
            },
          ),
        );
      },
    );
  }

}
