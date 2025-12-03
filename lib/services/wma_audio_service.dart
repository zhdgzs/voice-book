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
      debugPrint('✅ WMA 音频服务已初始化，缓存目录: ${_cacheDir.path}');
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ WMA 音频服务初始化失败: $e');
      rethrow;
    }
  }

  /// 将 WMA 文件转码为 WAV
  /// 返回转码后的文件路径
  Future<String> transcodeWmaToWav(String wmaFilePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final fileName = File(wmaFilePath).path.split('/').last.replaceAll('.wma', '.wav');
      final outputPath = '${_cacheDir.path}/$fileName';

      // 如果转码文件已存在，直接返回
      if (await File(outputPath).exists()) {
        debugPrint('✅ 转码文件已存在: $outputPath');
        return outputPath;
      }

      debugPrint('🔄 开始转码 WMA 文件: $wmaFilePath');

      // 使用 FFmpeg 转码 WMA 为 WAV
      final session = await FFmpegKit.execute(
        '-i "$wmaFilePath" -acodec pcm_s16le -ar 44100 "$outputPath"',
      );

      final returnCode = await session.getReturnCode();
      if (returnCode?.getValue() == 0) {
        debugPrint('✅ WMA 转码成功: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getLogsAsString();
        throw Exception('FFmpeg 转码失败: $logs');
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
