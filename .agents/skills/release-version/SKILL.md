---
name: release-version
description: 从 main 发布 Voice Book 新版本。检查工作区、递增版本号、提交并推送 main、推送 v* tag，由 GitHub Actions 构建 APK 并创建 Release。
compatibility: Requires git, gh CLI with access to zhdgzs/voice-book, and network access. Run from the voiceBook repository root.
---

# 发布版本

仅在用户明确要求执行发布时运行；修改或读取本技能不等于执行发布。遵守 `AGENTS.md`：不在本地编译、运行测试或新增测试文件。无需逐步征求确认。

1. **先检查工作区**：执行 `git status --porcelain --untracked-files=all`。只要有任何未提交的修改或未跟踪文件，立即停止，不暂存、不清理、不发布。确认当前分支是 `main`，`origin` 指向 `zhdgzs/voice-book`。
2. **确定版本**：读取 `pubspec.yaml` 和 `pubspec_lite.yaml`，要求 `version` 相同且格式为 `MAJOR.MINOR.PATCH+BUILD`。若用户指定新版本，使用该版本；否则补丁版本加 1、build number 加 1（例如 `1.0.2+3` → `1.0.3+4`）。新版本必须高于旧版本，build number 必须递增。目标 tag 为 `vMAJOR.MINOR.PATCH`。
3. **核对远端**：`git fetch origin main --tags`，要求本地 `main` 与 `origin/main` 一致，目标 tag 在本地和远端都不存在，且现有 `.github/workflows/build-apk.yml` 仍由 `v*` tag 推送触发并创建 Release。有任何不一致或失败就停止，不强推、不覆盖 tag。获取远端引用后再次确认工作区干净。
4. **提交并推送**：只把两个 pubspec 的 `version:` 改为目标版本；只暂存这两个文件，检查 `git diff --cached --check` 和暂存差异只含预期版本变更。创建提交 `chore(release): 发布 vX.Y.Z`，执行 `git push origin main`。推送失败立即停止，不推 tag。
5. **打 tag 发布**：在刚推送的提交上创建附注 tag：`git tag -a vX.Y.Z -m "Release vX.Y.Z"`；确认 tag 指向该提交，再执行 `git push origin vX.Y.Z`。tag 推送自动触发 GitHub Actions 构建 Full/Lite APK 并创建公开 Release，不手动触发工作流或调用 `gh release create`。
6. **确认结果**：通过 `gh run list` / `gh run watch` 确认本次 tag 的构建与发布任务成功，并通过 `gh release view vX.Y.Z` 确认 Release 已公开且包含四个 APK。成功后报告版本、提交和 Release 链接；失败则报告已完成的推送和失败环节，不删除或重打 tag，也不声称发布成功。
