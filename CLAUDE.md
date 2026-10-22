# 机甲指挥 · 项目说明书（CLAUDE.md）

> 2026-10-20 重写。**JS 时代那份说明书已原样归档**到 [`协作/归档/CLAUDE-JS时代.md`](协作/归档/CLAUDE-JS时代.md)
> （历史参考，别再往里加东西；里面「`CLAUDE.md` 第 N 节」的自引用一律指那份归档）。
> 本文件只留**现在有效**的东西：项目是什么、入口在哪、怎么协作、交付怎么算合格。

## 0. 冷启动（每个新会话先看这一节）

- **唯一正本**：仓库 `F:\DSH-mecha\mecha-autobattle`（作者主机 `desktop-ckhk2fd`，Windows）。claude.ai 项目里的文档只是参考副本，可能过期。
  `F:\DSH-mecha\mecha-tactics` 是**只读的旧仓库**，任何人都不在那里干活。
- **读的顺序**：本文件 → `协作/` 下最新的 `交接卡-日期.md` → `协作/开发路线图-v0.1.md`。其余按需再读，查代码先看 [`协作/代码地图.md`](协作/代码地图.md)。

| 谁、在哪 | 能做什么 | 怎么开工 |
|---|---|---|
| **Claude · 远程会话**（claude.ai / 手机，连着作者电脑） | 在作者电脑上只能读写文件；**在自己的云端容器里能跑命令**（Linux 版 Godot、git、node） | 申请访问仓库文件夹 → 读上面三份 → 按下面「云端迭代流程」干活。往作者电脑写文件后**必须读回比对**（偶尔会写入旧版本，不一致就再写一次） |
| **Claude · 主机**（桌面端 / Claude Code） | 能跑命令；有 MCP `deepseek-autobattle`（`ds_code` / `ds_test` / `ds_status`） | 读上面三份 → 按交接卡第 0 项开工；代码活优先用 `ds_code` 派出去 |
| **DS · DSH 里**（DeepSeek 智能体） | 能跑命令、改代码、提交 | DSH 的工作区要设在仓库根目录；它会自动加载本文件和 [`AGENTS.md`](AGENTS.md)。作者派活只需一句：「读 `协作/派单/<单子>.md`，照单做」 |

**派活队列（远程给 DS 派活的唯一正规通道）**
- 票放进 `F:\DSH-mecha\.tools\ds-mcp\queue\inbox\<日期-时间-单号>.json`，内容 `{"单": "协作/派单/<单子>.md", "说明": "可选"}`；结果看同目录 `queue\done\<同名>.结果.md`，进度看 `queue\status.json`。用法见 `F:\DSH-mecha\.tools\ds-mcp\README.md` 后半。
- 队列要作者在主机上启动（`启动派活队列.cmd`）；`status.json` 的 `updatedAt` 很旧就说明队列没在跑，提醒作者。
- **DSH 网页界面是作者自己的后门，任何 agent 都不走**（作者 10-21 定）。
- **DSH 的入口与模型分工**：网页界面的主模型是 ARGON，只有作者用；派活队列用 DS；需要世界知识时写「ARGON 问询单」交给作者转给 ARGON。详见 [`协作/DSH使用说明.md`](协作/DSH使用说明.md)。

**云端迭代流程（远程会话的标准做法，10-21 起）**
1. **同步**：云端克隆在 `/home/claude/fanboy3006/mecha-autobattle`（分支 `dev`），开工前先把作者电脑上比它新的文件同步进来。Godot 在 `/home/claude/tools/`（Web 导出模板也装好了），不在就重新下载 4.7.2。
2. **改代码、跑门禁**：都在云端做，包括全量测试、重录原生样例（附差异摘要）和 RouteMap `--check`。
3. **交付**：
   - 用 `git -c core.quotepath=false format-patch` 出补丁，和样例 json、`SHA256SUMS.txt`、回执一起写到作者电脑的 `.tmp/<批次>/`。
   - 写派活单，放一张队列票。DS 只做 git：`git apply --index` + `git mailinfo` + `git commit -F`（沙箱里 `git am` 不能用）。
4. **试玩包**：云端导出 Web 版，用新的 `index.pck` 覆盖 `F:\DSH-mecha\.tools\smoke\_site\godot\index.pck`。
5. **发布到 GitHub**：只推**单提交快照**。快照来自云端的 `publish` 分支，内容是本机最新的文件树，但不含 `协作/私密/`。推之前必须作者确认。`dev` 永远不推，因为它的基底含剧情。
6. **剧情保密**：剧情、设定、反派、台词只放 `协作/私密/`（本机私密仓库，无 remote）。公开数据里敌人一律用代号。

**工具位置**（都在主机上）
- Godot 4.7.2 控制台版：`godot` 不在 PATH 上时用 `F:\DSH-mecha\.tools\godot\Godot_v4.7.2-stable_win64_console.exe`
- DeepSeek MCP：`F:\DSH-mecha\.tools\ds-mcp\server.mjs`（说明见同目录 `README.md`，日志在同目录 `logs\`）；它调用的 Aider 在 `C:\Users\zxwu0\.aider312\Scripts\aider.exe`
- Claude 桌面端的 MCP 配置：**不在** `%APPDATA%\Claude`（那个目录不存在），要从 Claude 的 设置 → 开发者 → 编辑配置 打开真正的那份
- DSH 配置：`C:\Users\zxwu0\.dsh\`（全局指令文件是其中的 `AGENTS.md`）

**已知的坑**
- 跑仓库里的 `.ps1` 要用 `powershell -NoProfile -ExecutionPolicy Bypass -File <脚本>`，否则可能被执行策略拦下。
- 两种情况要先补跑 `godot --headless --path godot --import` 再跑测试：重新生成字体子集后（否则缺字检查一直红）；**新增 `class_name` 后**（否则报 `Identifier "…" not declared`，NAME-2a 踩到）。
- 新增或删除 `.gd` 后，RouteMap 会过期：先 `node godot/tools/build_godot_routemap.mjs` 重建，再跑 `--check`。
- 永远不要整份打开：`godot/tests/golden/` 下的大 JSON、`协作/架构/Godot-AST依赖清单.json`、`Godot-RouteMap-明细.md`。

## 1. 项目是什么

机甲题材的单机肉鸽卡牌战棋：一局从选分队开始，走分层地图、打节点战斗；战斗里双方按速度出手，
玩家用手牌（单机牌组）出招，角色按「势力 / 职业」各有特色与卡池。
**方向与取舍由作者定；架构、规则、数值与验收由 Claude 负责；代码尽量派给 DeepSeek 写。**

## 2. 唯一的游戏引擎是 `godot/`

- **`godot/` 是唯一长期维护的引擎**（Godot 4.7.2 · 纯 GDScript · 可导出 Web）。
- 仓库根目录的 JS 版（`src/`、`index.html`、`tools/`、`tests/`）是**冻结的玩法参考**（tag `js-reference-final`），
  只读、只用来查旧行为和对拍；**新功能一律加在 `godot/` 里**。

## 3. 目录与入口

| 想去哪 | 入口 |
|---|---|
| 引擎怎么跑 / 目录分工 / 注释与体积约定 / 常用命令 / 发布 | [`godot/README.md`](godot/README.md) |
| 接下来做什么（路线图与优先级） | [`协作/开发路线图-v0.1.md`](协作/开发路线图-v0.1.md) |
| 设计稿（规则、势力 / 职业卡牌、卡牌流转、武器范围…） | [`协作/设计/`](协作/设计) |
| 架构文档与施工单 | [`协作/架构/`](协作/架构) |
| 回执（每单的验收证据） | `协作/架构/RT回执/` · `BR回执/` · `COL回执/`（一单一目录） |
| 代码地图（一页速查，人工维护） | [`协作/代码地图.md`](协作/代码地图.md) |
| 代码结构明细（自动生成，别手改） | [`协作/架构/Godot-RouteMap.md`](协作/架构/Godot-RouteMap.md) |
| 派活卡 / 交接卡模板 | [`协作/模板/`](协作/模板) |
| 设计约定（三层反馈、职业分工、文案与版权…） | [`协作/设计/设计约定.md`](协作/设计/设计约定.md) |

## 4. 协作分工

| 角色 | 负责 |
|---|---|
| **作者** | 定方向、试玩、拍板；「继续 / 停」由作者说 |
| **Claude** | **主开发框架**：架构设计、规则与数值、写规格和派活卡、验收（闸门签字）、疑难问题；DeepSeek 不可用时直接写代码 |
| **DeepSeek**（经 MCP `deepseek-autobattle`：`ds_code` / `ds_test` / `ds_status`） | 照派活卡改代码并提交，工具自动跑测试与 RouteMap 检查；**不做设计判断** |
| **ARGON**（DSH 网页主模型 `gemini-4-argon`） | 创意与世界观灵感 + **世界知识问询**：原作考据、改名查重、设定一致性、真实科技参考，用法见 [`协作/DSH使用说明.md`](协作/DSH使用说明.md) §三～四。**已退出架构岗**，不再写施工单 / 架构文档；涉及剧情的产出一律写进 `协作/私密/` |

- **省 token**：验收先看提交统计、测试摘要和样例差异摘要，出问题才读代码；该交接时 Claude 主动提醒作者换会话，交接卡按 [`协作/模板/交接卡.md`](协作/模板/交接卡.md) 写。
- **Claude 和 DeepSeek 不同时改 `godot/core/`**（作者 10-21 定）：派给 DeepSeek 的活改到 `core/` 时，活没回来之前 Claude 不碰 `core/`；其它目录至少不同时改同一个文件。

- **这三类必须停下来问，不要自己拍板**：设计稿互相矛盾 · 需要上调任何棘轮 · 样例差异超出预期。
- 需要别人改的，写进文档注明「给谁」，不要动别人的地盘。

## 5. 施工单与回执规矩

1. **一个 Batch 一个提交**，提交信息以 `[单号-x]` 开头（如 `[BR-1-b]`、`[COL-2]`）；文档类用 `[docs]`。
2. **回执写小文件**（DeepSeek 做的活，由 Claude 根据 `ds_code` 返回的摘要写）：`协作/架构/<单号>回执/<Batch>.md`，一单一文件、≤ 40 行，只写结论；
   命令输出写进文件，回执里只留结论行，**不列 sha 清单**。
3. **门禁**（每个 Batch 都要过）：全量 `godot/tests/run_tests.gd` 全绿 +
   `node godot/tools/build_godot_routemap.mjs --check` EXIT=0。
4. **改战斗结果的 Batch 只重录一次**原生样例，并附差异摘要；差异要能解释（应集中在相关势力 / 机制覆盖的场次）。
5. **一次只改一个文件**，改完先跑相关测试；**不做跨行批量替换**（用「精确字符串替换 + 先断言目标存在」）。
6. **规则先写进文档、再改代码**；文档与代码不一致时以作者最新决定为准，并同步修正文档。
7. **不许编造**：没实现的功能不写成已完成，没跑过的命令不写成「已通过」。

> 旧 CLAUDE.md 的 JS 时代内容（`src/js/*` 文件表、M0–M6 里程碑、二十一套 Node 测试、第 N 节跳转表）
> **一律不搬**；要查历史看归档那一份。
