import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/audio_file.dart';
import '../providers/book_provider.dart';
import '../providers/audio_player_provider.dart';
import '../utils/helpers.dart';
import '../widgets/mini_player.dart';
import '../main.dart';

/// 书籍详情页面
///
/// 显示书籍的详细信息，包括：
/// - 书籍基本信息（标题、作者、描述、时长）
/// - 音频文件列表
/// - 播放、编辑、删除等操作
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<BookProvider>().setCurrentBook(widget.book);
      if (mounted) _scrollToCurrentAudio();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动到当前播放的音频（基于索引计算）
  void _scrollToCurrentAudio() {
    final bookProvider = context.read<BookProvider>();
    final currentAudioId = widget.book.currentAudioFileId;

    if (currentAudioId == null) return;

    final index = bookProvider.currentBookAudioFiles
        .indexWhere((f) => f.id == currentAudioId);
    if (index <= 0) return;

    // itemExtent 固定为 72
    const itemHeight = 72.0;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final targetOffset = (index * itemHeight).clamp(0.0, maxOffset);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
      body: Stack(
        children: [
          CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 顶部应用栏
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.book.title,
                style: const TextStyle(
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),
              background: _buildCoverBackground(),
            ),
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

          // 书籍信息
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 作者
                  if (widget.book.author != null) ...[
                    Row(
                      children: [
                        Icon(Icons.person, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          widget.book.author!,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 时长
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '总时长: ${Helpers.formatDuration(widget.book.totalDuration)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 更新时间
                  Row(
                    children: [
                      Icon(Icons.update, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '更新于 ${Helpers.formatRelativeTime(widget.book.updatedAt)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                      ),
                    ],
                  ),

                  // 描述
                  if (widget.book.description != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      '简介',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.book.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // 音频文件列表标题
                  Text(
                    '音频文件',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),

          // 音频文件列表
          Consumer<BookProvider>(
            builder: (context, bookProvider, child) {
              final audioFiles = bookProvider.currentBookAudioFiles;

              if (bookProvider.isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (audioFiles.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
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
                  ),
                );
              }

              return SliverFixedExtentList(
                itemExtent: 72,
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildAudioFileItem(audioFiles[index], index);
                  },
                  childCount: audioFiles.length,
                ),
              );
            },
          ),
        ],
      ),
      // 迷你播放器
      Positioned(
        right: 0,
        bottom: 0,
        child: MiniPlayer(),
      ),
    ],
      ),
    );
  }

  /// 构建封面背景
  Widget _buildCoverBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
          ],
        ),
      ),
      child: widget.book.coverPath != null
          ? Image.network(
              widget.book.coverPath!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildDefaultCover();
              },
            )
          : _buildDefaultCover(),
    );
  }

  /// 构建默认封面
  Widget _buildDefaultCover() {
    return Center(
      child: Icon(
        Icons.book,
        size: 80,
        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.5),
      ),
    );
  }

  /// 构建音频文件项
  Widget _buildAudioFileItem(AudioFile audioFile, int index) {
    return Consumer2<AudioPlayerProvider, BookProvider>(
      builder: (context, playerProvider, bookProvider, child) {
        final isPlaying = playerProvider.currentAudioFile?.id == audioFile.id && playerProvider.isPlaying;
        final isCurrentAudio = widget.book.currentAudioFileId == audioFile.id;

        return Container(
          color: isCurrentAudio ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCurrentAudio
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primaryContainer,
              child: isPlaying
                ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.onPrimary)
                : isCurrentAudio
                  ? Icon(Icons.bookmark, color: Theme.of(context).colorScheme.onPrimary)
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
                fontWeight: isCurrentAudio ? FontWeight.bold : null,
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
