# 离线本地有声书播放器设计与开发记录

## 1. 设计范围与目标
- **范围**：覆盖导入管理、播放控制、播放增强、设置中心、非功能要求以及开发记录机制。
- **目标**：在 Android / iOS 双端提供完全离线、低资源占用、无广告的本地有声书体验，保证易维护、扩展友好并严格遵循 SOLID、KISS、DRY、YAGNI。

## 2. 整体架构
| 层级 | 主要组件 | 说明 |
| --- | --- | --- |
| 表现层 | 书架、书籍详情、播放器、设置（Flutter UI + 状态管理） | 纯 UI 组件，不直接访问系统资源，保持单一职责。 |
| 业务服务层 | BookService、PlaybackService、EnhancementService、SettingsService | 聚合业务规则，通过接口依赖 Repository / AudioEngine。 |
| 数据层 | SQLite（sqflite）、FileScanner、MetadataParser | 负责持久化、文件扫描与元数据读取。 |
| 平台桥接 | AudioEngine（ExoPlayer / AVPlayer）、Media Session、后台 Service | 维护播放生命周期与系统交互。 |

> 依赖方向自上而下，所有模块依赖抽象接口，确保 SOLID 中的 DIP / LSP。

## 3. 核心模块设计
### 3.1 导入与管理
- 文件夹导入、拖拽（桌面端可选），FileScanner 以白名单后缀过滤并执行自然排序。
- MetadataParser 解析时长并写入章节表；异步队列串行写 DB，防止资源占用过高。
- 手动排序写入 `sort_order`；章节状态（未听/在听/已听）与进度字段解耦，保持 SRP。

### 3.2 播放器
- `PlaybackController` 维护状态机（Idle/Buffering/Playing/Paused/Completed），统一入口调用 AudioEngine。
- `PlaybackQueue` 负责章节切换策略（顺序/循环/停止）；完成事件驱动后续动作。
- 锁屏与后台控制通过平台 Media Session，Flutter 层仅暴露可订阅状态流，遵守 KISS。

### 3.3 播放增强
- 跳过片头/片尾：`SkipRule`（全局 < 书籍 < 章节）三层覆盖，开始/结束前注入 offset。
- 定时器：`SleepTimerService` 支持分钟倒计时与“播完 N 集”两种模式，触发后统一调用 `stopPlayback()`.
- 变速播放、断点续播、播放统计（可选）分别通过 AudioEngine、PlaybackStateStore、PlaybackStatsRepository 实现。

### 3.4 设置中心 & UI
- PreferenceRepository 存储全局跳过、倍速、主题、结束策略等。
- UI 提供深色模式、字号、播放页布局切换，通过配置对象驱动 Widget，避免分支重复（DRY）。

## 4. 数据模型
| 表 | 字段要点 | 备注 |
| --- | --- | --- |
| `books` | `id`, `title`, `cover_path`, `folder_uri`, `chapter_count`, `total_duration`, `last_played_at` | 记录书籍级元信息。 |
| `chapters` | `id`, `book_id`, `title`, `file_path`, `duration_ms`, `sort_order`, `play_status`, `last_position_ms`, `skip_intro_s`, `skip_outro_s` | 支撑播放顺序与状态。 |
| `preferences` | `key`, `value(json)` | 全局设置。 |
| `playback_stats`（可选） | `date`, `book_id`, `listened_ms` | 仅在用户启用统计后创建。 |

所有写操作使用事务；常用字段建索引（如 `chapters(book_id, sort_order)`），确保性能。

## 5. 核心流程
1. **导入**：选择目录 → FileScanner 过滤排序 → MetadataParser 解析 → Repository 事务写入 → UI 刷新。
2. **播放**：点击章节 → PlaybackController 组装 Session（skip、倍速、定时）→ AudioEngine 载入并监听 → PlaybackQueue 根据设置连播。
3. **跳过设置**：用户在全局/书籍/章节层更新 SkipRule → Preference/Book/Chapter 表写入 → 播放开始前按优先级取值。
4. **定时或播完 N 集**：SleepTimerService 记录策略 → 监听计时或章节完成 → 触发 stop 并可返回书籍列表。
5. **断点续播**：PlaybackStateStore 定期写 last_position → 进入书籍时读取，决定播放按钮状态与进度。

## 6. 非功能与技术要点
- **性能**：Isolate 异步解析音频、列表分页、封面压缩缓存，AudioEngine 流式播放避免高内存。
- **稳定性**：播放控制与数据层解耦，异常捕获后记录本地日志；关键流程提供重试（导入、播放启动）。
- **安全/离线**：不启用任何网络请求；权限在使用前申请，最小化授权。
- **测试策略**：Repository/SkipRule/SleepTimer 单测；导入→播放集成测试；原生层做后台播放和锁屏控制仪表测试。

## 7. 风险与缓解
| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 平台权限差异 | 无法读取文件或后台播放中断 | 封装 DirectoryAccessService，分别适配 Android/iOS；提供电池优化提示。 |
| 大批量导入性能 | 初次导入耗时长、卡顿 | 批量解析限流、提供进度反馈和取消按钮。 |
| 资源占用 | 长时间播放可能导致内存上升 | 不缓存整集音频，定期清理封面缓存，后台 Service 仅保留必要状态。 |

## 8. 开发步骤记录（持续更新）
| 时间/阶段 | 内容 | 负责人 | 备注 |
| --- | --- | --- | --- |
| Step 1 | PRD 分析与架构设计（本文档） | AI/团队 | 完成需求拆解与设计定稿。 |
| Step 2 | 基础工程与数据层搭建 | AI/团队 | 已创建 Flutter 项目骨架（pubspec、lib/main.dart、目录结构）与 AGENTS 文档。 |
| Step 3 | 书籍导入与管理模块开发 | 待定 | 实现文件夹导入、排序、元数据解析、书架展示。 |
| Step 4 | 播放核心与后台能力 | 待定 | AudioEngine 封装、PlaybackController/Queue、后台播放。 |
| Step 5 | 播放增强功能 | 待定 | 跳过片头尾、定时/播完 N 集、倍速与断点续播。 |
| Step 6 | 设置中心与 UI 完整化 | 待定 | 主题/字号/布局配置、全局设置存储。 |
| Step 7 | 非功能优化与测试 | 待定 | 性能优化、权限适配、自动化测试、稳定性验证。 |

> 规范：每完成一阶段（如导入模块开发、播放器集成、测试验证），补充表格行，包含交付内容、负责人、关键决策或问题，确保“每一步的开发都记录”。如需更细粒度，可扩展为“日期/Issue/结果”格式的附表。

## 9. 分阶段开发计划
1. **阶段 1：基础工程与数据层（Step 2）**
   - 初始化 Flutter 工程、依赖管理和环境检查脚本（KISS 保持最小依赖）。
   - 建立 `BookRepository`、`ChapterRepository`、`PreferenceRepository`、`PlaybackStateStore` 等接口及 SQLite 实现。
   - 搭建 CI（格式检查、单测），保证后续迭代质量。
2. **阶段 2：导入与管理（Step 3）**
   - 实现目录选择/拖拽、FileScanner、MetadataParser，并打通写库流程。
   - 书架/详情 UI，支持手动排序与状态展示，提供导入进度反馈。
   - 单测覆盖自然排序、元数据解析、状态改变。
3. **阶段 3：播放核心（Step 4）**
   - 封装跨平台 AudioEngine + PlaybackController 状态机。
   - 完成播放控制（播放/暂停/上一集/下一集/进度条）和后台锁屏控制。
   - 构建 PlaybackQueue 与自动连播策略、异常恢复。
4. **阶段 4：播放增强（Step 5）**
   - 跳过片头尾规则实现（全局/书籍/章节）。
   - SleepTimer（分钟与播完 N 集）、倍速调节、断点续播、可选播放统计。
   - 增强模块单测与集成测试。
5. **阶段 5：设置与 UI 完整化（Step 6）**
   - 设置页（跳过、倍速、主题、布局、权限提示）。
   - 深色模式、字号调整、播放布局切换。
   - 体验打磨与可访问性检查。
6. **阶段 6：非功能优化与发布准备（Step 7）**
   - 性能 Profiling、封面缓存策略、后台生命周期验证。
   - 权限适配（Android/iOS 差异）、本地化与日志策略。
   - 测试报告与文档更新，准备发布包。

> 每个阶段完成后需在“开发步骤记录”表中更新负责人、状态与备注，并将关键输出（代码、测试、文档）链接回主仓库，确保全过程可追溯。

---

本设计可作为后续冲刺的基准；若需求变更，需在此文档更新对应章节并同步开发记录表。
