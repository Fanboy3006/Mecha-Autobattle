# COL-TIER-1 回执：卡嘉莉 S2 / 特洛瓦 W3 档位 A → B（作者 10-22 拍板）

## 改了什么
- 设计稿《卡嘉莉与特洛瓦卡牌设计 v0.1》头部补一行档位 B 的拍板记录。
- `godot/data/js/12-档位职业.json`：`TIER.S2`、`TIER.W3` 由 `A` 改 `B`（招募 3→0 希望，晋升 2/3→1/2），与同势力大众脸 W4 / W5 一致。
- `godot/tests/golden/run_vectors.json` 重录（`record_run_golden.gd`，连录两次 SHA256 相同）。

## 样例差异
- `run_vectors`：只有 晋升面板 4 处 `价` 变化——S2@Lv10 2→1、S2@Lv20 3→2、W3@Lv10 2→1、W3@Lv20 3→2；地图 / 推进剂 / 招募券 / 三选一 0 差异。
- 原生战斗样例：未重录（档位不进战斗结算，全量逐场重跑 0 分叉）。

## 门禁（云端 Godot 4.7.2 Linux）
- 改数据后、重录前：全量 1 项红（就是上面的晋升面板价格），符合预期。
- 重录后全量：4438 项全绿，EXIT=0。
- `node godot/tools/build_godot_routemap.mjs --check`：EXIT=0。
