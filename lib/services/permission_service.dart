import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// 权限管理服务
///
/// 负责处理应用所需的各种权限，包括：
/// - 存储权限（读取和写入外部存储）
/// - 音频权限（如果需要录音功能）
/// - 通知权限（用于后台播放通知）
///
/// 使用单例模式，确保全局只有一个实例
class PermissionService {
  // 单例模式
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // 设备信息插件
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // 缓存 Android SDK 版本
  int? _androidSdkVersion;

  /// 请求存储权限
  ///
  /// Android 13+ 需要请求 READ_MEDIA_AUDIO 权限
  /// Android 11-12 需要请求 READ_EXTERNAL_STORAGE 权限
  /// Android 10- 需要请求 READ_EXTERNAL_STORAGE 和 WRITE_EXTERNAL_STORAGE 权限
  ///
  /// 返回 true 表示权限已授予，false 表示权限被拒绝
  Future<bool> requestStoragePermission() async {
    // Android 13+ 使用新的媒体权限
    if (await _isAndroid13OrAbove()) {
      final status = await Permission.audio.request();
      return status.isGranted;
    }

    // Android 11-12 使用传统存储权限
    if (await _isAndroid11OrAbove()) {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }

      // 如果被永久拒绝，引导用户到设置页面
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    // Android 10 及以下版本
    final statuses = await [
      Permission.storage,
    ].request();

    return statuses[Permission.storage]?.isGranted ?? false;
  }

  /// 检查存储权限状态
  ///
  /// 返回 true 表示权限已授予，false 表示权限未授予
  Future<bool> checkStoragePermission() async {
    // Android 13+ 检查音频权限
    if (await _isAndroid13OrAbove()) {
      return await Permission.audio.isGranted;
    }

    // Android 11-12 检查存储权限
    if (await _isAndroid11OrAbove()) {
      return await Permission.storage.isGranted;
    }

    // Android 10 及以下版本
    return await Permission.storage.isGranted;
  }

  /// 请求通知权限
  ///
  /// 用于显示后台播放通知
  /// Android 13+ 需要显式请求通知权限
  ///
  /// 返回 true 表示权限已授予，false 表示权限被拒绝
  Future<bool> requestNotificationPermission() async {
    if (await _isAndroid13OrAbove()) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }

    // Android 12 及以下版本默认有通知权限
    return true;
  }

  /// 检查通知权限状态
  ///
  /// 返回 true 表示权限已授予，false 表示权限未授予
  Future<bool> checkNotificationPermission() async {
    if (await _isAndroid13OrAbove()) {
      return await Permission.notification.isGranted;
    }

    // Android 12 及以下版本默认有通知权限
    return true;
  }

  /// 请求所有必需的权限
  ///
  /// 一次性请求应用所需的所有权限
  /// 返回 Map，key 为权限名称，value 为是否授予
  Future<Map<String, bool>> requestAllPermissions() async {
    final storageGranted = await requestStoragePermission();
    final notificationGranted = await requestNotificationPermission();

    return {
      'storage': storageGranted,
      'notification': notificationGranted,
    };
  }

  /// 检查所有必需的权限状态
  ///
  /// 返回 Map，key 为权限名称，value 为是否授予
  Future<Map<String, bool>> checkAllPermissions() async {
    final storageGranted = await checkStoragePermission();
    final notificationGranted = await checkNotificationPermission();

    return {
      'storage': storageGranted,
      'notification': notificationGranted,
    };
  }

  /// 打开应用设置页面
  ///
  /// 当权限被永久拒绝时，引导用户到设置页面手动授予权限
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// 获取 Android SDK 版本
  Future<int> _getAndroidSdkVersion() async {
    if (_androidSdkVersion != null) {
      return _androidSdkVersion!;
    }

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      _androidSdkVersion = androidInfo.version.sdkInt;
      return _androidSdkVersion!;
    }

    return 0;
  }

  /// 检查是否为 Android 13 或以上版本
  /// Android 13 = API Level 33
  Future<bool> _isAndroid13OrAbove() async {
    final sdkVersion = await _getAndroidSdkVersion();
    return sdkVersion >= 33;
  }

  /// 检查是否为 Android 11 或以上版本
  /// Android 11 = API Level 30
  Future<bool> _isAndroid11OrAbove() async {
    final sdkVersion = await _getAndroidSdkVersion();
    return sdkVersion >= 30;
  }

  /// 获取权限状态的描述文本
  ///
  /// 用于向用户展示权限状态
  String getPermissionStatusDescription(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted => '已授予',
      PermissionStatus.denied => '已拒绝',
      PermissionStatus.restricted => '受限制',
      PermissionStatus.limited => '部分授予',
      PermissionStatus.permanentlyDenied => '永久拒绝',
      PermissionStatus.provisional => '临时授予',
    };
  }
}
