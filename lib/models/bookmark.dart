/// 书签模型
///
/// 表示用户在音频文件中添加的书签，用于快速跳转到特定位置
class Bookmark {
  /// 书签 ID
  final int? id;

  /// 音频文件 ID
  final int audioFileId;

  /// 书签位置（毫秒）
  final int position;

  /// 书签标题
  final String? title;

  /// 书签备注
  final String? note;

  /// 创建时间（Unix 时间戳，毫秒）
  final int createdAt;

  Bookmark({
    this.id,
    required this.audioFileId,
    required this.position,
    this.title,
    this.note,
    required this.createdAt,
  });

  /// 从数据库 Map 创建 Bookmark 对象
  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as int?,
      audioFileId: map['audio_file_id'] as int,
      position: map['position'] as int,
      title: map['title'] as String?,
      note: map['note'] as String?,
      createdAt: map['created_at'] as int,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'audio_file_id': audioFileId,
      'position': position,
      'title': title,
      'note': note,
      'created_at': createdAt,
    };
  }

  /// 复制并修改部分字段
  Bookmark copyWith({
    int? id,
    int? audioFileId,
    int? position,
    String? title,
    String? note,
    int? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      audioFileId: audioFileId ?? this.audioFileId,
      position: position ?? this.position,
      title: title ?? this.title,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 获取格式化的位置
  String get formattedPosition {
    final seconds = position ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  /// 获取格式化的创建时间
  String get formattedCreatedAt {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 获取显示标题（如果没有自定义标题，则使用位置作为标题）
  String get displayTitle {
    return title?.isNotEmpty == true ? title! : '书签 $formattedPosition';
  }

  @override
  String toString() {
    return 'Bookmark{id: $id, audioFileId: $audioFileId, position: $formattedPosition, title: $title}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Bookmark &&
        other.id == id &&
        other.audioFileId == audioFileId &&
        other.position == position &&
        other.title == title &&
        other.note == note &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      audioFileId,
      position,
      title,
      note,
      createdAt,
    );
  }
}
