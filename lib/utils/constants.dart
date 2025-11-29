/// 应用常量定义
///
/// 包含应用中使用的各种常量，如：
/// - 应用信息
/// - 文件格式
/// - 默认值
/// - 限制值

/// 应用信息
class AppConstants {
  static const String appName = 'Voice Book';
  static const String appVersion = '0.0.1';
  static const String appDescription = '离线本地有声书播放器';
}

/// 音频文件相关常量
class AudioConstants {
  /// 支持的音频格式
  static const List<String> supportedFormats = [
    'mp3',
    'm4a',
    'm4b',
    'aac',
    'wav',
    'flac',
    'ogg',
    'opus',
  ];

  /// 默认播放速度
  static const double defaultPlaybackSpeed = 1.0;

  /// 播放速度选项
  static const List<double> playbackSpeedOptions = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  /// 快进/快退步长（秒）
  static const int seekStepSeconds = 10;

  /// 进度保存间隔（毫秒）
  static const int progressSaveInterval = 5000;
}

/// 数据库相关常量
class DatabaseConstants {
  /// 数据库名称
  static const String databaseName = 'voice_book.db';

  /// 数据库版本
  static const int databaseVersion = 1;

  /// 表名
  static const String tableBooks = 'books';
  static const String tableAudioFiles = 'audio_files';
  static const String tablePlaybackProgress = 'playback_progress';
  static const String tableBookmarks = 'bookmarks';
}

/// UI 相关常量
class UIConstants {
  /// 默认边距
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  /// 默认圆角
  static const double defaultBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  /// 图标大小
  static const double smallIconSize = 16.0;
  static const double defaultIconSize = 24.0;
  static const double largeIconSize = 32.0;

  /// 封面图片大小
  static const double coverImageSmallSize = 60.0;
  static const double coverImageMediumSize = 120.0;
  static const double coverImageLargeSize = 200.0;

  /// 列表项高度
  static const double listItemHeight = 80.0;

  /// 动画时长（毫秒）
  static const int defaultAnimationDuration = 300;
}

/// 文件相关常量
class FileConstants {
  /// 最大文件大小（字节）- 500MB
  static const int maxFileSize = 500 * 1024 * 1024;

  /// 封面图片目录
  static const String coverImageDirectory = 'covers';

  /// 默认封面图片
  static const String defaultCoverImage = 'assets/images/default_cover.png';
}

/// 睡眠定时器相关常量
class SleepTimerConstants {
  /// 默认时长（分钟）
  static const int defaultDuration = 30;

  /// 时长选项（分钟）
  static const List<int> durationOptions = [
    5,
    10,
    15,
    20,
    30,
    45,
    60,
    90,
    120,
  ];
}

/// 错误消息
class ErrorMessages {
  static const String databaseError = '数据库操作失败';
  static const String fileNotFound = '文件不存在';
  static const String fileFormatNotSupported = '不支持的文件格式';
  static const String fileTooLarge = '文件过大';
  static const String permissionDenied = '权限被拒绝';
  static const String audioLoadError = '音频加载失败';
  static const String audioPlayError = '音频播放失败';
  static const String networkError = '网络错误';
  static const String unknownError = '未知错误';
}

/// 成功消息
class SuccessMessages {
  static const String bookCreated = '书籍创建成功';
  static const String bookUpdated = '书籍更新成功';
  static const String bookDeleted = '书籍删除成功';
  static const String bookmarkAdded = '书签添加成功';
  static const String bookmarkDeleted = '书签删除成功';
  static const String progressSaved = '进度已保存';
  static const String settingsSaved = '设置已保存';
}
