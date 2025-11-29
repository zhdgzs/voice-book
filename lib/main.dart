import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/book_provider.dart';
import 'providers/audio_player_provider.dart';
import 'providers/settings_provider.dart';
import 'utils/constants.dart';
import 'screens/file_scanner_test_screen.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化设置 Provider
  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();

  runApp(VoiceBookApp(settingsProvider: settingsProvider));
}

class VoiceBookApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const VoiceBookApp({
    super.key,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 设置 Provider
        ChangeNotifierProvider.value(value: settingsProvider),
        // 书籍管理 Provider
        ChangeNotifierProvider(create: (_) => BookProvider()),
        // 音频播放器 Provider
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,

            // 主题配置
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
              ),
              useMaterial3: true,

              // 自定义主题样式
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    UIConstants.defaultBorderRadius,
                  ),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    UIConstants.defaultBorderRadius,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: UIConstants.defaultPadding,
                  vertical: UIConstants.smallPadding,
                ),
              ),
            ),

            // 暗色主题配置
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,

              // 自定义暗色主题样式
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    UIConstants.defaultBorderRadius,
                  ),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    UIConstants.defaultBorderRadius,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: UIConstants.defaultPadding,
                  vertical: UIConstants.smallPadding,
                ),
              ),
            ),

            // 主题模式
            themeMode: settings.themeMode,

            // 首页
            home: const HomePage(),
          );
        },
      ),
    );
  }
}

/// 首页占位符
///
/// 临时首页，展示项目基础架构已完成的信息
/// 后续将替换为实际的书架页面
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          // 主题切换按钮
          IconButton(
            icon: Icon(
              context.watch<SettingsProvider>().isDarkMode
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              context.read<SettingsProvider>().toggleThemeMode();
            },
            tooltip: '切换主题',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 应用图标占位
              Icon(
                Icons.book,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: UIConstants.largePadding),

              // 应用名称
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: UIConstants.smallPadding),

              // 应用描述
              Text(
                AppConstants.appDescription,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: UIConstants.largePadding * 2),

              // 状态信息
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(UIConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✅ 基础架构已完成',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: UIConstants.smallPadding),
                      const Text('• 项目目录结构'),
                      const Text('• 数据库服务'),
                      const Text(
                          '• 数据模型（Book, AudioFile, PlaybackProgress, Bookmark）'),
                      const Text(
                          '• 状态管理（BookProvider, AudioPlayerProvider, SettingsProvider）'),
                      const Text('• 工具类和常量定义'),
                      const Text('• 文件扫描服务 ✨ 新增'),
                      const Text('• 权限管理服务 ✨ 新增'),
                      const SizedBox(height: UIConstants.defaultPadding),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const FileScannerTestScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.science),
                          label: const Text('测试文件扫描功能'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
