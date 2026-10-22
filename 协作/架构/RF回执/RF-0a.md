# RF-0a 回执：殖民卫星军主武器门槛返回终局，门槛生效

> 执行者 DSH 里的 DeepSeek，2026-10-21。派活卡：`协作/派单/RF-0a-殖民卫星军主武器门槛.md`。

## 改了什么
- `godot/core/battle/colonial_v01.gd`：只改 `区规则门槛`（函数体 + 签名 `_区` → `区`，共 7 行，派活卡给的原文）。
  非主武器区 / 非本势力牌 → `终局: false`；能打 → `终局: false`（不「接手」，后面的战意 / 销毁 / 合体技检查照常）；
  不能打 → `终局: true, 接手: true, 原因: 因`。上方 `##` 注释与 `副武器门槛` 未动。
- `godot/tests/unit/test_rf0_fixes.gd`（新建）：6 项断言。主武器卡取殖民卫星军卡包 `COL_S1_W1`「光束军刀」
  （耗气 5，战意费用 > 0）：(a) `本回合不能打武器` → 「本回合不能打武器牌（潜入准备）」；(b) 战意 4 → 「战意不足」；
  (c) 战意 5 → `""`；(d) 筹码区调 `区规则门槛` → `终局 == false`；外加「取到卡且费用 > 0」一条。
  沙盒工具按 `test_colonial_v01.gd` 的 `_场 / _单位 / _牌 / _手牌` 复制，函数名加 `_c` 前缀（`_c场 / _c单位 / _c靶 / _c主武器卡`）。
- 机械重生成（非手改）：`协作/架构/Godot-RouteMap.md`、`Godot-RouteMap-明细.md`、`Godot-AST依赖清单.json`。
  原因：本单新增 `.gd`，仓库规矩要求重建 RouteMap 才让 `--check` 绿；三个文件只反映新测试文件的条目与行数位移。
  新测试文件注释占比 18.7%（< 测试层 20% 阈值），规则⑧「未登记且超阈值」仍为 73 个，未新增警告。

## 门禁
- `--only=test_rf0_fixes,test_colonial`：4 个文件 **179 项全绿**（`test_rf0_fixes` 6 / `test_colonial_v01` 88 /
  `test_colonial_units` 51 / `test_colonial_presentation` 34），退出码 0。
- 按派活卡**未跑全量**、**未重录原生样例**（`test_native_goldens` 预期红，留给 RF-0d）。
- `node godot/tools/build_godot_routemap.mjs` 重建 → `--check` **EXIT=0**（三份生成物逐字节一致）。

## 过程记录
- 首版测试文件注释占比 24.8%，把规则⑧未登记超阈值从 73 顶到 74；已压到 18.7% 后重建，恢复 73。
- 本机 `godot` 不在 PATH，用 `F:\DSH-mecha\.tools\godot\Godot_v4.7.2-stable_win64_console.exe`（4.7.2）。
  运行期 stderr 有 `user://logs` 建目录失败 / 根证书读取失败，与测试结果无关。

## 耗时
- 约 20 分钟（含两次 RouteMap 重建、两轮目标测试）。

## 下一步从哪开始
- RF-0b：照 `重构规格-RF-v0.1.md` §三 RF-0 继续，往 `test_rf0_fixes.gd` 追加断言（用 `_c` 前缀辅助）。
- RF-0d 统一重录原生样例（0a 改了刷牌结果，样例差异应只落在殖民卫星军相关场次）。
