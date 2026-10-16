// 从封存的 JS 参考版导出**局外（肉鸽大地图 / 券 / 晋升 / 三选一）黄金样例** → godot/tests/golden/run_vectors.json
// 用法（仓库根目录）：node godot/tools/export_run_golden.mjs [JS 根目录=.] [输出文件=godot/tests/golden/run_vectors.json]
//
// 这是 M3「肉鸽内核」迁移的对拍依据（与战斗黄金样例 `tests/golden/battle/*.json` 同一套路：
// 从封存版导出真值，Godot 用同一份输入重跑后逐字段比对）。内容五块：
//   ① 地图：8 个种子 × 4 层 → `生成层(层, 地图种子(种子, 层))` 的**整张图**（列数 / 存在率 / 连通下限 /
//      起点 / 两个出口 / 守军 / 隧道 / 每格的节点类型 / 最短路家族 / 试了几次）；
//   ② 推进剂明细：每层的 `推进剂上限(R) / 推进剂账(R)`（上限 = 该图最短路 + 偶数额外余量）与 `R.推进剂`；
//   ③ 招募券：每种子开局那 3 张（`发开局券`）、`随机券(R, 偏移)` 的纯函数结果、
//      `掷战后券(R, 档)` 三档的掷骰结果（含「没给」= null）；
//   ④ 晋升面板：34 名机师 × Lv10 / Lv20 的**晋升前后全字段**（HP / 装甲 / 防御 / 机动 / 速度 / 命中…，
//      数字全部来自 `makeUnit()`）+ 该档价格；
//   ⑤ 三选一战术牌：每名机师的 `候选战术牌们(RUN, 键, 3)`（0 随机数），外加「选走第一张之后再候选」。
//
// 编码约定与战斗样例一致（见 Godot迁移架构-v1.md §5.4）：整数照存；非整数存 {"$f": IEEE-754 位串}；
// 不存 JSON 小数。**键顺序保持 JS 的遍历顺序**（Godot 的 Dictionary 按插入顺序遍历）。
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { normalize, loadReference } from './js_ref.mjs';

const JS_ROOT = resolve(process.argv[2] || '.');
const OUT = resolve(process.argv[3] || join(JS_ROOT, 'godot', 'tests', 'golden', 'run_vectors.json'));
const ref = await loadReference(JS_ROOT);
const { G, REF } = ref;
console.log(`JS 参考版 ${ref.version} · ${ref.signature} · ${ref.sealNote}`);

const 种子们 = [20261010, 20261011, 20261012, 20261013, 20261014, 20261015, 20261016, 20261017];
const 层们 = [1, 2, 3, 4];
const 分队 = '无';                       // 地图不依赖分队；分队只在券那一块用得上
const ALLY = REF.consts.ALLY_T;
const CLASSES = REF.consts.CLASSES || [];
const FACTIONS = REF.consts.FACTIONS || [];

/** 一局新 RUN（**不导出**任何带时间的字段：`新的一局` 里的 `t0` 不进样例） */
const 开一局 = (种子, 队 = 分队) => G.肉鸽.新的一局(队, 种子);

/* ---------- ① + ② 地图与推进剂：8 个种子 × 4 层 ---------- */
const 地图 = [];
for (const 种子 of 种子们) {
  const R = 开一局(种子);
  for (const 层 of 层们) {
    G.肉鸽.进层(层);
    const 账 = G.推进剂账(R);
    地图.push(normalize({
      种子, 层, 地图种子: G.地图种子(种子, 层), 形状: G.形状(层),
      地图: R.地图,
      推进剂: { 上限: G.推进剂上限(R), 账, 进层后实发: R.推进剂 },
    }));
    // 自检：上限 = 最短路 + 余量（且余量是偶数 —— 二部图那一条）
    if (R.推进剂 !== G.推进剂上限(R)) throw new Error(`种子 ${种子} 第 ${层} 层：进层实发推进剂 ≠ 上限`);
    if (账.最短路 <= 0 || (账.余量 % 2) !== 0) throw new Error(`种子 ${种子} 第 ${层} 层：余量 ${账.余量} 不是偶数`);
  }
}

/* ---------- ②b 推进剂余量表（逐层的静态口径） ---------- */
const 推进剂明细 = 层们.map(层 => normalize({
  层, 形状: G.形状(层), 余量表: G.推进剂余量表[层], 余量: G.推进剂余量(层), 是偶数: G.推进剂余量是偶数(层),
}));

/* ---------- ③ 招募券掷骰 ---------- */
const 招募券 = [];
for (const 种子 of 种子们) {
  const R = 开一局(种子);
  const 开局券 = (R.券 || []).map(c => Object.assign({}, c));
  /* 纯函数：5 个偏移各抽一张（不写 RUN、不消耗别的随机数） */
  const 随机 = [0, 1, 2, 3, 4].map(偏移 => {
    const 选 = G.随机券(R, 偏移);
    return { 偏移, 类: 选 && 选.类, 名: 选 && 选.名 };
  });
  /* 有副作用：三档掷一次（返回发出去的券或 null）。
     ★ `掷战后券` 是 **JS 模块内的纯函数口子**（`function 掷战后券(...)`，没挂到 `__game`），
       所以从 `REF.consts` 取（`js_ref.mjs` 的顶层函数登记，见那里的注释）。 */
  const 掷战后券 = REF.consts.掷战后券;
  if (typeof 掷战后券 !== 'function') throw new Error('JS 参考版里取不到 `掷战后券`：js_ref.mjs 的函数登记没生效');
  const 战后 = ['战斗', '精英', 'Boss'].map(档 => {
    const 券 = 掷战后券(R, 档);
    return { 档, 券: 券 ? Object.assign({}, 券) : null };
  });
  /* 分队券（开局第 1 张是分队券）也是「同种子可复现」的一条链 */
  const 分队R = 开一局(种子, CLASSES[0] || '无');
  招募券.push(normalize({
    种子, 分队, 开局券, 随机, 战后,
    分队券: { 分队: 分队R.分队, 开局券: (分队R.券 || []).map(c => Object.assign({}, c)) },
    发券后手上: (R.券 || []).map(c => Object.assign({}, c)),
  }));
}

/* ---------- ④ 晋升前后五维面板 ---------- */
const 晋升面板 = [];
for (const a of ALLY) {
  for (const 等级 of [10, 20]) {
    const 预览 = G.晋升预览(a.short, 等级);
    const R = 开一局(20261010);
    预览.价 = G.晋升要多少(a.short, 预览.到, R);
    晋升面板.push(normalize({ 职业: a.tags.战斗分类, 势力: a.tags.势力, ...预览 }));
  }
}

/* ---------- ⑤ 三选一战术牌候选 ---------- */
const 战术牌三选一 = [];
const R0 = 开一局(20261010);
for (const a of ALLY) {
  const 候选 = G.候选战术牌们(R0, a.short, 3).map(c => c.id);
  /* 「选走第一张之后再候选」= 证明候选会排除 `RUN.战术牌库` 里已有的 */
  const R2 = 开一局(20261010);
  const 第一次 = G.候选战术牌们(R2, a.short, 3).map(c => c.id);
  const 选了 = 第一次.length ? G.选战术牌(R2, 第一次[0]) : false;
  const 再来 = G.候选战术牌们(R2, a.short, 3).map(c => c.id);
  战术牌三选一.push(normalize({ 键: a.short, 职业: a.tags.战斗分类, 势力: a.tags.势力, 候选, 第一次, 选成功: 选了, 选后再候选: 再来 }));
}

const out = {
  meta: {
    来源: `机甲指挥 JS 参考版 ${ref.version}`, rulesSignature: ref.signature, tag: 'js-reference-final',
    生成: 'godot/tools/export_run_golden.mjs',
    口径: '局外（肉鸽）：地图生成 / 推进剂 / 招募券 / 晋升面板 / 三选一战术牌；同种子同输入逐字相同（0 界面依赖）',
    种子们,
  },
  地图, 推进剂明细, 招募券, 晋升面板, 战术牌三选一,
};
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(out) + '\n');
console.log(` 地图 ${地图.length} 张（${种子们.length} 种子 × ${层们.length} 层）· 推进剂明细 ${推进剂明细.length} 层`);
console.log(` 招募券 ${招募券.length} 局（开局券 ${招募券.reduce((n, x) => n + x.开局券.length, 0)} 张）· 晋升面板 ${晋升面板.length} 条 · 三选一 ${战术牌三选一.length} 条`);
console.log(`已导出 → ${OUT}`);
