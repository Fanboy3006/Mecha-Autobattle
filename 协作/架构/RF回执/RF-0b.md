# RF-0b 回执：秘银「回血比」回复量取整

> 执行者 DSH 里的 DeepSeek，2026-10-21。派活卡：`协作/派单/RF-0b-秘银回血比取整.md`。

## 改了什么
- `godot/core/battle/mithril_v03_cards.gd`：`"回血比"` 分支只改 4 行 —— 新增 `上限` / `量`
  （`量 = J.round(maxHp × 比)`），`hp = minf(上限, 前 + 量)`；`回 = …` / `_记` / `return` 一字未动。
- `godot/tests/unit/test_rf0_fixes.gd`：`run` 追加 `_段_0b(t)`（4 项断言）。沙盒用 `Setup.开局` +
  `{"单机牌组": true, "秘银v03": true}`，U7 设 `maxHp 1001 / hp 500`，目标走 `ctx["_当前目标"]`（单位 key）。
- 机械重生成（非手改）：`Godot-RouteMap.md` / `Godot-RouteMap-明细.md` / `Godot-AST依赖清单.json`。
  `.gd` 行数 / 字节 / 函数数变了，按 AGENTS 门禁必须重建；属列外文件，请验收确认。

## 门禁
- `--only=test_rf0_fixes`：1 个文件 **10 项全绿**，EXIT=0。
- 单子原命令 `--only=test_rf0_fixes,test_mithril`：**EXIT=1，71 项红后脚本中断**（与 0b 改动无关）：
  `test_mithril_v03.gd` 自己不装数据（依赖同进程先跑的测试 `DataLoader.install`），而 `--only` 按文件名排序后
  它排在 `test_rf0_fixes` **之前** → `Db` 为空，`Setup.开局` 在 `setup.gd:227` 报缺 `战术卡牌表`。属既有测试隔离缺陷。
- 等价验证（把装数据的测试排在前面）：`--only=test_armor_pool,test_rf0_fixes,test_mithril` →
  **249 项全绿**（armor_pool 15 / mithril 224 / rf0 10），EXIT=0。
- `node godot/tools/build_godot_routemap.mjs --check`：**EXIT=0**，三份逐字节一致，索引页 7813 token < 8000。
- 按单**未跑全量、未重录原生样例**（留给 RF-0d）。

## 耗时
- 约 10 分钟（3 轮目标测试 + 1 次 RouteMap 重建）。

## 下一步从哪开始
- RF-0c（同文件 `_阵型调整`）/ RF-0d（统一重录样例与全量门禁）。
- 建议 Claude 顺手修测试隔离：给 `test_mithril_v03.gd` 的 `run` 首行补 `DataLoader.install`，
  或把派活单的验收命令改成 `--only=test_armor_pool,test_rf0_fixes,test_mithril`。
