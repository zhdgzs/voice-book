import 'dart:io';
import 'package:path/path.dart' as path;
import 'constants.dart';

/// 辅助函数工具类
///
/// 提供各种通用的辅助函数，如：
/// - 时间格式化
/// - 文件大小格式化
/// - 文件验证
/// - 路径处理

class Helpers {
  /// 格式化时长（毫秒 -> HH:MM:SS 或 MM:SS）
  static String formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
  }

  /// 格式化文件大小（字节 -> KB/MB/GB）
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 格式化日期时间
  static String formatDateTime(int milliseconds) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化相对时间（如：刚刚、5分钟前、昨天）
  static String formatRelativeTime(int milliseconds) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}周前';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else {
      return '${(difference.inDays / 365).floor()}年前';
    }
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取文件大小
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  /// 检查文件格式是否支持
  static bool isSupportedAudioFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase().replaceAll('.', '');
    return AudioConstants.supportedFormats.contains(extension);
  }

  /// 获取文件扩展名
  static String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase().replaceAll('.', '');
  }

  /// 获取文件名（不含扩展名）
  static String getFileNameWithoutExtension(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  /// 获取文件名（含扩展名）
  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  /// 验证文件大小是否在限制内
  static Future<bool> validateFileSize(String filePath) async {
    final fileSize = await getFileSize(filePath);
    return fileSize > 0 && fileSize <= FileConstants.maxFileSize;
  }

  /// 生成唯一的文件名
  static String generateUniqueFileName(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(originalFileName);
    final nameWithoutExtension = path.basenameWithoutExtension(originalFileName);
    return '${nameWithoutExtension}_$timestamp$extension';
  }

  /// 清理文件名（移除非法字符）
  static String sanitizeFileName(String fileName) {
    // 移除或替换非法字符
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// 计算播放进度百分比
  static double calculateProgress(int position, int duration) {
    if (duration == 0) return 0.0;
    return (position / duration).clamp(0.0, 1.0);
  }

  /// 将百分比转换为位置
  static int progressToPosition(double progress, int duration) {
    return (progress * duration).round().clamp(0, duration);
  }

  /// 获取当前时间戳（毫秒）
  static int getCurrentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// 延迟执行
  static Future<void> delay(int milliseconds) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// 截断文本（超过指定长度时添加省略号）
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// 判断字符串是否为空或仅包含空白字符
  static bool isNullOrEmpty(String? text) {
    return text == null || text.trim().isEmpty;
  }

  /// 安全地解析整数
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 安全地解析浮点数
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
