import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../models/book.dart';
import '../utils/helpers.dart';

/// 书籍列表页面
///
/// 显示所有书籍的列表，支持：
/// - 查看所有书籍
/// - 搜索书籍
/// - 筛选收藏的书籍
/// - 跳转到书籍详情
/// - 导入新书籍
class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

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
      body: Column(
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
      // 浮动按钮 - 导入书籍
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/file-import');
        },
        icon: const Icon(Icons.add),
        label: const Text('导入书籍'),
      ),
    );
  }

  /// 构建书籍卡片
  Widget _buildBookCard(
      BuildContext context, Book book, BookProvider bookProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/book-detail',
            arguments: book,
          );
        },
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
