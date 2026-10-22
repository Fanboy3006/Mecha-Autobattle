# AGENTS.md · 给 DSH 里的 DeepSeek（执行者须知）

> DSH 会自动加载本文件和同目录的 `CLAUDE.md`。`CLAUDE.md` 讲项目全貌和协作规矩，本文件只讲**你（DS）怎么干活**。两者冲突时以 `CLAUDE.md` 为准，并在报告里指出冲突。

## 你是谁
- 你是**执行者**：照派活单写代码、跑测试、提交、写回执。**不做设计判断**；规则或数值的取舍归 Claude，方向归作者。
- 派活单在 `协作/派单/`。作者通常只说一句「读 `协作/派单/<单子>.md`，照单做」，单子里写明了要改的文件、具体改法、验收办法和停点。

## 先定位（每次开工）
1. 确认当前目录是仓库根目录 `F:\DSH-mecha\mecha-autobattle`，不是就先切过去。**不要在 `F:\DSH-mecha\mecha-tactics`（只读旧仓库）里做任何事。**
2. 跑 `git status --short`，把输出记下来。不属于本单的改动不要碰，提交时也不要带上，在报告里列出来。
3. Godot：先试 `godot --version`；不在 PATH 上就用 `F:\DSH-mecha\.tools\godot\Godot_v4.7.2-stable_win64_console.exe`。

## 常用命令（都在仓库根执行）
```
godot --headless --path godot --script res://tests/run_tests.gd                      # 全量测试，约 5 分钟，退出码 0 = 全绿
godot --headless --path godot --script res://tests/run_tests.gd -- --only=test_swap  # 只跑文件名含这些片段的测试，逗号分隔
node godot/tools/build_godot_routemap.mjs                                            # 重建 RouteMap（增删 .gd 后必做）
node godot/tools/build_godot_routemap.mjs --check                                    # 门禁：要 EXIT=0
godot --headless --path godot --script res://tools/record_native_golden.gd           # 重录原生样例（只在单子写明时才跑）
powershell -NoProfile -ExecutionPolicy Bypass -File "<脚本.ps1>"                       # 跑仓库里的 PowerShell 脚本
```
- **新增 `class_name` 或重新生成字体后**，先跑 `godot --headless --path godot --import`，再跑测试。

## 规矩（细则见 `CLAUDE.md` §5 和 `godot/README.md`）
- **一个 Batch 一个提交**，提交信息以 `[单号]` 开头；文档类用 `[docs]`。
- **门禁**：全量测试全绿 + `--check` EXIT=0。没跑过的不写成「已通过」。
- **一次只改一个文件**，改完先跑相关测试；用「精确字符串替换 + 先确认目标存在」，不做跨行批量替换。
- **只改单子里列的文件**。不改数值、战报文案（除非单子写明）。
- 不许在 `calc.gd` / `btl.gd` / `flow.gd` / `card_play.gd` 里点名势力模块；不许删、不许挪 `.gd` 文件首行的 `##` 职责注释。
- 不写来源 / 日期标签和「从前……现在……」式注释；历史写在提交记录里。
- 永远不要整份打开：`godot/tests/golden/` 下的大 JSON、`协作/架构/Godot-AST依赖清单.json`、`协作/架构/Godot-RouteMap-明细.md`。

## 必须停下报告、不要自己拍板
- 设计稿互相矛盾，或单子没写清、要你做取舍。
- 需要上调任何棘轮（`SIZE_RATCHET`、`COMMENT_RATCHET`、`CORE_TO_FACTION_RATCHET_MAX`）。
- 原生样例出现单子没预期的差异。
- 测试红了，而且原因不在本单改动范围内。
- 同一个问题修了两次还不过。

## 回执与报告
- 回执写 `协作/架构/<单号>回执/<Batch>.md`，≤ 40 行，只写结论：改了哪些文件、测试项数、`--check` 结果、样例差异摘要、耗时、「下一步从哪开始」。不列 sha 清单；长输出写进日志文件，回执里只引用路径。
- 做完给作者一份短报告（作者会转给 Claude 验收）：每个 Batch 一行（提交号 + 结论，或停在哪、为什么），再加一行「意外改动：无 / 列表」。
