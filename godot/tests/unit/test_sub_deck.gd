## ★ A3a：通用「副牌库（SubDeck）」层的单元断言 —— 抽一张 / 回库或移出 / 放入（断路器）。
## 这一层只认「库 / 手牌 / 移出表 / 断路器集合 + 卡上的等级字段」，不认识任何势力与卡名。
## 这里测的是**这一层自己的口径**：
##   · 满手不抽（库长度不变、随机数一个都不掷）
##   · 未满抽 1 张（库 −1、手牌 +1）
##   · 等级 1 / 2 → 回库；等级 3 → 移出（`移出表` +1）
##   · `放入` 同一张三级牌第二次 → 被断路器拦下（返回 false）
##   · 同种子两遍：抽取序列逐字相同
extends RefCounted

const 上限 := 6

func _卡(id: String, 级: int) -> Dictionary:
	return {"id": id, "名": id, "连携等级": 级, "回库": 级 <= 2}

func _库(n: int) -> Array:
	var 出: Array = []
	for i in range(n):
		出.append(_卡("C%d" % i, 1))
	return 出

## 用同一个 rng 连着抽 5 张，返回抽到的 id 序列（对账用）。
func _抽五(rng) -> Array:
	var 库 := _库(8)
	var 手: Array = []
	var 出: Array = []
	while 出.size() < 5:
		var 抽 := SubDeck.抽一张(库, 手, 99, rng)
		if 抽.is_empty():
			break
		出.append(str(抽.get("id", "")))
	return 出

func run(t) -> void:
	t.ok(SubDeck.默认等级键 == "连携等级" and SubDeck.默认回库键 == "回库",
		"① 默认字段名与卡表 schema 一致（%s / %s）" % [SubDeck.默认等级键, SubDeck.默认回库键])

	# ---- ① 抽一张：满手不抽 ----
	var 满库 := _库(4)
	var 满手: Array = []
	for i in range(上限):
		满手.append(_卡("满%d" % i, 1))
	var rng满 := Mulberry32.new(7)
	var 没抽 := SubDeck.抽一张(满库, 满手, 上限, rng满)
	t.ok(没抽.is_empty() and 满库.size() == 4 and 满手.size() == 上限,
		"① 满手（%d/%d）→ 不抽：库仍是 %d 张、手牌仍是 %d 张" % [满手.size(), 上限, 满库.size(), 满手.size()])
	t.ok(rng满.steps == 0, "① 满手不抽时一个随机数都没掷（steps = %d）" % rng满.steps)

	# ---- ① 抽一张：未满 → 抽 1 张 ----
	var 库2 := _库(5)
	var 手2: Array = [_卡("H0", 1)]
	var 库前 := 库2.size()
	var 一张 := SubDeck.抽一张(库2, 手2, 上限, Mulberry32.new(99))
	t.ok(not 一张.is_empty() and 库2.size() == 库前 - 1 and 手2.size() == 2,
		"① 未满（1/%d）→ 抽 1 张：库 %d → %d、手牌 1 → %d" % [上限, 库前, 库2.size(), 手2.size()])
	t.ok(is_same(手2[手2.size() - 1], 一张), "① 抽到的那张就是 append 进手牌的那张")

	# ---- ① 抽一张：空库不抽、也不掷 ----
	var 空库: Array = []
	var 空手: Array = []
	var rng空 := Mulberry32.new(3)
	t.ok(SubDeck.抽一张(空库, 空手, 上限, rng空).is_empty() and 空手.is_empty() and rng空.steps == 0,
		"① 空库 → 不抽、也不掷随机数")
	t.ok(SubDeck.随机下标(Mulberry32.new(3), 1) == 0, "① 库只剩 1 张时不用掷（下标固定 0）")

	# ---- ② 回库或移出 ----
	var 库3 := _库(1)
	var 移出表: Array = []
	var 卡1 := _卡("一级", 1)
	var 卡2 := _卡("二级", 2)
	var 卡3 := _卡("三级", 3)
	t.ok(SubDeck.回库或移出(库3, 移出表, 卡1) == "回库" and 库3.size() == 2 and 移出表.is_empty(),
		"② 等级 1 → 回库（库 1 → %d、移出表 0 张）" % 库3.size())
	t.ok(SubDeck.回库或移出(库3, 移出表, 卡2) == "回库" and 库3.size() == 3,
		"② 等级 2 → 回库（库 2 → %d）" % 库3.size())
	var 移出前 := 移出表.size()
	var 去处 := SubDeck.回库或移出(库3, 移出表, 卡3)
	t.ok(去处 == "移出" and 移出表.size() == 移出前 + 1 and 库3.size() == 3,
		"② 等级 3 → 移出：移出表 %d → %d 张、库不变（%d 张）" % [移出前, 移出表.size(), 库3.size()])
	t.ok(is_same(移出表[移出表.size() - 1], 卡3), "② 移出的就是那张三级牌")

	# ---- ③ 放入：三级牌每种每场限 1 次 ----
	var 库4: Array = []
	var 集合 := {}
	var 限次卡 := _卡("三级", 3)
	t.ok(SubDeck.放入(库4, 限次卡, 集合, "三级") and 库4.size() == 1 and 集合.has("三级"),
		"③ 放入：三级牌第一次成功（库 +1、断路器集合登记）")
	t.ok(not SubDeck.放入(库4, 限次卡, 集合, "三级") and 库4.size() == 1,
		"③ 放入：同一张三级牌第二次 → 被断路器拦下（返回 false、库仍是 %d 张）" % 库4.size())
	var 一级卡 := _卡("一级", 1)
	t.ok(SubDeck.放入(库4, 一级卡, 集合, "一级") and SubDeck.放入(库4, 一级卡, 集合, "一级") and 库4.size() == 3,
		"③ 放入：等级 1 的牌不进断路器（同一张放两次都算过）")
	t.ok(not 集合.has("一级"), "③ 放入：等级 1 不登记进断路器集合")
	var 库5: Array = []
	t.ok(SubDeck.放入(库5, 限次卡, null, "三级") and SubDeck.放入(库5, 限次卡, null, "三级") and 库5.size() == 2,
		"③ 放入：断路器集合给 null → 整场不限次（同一张三级牌放两次都成）")

	# ---- 纯读：等级 / 各级张数 ----
	var 各样: Array = [_卡("a", 1), _卡("b", 2), _卡("c", 3), _卡("d", 1)]
	var 计 := SubDeck.各级张数(各样)
	t.ok(int(计["一级"]) == 2 and int(计["二级"]) == 1 and int(计["三级"]) == 1,
		"④ 各级张数：一 %d / 二 %d / 三 %d" % [int(计["一级"]), int(计["二级"]), int(计["三级"])])
	t.ok(SubDeck.等级(卡2) == 2 and SubDeck.等级({}) == 0 and SubDeck.等级(null) == 0,
		"④ 等级：读得到就给档位，读不到（{} / null）一律 0")

	# ---- ⑤ 同种子两遍：抽取序列逐字相同 ----
	var 序A := _抽五(Mulberry32.new(20261021))
	var 序B := _抽五(Mulberry32.new(20261021))
	t.ok(序A.size() == 5 and JSON.stringify(序A) == JSON.stringify(序B),
		"⑤ 同种子两遍抽取序列逐字相同：%s" % JSON.stringify(序A))
