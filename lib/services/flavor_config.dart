/// 应用版本配置
///
/// 通过编译时常量区分 full/lite 版本
class FlavorConfig {
  static const bool hasFFmpeg = bool.fromEnvironment(
    'HAS_FFMPEG',
    defaultValue: true,
  );

  /// 检查是否支持转码功能
  static bool get supportsTranscode => hasFFmpeg;
}
