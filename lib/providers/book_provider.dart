import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as meta;
import '../models/book.dart';
import '../models/audio_file.dart';
import '../services/database_service.dart';

/// 书籍管理 Provider
///
/// 负责管理书籍的增删改查操作，包括：
/// - 书籍列表的加载和缓存
/// - 书籍的创建、更新、删除
/// - 书籍的搜索和筛选
/// - 音频文件的关联管理
class BookProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  /// 获取数据库服务实例（用于直接数据库操作）
  DatabaseService get databaseService => _databaseService;

  /// 书籍列表
  List<Book> _books = [];

  /// 当前选中的书籍
  Book? _currentBook;

  /// 当前书籍的音频文件列表
  List<AudioFile> _currentBookAudioFiles = [];

  /// 是否正在加载
  bool _isLoading = false;

  /// 错误信息
  String? _errorMessage;

  // Getters
  List<Book> get books => _books;
  Book? get currentBook => _currentBook;
  List<AudioFile> get currentBookAudioFiles => _currentBookAudioFiles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 收藏的书籍列表
  List<Book> get favoriteBooks =>
      _books.where((book) => book.isFavorite).toList();

  /// 加载所有书籍
  Future<void> loadBooks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        orderBy: 'updated_at DESC',
      );

      _books = maps.map((map) => Book.fromMap(map)).toList();

      // 后台补全缺失的音频时长（不等待，避免阻塞）
      _updateMissingDurations();
    } catch (e) {
      _errorMessage = '加载书籍失败: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 根据 ID 获取书籍
  Future<Book?> getBookById(int id) async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return Book.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      _errorMessage = '获取书籍失败: $e';
      debugPrint(_errorMessage);
      return null;
    }
  }

  /// 创建书籍
  Future<Book?> createBook(Book book) async {
    try {
      final db = await _databaseService.database;
      final id = await db.insert('books', book.toMap());

      final newBook = book.copyWith(id: id);
      _books.insert(0, newBook);
      notifyListeners();

      return newBook;
    } catch (e) {
      _errorMessage = '创建书籍失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return null;
    }
  }

  /// 更新书籍
  Future<bool> updateBook(Book book) async {
    if (book.id == null) return false;

    try {
      final db = await _databaseService.database;
      await db.update(
        'books',
        book.toMap(),
        where: 'id = ?',
        whereArgs: [book.id],
      );

      final index = _books.indexWhere((b) => b.id == book.id);
      if (index != -1) {
        _books[index] = book;
      }

      if (_currentBook?.id == book.id) {
        _currentBook = book;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '更新书籍失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// 删除书籍
  Future<bool> deleteBook(int id) async {
    try {
      final db = await _databaseService.database;
      await db.delete(
        'books',
        where: 'id = ?',
        whereArgs: [id],
      );

      _books.removeWhere((book) => book.id == id);

      if (_currentBook?.id == id) {
        _currentBook = null;
        _currentBookAudioFiles = [];
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '删除书籍失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(int id) async {
    final book = _books.firstWhere((b) => b.id == id);
    final updatedBook = book.copyWith(
      isFavorite: !book.isFavorite,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    return await updateBook(updatedBook);
  }

  /// 设置当前书籍
  Future<void> setCurrentBook(Book book) async {
    _currentBook = book;
    await loadAudioFilesForBook(book.id!);
    notifyListeners();
  }

  /// 加载书籍的音频文件列表
  Future<void> loadAudioFilesForBook(int bookId) async {
    try {
      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'audio_files',
        where: 'book_id = ?',
        whereArgs: [bookId],
        orderBy: 'sort_order ASC',
      );

      _currentBookAudioFiles =
          maps.map((map) => AudioFile.fromMap(map)).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载音频文件失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  /// 搜索书籍
  List<Book> searchBooks(String query) {
    if (query.isEmpty) return _books;

    final lowerQuery = query.toLowerCase();
    return _books.where((book) {
      return book.title.toLowerCase().contains(lowerQuery) ||
          (book.author?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// 清空错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 后台补全缺失的音频时长（duration=0 的记录）
  Future<void> _updateMissingDurations() async {
    try {
      final db = await _databaseService.database;

      // 查找所有 duration=0 的音频文件
      final rows = await db.query('audio_files', where: 'duration = 0');
      if (rows.isEmpty) return;

      // 在隔离线程中批量读取时长
      final filePaths = rows.map((r) => r['file_path'] as String).toList();
      final durations = await compute(_readDurationsInIsolate, filePaths);

      // 按书籍分组统计
      final Map<int, int> bookDurations = {};

      for (int i = 0; i < rows.length; i++) {
        final id = rows[i]['id'] as int;
        final bookId = rows[i]['book_id'] as int;
        final duration = durations[i];

        if (duration > 0) {
          await db.update('audio_files', {'duration': duration}, where: 'id = ?', whereArgs: [id]);
          bookDurations[bookId] = (bookDurations[bookId] ?? 0) + duration;
        }
      }

      // 更新受影响书籍的总时长
      for (final entry in bookDurations.entries) {
        final totalResult = await db.rawQuery(
          'SELECT SUM(duration) as total FROM audio_files WHERE book_id = ?',
          [entry.key],
        );
        final total = totalResult.first['total'] as int? ?? 0;
        await db.update('books', {'total_duration': total}, where: 'id = ?', whereArgs: [entry.key]);
      }

      // 刷新数据（直接查询，避免递归调用 loadBooks）
      if (bookDurations.isNotEmpty) {
        final bookMaps = await db.query('books', orderBy: 'updated_at DESC');
        _books = bookMaps.map((map) => Book.fromMap(map)).toList();

        if (_currentBook != null && bookDurations.containsKey(_currentBook!.id)) {
          await loadAudioFilesForBook(_currentBook!.id!);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('补全音频时长失败: $e');
    }
  }
}

/// 在隔离线程中读取音频时长（顶层函数）
List<int> _readDurationsInIsolate(List<String> filePaths) {
  return filePaths.map((path) {
    try {
      final metadata = meta.readMetadata(File(path), getImage: false);
      return metadata.duration?.inMilliseconds ?? 0;
    } catch (_) {
      return 0;
    }
  }).toList();
}
