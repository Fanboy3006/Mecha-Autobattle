# 机甲指挥 · Godot 版

本项目**唯一长期维护的游戏引擎**。仓库根目录的 JS 版是冻结的玩法参考（tag `js-reference-final`），迁移完成后移到 `archive/js/`。
架构与迁移计划：[`../协作/架构/Godot迁移架构-v1.md`](../协作/架构/Godot迁移架构-v1.md)

当前进度：**M0 地基** ✅ · **M1 数据与样例** ✅（`data/js/` 121 个常量 · **168 场**战斗黄金样例）· **M2 Battle Core** ✅（`core/battle/`：**168/168** 场与 JS 参考版逐条一致；正式规则与 JS 的差异见 [`tests/golden/已接受差异表.md`](tests/golden/已接受差异表.md)）· **M3-Prep** ✅（藏品开战注入 = `core/battle/relic_battle.gd`（DEBT-06：不读全局 `肉鸽.RUN`，由 `Setup.开局(..., 选项.藏品)` 传入）· 局外黄金样例 [`tests/golden/run_vectors.json`](tests/golden/run_vectors.json)：8 种子 × 4 层地图 / 推进剂 / 招募券 / 晋升面板 / 三选一）· 下一步 **M3 肉鸽内核**。

## 本地开发

- 用 **Godot 4.7.2** 打开 `godot/project.godot`（渲染器：Compatibility，Web 只支持 WebGL 2）。
- 只用 **GDScript**：Godot 4 的 C# 项目不能导出到 Web。

```
godot --headless --path godot --import
godot --headless --path godot --script res://tests/run_tests.gd     # 退出码 0 = 全绿
```

## 目录

| 目录 | 内容 | 规矩 |
|---|---|---|
| `core/` | 纯逻辑（战斗 / 肉鸽内核、随机数、规则） | 只继承 `RefCounted` / `Resource`；不碰场景树、文件、时间、引擎随机数；四舍五入用 `J.round`（= `JsCompat.js_round`），排序用 `J.sort`（= `JsCompat.stable_sort`）；与 JS 语义不同的地方（真假值、`||`、数字转字符串、`includes`…）一律走 `core/util/js.gd` 的 `J`。`tests/unit/test_boundary.gd` 自动检查 |
| `core/battle/` | 战斗内核，一个文件对应 JS 的一个片段：`setup`（开局 / 一回合 / 胜负）· `flow`（回合开始 / 行动 / 结算）· `btl`（记录 / 气势 / 嘲讽 / 自爆 / 词条 / 战术牌）· `calc`（命中 / 伤害 / 标定）· `ai` · `boss` · `fac*`（六个势力）· `params` · `units` · `traits` · `reach` · `fm` · `diff` · `relic_battle`（藏品开战注入，93-藏品.js） | 入口：`Setup.开局()` → 每回合 `Btl.打战术牌()`… → `Setup.打一回合()`；单位与 ctx 是 Dictionary，键名照 JS；藏品 id 从 `选项.藏品` 进来（DEBT-06，不读全局 `肉鸽.RUN`） |
| `data/js/` | 内容与数值（从 JS 参考版导出，`manifest.json` 记来源与规则签名）；由 `session/data_loader.gd` 读入成 `GameData` | 内核只读；小数要能被 Godot 无损解析（`test_data` 检查） |
| `session/` | 会话层：读数据、存档、命令分发（IO 只在这里） | |
| `presentation/` | 场景与界面 | 只读内核状态；玩家操作变成命令交给内核 |
| `assets/fonts/` | `ui_font.tres` = 中文主字体子集 + emoji / 符号后备（全部 SIL OFL 1.1，许可证在同目录） | 缺字时 `test_font_coverage` 报红 → 运行下面的字体命令 |
| `tests/` | `run_tests.gd` 自动发现 `tests/unit/test_*.gd`；`golden/` 放从 JS 导出的对拍数据（格式见 `tests/golden/README.md`） | golden 文件**不存 JSON 小数**（Godot 解析会丢精度）：随机数存 uint32，浮点存 IEEE-754 位串 |
| `tools/` | CI 安装脚本、字体子集、JS 向量导出、浏览器冒烟 | 不打进游戏包 |

## 常用命令

```
python godot/tools/build_font_subset.py                                    # 重新生成中文字体子集（需要 pip install fonttools）
node godot/tools/gen_rng_vectors.mjs . godot/tests/golden/rng_vectors.json # 从 JS 参考版导出 RNG 对拍向量
node godot/tools/export_data.mjs                                           # 从 JS 参考版导出 data/js/（会校验规则签名与 js-reference-final）
node godot/tools/export_golden.mjs                                         # 从 JS 参考版导出战斗黄金样例（含 2788 自检）
node godot/tools/export_run_golden.mjs                                     # 从 JS 参考版导出局外黄金样例 → tests/golden/run_vectors.json
mkdir -p godot/build/web && touch godot/build/.gdignore
godot --headless --path godot --export-release "Web" build/web/index.html  # Web 导出（需要 4.7.2 的 Web 模板）
```

## 发布

推到 `main` 后，`.github/workflows/pages.yml` 依次执行：测试 → 导出 Web → 组装站点 → 浏览器冒烟 → 发布。任何一步失败都不会发布。

- `/`：JS 参考版（M4 之前朋友玩的仍是这一版）
- `/godot/`：Godot 版
