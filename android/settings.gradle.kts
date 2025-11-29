// android/settings.gradle.kts
pluginManagement {
    val flutterSdkPath = file("../flutter").absolutePath
        .takeIf { File(it).exists() }
        ?: System.getenv("FLUTTER_ROOT")

    if (flutterSdkPath != null) {
        includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    }

    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    // 启用集中式仓库管理
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)

    repositories {
        maven("https://storage.flutter-io.cn/download.flutter.io")
        google()
        mavenCentral()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
