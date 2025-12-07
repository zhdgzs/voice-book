// FFmpeg stub - lite 版本使用（当 FFmpeg 依赖被移除时）

/// 模拟 FFmpegKit 类
class FFmpegKit {
  static Future<FFmpegSession> execute(String command) async {
    throw UnsupportedError('FFmpeg 在 lite 版本中不可用');
  }
}

/// 模拟 FFmpegSession 类
class FFmpegSession {
  Future<ReturnCode?> getReturnCode() async => null;
  Future<String?> getLogsAsString() async => null;
}

/// 模拟 ReturnCode 类
class ReturnCode {
  int? getValue() => null;
}
