import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/book_provider.dart';
import 'providers/audio_player_provider.dart';
import 'providers/settings_provider.dart';
import 'utils/constants.dart';
import 'screens/book_list_screen.dart';
import 'screens/book_detail_screen.dart';
import 'screens/file_import_screen.dart';
import 'screens/file_scanner_test_screen.dart';
import 'models/book.dart';

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
            home: const MainScreen(),

            // 路由配置
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/file-import':
                  return MaterialPageRoute(
                    builder: (_) => const FileImportScreen(),
                  );
                case '/book-detail':
                  final book = settings.arguments as Book;
                  return MaterialPageRoute(
                    builder: (_) => BookDetailScreen(book: book),
                  );
                case '/test-scanner':
                  return MaterialPageRoute(
                    builder: (_) => const FileScannerTestScreen(),
                  );
                default:
                  return null;
              }
            },
          );
        },
      ),
    );
  }
}

/// 主屏幕
///
/// 包含底部导航栏，切换不同的页面
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 页面列表
  final List<Widget> _pages = const [
    BookListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 设置页面
///
/// 显示应用设置选项
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 主题设置
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '外观',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Consumer<SettingsProvider>(
                  builder: (context, settings, child) {
                    return Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          title: const Text('跟随系统'),
                          subtitle: const Text('根据系统设置自动切换主题'),
                          value: ThemeMode.system,
                          groupValue: settings.themeMode,
                          onChanged: (value) {
                            settings.setThemeMode(value!);
                          },
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('浅色模式'),
                          subtitle: const Text('始终使用浅色主题'),
                          value: ThemeMode.light,
                          groupValue: settings.themeMode,
                          onChanged: (value) {
                            settings.setThemeMode(value!);
                          },
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('深色模式'),
                          subtitle: const Text('始终使用深色主题'),
                          value: ThemeMode.dark,
                          groupValue: settings.themeMode,
                          onChanged: (value) {
                            settings.setThemeMode(value!);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 播放设置
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '播放',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Consumer<SettingsProvider>(
                  builder: (context, settings, child) {
                    return Column(
                      children: [
                        ListTile(
                          title: const Text('默认播放速度'),
                          subtitle: Text('${settings.defaultPlaybackSpeed}x'),
                          trailing: DropdownButton<double>(
                            value: settings.defaultPlaybackSpeed,
                            items: const [
                              DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                              DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                              DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                              DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                              DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                              DropdownMenuItem(value: 1.75, child: Text('1.75x')),
                              DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                settings.setDefaultPlaybackSpeed(value);
                              }
                            },
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('自动播放下一个'),
                          subtitle: const Text('当前音频播放完成后自动播放下一个'),
                          value: settings.autoPlay,
                          onChanged: (value) {
                            settings.setAutoPlay(value);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 关于
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '关于',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ListTile(
                  title: const Text('应用名称'),
                  subtitle: const Text(AppConstants.appName),
                ),
                ListTile(
                  title: const Text('版本'),
                  subtitle: const Text('0.0.1'),
                ),
                ListTile(
                  title: const Text('描述'),
                  subtitle: const Text(AppConstants.appDescription),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // 开发者选项
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '开发者选项',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.science),
                  title: const Text('测试文件扫描'),
                  subtitle: const Text('测试文件扫描和元数据读取功能'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/test-scanner');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
