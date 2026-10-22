# NAME-2a 回执：显示名表骨架与取名入口

> 执行者 DSH 里的 DeepSeek，2026-10-21。派活卡：`协作/派单/NAME-2a-派活卡.md`。

## 改了什么
- 新建 `godot/data/js/15-显示名.json`：一个常量 `显示名`，八个空分区（势力 / 驾驶员 / 机体 / 关键词 / 状态标签 / 身份 / 卡牌 / 其它）。
- 改 `godot/data/js/manifest.json`：`"文件"` 里在 `12-档位职业.json` 后加一项 `"15-显示名.json": ["显示名"]`；其它字段（含 `rulesSignature`）未动。
- 新建 `godot/core/data/display_names.gd`：`class_name DisplayNames`，`名(类别, id, 兜底)` / `卡名(卡)`，纯读 `Db.T`。
- 新建 `godot/tests/unit/test_display_names.gd`：11 项断言（八分区齐全；演习表验证表内优先 / 回落到兜底 / 回落到 id / 卡名覆盖），用完还原 `Db.T["显示名"]`。
- 未改任何现有调用点、未改加载器、未重录样例、未改 `test_data`。

## 门禁
- `--only=test_display_names,test_data,test_boundary`：3 个文件 68 项全绿（`test_data` 无红，无需停）。
- 全量 `godot/tests/run_tests.gd`：**3807 项全绿**，退出码 0，耗时 5.1 分（比上单 3796 多 11 项 = 本单新增）。
- 原生样例：全量里 `test_native_goldens` 通过，逐场不变，未重录。
- `node godot/tools/build_godot_routemap.mjs` 重建 → `--check` **EXIT=0**（三份生成物逐字节同步，索引页 7813 / 8000 估算 token）。
- RouteMap 差异只含 `core/data/display_names.gd` 与 `tests/unit/test_display_names.gd` 两个新条目（另加 `tests/run_tests.gd` 的行号位移）。

## 过程中要注意的一条
- 新增 `class_name` 后，只跑测试会报 `Identifier "DisplayNames" not declared`：必须先跑一次
  `godot --headless --path godot --import` 让全局类缓存登记，再跑测试。这不是代码问题，以后每新增 `class_name` 都要做一次。

## 耗时
- 约 25 分钟（含两次全量 + 一次 import + RouteMap 重建）。

## 下一步从哪开始
- NAME-2b（Claude 在主机上做）：样例比对契约——样例补内部 id、`武器` / `卡牌` / `牌名` 等显示字段列入 `DISPLAY_ONLY`，单独一个提交并停等验收。
- 之后 NAME-2c 起才改调用点（`DisplayNames.名(...)` / `卡名(...)`），按 ≤3 文件一批切。
