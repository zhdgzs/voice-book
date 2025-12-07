import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../models/book.dart';
import '../utils/helpers.dart';
import '../widgets/mini_player.dart';
import '../widgets/skip_settings_dialog.dart';
import 'book_detail_screen.dart';

/// 书籍列表页面
///
/// 显示所有书籍的列表，支持：
/// - 查看所有书籍
/// - 搜索书籍
/// - 筛选收藏的书籍
/// - 跳转到书籍详情
/// - 导入新书籍
class BookListScreen extends StatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const BookListScreen({super.key, this.navigatorKey});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();

  /// 搜索关键词
  String _searchQuery = '';

  /// 是否只显示收藏
  bool _showFavoritesOnly = false;

  /// 记录长按位置
  Offset _lastTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    // 页面加载时自动加载书籍列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 过滤书籍列表
  List<Book> _filterBooks(List<Book> books) {
    var filtered = books;

    // 筛选收藏
    if (_showFavoritesOnly) {
      filtered = filtered.where((book) => book.isFavorite).toList();
    }

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((book) {
        final titleMatch =
            book.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final authorMatch = book.author
                ?.toLowerCase()
                .contains(_searchQuery.toLowerCase()) ??
            false;
        return titleMatch || authorMatch;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          // 收藏筛选按钮
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? Colors.red : null,
            ),
            onPressed: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
              });
            },
            tooltip: _showFavoritesOnly ? '显示全部' : '只看收藏',
          ),
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<BookProvider>().loadBooks();
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索书名或作者...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // 书籍列表
          Expanded(
            child: Consumer<BookProvider>(
              builder: (context, bookProvider, child) {
                // 加载中状态
                if (bookProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // 错误状态
                if (bookProvider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          bookProvider.errorMessage!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            bookProvider.loadBooks();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }

                // 过滤书籍
                final filteredBooks = _filterBooks(bookProvider.books);

                // 空状态
                if (filteredBooks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showFavoritesOnly
                              ? Icons.favorite_border
                              : Icons.library_books_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showFavoritesOnly
                              ? '还没有收藏的书籍'
                              : _searchQuery.isNotEmpty
                                  ? '没有找到匹配的书籍'
                                  : '书架空空如也',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _showFavoritesOnly
                              ? '点击书籍的收藏按钮添加到收藏'
                              : '点击右下角按钮导入书籍',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 书籍列表
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredBooks.length,
                  itemBuilder: (context, index) {
                    final book = filteredBooks[index];
                    return _buildBookCard(context, book, bookProvider);
                  },
                );
              },
            ),
          ),
        ],
          ),
          // 迷你播放器
          const Positioned(
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      // 浮动按钮 - 导入书籍（避开迷你播放器）
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pushNamed('/file-import');
          },
          icon: const Icon(Icons.add),
          label: const Text('导入书籍'),
        ),
      ),
    );
  }

  /// 显示书籍操作菜单
  void _showBookMenu(BuildContext context, Book book, Offset position) {
    final bookProvider = context.read<BookProvider>();
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        if (book.sourceFolderPath != null)
          const PopupMenuItem(
            value: 'rescan',
            child: Row(
              children: [
                Icon(Icons.refresh),
                SizedBox(width: 8),
                Text('重新扫描'),
              ],
            ),
          ),
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
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'rescan':
          _rescanFolder(book);
          break;
        case 'skip_settings':
          _showSkipSettingsDialog(book);
          break;
        case 'edit':
          _showEditDialog(book);
          break;
        case 'delete':
          _showDeleteConfirmDialog(book, bookProvider);
          break;
      }
    });
  }

  /// 重新扫描文件夹
  Future<void> _rescanFolder(Book book) async {
    final bookProvider = context.read<BookProvider>();
    if (book.sourceFolderPath == null) return;

    try {
      final preview = await bookProvider.previewRescanFolder(book);
      final total = preview['added']! + preview['removed']! + preview['updated']!;
      if (total == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('扫描完成，没有发现变更')),
          );
        }
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认应用变更'),
          content: Text(
            '发现以下变更：\n'
            '• 新增 ${preview['added']} 个文件\n'
            '• 删除 ${preview['removed']} 个文件\n'
            '• 更新 ${preview['updated']} 个文件\n\n'
            '是否应用这些变更？',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('应用')),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await bookProvider.applyRescanChanges(book, preview);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已应用变更：新增 ${preview['added']} 个，删除 ${preview['removed']} 个，更新 ${preview['updated']} 个')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('扫描失败: $e')));
      }
    }
  }

  /// 显示跳过设置对话框
  Future<void> _showSkipSettingsDialog(Book book) async {
    await showDialog(
      context: context,
      builder: (context) => SkipSettingsDialog(bookId: book.id!, isFromPlayer: false),
    );
  }

  /// 显示编辑对话框
  Future<void> _showEditDialog(Book book) async {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author);
    final descriptionController = TextEditingController(text: book.description);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑书籍'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: authorController, decoration: const InputDecoration(labelText: '作者', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: '描述', border: OutlineInputBorder()), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final updatedBook = book.copyWith(
        title: titleController.text,
        author: authorController.text.isEmpty ? null : authorController.text,
        description: descriptionController.text.isEmpty ? null : descriptionController.text,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await context.read<BookProvider>().updateBook(updatedBook);
    }

    titleController.dispose();
    authorController.dispose();
    descriptionController.dispose();
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(Book book, BookProvider bookProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除《${book.title}》吗？\n此操作无法撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await bookProvider.deleteBook(book.id!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('书籍已删除')));
      }
    }
  }

  /// 构建书籍卡片
  Widget _buildBookCard(
      BuildContext context, Book book, BookProvider bookProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          final navigator = widget.navigatorKey?.currentState ?? Navigator.of(context);
          navigator.push(
            MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
          );
        },
        onLongPress: () => _showBookMenu(context, book, _lastTapPosition),
        onTapDown: (details) => _lastTapPosition = details.globalPosition,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              _buildCover(book),
              const SizedBox(width: 12),

              // 书籍信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 作者
                    if (book.author != null) ...[
                      Text(
                        book.author!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 时长和更新时间
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          Helpers.formatDuration(book.totalDuration),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.update,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          Helpers.formatRelativeTime(book.updatedAt),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 收藏按钮
              IconButton(
                icon: Icon(
                  book.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: book.isFavorite ? Colors.red : null,
                ),
                onPressed: () {
                  bookProvider.toggleFavorite(book.id!);
                },
                tooltip: book.isFavorite ? '取消收藏' : '收藏',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建封面
  Widget _buildCover(Book book) {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[300],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: book.coverPath != null
            ? Image.network(
                book.coverPath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultCover(book);
                },
              )
            : _buildDefaultCover(book),
      ),
    );
  }

  /// 构建默认封面
  Widget _buildDefaultCover(Book book) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book,
              size: 32,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                book.title,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
