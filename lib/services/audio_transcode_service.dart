import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:path/path.dart' as path;

/// 音频转码服务
///
/// 使用 ffmpeg_kit_flutter_new_audio 将 just_audio 不支持的格式转码为 WAV
class AudioTranscodeService {
  static final AudioTranscodeService _instance = AudioTranscodeService._internal();
  factory AudioTranscodeService() => _instance;
  AudioTranscodeService._internal();

  bool _isInitialized = false;
  late Directory _cacheDir;

  /// just_audio 原生支持的格式（无需转码）
  static const Set<String> nativelySupportedFormats = {
    '.mp3', '.m4a', '.m4b', '.wav', '.flac', '.aac', '.ogg', '.opus',
  };

  /// 需要转码的格式
  static const Set<String> transcodableFormats = {
    '.wma',   // Windows Media Audio
    '.ape',   // Monkey's Audio
    '.amr',   // Adaptive Multi-Rate
    '.ac3',   // Dolby Digital
    '.dts',   // DTS Audio
    '.ra',    // RealAudio
    '.rm',    // RealMedia
    '.wv',    // WavPack
    '.tta',   // True Audio
    '.mka',   // Matroska Audio
    '.spx',   // Speex
    '.caf',   // Core Audio Format
    '.au',    // Sun Audio
    '.snd',   // Sound File
  };

  /// 所有支持的音频格式（原生 + 可转码）
  static Set<String> get allSupportedFormats =>
      {...nativelySupportedFormats, ...transcodableFormats};

  /// 初始化转码服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _cacheDir = await getTemporaryDirectory();
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }
      debugPrint('✅ 音频转码服务已初始化，缓存目录: ${_cacheDir.path}');
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ 音频转码服务初始化失败: $e');
      _isInitialized = false;
    }
  }

  /// 检查文件是否需要转码
  bool needsTranscode(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return transcodableFormats.contains(ext);
  }

  /// 将音频文件转码为 WAV
  Future<String> transcodeToWav(String sourceFilePath) async {
    if (!_isInitialized) {
      throw Exception('音频转码服务未初始化，请先调用 initialize()');
    }

    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        throw Exception('源文件不存在: $sourceFilePath');
      }

      // 生成输出文件名（保留原文件名，仅替换扩展名）
      final baseName = path.basenameWithoutExtension(sourceFilePath);
      final outputPath = '${_cacheDir.path}/$baseName.wav';

      // 如果转码文件已存在，直接返回
      if (await File(outputPath).exists()) {
        debugPrint('✅ 转码文件已存在: $outputPath');
        return outputPath;
      }

      debugPrint('🔄 开始转码: $sourceFilePath');
      debugPrint('📁 输出路径: $outputPath');

      // FFmpeg 转码命令
      final command = '-i "$sourceFilePath" -acodec pcm_s16le -ar 44100 "$outputPath"';
      debugPrint('🎬 FFmpeg 命令: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode?.getValue() == 0 && await File(outputPath).exists()) {
        debugPrint('✅ 转码成功: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getLogsAsString();
        debugPrint('❌ FFmpeg 日志: $logs');
        throw Exception('FFmpeg 返回错误代码: ${returnCode?.getValue()}');
      }
    } catch (e) {
      debugPrint('❌ 转码失败: $e');
      rethrow;
    }
  }

  /// 清理转码缓存
  Future<void> clearCache() async {
    try {
      if (await _cacheDir.exists()) {
        final files = _cacheDir.listSync();
        for (final file in files) {
          if (file is File && file.path.endsWith('.wav')) {
            await file.delete();
            debugPrint('🗑️ 删除缓存文件: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 清理缓存失败: $e');
    }
  }

  bool get isInitialized => _isInitialized;
}
