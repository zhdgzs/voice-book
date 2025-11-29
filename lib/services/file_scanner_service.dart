import 'dart:io';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 文件扫描服务
///
/// 负责扫描本地存储中的音频文件，包括：
/// - 扫描指定目录下的音频文件
/// - 递归扫描子目录
/// - 读取音频文件元数据（标题、作者、专辑、时长等）
/// - 过滤支持的音频格式
///
/// 使用单例模式，确保全局只有一个实例
class FileScannerService {
  // 单例模式
  static final FileScannerService _instance = FileScannerService._internal();
  factory FileScannerService() => _instance;
  FileScannerService._internal();

  /// 支持的音频文件扩展名
  static const List<String> supportedExtensions = [
    '.mp3',
    '.m4a',
    '.m4b',
    '.wav',
    '.flac',
    '.aac',
    '.ogg',
    '.opus',
    '.wma',
  ];

  /// 扫描指定目录下的音频文件
  ///
  /// [directoryPath] 要扫描的目录路径
  /// [recursive] 是否递归扫描子目录，默认为 true
  /// [onProgress] 进度回调，参数为已扫描的文件数量
  ///
  /// 返回扫描到的音频文件列表
  Future<List<File>> scanDirectory(
    String directoryPath, {
    bool recursive = true,
    void Function(int scannedCount)? onProgress,
  }) async {
    final List<File> audioFiles = [];
    final directory = Directory(directoryPath);

    // 检查目录是否存在
    if (!await directory.exists()) {
      throw Exception('目录不存在: $directoryPath');
    }

    try {
      // 获取目录中的所有文件和子目录
      final entities = directory.listSync(recursive: recursive);

      for (final entity in entities) {
        // 只处理文件
        if (entity is File) {
          // 检查是否为支持的音频格式
          if (_isSupportedAudioFile(entity.path)) {
            audioFiles.add(entity);

            // 调用进度回调
            onProgress?.call(audioFiles.length);
          }
        }
      }
    } catch (e) {
      throw Exception('扫描目录失败: $e');
    }

    return audioFiles;
  }

  /// 扫描多个目录
  ///
  /// [directoryPaths] 要扫描的目录路径列表
  /// [recursive] 是否递归扫描子目录，默认为 true
  /// [onProgress] 进度回调，参数为已扫描的文件数量
  ///
  /// 返回扫描到的音频文件列表（去重）
  Future<List<File>> scanMultipleDirectories(
    List<String> directoryPaths, {
    bool recursive = true,
    void Function(int scannedCount)? onProgress,
  }) async {
    final Set<String> uniquePaths = {};
    final List<File> allAudioFiles = [];

    for (final directoryPath in directoryPaths) {
      try {
        final files = await scanDirectory(
          directoryPath,
          recursive: recursive,
          onProgress: onProgress,
        );

        // 去重
        for (final file in files) {
          if (!uniquePaths.contains(file.path)) {
            uniquePaths.add(file.path);
            allAudioFiles.add(file);
          }
        }
      } catch (e) {
        // 忽略单个目录的扫描错误，继续扫描其他目录
        print('扫描目录失败: $directoryPath, 错误: $e');
      }
    }

    return allAudioFiles;
  }

  /// 获取常用的音频文件目录
  ///
  /// 返回系统中常用的音频文件存储位置
  Future<List<String>> getCommonAudioDirectories() async {
    final List<String> directories = [];

    try {
      // 获取外部存储目录
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        directories.add(externalDir.path);
      }

      // 获取下载目录
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        directories.add(downloadDir.path);
      }

      // 获取音乐目录
      final musicDir = Directory('/storage/emulated/0/Music');
      if (await musicDir.exists()) {
        directories.add(musicDir.path);
      }

      // 获取有声书目录（如果存在）
      final audiobooksDir = Directory('/storage/emulated/0/Audiobooks');
      if (await audiobooksDir.exists()) {
        directories.add(audiobooksDir.path);
      }

      // 获取文档目录
      final documentsDir = await getApplicationDocumentsDirectory();
      directories.add(documentsDir.path);
    } catch (e) {
      print('获取常用目录失败: $e');
    }

    return directories;
  }

  /// 读取音频文件元数据
  ///
  /// [file] 音频文件
  ///
  /// 返回包含元数据的 Map，包括：
  /// - title: 标题
  /// - artist: 作者/艺术家
  /// - album: 专辑
  /// - duration: 时长（毫秒）
  /// - trackNumber: 曲目编号
  /// - year: 年份
  /// - genre: 流派
  /// - filePath: 文件路径
  /// - fileName: 文件名
  /// - fileSize: 文件大小（字节）
  Future<Map<String, dynamic>> readMetadata(File file) async {
    final metadata = <String, dynamic>;

    try {
      // 使用 flutter_media_metadata 读取元数据
      final retriever = MetadataRetriever();
      final mediaMetadata = await retriever.fromFile(file);

      // 提取元数据
      metadata['title'] = mediaMetadata.trackName ?? _getFileNameWithoutExtension(file.path);
      metadata['artist'] = mediaMetadata.trackArtistNames?.join(', ') ?? '未知作者';
      metadata['album'] = mediaMetadata.albumName ?? '未知专辑';
      metadata['duration'] = mediaMetadata.trackDuration?.inMilliseconds ?? 0;
      metadata['trackNumber'] = mediaMetadata.trackNumber;
      metadata['year'] = mediaMetadata.year;
      metadata['genre'] = mediaMetadata.genre;
    } catch (e) {
      // 如果读取元数据失败，使用默认值
      print('读取元数据失败: ${file.path}, 错误: $e');
      metadata['title'] = _getFileNameWithoutExtension(file.path);
      metadata['artist'] = '未知作者';
      metadata['album'] = '未知专辑';
      metadata['duration'] = 0;
      metadata['trackNumber'] = null;
      metadata['year'] = null;
      metadata['genre'] = null;
    }

    // 添加文件信息
    metadata['filePath'] = file.path;
    metadata['fileName'] = path.basename(file.path);
    metadata['fileSize'] = await file.length();

    return metadata;
  }

  /// 批量读取音频文件元数据
  ///
  /// [files] 音频文件列表
  /// [onProgress] 进度回调，参数为已处理的文件数量和总文件数量
  ///
  /// 返回包含元数据的 Map 列表
  Future<List<Map<String, dynamic>>> readMultipleMetadata(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    final List<Map<String, dynamic>> metadataList = [];

    for (int i = 0; i < files.length; i++) {
      try {
        final metadata = await readMetadata(files[i]);
        metadataList.add(metadata);

        // 调用进度回调
        onProgress?.call(i + 1, files.length);
      } catch (e) {
        print('读取元数据失败: ${files[i].path}, 错误: $e');
      }
    }

    return metadataList;
  }

  /// 按目录分组音频文件
  ///
  /// [files] 音频文件列表
  ///
  /// 返回按目录分组的 Map，key 为目录路径，value 为该目录下的文件列表
  Map<String, List<File>> groupFilesByDirectory(List<File> files) {
    final Map<String, List<File>> groupedFiles = {};

    for (final file in files) {
      final directory = path.dirname(file.path);

      if (!groupedFiles.containsKey(directory)) {
        groupedFiles[directory] = [];
      }

      groupedFiles[directory]!.add(file);
    }

    return groupedFiles;
  }

  /// 按文件名排序音频文件
  ///
  /// [files] 音频文件列表
  /// [ascending] 是否升序排序，默认为 true
  ///
  /// 返回排序后的文件列表
  List<File> sortFilesByName(List<File> files, {bool ascending = true}) {
    final sortedFiles = List<File>.from(files);

    sortedFiles.sort((a, b) {
      final comparison = path.basename(a.path).compareTo(path.basename(b.path));
      return ascending ? comparison : -comparison;
    });

    return sortedFiles;
  }

  /// 按文件大小排序音频文件
  ///
  /// [files] 音频文件列表
  /// [ascending] 是否升序排序，默认为 true
  ///
  /// 返回排序后的文件列表
  Future<List<File>> sortFilesBySize(List<File> files, {bool ascending = true}) async {
    final sortedFiles = List<File>.from(files);

    // 获取所有文件的大小
    final fileSizes = <File, int>{};
    for (final file in sortedFiles) {
      fileSizes[file] = await file.length();
    }

    // 按大小排序
    sortedFiles.sort((a, b) {
      final sizeA = fileSizes[a] ?? 0;
      final sizeB = fileSizes[b] ?? 0;
      final comparison = sizeA.compareTo(sizeB);
      return ascending ? comparison : -comparison;
    });

    return sortedFiles;
  }

  /// 检查文件是否为支持的音频格式
  ///
  /// [filePath] 文件路径
  ///
  /// 返回 true 表示支持，false 表示不支持
  bool _isSupportedAudioFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return supportedExtensions.contains(extension);
  }

  /// 获取不带扩展名的文件名
  ///
  /// [filePath] 文件路径
  ///
  /// 返回不带扩展名的文件名
  String _getFileNameWithoutExtension(String filePath) {
    final fileName = path.basename(filePath);
    final lastDotIndex = fileName.lastIndexOf('.');

    if (lastDotIndex > 0) {
      return fileName.substring(0, lastDotIndex);
    }

    return fileName;
  }

  /// 格式化文件大小
  ///
  /// [bytes] 文件大小（字节）
  ///
  /// 返回格式化后的文件大小字符串（如 "1.5 MB"）
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 获取音频文件总时长
  ///
  /// [files] 音频文件列表
  ///
  /// 返回总时长（毫秒）
  Future<int> getTotalDuration(List<File> files) async {
    int totalDuration = 0;

    for (final file in files) {
      try {
        final metadata = await readMetadata(file);
        totalDuration += (metadata['duration'] as int?) ?? 0;
      } catch (e) {
        print('获取时长失败: ${file.path}, 错误: $e');
      }
    }

    return totalDuration;
  }
}
