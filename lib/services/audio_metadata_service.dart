import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
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
  /// [batchSize] 每批处理的文件数，默认 20
  ///
  /// 返回包含元数据的 AudioMetadata 列表
  Future<List<AudioMetadata>> readMultipleMetadataQuick(
    List<File> files, {
    void Function(int current, int total)? onProgress,
    int batchSize = 20,
  }) async {
    return _readMultipleInBatches(files, loadCover: false, onProgress: onProgress, batchSize: batchSize);
  }

  /// 批量读取音频文件元数据（完整模式）
  ///
  /// [files] 音频文件列表
  /// [onProgress] 进度回调，参数为已处理的文件数量和总文件数量
  /// [batchSize] 每批处理的文件数，默认 20
  ///
  /// 返回包含完整元数据的 AudioMetadata 列表，包括封面图片
  Future<List<AudioMetadata>> readMultipleMetadataFull(
    List<File> files, {
    void Function(int current, int total)? onProgress,
    int batchSize = 20,
  }) async {
    return _readMultipleInBatches(files, loadCover: true, onProgress: onProgress, batchSize: batchSize);
  }

  /// 快速获取文件基本信息（不读取元数据，避免卡死）
  Future<List<AudioMetadata>> _readMultipleInBatches(
    List<File> files, {
    required bool loadCover,
    void Function(int current, int total)? onProgress,
    int batchSize = 10,
  }) async {
    if (files.isEmpty) return [];

    final List<AudioMetadata> allResults = [];
    final total = files.length;

    for (int i = 0; i < total; i++) {
      final file = files[i];
      final fileSize = file.existsSync() ? file.lengthSync() : 0;
      allResults.add(AudioMetadata(
        filePath: file.path,
        fileName: path.basename(file.path),
        fileSize: fileSize,
      ));

      // 每 20 个文件更新一次进度
      if (i % 20 == 0) {
        onProgress?.call(i + 1, total);
        await Future.delayed(Duration.zero);
      }
    }

    onProgress?.call(total, total);
    return allResults;
  }

  /// 读取单个文件元数据（用于详情页等场景）
  Future<AudioMetadata> _readMetadataInternal(File file, {required bool loadCover}) async {
    try {
      return _readMetadataSync(file.path, loadCover);
    } catch (e) {
      debugPrint('读取元数据失败: ${file.path}, 错误: $e');
      return _createFallbackMetadata(file);
    }
  }

  /// 创建备用元数据（当读取失败时使用）
  Future<AudioMetadata> _createFallbackMetadata(File file) async {
    final fileSize = await file.length();
    final fileName = path.basename(file.path);
    return AudioMetadata(
      filePath: file.path,
      fileName: fileName,
      fileSize: fileSize,
    );
  }
}

/// 同步读取单个文件元数据
AudioMetadata _readMetadataSync(String filePath, bool loadCover) {
  final file = File(filePath);
  try {
    final metadata = readMetadata(file, getImage: loadCover);

    Uint8List? coverImage;
    if (loadCover && metadata.pictures.isNotEmpty) {
      coverImage = metadata.pictures.first.bytes;
    }

    final fileSize = file.lengthSync();
    final fileName = path.basename(filePath);

    return AudioMetadata(
      title: metadata.title,
      artist: metadata.artist,
      album: metadata.album,
      year: metadata.year,
      duration: metadata.duration?.inMilliseconds,
      trackNumber: metadata.trackNumber,
      genre: metadata.genres.join(', '),
      coverImage: coverImage,
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
    );
  } catch (e) {
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    final fileName = path.basename(filePath);
    return AudioMetadata(
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
    );
  }
}
