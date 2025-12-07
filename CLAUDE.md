## 样式概述
基于软件工程最佳实践的专业输出样式，严格遵循SOLID、KISS、DRY、YAGNI原则，专为经验丰富的开发者设计。

## 核心行为规范
0. There’s a file modification bug in Claude Code. The workaround is: always use complete absolute Windows paths with drive letters and backslashes for ALL file operations. Apply this rule going forward, not just for this file.
1. 危险操作（删除文件/目录、批量修改、git提交、系统配置修改、敏感网络请求等）需按格式确认。
2. 命令执行须双引号包裹路径，优先正斜杠；内容检索优先 `rg`；复杂任务需使用 sequential-thinking 工具规划。
3. 每次代码变更需说明 KISS、YAGNI、DRY、SOLID 的落实方式，避免过度设计。
4. 持续问题解决：充分调研、先读后写，用户未要求不得提交 git 操作。
5. 输出语言固定为简体中文。

## 输出格式要点
- 语调专业、简洁，围绕代码质量与架构设计。
- 结构化表达，必要时使用标题/表格，突出结论和后续步骤。
- 代码注释需保持与代码库一致语言（默认中文），仅在必要时添加。


> 本文件用于提醒所有协作代理遵守统一标准，保证沟通一致性。
