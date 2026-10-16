# 机甲指挥 · Godot 版

本项目**唯一长期维护的游戏引擎**。仓库根目录的 JS 版是冻结的玩法参考（tag `js-reference-final`），迁移完成后移到 `archive/js/`。
架构与迁移计划：[`../协作/架构/Godot迁移架构-v1.md`](../协作/架构/Godot迁移架构-v1.md)

当前进度：**M0 地基**（工程、测试、CI、Web 发布）。

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
| `core/` | 纯逻辑（战斗 / 肉鸽内核、随机数、规则） | 只继承 `RefCounted` / `Resource`；不碰场景树、文件、时间、引擎随机数；四舍五入用 `JsCompat.js_round`，排序用 `JsCompat.stable_sort`。`tests/unit/test_boundary.gd` 自动检查 |
| `data/` | 内容与数值（M1 从 JS 参考版导出） | 内核只读 |
| `presentation/` | 场景与界面 | 只读内核状态；玩家操作变成命令交给内核 |
| `assets/fonts/` | `NotoSansSC-Subset.otf`（SIL OFL 1.1，见同目录许可证） | 缺字时 `test_font_coverage` 报红 → 运行下面的字体命令 |
| `tests/` | `run_tests.gd` 自动发现 `tests/unit/test_*.gd`；`golden/` 放从 JS 导出的对拍数据 | golden 文件**不存 JSON 小数**（Godot 解析会丢精度）：随机数存 uint32，浮点存 IEEE-754 位串 |
| `tools/` | CI 安装脚本、字体子集、JS 向量导出、浏览器冒烟 | 不打进游戏包 |

## 常用命令

```
python godot/tools/build_font_subset.py                                    # 重新生成中文字体子集（需要 pip install fonttools）
node godot/tools/gen_rng_vectors.mjs . godot/tests/golden/rng_vectors.json # 从 JS 参考版导出 RNG 对拍向量
mkdir -p godot/build/web && touch godot/build/.gdignore
godot --headless --path godot --export-release "Web" build/web/index.html  # Web 导出（需要 4.7.2 的 Web 模板）
```

## 发布

推到 `main` 后，`.github/workflows/pages.yml` 依次执行：测试 → 导出 Web → 组装站点 → 浏览器冒烟 → 发布。任何一步失败都不会发布。

- `/`：JS 参考版（M4 之前朋友玩的仍是这一版）
- `/godot/`：Godot 版
