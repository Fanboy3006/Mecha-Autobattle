# NAME-0 回执：字体缺字修复（回旋镖）

一、改动
- `godot/data/cards/殖民卫星军.json`：`COL_W2_W3` 的 `名` 由「破坏者盾·回旋」改回**「破坏者盾·回旋镖」**（1 行；`core/` `session/` `presentation/` `tests/` 里没有硬编码这个牌名的 .gd）。
- 字体子集：作者本机重跑 `python godot/tools/build_font_subset.py` 后，`NotoSansSC-Subset.otf` / `ui_font.tres` 已更新（随本提交入库）。
  ★ 踩到一个坑：只换 .otf 不够 —— `ui_font.tres` 读的是 `.godot/imported/` 里的旧导入产物，缺字会一直红；
  补跑 `godot --headless --path godot --import`（8.9 秒）刷新导入缓存后才转绿。以后谁重生成字体都要带这一步。

二、样例重录（按 Claude 拍板的 A 方案）
- 只重录、不改其它：`colonial.json` / `faction_殖民卫星军.json` / `relic.json` 三个文件有差异，其余 9 个样例文件**逐字节不变**。
- 逐条核对（脚本把旧 HEAD 版与新录版做深比对）：**14 场 · 42 处叶子差异**，全部落在 `.事件[N].武器` 这一个字段，
  且值恰好是 `破坏者盾·回旋` → `破坏者盾·回旋镖`；**没有一个数字 / 判定 / rng 步数 / 其它字段变化**。
  - colonial 3 场 14 处 · faction_殖民卫星军 10 场 26 处 · relic 1 场 2 处（`g3-限制器解除负装甲`）。

三、门禁：`test_font_coverage` **1532 个字全部有字形** ✓；全量 `run_tests.gd` **3676 项全绿**；
`build_godot_routemap.mjs --check` **EXIT=0 / violations []**；原生样例 180 场逐场一致。

四、耗时：全量测试 **5.1 分钟**、录样例 **3.5 分钟**。

五、下一步从哪开始：NAME-1 盘点（只查不改）—— 扫 `core/ session/ presentation/` 的字符串字面量与 `data/` 的 JSON 字段，
分「内部 id / 玩家可见」，盘完停下等 Claude 确认分类方案。
