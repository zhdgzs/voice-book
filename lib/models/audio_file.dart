/// 音频文件模型
///
/// 表示一个音频文件，属于某本书籍
class AudioFile {
  /// 音频文件 ID
  final int? id;

  /// 所属书籍 ID
  final int bookId;

  /// 文件路径
  final String filePath;

  /// 文件名
  final String fileName;

  /// 文件大小（字节）
  final int fileSize;

  /// 音频时长（毫秒）
  final int duration;

  /// 排序顺序
  final int sortOrder;

  /// 创建时间（Unix 时间戳，毫秒）
  final int createdAt;

  AudioFile({
    this.id,
    required this.bookId,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.duration,
    this.sortOrder = 0,
    required this.createdAt,
  });

  /// 从数据库 Map 创建 AudioFile 对象
  factory AudioFile.fromMap(Map<String, dynamic> map) {
    return AudioFile(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      fileSize: map['file_size'] as int,
      duration: map['duration'] as int,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: map['created_at'] as int,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'book_id': bookId,
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'duration': duration,
      'sort_order': sortOrder,
      'created_at': createdAt,
    };
  }

  /// 复制并修改部分字段
  AudioFile copyWith({
    int? id,
    int? bookId,
    String? filePath,
    String? fileName,
    int? fileSize,
    int? duration,
    int? sortOrder,
    int? createdAt,
  }) {
    return AudioFile(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 获取格式化的文件大小
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 获取格式化的时长
  String get formattedDuration {
    final seconds = duration ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  String toString() {
    return 'AudioFile{id: $id, bookId: $bookId, fileName: $fileName, duration: $formattedDuration}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AudioFile &&
        other.id == id &&
        other.bookId == bookId &&
        other.filePath == filePath &&
        other.fileName == fileName &&
        other.fileSize == fileSize &&
        other.duration == duration &&
        other.sortOrder == sortOrder &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      bookId,
      filePath,
      fileName,
      fileSize,
      duration,
      sortOrder,
      createdAt,
    );
  }
}
