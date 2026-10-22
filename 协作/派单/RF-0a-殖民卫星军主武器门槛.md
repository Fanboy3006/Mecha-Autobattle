# 派活单 RF-0a：殖民卫星军主武器门槛生效（会改战斗结果；本单不重录样例）

> 依据：`协作/架构/重构规格-RF-v0.1.md` §三 RF-0 · 0a（作者 10-21 已拍板「照修」）。
> 先读 `AGENTS.md`。只改下面列的 2 个文件；一个提交。

## 背景（只给动手需要的）
- `CardPlay.主武器门槛`（`godot/core/battle/card_play.gd` 约 140 行）问 `RuleHooks.首个结论("区规则门槛", …)`，
  只有返回值带 `终局 = true` 才会被采纳；采纳后若 `接手 = true` 就直接返回 `原因`（**空串 = 能打，后面的「主武器已销毁 / 合体技 / 战意不足」检查全部跳过**）。
- `ColonialV01.区规则门槛`（`godot/core/battle/colonial_v01.gd` 约 295 行）只返回 `{接手, 原因}`、不带 `终局` → 殖民卫星军的「本回合不能打武器（潜入准备）」「依赖未冷却」门槛**从来没生效**。

## 要改的文件
1. `godot/core/battle/colonial_v01.gd`：只改 `区规则门槛` 这一个函数。
2. `godot/tests/unit/test_rf0_fixes.gd`（**新文件**，本单建，0b / 0c 往里追加）。

## 具体改法
1. 把 `colonial_v01.gd` 里的整个函数（含签名，共 5 行）精确替换为：
```gdscript
static func 区规则门槛(ctx: Dictionary, u: Dictionary, 卡: Dictionary, 区: String) -> Dictionary:
	if 区 != CardPlay.区_主武器:
		return {"终局": false}
	if not ColonialDeck.是殖民卫星军牌(卡) and str(卡.get("角色所属势力", "")) != 势力:
		return {"终局": false}
	var 因 := ColonialUnits.武器门槛(ctx, u, 卡)
	return {"终局": 因 != "", "接手": 因 != "", "原因": 因}
```
   - **不要**照抄 `atx_three.gd` 的「能打也返回 `终局:true`」写法：那样会让殖民卫星军主武器跳过战意检查。能打时必须返回 `终局:false`，让后面的通用检查照常进行。
   - 函数上方的 `##` 注释行不动。
2. 新建 `godot/tests/unit/test_rf0_fixes.gd`：`extends RefCounted`，`func run(t) -> void:`，首行 `##` 职责注释写「RF-0 三处缺陷修复的回归测试」。
   沙盒搭法照抄 `test_colonial_v01.gd` 的 `_场 / _单位 / _牌 / _手牌`（复制需要的几个小工具进新文件，函数名加前缀 `_c` 避免以后和 0b/0c 撞名）。断言：
   - (a) 殖民卫星军成员手里一张殖民卫星军主武器卡，`u["本回合不能打武器"] = true` → `CardPlay.主武器门槛(ctx, u, 卡)` == `"本回合不能打武器牌（潜入准备）"`。
   - (b) 同一张卡，去掉该标记、把战意设成低于这张卡的费用 → 返回 `"战意不足"`（证明能打时不再「接手」，通用检查还在）。
   - (c) 同上、战意足够 → 返回 `""`。
   - (d) 直接调 `ColonialV01.区规则门槛(ctx, u, 卡, CardPlay.区_筹码)` → `终局 == false`。
   - 用哪张卡：从殖民卫星军卡包里挑任意一张 `卡类 == "主武器卡"` 且战意费用 > 0 的；挑中的 id 写进测试注释。

## 不许做
- 不改 `files` 以外的文件；不改任何数值、战报文案。
- 不重录黄金样例（0a/0b/0c 都做完后由 RF-0d 统一重录）。

## 验收
- 跑：`--only=test_rf0_fixes,test_colonial`。预期全绿；新增断言 ≥ 4 项。
- **本单不跑全量**（改了战斗结果，`test_native_goldens` 预期会红，留给 RF-0d）。
- 提交信息：`[RF-0a] 殖民卫星军主武器门槛返回终局，门槛生效`
- 回执：`协作/架构/RF回执/RF-0a.md`（≤ 40 行：改了哪些文件、测试项数、意外改动）。
