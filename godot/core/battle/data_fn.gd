## 10-数据 / 11-敌方梯队 / 12-档位职业 里战斗运行期要用的三个小函数（其余是启动期就算好的数据，见 data/js/）。
class_name DataFn
extends RefCounted

## 10-数据.js wp()：武器规格补默认值
static func wp(o: Dictionary) -> Dictionary:
	return J.assign({
		"range": [1.0, 1.0], "hit": 100.0, "critMod": 0.0, "stat": "射击", "fire": "direct", "dmgType": "物理",
		"cd": 0.0, "uses": null, "unlock": 1.0, "upgrades": [], "afterMove": true, "ignoreDef": false,
		"special": null, "power": 0.0, "desc": "",
	}, o)

## 11-敌方梯队.js tierOfEnemy()
static func tierOfEnemy(k: Variant) -> String:
	if J.inc(Db.T.ENEMY_BOSS, k) or J.inc(Db.T.BOSS_SPECIAL, k):
		return "Boss"
	var tiers: Dictionary = Db.T.ENEMY_TIER
	for t in tiers.keys():
		if J.inc(tiers[t], k):
			return String(t)
	return "杂兵"

## 12-档位职业.js tplOf()
static func tplOf(m: Variant) -> Variant:
	return J.find(Db.T.ALLY_T, func(t): return t.mech == m)
