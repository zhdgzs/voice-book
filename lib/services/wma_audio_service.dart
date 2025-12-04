import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';

/// WMA 音频服务
///
/// 使用 ffmpeg_kit_flutter_new_audio 将 WMA 文件转码为 WAV
/// 然后通过 just_audio 播放转码后的文件
class WmaAudioService {
  static final WmaAudioService _instance = WmaAudioService._internal();
  factory WmaAudioService() => _instance;
  WmaAudioService._internal();

  bool _isInitialized = false;
  late Directory _cacheDir;

  /// 初始化 WMA 音频支持
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _cacheDir = await getTemporaryDirectory();

      // 确保缓存目录存在
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }

      debugPrint('✅ WMA 音频服务已初始化，缓存目录: ${_cacheDir.path}');
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ WMA 音频服务初始化失败: $e');
      // 不抛出异常，允许应用继续运行（只是不支持 WMA）
      _isInitialized = false;
    }
  }

  /// 将 WMA 文件转码为 WAV
  /// 返回转码后的文件路径
  Future<String> transcodeWmaToWav(String wmaFilePath) async {
    if (!_isInitialized) {
      throw Exception('WMA 音频服务未初始化，请先调用 initialize()');
    }

    try {
      // 检查源文件是否存在
      final sourceFile = File(wmaFilePath);
      if (!await sourceFile.exists()) {
        throw Exception('源文件不存在: $wmaFilePath');
      }

      final fileName = wmaFilePath.split('/').last.replaceAll('.wma', '.wav');
      final outputPath = '${_cacheDir.path}/$fileName';

      // 如果转码文件已存在，直接返回
      if (await File(outputPath).exists()) {
        debugPrint('✅ 转码文件已存在: $outputPath');
        return outputPath;
      }

      debugPrint('🔄 开始转码 WMA 文件: $wmaFilePath');
      debugPrint('📁 输出路径: $outputPath');

      // 使用 FFmpeg 转码 WMA 为 WAV
      final command = '-i "$wmaFilePath" -acodec pcm_s16le -ar 44100 "$outputPath"';
      debugPrint('🎬 FFmpeg 命令: $command');

      final session = await FFmpegKit.execute(command);

      final returnCode = await session.getReturnCode();
      if (returnCode?.getValue() == 0) {
        // 验证输出文件是否存在
        if (await File(outputPath).exists()) {
          debugPrint('✅ WMA 转码成功: $outputPath');
          return outputPath;
        } else {
          throw Exception('转码完成但输出文件不存在');
        }
      } else {
        final logs = await session.getLogsAsString();
        debugPrint('❌ FFmpeg 日志: $logs');
        throw Exception('FFmpeg 返回错误代码: ${returnCode?.getValue()}');
      }
    } catch (e) {
      debugPrint('❌ WMA 转码失败: $e');
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

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;
}
