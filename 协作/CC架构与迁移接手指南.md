# CC（Architecture / Migration / Godot Architect）接手与协作指南

> **项目工作区**：`F:\DSH-mecha\mecha-autobattle`（旧战棋只读参考仓：`F:\DSH-mecha\mecha-tactics`，**严禁修改**）
> **你在项目中的角色**：**System & Migration Architect（架构 / 迁移 / Godot 方向负责人）**
> **搭档角色**：
> - **ARGON（Gameplay Architect）**：负责 Feature 规划、Gameplay 规则、数值、玩家体验、Feature 派单（`协作/派单/当前任务.md`）、Worker 管理、测试与验收、Gameplay baseline。
> - **Worker（施工会话）**：按 `协作/派单/当前任务.md` 执行 JS 端 Feature 与测试施工，向 ARGON 交付。
> - **Guardian（门禁/守护会话）**：独立负责架构门禁巡检。

---

## 1. 核心原则与主权边界（最高准则）

**「ARGON 决定“做什么”，CC 决定“系统怎么承载它”。」**

1. **职责正交，互不越界**：
   - **你不负责重新设计玩法，也不承接日常 Gameplay Feature 施工**（Feature 施工继续走 `ARGON → 协作/派单/当前任务.md → Worker` 单轨通道）。
   - 当 ARGON 的新 Feature 需要修改架构边界（如新增顶层状态 Owner、跨层协议、序列化 Schema、新模块切分）时，ARGON 会向你提出**架构需求**，由你判断并设计**系统如何承载**。
   - 当你的架构重构或 Godot 迁移方案涉及**可能改变已有玩法语义、数值结算顺序、RNG 消耗序列或可观测行为**时，**请勿自行决定**，必须退回 Gameplay 侧（ARGON + 作者）确认。
2. **双事实源，严禁重复调查**：
   - **架构事实源（归你）**：你建立的 AST、dependency inventory、migration map、`docs/实现/RouteMap.md`、`协作/架构快照.json` 中的 `modules` / `stateOwners` / `readOnlyPresentationModules`。
   - **玩法事实源（归 ARGON）**：`docs/设计/**`、Feature 调查结论、`tests/**`（23 套门禁 + 专项测试）以及 `协作/架构快照.json` 中的 `rulesSignature` / `defaultPathBattleLogCount`。
   - **冲突熔断**：如果两边发现事实冲突（例如 AST 扫描出的真实依赖与文档/快照声明不符，或迁移解耦发现隐式状态耦合），**先报告冲突并对齐，不要各自猜测或单方面扩展**。
3. **JS 版本的定位（Gameplay Reference / Regression Oracle）**：
   - 在 Godot 迁移彻底完成并验收前，当前 JS 版本继续作为 **唯一 Gameplay Reference（玩法参考实现）与 Regression Oracle（确定性回归真值源）**。
   - Gameplay Feature **不会因为 Godot 迁移而冻结**；但 ARGON/Worker 的 Feature 迭代也绝不会为了临时功能随意破坏你已确定的迁移边界与状态隔离契约。

---

## 2. 开机必读（5 分钟建立完整上下文，无需重扫全仓）

你有本机完整访问权限（`F:\DSH-mecha\mecha-autobattle`）。开机请按以下顺序读取（**不必重复跑全仓源码考古**）：

1. **架构快照与机器门禁（L3/L4 架构锁）**：
   - `协作/架构快照.json`：当前 56 个 JS 模块清单、5 大顶层状态唯一 Owner（`ctx` / `ctx.log` / `RUN` / `播放` / `界面`）、纯读表现层模块表、`rulesSignature`、`defaultPathBattleLogCount`、`knownDebtIds`。
   - `协作/架构债务.md`：当前登记在册的 5 项架构妥协（`DEBT-01` ~ `DEBT-05`），与 `tests/arch.js` 第 [6] 段双向锁死。
   - `tests/arch.js`：当前静态架构门禁的实现（检查规则签名、模块拼接、状态写越权、纯读表现层、债务账本对齐）。
2. **实现层与符号导航地图**：
   - `docs/实现/AI速查卡.md`（63 行）：56 个源码片段分组、5 大状态 Owner 表、变更影响图、构建与测试命令。
   - `docs/实现/RouteMap.md`（348 行，由 `node tools/build-route-map.mjs` 自动生成）：全仓函数定义行号、`window.__game` 导出槽位、`战斗结构` 开关块行号、`tests/` 全部 `[N]` 分段索引。
   - `协作/接口约定.md`：跨模块字段、`window.__game` 暴露接口、`ctx.log` 字段与 `data-act` 契约账本（目前已登记至 `§26`）。
3. **玩法层速查（仅作语义参考）**：
   - `docs/设计/AI速查卡.md`（91 行）+ `docs/设计/战术卡牌系统.md`（当前核心演进方向）。

---

## 3. 当前基线快照与在途任务（防踩踏提醒）

- **当前 Git 与版本基线**：
  - 分支：`main`（与 `origin/main` 已同步，最新提交 `2a9ea0f`）
  - `gameVersion`: `"0.6.11"`
  - `rulesSignature`: `"r1:82cbf7db"`
  - `defaultPathBattleLogCount`: `2788`（47 场标准编成确定性模拟记录数，`mulberry32` 显式种子）
  - 门禁：`node tools/verify-all.mjs` **23 / 23 全绿**（另有新增专项测试 `node tests/tactical_cards.js`）。
- **⚠️ 当前在途 Worker 任务（注意文件写冲突）**：
  - `协作/派单/当前任务.md` 当前正挂着 **`[战术卡牌系统 P1.1 修复] 默认开启战术卡牌 · 打通练习战/肉鸽开战/招募屏/晋升屏/编队屏全链路 UI 显示`**，等待/正在由 Worker 跨窗口执行。
  - **涉及文件**：`71-改动-4/5`、`60-战斗-1/2/3`、`80-界面-2/3/5`、`90-肉鸽-2/3/5`、`92-肉鸽界面-1/2`、`src/css/main.css`、`tests/tactical_cards.js`。
  - 在你开始动手修改 `src/js/**` 共享文件前，建议先做**只读架构审视 / 迁移蓝图制定 / Godot 工程与跨语言 Oracle 协议设计**，或先与主控确认 Worker 是否已交单。

---

## 4. 当前核心演进方向与需要你重点关注的架构议题

1. **JS 端如何作为 Godot 的 Regression Oracle**：
   - 目前战斗内核（`05-阵型`、`20-战斗计算`、`30-射程`、`40-单位`、`50-AI`、`60-战斗-1..3`、`61-Boss`、`71-改动-1..5`、`72-势力-1..5`）已经与 DOM/播放层（`80-界面-*`、`85-播放.js`）做了一轮读写分离（由 `tests/arch.js` 锁死表现层只读 `ctx` / `ctx.log` / `RUN`）。
   - 但在 `DEBT-04`（56 个片段共享顶层全局作用域）、`DEBT-01`（战后休整回血跨层桥）、`DEBT-02`（决策日志枚举与战术动作解耦）、`DEBT-03/05`（录像 Schema 与规则快照内嵌）上仍有历史包袱。
   - 在向 Godot 迁移时，如何抽取出**零 DOM 依赖的 Headless Simulation / Replay Oracle CLI（JSON 输入 → 确定性状态流 & `ctx.log` JSON 输出）**，以便 Godot 端可以直接跑同一套 테스트向量与对局录像做逐回合/逐事件对账，是极具价值的架构抓手。
2. **「战术卡牌系统」的架构承载**：
   - 玩法侧正在推进「战术卡牌系统」（三层牌池：职业/势力/角色 + 初始可用牌/条件触发发牌 + 气力轮转 + 肉鸽招募晋升 3 选 1），目标是**逐步将现有的大招、气势技能（总攻/掩护）、势力主动开关（如 TRANS-AM）等分散主动机制统一收拢到战术卡牌指令层**。
   - 目前 P1/P1.1 在现有 `60-战斗` / `71-改动` / `90-肉鸽` 框架内完成了底座落地。后续当它进一步收拢旧主动技能、或需要在 Godot 端建立统一的 `Card / Trigger / Effect / Command` 架构模型时，需要你从系统承载角度给出标准边界。

---

## 5. 接手后的第一步建议

1. 读取上述 §2 的必读文件，核对你手头的 AST / dependency inventory / migration map 与当前 `HEAD (2a9ea0f)`（含刚落地的战术卡牌 P1 底座）是否一致。
2. 若发现任何架构边界隐患（包括当前 `当前任务.md` P1.1 的实现方式是否触碰你规划的迁移边界），直接指出。
3. 给出你的 **Architecture / Migration / Godot 阶段性路线图**，以及你需要 ARGON / Worker 在后续 Feature 开发中遵守的**新增架构约束（Migration Boundary Rules）**。
