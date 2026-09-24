---
name: release-version
description: 发布 Voice Book 正式版本。用户要求升级版本号、合并 test 到 main、推送 v* tag、通过 GitHub Actions 构建 APK 并发布 GitHub Release 时使用。
compatibility: Requires git, gh CLI with write access to zhdgzs/voice-book, and network access. Run from the voiceBook repository root.
---

# 发布版本

仅在用户明确要求发布版本时执行。本技能描述完整发布过程，但加载技能本身不意味着授权提交、推送、打 tag 或创建 Release。遵守仓库 `AGENTS.md`：不在本地编译、运行测试或新增测试文件。

## 1. 核对发布输入

- 获取用户指定的目标语义版本（如 `1.0.2`）及 Android build number（`+` 后的整数）；未指定时，根据当前两个 pubspec、最新 tag 和已有 build number 给出建议，向用户确认。不得自行猜测版本。
- 读取 `pubspec.yaml`、`pubspec_lite.yaml`、`.github/workflows/build-apk.yml`、`AGENTS.md` 和当前 git 状态。两个 pubspec 的 `version` 必须相同，格式为 `MAJOR.MINOR.PATCH+BUILD`。Android 的 `versionName`/`versionCode` 由 Flutter 读取，不要另外改 `android/app/build.gradle.kts`。
- `git status --porcelain --untracked-files=all` 必须为空。存在其他改动时，不要清理、暂存或覆盖它们；请用户处理或指定隔离工作树。确认当前分支为 `test`，远端为预期的 `origin`，且 `gh auth status` 有该仓库的写权限。
- `git fetch origin --tags` 后确认 `origin/test`、`origin/main` 和本地分支同步；不能用强制推送、reset、删除分支/tag 或覆盖已有 Release。目标 tag `vMAJOR.MINOR.PATCH` 不得存在于本地、远端或 GitHub Release。若 `main` 不能快进到准备发布的 `test`，停止并请求人工决定合并策略。
- 确认最近一次 `test` 对应源码提交的 GitHub Actions Full/Lite 构建均成功，且所用工作流仍配置为 tag `v*` 推送自动触发（`push.tags`）。若未经验证，先告知用户并征得同意后在 `test` 触发一次手动构建；不要跳过失败结果。不要把旧提交的成功记录当作当前提交的验证。

## 2. 修改版本并审批

- 只修改 `pubspec.yaml` 与 `pubspec_lite.yaml` 的 `version:` 字段到相同的目标版本。新版本高于当前版本；build number 为正整数且高于当前值。检查差异只包含预期字段，并再次核对 `git status`。
- 在执行任何 git 写操作前，向用户展示目标版本、目标 tag、准备合并的 `test` 提交、将推送的 `main` 和由 tag 启动的公开 Release；按项目危险操作确认要求取得明确同意。用户只要求方案时在此停止。

## 3. 提交、合并、推送

依次执行，每步出错立即停止，报告已经完成的远端操作，不自动回滚或重写历史：

1. 在 `test` 上只暂存两个 pubspec，运行 `git diff --cached --check`、`git diff --cached`，创建发布版本提交（例如 `chore(release): 发布 v1.0.2`），记录提交 SHA。推送 `test`：`git push origin test`；若远端在此期间发生变化，停止。
2. 再次获取远端引用，确保 `origin/main` 是发布提交的祖先，且 `origin/test` 仍指向该提交。切换 `main`，以 `git merge --ff-only origin/test` 快进，确认 HEAD 与发布提交一致，然后 `git push origin main`。不进行隐式冲突合并。
3. 从 `main` 的发布提交创建唯一的附注 tag（`git tag -a vX.Y.Z -m "Release vX.Y.Z"`），校验 tag 解引用 SHA 等于 `main` 的 HEAD；`git push origin vX.Y.Z`。**推送 tag 会自动触发构建与 Release**，不要额外 `gh workflow run`，也不要移动、删除或重打已有 tag。

## 4. 验证远端发布

- 使用 `gh run list --repo zhdgzs/voice-book --workflow build-apk.yml` 找到由本次 tag 推送产生、源码 SHA 匹配发布提交的运行；必要时等待 GitHub 生成记录。用 `gh run watch <run-id> --repo zhdgzs/voice-book --exit-status` 跟踪结束，确认 `build-full`、`build-lite`、`release` 均为 success。不得用其他分支的成功构建替代。
- 用 `gh release view vX.Y.Z --repo zhdgzs/voice-book --json isDraft,isPrerelease,assets,url` 确认 Release 已公开，且至少包含 `voice-book-arm32-full.apk`、`voice-book-arm64-full.apk`、`voice-book-arm32-lite.apk`、`voice-book-arm64-lite.apk` 四个可下载资产。必要时核对 tag 在远端指向 `main` 的发布提交。
- 只有全部满足后才报告发布完成，附版本、提交 SHA、Actions 运行链接和 Release 链接。构建/发布失败时说明失败步骤和日志，保留 tag 与已推送分支，调查修复方案并另行征求修复/重新发布授权；绝不称其发布成功。

## 原则

KISS/YAGNI：只处理版本字段和必要 git 操作，不加入额外发布脚本或本地构建。DRY：两个 flavor 共用同一版本和现有 Actions 工作流。SOLID：版本控制负责引用，Actions 负责构建发布，技能只负责核对与编排。
