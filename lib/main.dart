import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/book_provider.dart';
import 'providers/audio_player_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/sleep_timer_provider.dart';
import 'services/database_service.dart';
import 'utils/constants.dart';
import 'screens/book_list_screen.dart';
import 'screens/file_import_screen.dart';
import 'screens/file_scanner_test_screen.dart';
import 'screens/player_screen.dart';
import 'screens/metadata_test_screen.dart';
import 'models/book.dart';
import 'models/audio_file.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 预初始化数据库，避免后续多个 Provider 同时访问导致冲突
  // 这个操作很快（10-30ms），且能避免后续的并发问题
  await DatabaseService().database;

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
        // 睡眠定时器 Provider
        ChangeNotifierProvider(create: (_) => SleepTimerProvider()),
        // 音频播放器 Provider（使用 ProxyProvider 注入 SettingsProvider 和 SleepTimerProvider）
        ChangeNotifierProxyProvider2<SettingsProvider, SleepTimerProvider, AudioPlayerProvider>(
          create: (context) {
            final audioPlayer = AudioPlayerProvider();
            audioPlayer.setSettingsProvider(context.read<SettingsProvider>());
            audioPlayer.setSleepTimerProvider(context.read<SleepTimerProvider>());
            return audioPlayer;
          },
          update: (context, settings, sleepTimer, audioPlayer) {
            audioPlayer?.setSettingsProvider(settings);
            audioPlayer?.setSleepTimerProvider(sleepTimer);
            return audioPlayer ?? AudioPlayerProvider();
          },
        ),
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
                  return null; // 不使用路由，直接在BookListScreen中导航
                case '/player':
                  final args = settings.arguments as Map<String, dynamic>?;
                  return MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      book: args?['book'] as Book?,
                      audioFile: args?['audioFile'] as AudioFile,
                    ),
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

  /// 打开播放器页面（使用根 Navigator）
  static void openPlayer(BuildContext context, {Book? book, required AudioFile audioFile}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(book: book, audioFile: audioFile),
      ),
    );
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // 默认进入"正在播放"页面

  // 每个 Tab 的 Navigator Key
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];


  // 构建带嵌套 Navigator 的 Tab 页面
  Widget _buildNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (_) => child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 先尝试在当前 Tab 的 Navigator 中返回
        final navigator = _navigatorKeys[_currentIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildNavigator(0, BookListScreen(navigatorKey: _navigatorKeys[0])),
            _buildNavigator(1, const NowPlayingScreen()),
            _buildNavigator(2, const SettingsScreen()),
          ],
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
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: '正在播放',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
        ),
      ),
    );
  }
}

/// 正在播放页面
///
/// 显示当前播放或上次播放的音频
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // 延迟初始化，确保 Provider 已经准备好
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 等待下一帧，确保 widget 树已经构建完成
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // 数据库已在 main() 中预初始化，可以安全地恢复播放状态
    try {
      await Provider.of<AudioPlayerProvider>(context, listen: false).ensureInitialized();
    } catch (e) {
      debugPrint('初始化播放器失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, playerProvider, child) {
        if (playerProvider.currentAudioFile == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('正在播放'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_note,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无播放内容',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '去书架选择一本书开始播放吧',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return PlayerScreen(
          book: null,
          audioFile: playerProvider.currentAudioFile!,
        );
      },
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
                        // ignore: deprecated_member_use
                        RadioListTile<ThemeMode>(
                          title: const Text('跟随系统'),
                          subtitle: const Text('根据系统设置自动切换主题'),
                          value: ThemeMode.system,
                          // ignore: deprecated_member_use
                          groupValue: settings.themeMode,
                          // ignore: deprecated_member_use
                          onChanged: (value) => settings.setThemeMode(value!),
                        ),
                        // ignore: deprecated_member_use
                        RadioListTile<ThemeMode>(
                          title: const Text('浅色模式'),
                          subtitle: const Text('始终使用浅色主题'),
                          value: ThemeMode.light,
                          // ignore: deprecated_member_use
                          groupValue: settings.themeMode,
                          // ignore: deprecated_member_use
                          onChanged: (value) => settings.setThemeMode(value!),
                        ),
                        // ignore: deprecated_member_use
                        RadioListTile<ThemeMode>(
                          title: const Text('深色模式'),
                          subtitle: const Text('始终使用深色主题'),
                          value: ThemeMode.dark,
                          // ignore: deprecated_member_use
                          groupValue: settings.themeMode,
                          // ignore: deprecated_member_use
                          onChanged: (value) => settings.setThemeMode(value!),
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
                const ListTile(
                  title: Text('应用名称'),
                  subtitle: Text(AppConstants.appName),
                ),
                const ListTile(
                  title: Text('版本'),
                  subtitle: Text('0.0.1'),
                ),
                const ListTile(
                  title: Text('描述'),
                  subtitle: Text(AppConstants.appDescription),
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
                ListTile(
                  leading: const Icon(Icons.audio_file),
                  title: const Text('测试元数据读取'),
                  subtitle: const Text('选择音频文件查看元数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const MetadataTestScreen(),
                    ));
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
