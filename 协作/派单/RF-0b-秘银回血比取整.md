# 派活单 RF-0b：秘银「回血比」回复量取整（会改战斗结果；本单不重录样例）

> 依据：`协作/架构/重构规格-RF-v0.1.md` §三 RF-0 · 0b（作者 10-21 已拍板「照修」）。前置：RF-0a 已提交。
> 先读 `AGENTS.md`。只改下面列的 2 个文件；一个提交。

## 背景
- `godot/core/battle/mithril_v03_cards.gd` 的 `执行算子` 里，`"回血比":` 分支用 `maxHp × 比` 直接加血，不取整 → HP 会出现小数。

## 要改的文件
1. `godot/core/battle/mithril_v03_cards.gd`：只改 `"回血比":` 分支里 `if t6 != null:` 块内的前 3 行。
2. `godot/tests/unit/test_rf0_fixes.gd`：追加一段。

## 具体改法
1. 把这 2 行（先确认原文存在、且只出现一次）：
```gdscript
				var 前 := float(t6.get("hp", 0.0))
				t6["hp"] = minf(float(t6.get("maxHp", 1.0)), 前 + float(t6.get("maxHp", 1.0)) * float(J.or_(表.get("比"), 0.25)))
```
   替换为：
```gdscript
				var 前 := float(t6.get("hp", 0.0))
				var 上限 := float(t6.get("maxHp", 1.0))
				var 量 := float(J.round(上限 * float(J.or_(表.get("比"), 0.25))))
				t6["hp"] = minf(上限, 前 + 量)
```
   其余行（`回 = …`、`_记(…)`、`return [...]`）一字不动。
2. `test_rf0_fixes.gd` 的 `run` 里追加 `_段_0b(t)`：搭一个开了秘银 v0.3 的沙盒（照 `test_mithril_v03.gd` 的做法），
   一台友军 `maxHp = 1001`、`hp = 500`，指定为 `_当前目标`，调
   `MithrilV03Cards.执行算子({"ctx": ctx, "card": {"名": "测试"}}, {"动作": "回血比", "比": 0.25}, [])`。断言：
   - hp == 750.0（250.25 取整为 250）；`hp == floor(hp)`。
   - 再把 hp 设成 990，同样调用 → hp == 1001.0（不超上限）。
   - （如 `_ctxOf` 要求的键名不同，以代码为准，在测试注释里写明。）

## 不许做
- 不改 `files` 以外的文件；不改战报文案；不重录样例。

## 验收
- 跑：`--only=test_rf0_fixes,test_mithril`。预期全绿。不跑全量（理由同 RF-0a）。
- 提交信息：`[RF-0b] 秘银回血比回复量取整`
- 回执：`协作/架构/RF回执/RF-0b.md`。
