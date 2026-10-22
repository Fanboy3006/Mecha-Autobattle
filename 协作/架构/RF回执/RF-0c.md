# RF-0c 回执：秘银「阵型调整」改走正规换位

> 执行者 DSH 里的 DeepSeek，2026-10-21。派活卡：`协作/派单/RF-0c-秘银阵型调整走正规换位.md`。

## 改了什么
- `godot/core/battle/mithril_v03_cards.gd`：`_阵型调整` 里手工对调 `slot` 的 3 行替换为
  `BattleSwap.换位(ctx, "ally", a.get("slot"), b.get("slot"), {"来源": "阵型调整"}) != 2 → ["换位没有成功"]`。
  选谁不变（仍是 `Units.livingOf("ally", ctx)` 前两台）；不传 `isShadowCard`（不记【移位】、不挂〔错位〕）；
  其后的命中 −10 增益、`_记`、`return` 一字未动。
- `godot/tests/unit/test_rf0_fixes.gd`：`run` 追加 `_段_0c(t)`（7 项断言）：slot 互换、战报
  `类型 == "换位"` / `来源 == "阵型调整"`、两台都有「阵型调整」增益（hit −10）、两台都无 `BattleSwap.错位键`、
  只剩 1 台存活返回 `["只有一台机体，换不了位"]` 且 slot 不变。沙盒用 `Setup.开局` + 秘银单机牌组，U7/U6 两位。
- 机械重生成（非手改）：`Godot-RouteMap.md` / `Godot-RouteMap-明细.md` / `Godot-AST依赖清单.json`。
  源码行数/字节变了，按 CLAUDE.md 门禁必须重建；单子写「只改 2 个文件」，与门禁冲突，按 CLAUDE.md 为准，
  属**列外文件，请验收确认**。

## 门禁
- 单子原命令 `--only=test_rf0_fixes,test_mithril,test_swap`：**EXIT=1**，`test_mithril_v03` 69 项红。
  原因与 RF-0b 回执记的既有测试隔离缺陷相同：该文件自己不装数据，`--only` 按文件名排序后排在 `test_rf0_fixes`
  之前 → `Db` 为空；**与本单改动无关**（其 224 项在装过数据后全绿）。
- 等价验证（`test_armor_pool` 先装数据）：`--only=test_armor_pool,test_rf0_fixes,test_mithril,test_swap`
  → **307 项全绿**（armor_pool 15 / mithril 224 / rf0 17 / swap 51），EXIT=0。
- `node godot/tools/build_godot_routemap.mjs --check`：**EXIT=0**，三份逐字节一致，索引页 7813 token < 8000。
- 按单**未跑全量、未重录原生样例**（留给 RF-0d）。

## 耗时
- 约 12 分钟（3 轮目标测试 + RouteMap 重建/复查）。

## 下一步从哪开始
- RF-0d：统一重录原生样例 + 全量门禁。
- 建议 Claude 顺手修测试隔离：给 `test_mithril_v03.gd` 的 `run` 首行补 `DataLoader.install`，
  或把派活单验收命令改成带 `test_armor_pool` 前缀的版本（RF-0b 已提过同一问题）。

## 意外改动
- 工作区原有未提交改动（`协作/剧情/*`、`协作/设定/*`、`协作/设计/肉鸽构筑规则 v0.1.md` 等）与大量
  未跟踪 `.gd.uid` 均未触碰、未提交。
