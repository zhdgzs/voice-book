# Android 权限配置指南

## 📋 概述

Voice Book 需要以下 Android 权限才能正常工作：
- 存储权限（读取音频文件）
- 通知权限（后台播放通知）

## 🔧 配置步骤

### 1. 修改 AndroidManifest.xml

在 `android/app/src/main/AndroidManifest.xml` 文件中添加以下权限声明：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 存储权限（Android 12 及以下） -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
                     android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                     android:maxSdkVersion="32" />

    <!-- Android 13+ 音频权限 -->
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

    <!-- 通知权限（Android 13+） -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <!-- 前台服务权限（用于后台播放） -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

    <!-- 唤醒锁权限（保持播放） -->
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <!-- 网络状态权限（可选，用于检查网络连接） -->
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:label="Voice Book"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- 主 Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- Flutter 引擎配置 -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

### 2. 修改 build.gradle

在 `android/app/build.gradle` 中确保以下配置：

```gradle
android {
    compileSdkVersion 34  // 或更高版本

    defaultConfig {
        applicationId "com.example.voice_book"
        minSdkVersion 21      // 最低支持 Android 5.0
        targetSdkVersion 34   // 目标 Android 14
        versionCode 1
        versionName "0.0.1"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}
```

### 3. 权限说明（可选）

如果需要在应用商店上架，建议在 `android/app/src/main/res/values/strings.xml` 中添加权限说明：

```xml
<resources>
    <string name="app_name">Voice Book</string>

    <!-- 权限说明 -->
    <string name="permission_storage_rationale">
        Voice Book 需要访问您的存储空间以读取音频文件。
        我们不会收集或上传您的任何个人数据。
    </string>

    <string name="permission_notification_rationale">
        Voice Book 需要通知权限以在后台播放时显示播放控制。
    </string>
</resources>
```

## 📱 权限版本说明

### Android 13+ (API 33+)
- 使用 `READ_MEDIA_AUDIO` 权限读取音频文件
- 需要 `POST_NOTIFICATIONS` 权限显示通知
- 不再需要 `READ_EXTERNAL_STORAGE` 和 `WRITE_EXTERNAL_STORAGE`

### Android 11-12 (API 30-32)
- 使用 `READ_EXTERNAL_STORAGE` 权限读取文件
- 通知权限默认授予

### Android 10 及以下 (API 29-)
- 使用 `READ_EXTERNAL_STORAGE` 和 `WRITE_EXTERNAL_STORAGE` 权限
- 通知权限默认授予

## ⚠️ 注意事项

### 1. 权限请求时机
- 在用户首次打开应用时请求存储权限
- 在用户首次播放音频时请求通知权限
- 不要在应用启动时一次性请求所有权限

### 2. 权限被拒绝处理
- 如果用户拒绝权限，显示友好的提示信息
- 如果权限被永久拒绝，引导用户到设置页面手动授予
- 提供"稍后再说"选项，不要强制用户授予权限

### 3. 隐私政策
- 在应用中明确说明权限用途
- 承诺不收集用户数据
- 遵守 Google Play 和应用商店的隐私政策要求

### 4. 测试建议
- 在不同 Android 版本上测试权限请求流程
- 测试权限被拒绝后的应用行为
- 测试权限被永久拒绝后的引导流程

## 🔗 相关文档

- [permission_handler 官方文档](https://pub.dev/packages/permission_handler)
- [Android 权限最佳实践](https://developer.android.com/training/permissions/requesting)
- [文件扫描服务使用指南](./文件扫描服务使用指南.md)

## 📝 更新日志

### 2025-11-29
- ✅ 创建 Android 权限配置指南
- ✅ 添加不同 Android 版本的权限说明
- ✅ 提供完整的 AndroidManifest.xml 配置示例
