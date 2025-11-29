# Voice Book - Claude Code 项目配置

## 📚 项目资源概览

### 项目基本信息
- **项目名称**: Voice Book
- **项目类型**: 离线本地有声书播放器
- **技术栈**: Flutter + Provider + SQLite + Just Audio
- **开发语言**: Dart
- **最低 SDK 版本**: 3.2.0
- **核心理念**: 低资源占用 + 隐私保护

### 核心依赖包
| 依赖包 | 版本 | 用途 |
|--------|------|------|
| provider | ^6.0.5 | 状态管理 |
| sqflite | ^2.3.0 | 本地数据库 |
| path_provider | ^2.1.2 | 路径管理 |
| just_audio | ^0.9.37 | 音频播放 |
| permission_handler | ^11.0.1 | 权限管理 |

### 项目目录结构

```
lib/
├── models/              # 数据模型
│   ├── book.dart       # 书籍模型
│   ├── audio_file.dart # 音频文件模型
│   ├── playback_progress.dart # 播放进度模型
│   └── bookmark.dart   # 书签模型
├── providers/          # 状态管理
│   ├── book_provider.dart # 书籍管理
│   ├── audio_player_provider.dart # 音频播放
│   └── settings_provider.dart # 设置管理
├── screens/            # 页面
│   ├── home_screen.dart # 首页
│   ├── book_list_screen.dart # 书籍列表
│   ├── book_detail_screen.dart # 书籍详情
│   ├── player_screen.dart # 播放器页面
│   └── settings_screen.dart # 设置页面
├── widgets/            # 组件
│   ├── audio_player_controls.dart # 播放控制组件
│   ├── progress_bar.dart # 进度条组件
│   ├── book_card.dart # 书籍卡片组件
│   └── bookmark_list.dart # 书签列表组件
├── services/           # 服务层
│   ├── database_service.dart # 数据库服务
│   ├── audio_service.dart # 音频服务
│   ├── file_scanner_service.dart # 文件扫描服务
│   └── permission_service.dart # 权限服务
├── utils/              # 工具类
│   ├── constants.dart  # 常量定义
│   ├── helpers.dart    # 辅助函数
│   └── extensions.dart # 扩展方法
└── main.dart           # 应用入口
```

### 已实现功能模块

#### 核心模块
| 模块 | 状态 | 位置 | 说明 |
|------|------|------|------|
| 项目初始化 | ✅ 已完成 | / | Flutter 项目创建、依赖配置 |
| 基础架构 | ⏳ 待开始 | lib/ | 目录结构、数据库设计、基础类 |
| 音频文件管理 | ⏳ 待开始 | lib/services/file_scanner_service.dart | 文件扫描、导入、管理 |
| 音频播放 | ⏳ 待开始 | lib/providers/audio_player_provider.dart | 播放控制、进度管理 |
| 播放进度记忆 | ⏳ 待开始 | lib/models/playback_progress.dart | 进度保存、恢复 |
| 书籍管理 | ⏳ 待开始 | lib/providers/book_provider.dart | 书籍增删改查 |

#### 增强模块
| 模块 | 状态 | 位置 | 说明 |
|------|------|------|------|
| 书签功能 | ⏳ 待开始 | lib/models/bookmark.dart | 书签添加、管理、跳转 |
| 播放列表 | ⏳ 待开始 | lib/providers/playlist_provider.dart | 播放列表管理 |
| 睡眠定时器 | ⏳ 待开始 | lib/widgets/sleep_timer.dart | 定时停止播放 |

#### 优化模块
| 模块 | 状态 | 位置 | 说明 |
|------|------|------|------|
| 主题切换 | ⏳ 待开始 | lib/providers/theme_provider.dart | 明暗主题切换 |
| 数据备份恢复 | ⏳ 待开始 | lib/services/backup_service.dart | 数据导出导入 |

## 🔧 开发规范

### 代码规范

#### 命名规范
- **文件命名**: 使用小写字母和下划线，如 `audio_player_provider.dart`
- **类命名**: 使用大驼峰命名法，如 `AudioPlayerProvider`
- **变量命名**: 使用小驼峰命名法，如 `currentBook`
- **常量命名**: 使用大写字母和下划线，如 `MAX_VOLUME`
- **私有成员**: 使用下划线前缀，如 `_privateMethod()`

#### 代码组织
- **导入顺序**:
  1. Dart SDK 导入
  2. Flutter 导入
  3. 第三方包导入
  4. 项目内部导入
- **类成员顺序**:
  1. 静态常量
  2. 实例变量
  3. 构造函数
  4. 生命周期方法
  5. 公共方法
  6. 私有方法

#### 注释规范
- 所有公共类、方法必须添加文档注释
- 使用 `///` 进行文档注释
- 复杂逻辑必须添加行内注释说明
- 注释语言：中文

示例：
```dart
/// 音频播放器状态管理
///
/// 负责管理音频播放的所有状态和操作，包括：
/// - 播放/暂停/停止控制
/// - 播放进度管理
/// - 倍速播放
/// - 后台播放
class AudioPlayerProvider extends ChangeNotifier {
  // 实现代码...
}
```

### Flutter 最佳实践

#### 状态管理
- 使用 Provider 进行状态管理
- 避免过度使用 setState
- 合理拆分 Provider，避免单个 Provider 过大

#### 性能优化
- 使用 const 构造函数
- 合理使用 ListView.builder 而非 ListView
- 避免在 build 方法中进行耗时操作
- 使用 RepaintBoundary 优化重绘

#### 资源管理
- 及时释放资源（如音频播放器、数据库连接）
- 在 dispose 方法中清理监听器
- 避免内存泄漏

### 数据库设计规范

#### 表命名
- 使用小写字母和下划线
- 使用复数形式，如 `books`, `audio_files`

#### 字段命名
- 使用小写字母和下划线
- 主键统一使用 `id`
- 外键使用 `表名_id` 格式，如 `book_id`
- 时间字段使用 `created_at`, `updated_at`

#### 数据类型
- 主键: INTEGER PRIMARY KEY AUTOINCREMENT
- 文本: TEXT
- 整数: INTEGER
- 浮点数: REAL
- 布尔值: INTEGER (0/1)
- 时间戳: INTEGER (Unix timestamp)

### Git 提交规范

#### 提交信息格式
```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Type 类型
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具相关

#### Scope 范围
- `player`: 音频播放相关
- `book`: 书籍管理相关
- `file`: 文件管理相关
- `ui`: 界面相关
- `db`: 数据库相关
- `config`: 配置相关

#### 示例
```
feat(player): 实现音频播放基本功能

- 添加播放/暂停/停止控制
- 实现进度条拖动
- 支持倍速播放

Closes #123
```

## 📋 项目管理命令

### 快速开始命令
- `/start` - 快速了解项目当前状态
- `/progress` - 查看详细项目进度
- `/next` - 获取下一步开发建议
- `/update-status` - 自动更新项目状态文档

### 使用场景

#### 每天开始工作
```
/start    # 快速进入工作状态
/next     # 获取今日任务
```

#### 开发完成后
```
git add .
git commit -m "feat(xxx): 完成xxx功能"
/update-status    # 自动更新项目状态
```

#### 需要汇报进度
```
/progress    # 生成详细进度报告
```

## 🎯 开发目标

### MVP 版本目标（2周）
- ✅ 项目初始化
- ⏳ 基础架构搭建
- ⏳ 音频文件管理
- ⏳ 音频播放功能
- ⏳ 播放进度记忆
- ⏳ 书籍管理

### 增强版本目标（1周）
- ⏳ 书签功能
- ⏳ 播放列表
- ⏳ 睡眠定时器

### 正式版本目标（1周）
- ⏳ 主题切换
- ⏳ 数据备份恢复
- ⏳ 性能优化
- ⏳ Bug 修复

## 📝 注意事项

### 开发注意事项
- ⚠️ 严格遵循 Flutter 最佳实践
- ⚠️ 确保代码注释完整，使用中文注释
- ⚠️ 每完成一个功能模块，运行 `/update-status` 更新项目状态
- ⚠️ 定期进行代码审查，保证代码质量
- ⚠️ 注意性能优化，确保低资源占用
- ⚠️ 保护用户隐私，不收集任何数据

### 测试注意事项
- 在真机上测试音频播放功能
- 测试不同格式的音频文件
- 测试后台播放和锁屏控制
- 测试低内存设备的性能表现
- 测试权限请求流程

### 发布注意事项
- 确保所有功能正常工作
- 完成性能优化
- 编写用户使用文档
- 准备应用商店截图和描述
- 遵守应用商店审核规范

## 🔗 相关文档

- [需求文档](./docs/需求文档.md)
- [项目状态](./docs/项目状态.md)
- [待办清单](./docs/待办清单.md)

## 📚 参考资源

- [Flutter 官方文档](https://flutter.dev/docs)
- [Provider 文档](https://pub.dev/packages/provider)
- [just_audio 文档](https://pub.dev/packages/just_audio)
- [sqflite 文档](https://pub.dev/packages/sqflite)
- [Dart 编码规范](https://dart.dev/guides/language/effective-dart)
