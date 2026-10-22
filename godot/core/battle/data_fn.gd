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
## ★ A6b：`data/js` 里没有塔斯克（A6）/ 雷欧娜（A7）的模板（**不许改 `data/js/*.json`**）——
##   这里在 `ALLY_T` 查不到时兜底问一次 `AtxDuo.模板()`（只认这两个新键；别人的键仍然返回 null，
##   所以 34 台既有角色与 168 场战斗黄金一个字节都不受影响）。
static func tplOf(m: Variant) -> Variant:
	var t = J.find(Db.T.ALLY_T, func(t): return t.mech == m)
	if t != null:
		return t
	return AtxDuo.模板(m)
