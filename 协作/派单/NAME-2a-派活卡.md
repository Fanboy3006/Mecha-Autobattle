# NAME-2a 派活卡（显示名表骨架 + 取名入口）

> Claude 10-21 写。依据：`协作/架构/施工单-NAME-命名底座-DS4.1F.md` 末尾「Claude 10-21 确认 NAME-1」§二、§三。
> 派发方式：下面整段作为 `ds_code` 的 `task`；`files` / `read_only` / `tests` 按卡里同名栏填。
> 状态：**待派**（等 `deepseek-autobattle` 工具配好；配不上就由 Claude 在主机上直接做）。

```
【单号】NAME-2a    【一句话】建显示名表骨架和取名入口，不改任何现有调用点

【背景】
- 规则出处：协作/架构/施工单-NAME-命名底座-DS4.1F.md 末尾「Claude 10-21 确认 NAME-1」§二、§三
- 现状：常量由 godot/session/data_loader.gd 按 godot/data/js/manifest.json 的 "文件" 表读入 Db.T；本单只新增，不改加载器

【要改的文件】
- godot/data/js/15-显示名.json（新建）
- godot/data/js/manifest.json（"文件" 里加一项）
- godot/core/data/display_names.gd（新建）
- godot/tests/unit/test_display_names.gd（新建）

【只读参考】
- godot/session/data_loader.gd
- godot/core/data/db.gd
- godot/tests/unit/test_data.gd（测试文件写法照它：`func run(t)`，用 `t.ok(条件, 说明)`）

【具体改法】
1. 新建 godot/data/js/15-显示名.json，内容恰好是：
   {"显示名": {"势力": {}, "驾驶员": {}, "机体": {}, "关键词": {}, "状态标签": {}, "身份": {}, "卡牌": {}, "其它": {}}}
2. manifest.json 的 "文件" 对象里加一项 "15-显示名.json": ["显示名"]，放在 "12-档位职业.json" 那项后面；其它字段（含 rulesSignature）一个字都不改。
3. 新建 godot/core/data/display_names.gd：
   - 首行：## 显示名取名入口：玩家看得到的名字一律从这里取（去版权化-A），键是内部 id。
   - 第二行：## 纯读 Db.T，不碰场景树和文件。
   - class_name DisplayNames，extends RefCounted
   - static func 名(类别: String, id: String, 兜底: String = "") -> String
     规则：Db.T.get("显示名") 是字典、其中「类别」区是字典且有 id → 返回 str(那个值)；
     否则 兜底 不为空返回 兜底，为空返回 id。
   - static func 卡名(卡: Dictionary) -> String
     规则：「卡牌」区有 str(卡.get("id", "")) 的覆盖就返回覆盖；否则返回 str(卡.get("名", ""))。
4. 新建 godot/tests/unit/test_display_names.gd（首行 ## 写职责），断言：
   a. DataLoader.load_game_data 无错误，且 data.has("显示名")，八个分区都在、都是字典。
   b. 把 Db.T["显示名"] 先存一份原值，临时换成 {"关键词": {"TRANS-AM": "※TA"}, "卡牌": {"X1": "※卡"}}：
      DisplayNames.名("关键词","TRANS-AM") == "※TA"；
      DisplayNames.名("关键词","不存在") == "不存在"；
      DisplayNames.名("关键词","不存在","兜底") == "兜底"；
      DisplayNames.名("没这个区","a") == "a"；
      DisplayNames.卡名({"id":"X1","名":"原名"}) == "※卡"；
      DisplayNames.卡名({"id":"X2","名":"原名"}) == "原名"。
      结束前把 Db.T["显示名"] 还原（原来没有这个键就 erase）。

【不许做】
- 不改 files 以外的文件；不改任何现有 .gd 的调用点（那是 NAME-2c 起的事）
- 不改 rulesSignature；如果 test_data 因为常量清单变化而报红，停下报告，不要改 test_data
- 不重录黄金样例

【验收】
- tests：test_display_names, test_data, test_boundary
- 预期：三组全绿；新增 .gd 会让 RouteMap 过期，必须先跑 node godot/tools/build_godot_routemap.mjs 重建，再 --check EXIT=0（经 ds_code 派发时由 Claude 重建；在 DSH 里直接做时由执行者自己重建，并和代码同一个提交）
- 提交信息：[NAME-2a] 显示名表骨架与取名入口
```

## Claude 收货备注
- 新增 `.gd` 会让 `Godot-RouteMap*.md` 过期 → 收货后跑 `node godot/tools/build_godot_routemap.mjs` 重建再 `--check`；`ds_code` 默认会跑 `--check`，第一次很可能因此报红，**这是预期的**，不算 DeepSeek 做错。
- 收货后再跑一次全量测试（原生样例应逐场不变），回执写 `协作/架构/NAME回执/NAME-2a.md`。
