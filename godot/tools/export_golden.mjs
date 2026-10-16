// 从 JS 参考版导出战斗黄金样例 → godot/tests/golden/battle/<组>.json
// 用法（仓库根目录）：node godot/tools/export_golden.mjs [JS 根目录=.] [输出目录=godot/tests/golden/battle]
//
// 一个样例 = 输入（我方 / 敌方规格 / 种子 / 选项）+ 命令（按回合，玩家在指令阶段打出的牌）
//          → 期望（逐条事件 + 每回合状态摘要 + 结果）。回合摘要只在第 0 项存全部单位，之后只存变化的单位。Godot 用同样的输入与命令重跑，逐项比对。
//
// 战斗流程与 JS 的 simulate() 同构（开局 → 每回合：先执行本回合命令，再打一回合 → 结束记录），
// 区别只在「每回合之间插入命令」。导出前先做自检：用本脚本的流程、按 2788 基线的口径重跑 47 场，
// 必须与 JS 自己的 simulate() 逐条相同、总数 = 2788 —— 证明插桩与流程都没有改变游戏行为。
//
// 编码约定（见 Godot迁移架构-v1.md §5.4）：整数照存；非整数存 {"$f": IEEE-754 位串}；不存 JSON 小数。
import { mkdirSync, writeFileSync } from 'fs';
import { join, resolve } from 'path';
import { loadReference, normalize } from './js_ref.mjs';

const JS_ROOT = resolve(process.argv[2] || '.');
const OUT = resolve(process.argv[3] || join(JS_ROOT, 'godot', 'tests', 'golden', 'battle'));
const ref = await loadReference(JS_ROOT);
const { G, REF, RNG_AT } = ref;
console.log(`JS 参考版 ${ref.version} · ${ref.signature} · ${ref.sealNote}`);

/** 事件里的纯展示文本（由表现层按事件生成），不参与对账 */
const DISPLAY_ONLY = new Set(['文本', '效果说明', '触发说明']);

const 摘要 = ctx => normalize({
  回合: ctx.turn,
  rng: ctx.rng.n,
  气势: ctx.气势,
  结果: ctx.result ? { 结果: ctx.result.结果, 原因: ctx.result.原因 } : null,
  手牌: (ctx.战术手牌 || []).map(c => c.id),
  待触发: (ctx.待触发战术牌 || []).map(c => c.id),
  已打出: ctx.已打出战术牌 || [],
  战况计数: ctx.战况计数 || null,
  全队憋大招: !!ctx.全队憋大招,
  单位: ctx.allies.concat(ctx.enemies).map(u => ({
    方: u.side, 位: u.slot, 键: u.key, hp: u.hp, maxHp: u.maxHp,
    shieldHp: u.shieldHp || 0, 掩护盾: u.掩护盾 || 0,
    buffs: u.buffs || [], debuffs: u.debuffs || [],
    武器: (u.weapons || []).map(w => [w.cd ?? null, w.uses ?? null, w.readyTurn ?? null]),
    势力状态: u.势力状态 || null, 标定经济: u.标定经济 || null,
    holdUlt: !!u.holdUlt, defending: !!u.defending,
  })),
});

const 事件 = ctx => {
  const at = RNG_AT.get(ctx) || [];
  return ctx.log.map((r, i) => {
    const o = {};
    for (const k of Object.keys(r)) if (!DISPLAY_ONLY.has(k)) o[k] = r[k];
    o._rng = at[i] ?? -1;
    return normalize(o);
  });
};

/** 战斗流程：与 simulate() 同构；policy(ctx) 在每回合的指令阶段决定要打的牌 */
function 跑一场({ 我方, 敌方, 种子, 选项, policy }) {
  const ctx = G.开局(我方, 敌方, 种子, null, Object.assign({}, 选项, { 方针: {} }));
  const 命令 = [];
  /* 回合摘要：第 0 项（开局后）完整；之后每回合的「单位」只记与上一回合不同的那几台：[[单位下标, 摘要], …] */
  const 摘要们 = [摘要(ctx)];
  let 上一单位 = 摘要们[0].单位.map(u => JSON.stringify(u));
  const 顶 = Math.max(REF.MAX_TURN, ctx.回合上限 || REF.MAX_TURN) + 2;
  let 护栏 = 0;
  while (!ctx.result && 护栏++ < 顶) {
    for (const id of (policy ? policy(ctx) : [])) 命令.push({ 回合: ctx.turn, 类型: '打战术牌', 参数: id });
    G.打一回合(ctx);
    const 全 = 摘要(ctx);
    const 本 = 全.单位.map(u => JSON.stringify(u));
    全.单位变化 = 全.单位.map((u, i) => [i, u]).filter(([i]) => 本[i] !== 上一单位[i]);
    全.单位数 = 全.单位.length;
    delete 全.单位;
    上一单位 = 本;
    摘要们.push(全);
  }
  if (!ctx.result) ctx.result = { 结果: '败', 原因: '超出回合上限' };
  REF.pushLog(ctx, `战斗结束：${ctx.result.结果}（${ctx.result.原因}）`, { 类型: '结束' });
  return { ctx, 命令, 摘要们 };
}

/** 自动出牌：按手牌顺序，能打就打，直到打不出（回气牌可能让后面的牌变得能打）。只记录成功的。 */
const 能打 = (ctx, c) => c && (Number(c.剩余次数 ?? 1) > 0) && !(Number(c.当前冷却) > 0) && (Number(ctx.气势) || 0) >= (Number(c.耗气) || 0);
function 全打(ctx) {
  const 打了 = [];
  for (let 轮 = 0; 轮 < 12; 轮++) {
    const c = (ctx.战术手牌 || []).find(x => 能打(ctx, x));
    if (!c) break;
    const r = G.打战术牌(ctx, c.id);
    if (!r || !r.成功) break;
    打了.push(c.id);
  }
  return 打了;
}

/* ---------- 自检：本流程 + 插桩 与 JS 的 simulate() 逐条相同（2788 口径） ---------- */
{
  const 机制 = G.战斗结构.敌人机制.开;
  G.战斗结构.敌人机制.开 = false;
  let 总 = 0, 不同 = 0;
  for (const 条目 of G.编成表) {
    const 敌 = () => G.敌方规格组(G.编成到单位(条目, 0));
    const 波次 = G.编成波次到单位(条目, 0);
    const a = G.simulate(G.默认五人队, 敌(), {}, 20261010, { 波次 });
    const b = 跑一场({ 我方: G.默认五人队, 敌方: 敌(), 种子: 20261010, 选项: { 波次, 战术卡牌: false } });
    总 += a.记录.length;
    if (JSON.stringify(a.记录) !== JSON.stringify(b.ctx.log)) 不同++;
  }
  G.战斗结构.敌人机制.开 = 机制;
  if (总 !== 2788 || 不同) throw new Error(`自检失败：总记录 ${总}（期望 2788），与 simulate() 不同的场次 ${不同}`);
  console.log(`✓ 自检：本流程与 simulate() 47 场逐条相同，总记录 2788`);
}

/* ---------- 队伍 ---------- */
const ALLY = REF.consts.ALLY_T;
const 前排职业 = new Set(['近卫', '重装', '尖兵']);
function 势力队(势力, 等级) {
  const 成员 = ALLY.filter(a => a.tags && a.tags.势力 === 势力);
  const 前 = 成员.filter(a => 前排职业.has(a.tags.战斗分类));
  const 后 = 成员.filter(a => !前排职业.has(a.tags.战斗分类));
  const 队 = [];
  前.slice(0, 4).forEach((a, i) => 队.push({ 键: a.short, 位: i, 等级 }));
  后.slice(0, 4).forEach((a, i) => 队.push({ 键: a.short, 位: 4 + i, 等级 }));
  for (const a of 前.slice(4)) { const 空 = [4, 5, 6, 7].find(p => !队.some(x => x.位 === p)); if (空 != null) 队.push({ 键: a.short, 位: 空, 等级 }); }
  return 队.slice(0, 5);
}
const 势力们 = [...new Set(ALLY.map(a => a.tags.势力))];
/** 势力组的代表编成：1~4 层各取一档，覆盖普通 / 精英 / 侵蚀源 / 守军 / Boss（每种取编成表里的第一条） */
const 代表类型 = ['1-普通', '2-精英', '2-侵蚀源', '3-守军', '4-普通', '4-Boss'];
const 代表编成 = 代表类型.map(k => G.编成表.find(e => `${e.层}-${e.类型}` === k));

const 样例 = (id, 条目, 我方, 种子, policy) => {
  const 敌方 = G.敌方规格组(G.编成到单位(条目, 0));
  const 波次 = G.编成波次到单位(条目, 0);
  const 输入 = normalize({ 我方, 敌方规格: 敌方, 种子, 选项: { 战术卡牌: true, 波次 }, 编成: { 编号: 条目.编号, 名: 条目.名, 层: 条目.层, 类型: 条目.类型 } });
  const { ctx, 命令, 摘要们 } = 跑一场({ 我方, 敌方, 种子, 选项: { 战术卡牌: true, 波次 }, policy });
  return { id, 输入, 命令, 期望: { 事件: 事件(ctx), 回合摘要: 摘要们, 结果: { 结果: ctx.result.结果, 原因: ctx.result.原因, 回合: ctx.turn } } };
};

const 组 = {};
组.default = G.编成表.map((e, i) => 样例(`default/${String(i).padStart(2, '0')}-${e.编号}`, e, G.默认五人队, 20261010, null));
组.faction = [];
势力们.forEach((势力, fi) => 代表编成.forEach((e, ei) => [20, 30].forEach(lv => {
  组.faction.push(样例(`faction/${势力}-Lv${lv}-${e.编号}`, e, 势力队(势力, lv), 20261100 + fi * 100 + ei * 10 + lv / 10, 全打));
})));
/* 角色牌组：初始手牌上限 6 张时，角色牌排在职业牌与势力牌之后，大队伍里会被截掉（见交付说明）。
   这里用「牌主 + 同势力 1 台」的两人队，让每张角色牌都能进手牌并被打出。 */
组.character = [];
for (const c of REF.consts.战术卡牌表.filter(c => c.层级 === '角色')) {
  const 主 = ALLY.find(a => a.short === c.id.replace(/^U_/, ''));
  if (!主) continue;
  const 伴 = ALLY.find(a => a.tags.势力 === 主.tags.势力 && a.short !== 主.short && 前排职业.has(a.tags.战斗分类) !== 前排职业.has(主.tags.战斗分类))
    || ALLY.find(a => a.tags.势力 === 主.tags.势力 && a.short !== 主.short);
  const 位 = a => (前排职业.has(a.tags.战斗分类) ? 0 : 4);
  const 队 = [{ 键: 主.short, 位: 位(主), 等级: 20 }, { 键: 伴.short, 位: 位(伴) + (位(伴) === 位(主) ? 1 : 0), 等级: 20 }];
  组.character.push(样例(`character/${c.id}`, G.编成表[0], 队, 20261200 + 组.character.length, 全打));
}
{
  const e = G.编成表[0];
  const 我方 = G.默认五人队;
  const 敌方 = G.敌方规格组(G.编成到单位(e, 0));
  const 首回合 = ctx => (ctx.turn === 1 ? ['C_CMD_1', 'C_GUARD_1'].filter(id => G.打战术牌(ctx, id).成功) : []);
  const { ctx, 命令, 摘要们 } = 跑一场({ 我方, 敌方, 种子: 20261015, 选项: { 战术卡牌: true }, policy: 首回合 });
  组.card_baseline = [{ id: 'card_baseline/激励+热血', 输入: normalize({ 我方, 敌方规格: 敌方, 种子: 20261015, 选项: { 战术卡牌: true }, 编成: { 编号: e.编号, 名: e.名, 层: e.层, 类型: e.类型 } }),
    命令, 期望: { 事件: 事件(ctx), 回合摘要: 摘要们, 结果: { 结果: ctx.result.结果, 原因: ctx.result.原因, 回合: ctx.turn } } }];
}

mkdirSync(OUT, { recursive: true });
const meta = { 来源: `机甲指挥 JS 参考版 ${ref.version}`, rulesSignature: ref.signature, tag: 'js-reference-final',
  口径: '敌人机制开 · 战术卡牌开 · 全军突击（行动方针已取消）', 生成: 'godot/tools/export_golden.mjs' };
let 合计 = 0;
for (const [名, 列] of Object.entries(组)) {
  const 事件数 = 列.reduce((n, s) => n + s.期望.事件.length, 0);
  const 出牌数 = 列.reduce((n, s) => n + s.命令.length, 0);
  const 胜 = 列.filter(s => s.期望.结果.结果 === '胜').length;
  writeFileSync(join(OUT, `${名}.json`), JSON.stringify({ meta: Object.assign({ 组: 名, 场数: 列.length, 事件数, 出牌数 }, meta), 样例: 列 }) + '\n');
  console.log(`  ${名}：${列.length} 场 · 事件 ${事件数} 条 · 出牌 ${出牌数} 张 · 胜 ${胜}`);
  合计 += 列.length;
}
console.log(`已导出 ${合计} 场战斗样例 → ${OUT}`);
