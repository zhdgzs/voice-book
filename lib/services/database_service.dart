import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 数据库服务
///
/// 负责管理应用的 SQLite 数据库，包括：
/// - 数据库的创建和版本管理
/// - 表结构的定义和迁移
/// - 提供数据库实例的单例访问
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'voice_book.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 创建书籍表
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        cover_path TEXT,
        description TEXT,
        total_duration INTEGER DEFAULT 0,
        current_audio_file_id INTEGER,
        is_favorite INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建音频文件表
    await db.execute('''
      CREATE TABLE audio_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        sort_order INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // 创建播放进度表
    await db.execute('''
      CREATE TABLE playback_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audio_file_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        playback_speed REAL DEFAULT 1.0,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (audio_file_id) REFERENCES audio_files (id) ON DELETE CASCADE,
        UNIQUE(audio_file_id)
      )
    ''');

    // 创建书签表
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audio_file_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        title TEXT,
        note TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (audio_file_id) REFERENCES audio_files (id) ON DELETE CASCADE
      )
    ''');

    // 创建索引以提升查询性能
    await db.execute(
        'CREATE INDEX idx_audio_files_book_id ON audio_files(book_id)');
    await db.execute(
        'CREATE INDEX idx_playback_progress_audio_file_id ON playback_progress(audio_file_id)');
    await db.execute(
        'CREATE INDEX idx_bookmarks_audio_file_id ON bookmarks(audio_file_id)');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未来版本升级时在这里处理数据库迁移
    // 例如：
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE books ADD COLUMN new_field TEXT');
    // }
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// 清空所有表数据（用于测试或重置）
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('bookmarks');
    await db.delete('playback_progress');
    await db.delete('audio_files');
    await db.delete('books');
  }

  /// 删除数据库（用于测试或完全重置）
  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'voice_book.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// 根据书籍 ID 获取音频文件列表
  Future<List<Map<String, dynamic>>> getAudioFilesByBookId(int bookId) async {
    final db = await database;
    return await db.query(
      'audio_files',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'sort_order ASC, file_name ASC',
    );
  }
}
