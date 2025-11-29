import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as path;

/// 音频元数据模型
///
/// 封装从音频文件中读取的元数据信息
class AudioMetadata {
  /// 标题
  final String? title;

  /// 艺术家/作者
  final String? artist;

  /// 专辑
  final String? album;

  /// 年份
  final DateTime? year;

  /// 音频时长（毫秒）
  final int? duration;

  /// 曲目编号
  final int? trackNumber;

  /// 流派
  final String? genre;

  /// 封面图片数据
  final Uint8List? coverImage;

  /// 文件路径
  final String filePath;

  /// 文件名
  final String fileName;

  /// 文件大小（字节）
  final int fileSize;

  AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.year,
    this.duration,
    this.trackNumber,
    this.genre,
    this.coverImage,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
  });

  /// 获取显示标题（如果没有标题则使用文件名）
  String get displayTitle => title ?? _getFileNameWithoutExtension(fileName);

  /// 获取显示艺术家（如果没有艺术家则返回"未知作者"）
  String get displayArtist => artist ?? '未知作者';

  /// 获取显示专辑（如果没有专辑则返回"未知专辑"）
  String get displayAlbum => album ?? '未知专辑';

  /// 是否有封面图片
  bool get hasCover => coverImage != null && coverImage!.isNotEmpty;

  /// 获取格式化的文件大小
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 获取格式化的时长
  String get formattedDuration {
    if (duration == null || duration == 0) return '00:00';

    final seconds = duration! ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  /// 获取不带扩展名的文件名
  String _getFileNameWithoutExtension(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex > 0) {
      return fileName.substring(0, lastDotIndex);
    }
    return fileName;
  }

  @override
  String toString() {
    return 'AudioMetadata{title: $displayTitle, artist: $displayArtist, duration: $formattedDuration, hasCover: $hasCover}';
  }
}

/// 音频元数据服务
///
/// 负责读取音频文件的元数据信息，包括：
/// - 标题、艺术家、专辑等基本信息
/// - 音频时长
/// - 封面图片
///
/// 使用 audio_metadata_reader 包实现，纯 Dart 实现，跨平台兼容性好
/// 支持分阶段加载：快速扫描时跳过封面，详情页再加载封面
class AudioMetadataService {
  // 单例模式
  static final AudioMetadataService _instance = AudioMetadataService._internal();
  factory AudioMetadataService() => _instance;
  AudioMetadataService._internal();

  /// 读取音频文件元数据（快速模式，不加载封面）
  ///
  /// [file] 音频文件
  ///
  /// 返回包含基本元数据的 AudioMetadata 对象
  /// 此方法跳过封面图片读取，适合批量扫描场景，速度提升 10 倍+
  Future<AudioMetadata> readMetadataQuick(File file) async {
    return _readMetadataInternal(file, loadCover: false);
  }

  /// 读取音频文件元数据（完整模式，包含封面）
  ///
  /// [file] 音频文件
  ///
  /// 返回包含完整元数据的 AudioMetadata 对象，包括封面图片
  /// 此方法会读取封面图片，适合详情页展示场景
  Future<AudioMetadata> readMetadataFull(File file) async {
    return _readMetadataInternal(file, loadCover: true);
  }

  /// 批量读取音频文件元数据（快速模式）
  ///
  /// [files] 音频文件列表
  /// [onProgress] 进度回调，参数为已处理的文件数量和总文件数量
  ///
  /// 返回包含元数据的 AudioMetadata 列表
  /// 适合批量扫描场景，跳过封面图片读取
  Future<List<AudioMetadata>> readMultipleMetadataQuick(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    final List<AudioMetadata> metadataList = [];

    for (int i = 0; i < files.length; i++) {
      try {
        final metadata = await readMetadataQuick(files[i]);
        metadataList.add(metadata);

        // 调用进度回调
        onProgress?.call(i + 1, files.length);
      } catch (e) {
        print('读取元数据失败: ${files[i].path}, 错误: $e');
        // 即使失败也添加基本信息
        metadataList.add(await _createFallbackMetadata(files[i]));
      }
    }

    return metadataList;
  }

  /// 批量读取音频文件元数据（完整模式）
  ///
  /// [files] 音频文件列表
  /// [onProgress] 进度回调，参数为已处理的文件数量和总文件数量
  ///
  /// 返回包含完整元数据的 AudioMetadata 列表，包括封面图片
  Future<List<AudioMetadata>> readMultipleMetadataFull(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    final List<AudioMetadata> metadataList = [];

    for (int i = 0; i < files.length; i++) {
      try {
        final metadata = await readMetadataFull(files[i]);
        metadataList.add(metadata);

        // 调用进度回调
        onProgress?.call(i + 1, files.length);
      } catch (e) {
        print('读取元数据失败: ${files[i].path}, 错误: $e');
        // 即使失败也添加基本信息
        metadataList.add(await _createFallbackMetadata(files[i]));
      }
    }

    return metadataList;
  }

  /// 内部方法：读取音频文件元数据
  ///
  /// [file] 音频文件
  /// [loadCover] 是否加载封面图片
  ///
  /// 返回 AudioMetadata 对象
  Future<AudioMetadata> _readMetadataInternal(File file, {required bool loadCover}) async {
    try {
      // 使用 audio_metadata_reader 读取元数据
      // getImage: false 可以大幅提升读取速度（10倍+）
      final metadata = readMetadata(file, getImage: loadCover);

      // 提取封面图片
      Uint8List? coverImage;
      if (loadCover && metadata.pictures != null && metadata.pictures!.isNotEmpty) {
        coverImage = metadata.pictures!.first.bytes;
      }

      // 获取文件信息
      final fileSize = await file.length();
      final fileName = path.basename(file.path);

      return AudioMetadata(
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        year: metadata.year,
        duration: metadata.duration?.inMilliseconds,
        trackNumber: metadata.trackNumber,
        genre: metadata.genres?.join(', '),
        coverImage: coverImage,
        filePath: file.path,
        fileName: fileName,
        fileSize: fileSize,
      );
    } catch (e) {
      print('读取元数据失败: ${file.path}, 错误: $e');
      // 如果读取失败，返回基本信息
      return _createFallbackMetadata(file);
    }
  }

  /// 创建备用元数据（当读取失败时使用）
  ///
  /// [file] 音频文件
  ///
  /// 返回包含基本文件信息的 AudioMetadata 对象
  Future<AudioMetadata> _createFallbackMetadata(File file) async {
    final fileSize = await file.length();
    final fileName = path.basename(file.path);

    return AudioMetadata(
      title: null,
      artist: null,
      album: null,
      year: null,
      duration: null,
      trackNumber: null,
      genre: null,
      coverImage: null,
      filePath: file.path,
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  /// 只读取封面图片
  ///
  /// [file] 音频文件
  ///
  /// 返回封面图片数据，如果没有封面则返回 null
  /// 适合已经有基本元数据，只需要补充封面的场景
  Future<Uint8List?> readCoverOnly(File file) async {
    try {
      final metadata = readMetadata(file, getImage: true);

      if (metadata.pictures != null && metadata.pictures!.isNotEmpty) {
        return metadata.pictures!.first.bytes;
      }

      return null;
    } catch (e) {
      print('读取封面失败: ${file.path}, 错误: $e');
      return null;
    }
  }

  /// 检查音频文件是否有封面
  ///
  /// [file] 音频文件
  ///
  /// 返回 true 表示有封面，false 表示没有封面
  /// 此方法会读取元数据但不加载封面数据，性能较好
  Future<bool> hasCover(File file) async {
    try {
      final metadata = readMetadata(file, getImage: false);
      return metadata.pictures != null && metadata.pictures!.isNotEmpty;
    } catch (e) {
      print('检查封面失败: ${file.path}, 错误: $e');
      return false;
    }
  }
}
