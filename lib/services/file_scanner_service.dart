import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'audio_metadata_service.dart';

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

  // 元数据服务实例
  final AudioMetadataService _metadataService = AudioMetadataService();

  /// 支持的音频文件扩展名（原生支持 + 可转码格式）
  static const List<String> supportedExtensions = [
    // just_audio 原生支持
    '.mp3', '.m4a', '.m4b', '.wav', '.flac', '.aac', '.ogg', '.opus',
    // 需要转码的格式
    '.wma', '.ape', '.amr', '.ac3', '.dts', '.ra', '.rm',
    '.wv', '.tta', '.mka', '.spx', '.caf', '.au', '.snd',
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
    final directory = Directory(directoryPath);

    // 检查目录是否存在
    if (!await directory.exists()) {
      throw Exception('目录不存在: $directoryPath');
    }

    try {
      // 在独立 isolate 中执行扫描，避免阻塞 UI
      final audioPaths = await compute(
        _scanDirectoryIsolate,
        _ScanParams(directoryPath, recursive, supportedExtensions),
      );

      // 分批转换为 File 对象，避免阻塞 UI
      final audioFiles = <File>[];
      const batchSize = 100;
      for (int i = 0; i < audioPaths.length; i += batchSize) {
        final end = (i + batchSize < audioPaths.length) ? i + batchSize : audioPaths.length;
        for (int j = i; j < end; j++) {
          audioFiles.add(File(audioPaths[j]));
        }
        // 每批处理后让出主线程
        if (end < audioPaths.length) {
          await Future.delayed(Duration.zero);
        }
      }

      // 调用进度回调（扫描完成）
      onProgress?.call(audioFiles.length);

      return audioFiles;
    } catch (e) {
      throw Exception('扫描目录失败: $e');
    }
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
      // 忽略获取目录失败的错误
    }

    return directories;
  }

  /// 读取音频文件元数据（快速模式，不加载封面）
  ///
  /// [file] 音频文件
  ///
  /// 返回包含元数据的 AudioMetadata 对象
  /// 此方法跳过封面图片读取，适合批量扫描场景
  Future<AudioMetadata> readMetadata(File file) async {
    return _metadataService.readMetadataQuick(file);
  }

  /// 读取音频文件元数据（完整模式，包含封面）
  ///
  /// [file] 音频文件
  ///
  /// 返回包含完整元数据的 AudioMetadata 对象，包括封面图片
  Future<AudioMetadata> readMetadataWithCover(File file) async {
    return _metadataService.readMetadataFull(file);
  }

  /// 批量读取音频文件元数据（快速模式）
  ///
  /// [files] 音频文件列表
  /// [onProgress] 进度回调，参数为已处理的文件数量和总文件数量
  ///
  /// 返回包含元数据的 AudioMetadata 列表
  /// 此方法跳过封面图片读取，适合批量扫描场景
  Future<List<AudioMetadata>> readMultipleMetadata(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    return _metadataService.readMultipleMetadataQuick(files, onProgress: onProgress);
  }

  /// 批量读取音频文件元数据（完整模式）
  ///
  /// [files] 音频文件列表
  /// [onProgress] 进度回调，参数为已处理的文件数量和总文件数量
  ///
  /// 返回包含完整元数据的 AudioMetadata 列表，包括封面图片
  Future<List<AudioMetadata>> readMultipleMetadataWithCover(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    return _metadataService.readMultipleMetadataFull(files, onProgress: onProgress);
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
      final comparison = _naturalCompareInstance(path.basename(a.path), path.basename(b.path));
      return ascending ? comparison : -comparison;
    });

    return sortedFiles;
  }

  /// 实例方法版本的自然排序
  int _naturalCompareInstance(String a, String b) {
    final regExp = RegExp(r'(\d+)|(\D+)');
    final partsA = regExp.allMatches(a).map((m) => m.group(0)!).toList();
    final partsB = regExp.allMatches(b).map((m) => m.group(0)!).toList();

    for (int i = 0; i < partsA.length && i < partsB.length; i++) {
      final partA = partsA[i];
      final partB = partsB[i];
      final numA = int.tryParse(partA);
      final numB = int.tryParse(partB);

      int cmp;
      if (numA != null && numB != null) {
        cmp = numA.compareTo(numB);
      } else {
        cmp = partA.toLowerCase().compareTo(partB.toLowerCase());
      }
      if (cmp != 0) return cmp;
    }
    return partsA.length.compareTo(partsB.length);
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
        totalDuration += metadata.duration ?? 0;
      } catch (e) {
        // 忽略单个文件的元数据读取错误
      }
    }

    return totalDuration;
  }
}

/// isolate 扫描参数
class _ScanParams {
  final String directoryPath;
  final bool recursive;
  final List<String> extensions;

  _ScanParams(this.directoryPath, this.recursive, this.extensions);
}

/// isolate 中执行的扫描函数（顶层函数）
List<String> _scanDirectoryIsolate(_ScanParams params) {
  final List<String> audioPaths = [];
  final directory = Directory(params.directoryPath);
  final entities = directory.listSync(recursive: params.recursive);

  for (final entity in entities) {
    if (entity is File) {
      final ext = entity.path.toLowerCase();
      for (final supportedExt in params.extensions) {
        if (ext.endsWith(supportedExt)) {
          audioPaths.add(entity.path);
          break;
        }
      }
    }
  }

  // 自然排序：数字按数值大小排序
  audioPaths.sort(_naturalCompare);

  return audioPaths;
}

/// 自然排序比较函数
/// 将字符串拆分为文本和数字部分，数字按数值比较
int _naturalCompare(String a, String b) {
  final regExp = RegExp(r'(\d+)|(\D+)');
  final partsA = regExp.allMatches(a).map((m) => m.group(0)!).toList();
  final partsB = regExp.allMatches(b).map((m) => m.group(0)!).toList();

  for (int i = 0; i < partsA.length && i < partsB.length; i++) {
    final partA = partsA[i];
    final partB = partsB[i];
    final numA = int.tryParse(partA);
    final numB = int.tryParse(partB);

    int cmp;
    if (numA != null && numB != null) {
      cmp = numA.compareTo(numB);
    } else {
      cmp = partA.toLowerCase().compareTo(partB.toLowerCase());
    }
    if (cmp != 0) return cmp;
  }
  return partsA.length.compareTo(partsB.length);
}
