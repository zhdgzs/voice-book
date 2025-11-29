/// 扩展方法
///
/// 为 Dart 内置类型添加便捷的扩展方法

/// String 扩展
extension StringExtension on String {
  /// 判断字符串是否为空或仅包含空白字符
  bool get isNullOrEmpty => trim().isEmpty;

  /// 判断字符串是否不为空
  bool get isNotNullOrEmpty => trim().isNotEmpty;

  /// 首字母大写
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// 截断文本
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }

  /// 移除所有空白字符
  String get removeWhitespace => replaceAll(RegExp(r'\s+'), '');

  /// 判断是否为有效的文件路径
  bool get isValidFilePath {
    return isNotEmpty && !contains(RegExp(r'[<>:"|?*]'));
  }
}

/// int 扩展（时间相关）
extension IntExtension on int {
  /// 将毫秒转换为格式化的时长字符串
  String get toDurationString {
    final seconds = this ~/ 1000;
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

  /// 将字节转换为格式化的文件大小字符串
  String get toFileSizeString {
    if (this < 1024) {
      return '$this B';
    } else if (this < 1024 * 1024) {
      return '${(this / 1024).toStringAsFixed(2)} KB';
    } else if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 将时间戳转换为 DateTime
  DateTime get toDateTime => DateTime.fromMillisecondsSinceEpoch(this);

  /// 将时间戳转换为格式化的日期时间字符串
  String get toDateTimeString {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(this);
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 将时间戳转换为相对时间字符串
  String get toRelativeTimeString {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(this);
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
}

/// double 扩展
extension DoubleExtension on double {
  /// 格式化为播放速度字符串
  String get toSpeedString => '${toStringAsFixed(2)}x';

  /// 格式化为百分比字符串
  String get toPercentageString => '${(this * 100).toStringAsFixed(0)}%';

  /// 限制在指定范围内
  double clampTo(double min, double max) => clamp(min, max);
}

/// DateTime 扩展
extension DateTimeExtension on DateTime {
  /// 转换为时间戳（毫秒）
  int get toTimestamp => millisecondsSinceEpoch;

  /// 格式化为日期字符串
  String get toDateString {
    return '$year-${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// 格式化为时间字符串
  String get toTimeString {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  /// 格式化为日期时间字符串
  String get toDateTimeString {
    return '$toDateString $toTimeString';
  }

  /// 判断是否为今天
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// 判断是否为昨天
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// 判断是否为本周
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return isAfter(startOfWeek) && isBefore(endOfWeek);
  }
}

/// List 扩展
extension ListExtension<T> on List<T> {
  /// 判断列表是否为空或 null
  bool get isNullOrEmpty => isEmpty;

  /// 判断列表是否不为空
  bool get isNotNullOrEmpty => isNotEmpty;

  /// 安全地获取指定索引的元素
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// 查找第一个满足条件的元素，如果没有则返回 null
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
