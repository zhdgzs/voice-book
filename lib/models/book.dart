/// 书籍模型
///
/// 表示一本有声书，包含书籍的基本信息和元数据
class Book {
  /// 书籍 ID
  final int? id;

  /// 书籍标题
  final String title;

  /// 作者
  final String? author;

  /// 封面图片路径
  final String? coverPath;

  /// 书籍描述
  final String? description;

  /// 总时长（毫秒）
  final int totalDuration;

  /// 当前播放的音频文件 ID
  final int? currentAudioFileId;

  /// 是否收藏
  final bool isFavorite;

  /// 跳过开头时长（秒）
  final int skipStartSeconds;

  /// 跳过结尾时长（秒）
  final int skipEndSeconds;

  /// 创建时间（Unix 时间戳，毫秒）
  final int createdAt;

  /// 更新时间（Unix 时间戳，毫秒）
  final int updatedAt;

  Book({
    this.id,
    required this.title,
    this.author,
    this.coverPath,
    this.description,
    this.totalDuration = 0,
    this.currentAudioFileId,
    this.isFavorite = false,
    this.skipStartSeconds = 0,
    this.skipEndSeconds = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从数据库 Map 创建 Book 对象
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String?,
      coverPath: map['cover_path'] as String?,
      description: map['description'] as String?,
      totalDuration: map['total_duration'] as int? ?? 0,
      currentAudioFileId: map['current_audio_file_id'] as int?,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      skipStartSeconds: map['skip_start_seconds'] as int? ?? 0,
      skipEndSeconds: map['skip_end_seconds'] as int? ?? 0,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'author': author,
      'cover_path': coverPath,
      'description': description,
      'total_duration': totalDuration,
      'current_audio_file_id': currentAudioFileId,
      'is_favorite': isFavorite ? 1 : 0,
      'skip_start_seconds': skipStartSeconds,
      'skip_end_seconds': skipEndSeconds,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 复制并修改部分字段
  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? coverPath,
    String? description,
    int? totalDuration,
    int? currentAudioFileId,
    bool? isFavorite,
    int? skipStartSeconds,
    int? skipEndSeconds,
    int? createdAt,
    int? updatedAt,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      description: description ?? this.description,
      totalDuration: totalDuration ?? this.totalDuration,
      currentAudioFileId: currentAudioFileId ?? this.currentAudioFileId,
      isFavorite: isFavorite ?? this.isFavorite,
      skipStartSeconds: skipStartSeconds ?? this.skipStartSeconds,
      skipEndSeconds: skipEndSeconds ?? this.skipEndSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Book{id: $id, title: $title, author: $author, totalDuration: $totalDuration}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Book &&
        other.id == id &&
        other.title == title &&
        other.author == author &&
        other.coverPath == coverPath &&
        other.description == description &&
        other.totalDuration == totalDuration &&
        other.currentAudioFileId == currentAudioFileId &&
        other.isFavorite == isFavorite &&
        other.skipStartSeconds == skipStartSeconds &&
        other.skipEndSeconds == skipEndSeconds &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      author,
      coverPath,
      description,
      totalDuration,
      currentAudioFileId,
      isFavorite,
      skipStartSeconds,
      skipEndSeconds,
      createdAt,
      updatedAt,
    );
  }
}
