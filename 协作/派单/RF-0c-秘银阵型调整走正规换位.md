# 派活单 RF-0c：秘银「阵型调整」改走 `BattleSwap.换位`（会改战斗结果；本单不重录样例）

> 依据：`协作/架构/重构规格-RF-v0.1.md` §三 RF-0 · 0c（作者 10-21 已拍板「照修」；换位语义由 Claude 在本单里写死）。前置：RF-0b 已提交。
> 先读 `AGENTS.md`。只改下面列的 2 个文件；一个提交。

## 背景
- `mithril_v03_cards.gd` 的 `_阵型调整(ctx)` 直接对调两台机体的 `slot`，绕过了 `BattleSwap.换位`（`godot/core/battle/swap.gd`）：
  敌方意图不会重算、`换位后` 钩子不广播、实时门槛不刷新、没有换位战报。

## 要改的文件
1. `godot/core/battle/mithril_v03_cards.gd`：只改 `_阵型调整`。
2. `godot/tests/unit/test_rf0_fixes.gd`：追加一段。

## 具体改法
1. 把 `_阵型调整` 里这 3 行（先确认原文存在、且只出现一次）：
```gdscript
	var 位: Variant = a.slot
	a.slot = b.slot
	b.slot = 位
```
   替换为：
```gdscript
	if BattleSwap.换位(ctx, "ally", a.get("slot"), b.get("slot"), {"来源": "阵型调整"}) != 2:
		return ["换位没有成功"]
```
   - 选谁不变：仍是 `Units.livingOf("ally", ctx)` 的前两台。
   - 不传 `isShadowCard`（这不是影世界牌，不记【移位】、不挂〔错位〕）。
   - 其后的「命中 −10」增益、`_记(…)`、`return [...]` 一字不动。`BattleSwap.换位` 会多写一行 `〔阵型调整〕我方：…` 战报，这是预期的。
2. `test_rf0_fixes.gd` 追加 `_段_0c(t)`：秘银沙盒里我方两台存活机体，记下双方原 `slot`，并在 `ctx["敌方意图表"]` 放一条任意意图；调用 `执行算子(…, {"动作": "阵型调整"}, [])`。断言：
   - 两台的 `slot` 互换。
   - 战报里出现一条 `类型 == "换位"` 且 `来源 == "阵型调整"` 的记录。
   - 两台都带「阵型调整」增益（hit −10）。
   - 两台都**没有** `BattleSwap.错位键`。
   - 只剩 1 台存活时返回 `["只有一台机体，换不了位"]`，slot 不变。

## 不许做
- 不改 `files` 以外的文件（`swap.gd` 不动）；不改其它文案；不重录样例。

## 验收
- 跑：`--only=test_rf0_fixes,test_mithril,test_swap`。预期全绿。不跑全量。
- 提交信息：`[RF-0c] 秘银阵型调整改走正规换位`
- 回执：`协作/架构/RF回执/RF-0c.md`。
