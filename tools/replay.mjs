#!/usr/bin/env node
/* ============================================================================
 * 对局录像重放工具（作者 2026-10-12 提出、Claude 出规格）
 * ----------------------------------------------------------------------------
 * 用法：
 *   node tools/replay.mjs <录像文件>              # 重放 + 校验（逐字一致 → 退出码 0）
 *   node tools/replay.mjs <录像文件> --导出决策    # 另外打一份 JSONL：每个决策点一行
 *   node tools/replay.mjs <录像文件> --out=决策.jsonl
 *   node tools/replay.mjs <录像文件> --quiet       # 只打结论
 *
 * 干什么：录像里**只有种子 + 游戏版本 + 按顺序的每一个操作**（录操作，不录局面）。
 * 这个工具用 `tests/lib/dom-stub.mjs` 的 `loadPage()` 把 `index.html` 在 Node 的 `vm` 里跑起来，
 * 再**按同一个动作派发入口**（`界面.动作(动作, 参数)`）逐条重放：
 *   ① **逐步校验**：每一步做完，把当前局面压成一条**紧凑串**（`录像.对账(界面)`），
 *      与录像里那一步的 `对账` 比 —— 对不上就报「**第 N 步开始对不上**」+ 当时**期望 / 实际**，**不崩**；
 *   ② **最终校验**：整局重放完，重建 `录像.摘要(RUN)`（规范化投影）与录像的 `最终摘要` **逐字比对**；
 *   ③ **版本不同时先警告，照样尽量重放**（录像里记的是当时的 `__game.version`）；
 *   ④ `--导出决策`：每个决策点一行 JSONL，`可选项` **由这个工具就当前局面现场枚举**
 *      （招募候选 / 可去的格子 / 黑市货 / 三选一 / 5 条方针……）—— 游戏本身不用为此改逻辑。
 *
 * 两个「重放侧」的特殊处理（都写在这里，不改游戏）：
 *   · `编队` 这一步是**录像自己补的一步**（出击名单与站位是拖动出来的，不走动作入口）——
 *     重放时直接写回 `界面.编队.出击` 与 `RUN.出击阵 / 出击`，等价于玩家在编队屏上摆好的那个结果；
 *   · 弹窗（隧道 / 遗迹 / 休整 / 瞭望站 / 侵蚀源）的答案不经过动作派发入口 ——
 *     录像把答案记成父动作**后面紧挨着的那一步** `弹窗:<值>`，重放时按这个位置把答案喂回
 *     `界面.对话框钩子`（位置对不上就按 null，与「没有钩子」的默认行为一致）。
 *
 * 本文件**一处 `Math.random` 都没有**；同一条录像重放两遍输出逐字相同。
 * ========================================================================== */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadPage } from '../tests/lib/dom-stub.mjs';

const 根 = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/* ---------------------------------------------------------------------------
 * 一、决策动作表（`--导出决策` 用）：动作名 → 就当前局面枚举「可选项」
 * ---------------------------------------------------------------------------
 * 每个枚举函数返回一个**动作串数组**（`动作` 或 `动作:参数`）——「选择」就是玩家实际按下的那一串，
 * 它必须在「可选项」里（`tests/录像.js` 第 [4] 段钉着这一条）。
 * 口径：枚举的是**当时界面上真的能点的那些**（招募屏列出的候选 / 能去的格 / 黑市摆的货 / 弹窗选项…）；
 * 拿不到局面（没有 RUN）时返回空数组，工具会照实报出来（不编一个假的选项）。
 */
const 决策表 = {
  选分队: G => 分队们(G).map(f => `选分队:${f}`),
  去节点: G => (能去的格们(G) || []).map(n => `去节点:${n.k}`),
  使用零件: G => ((G.肉鸽.RUN.零件) || []).map((p, i) => `使用零件:${i}`),
  招募: G => 招募候选们(G).map(k => `招募:${k}`),
  用券: G => ((G.肉鸽.RUN.券) || []).map((c, i) => `用券:${i}`),
  丢券: G => ((G.肉鸽.RUN.券) || []).map((c, i) => `丢券:${i}`),
  晋升: G => (G.肉鸽.晋升清单() || []).map(x => `晋升:${x.键}`),
  黑市买: G => 黑市可选项(G),
  黑市刷新: G => 黑市可选项(G),
  黑市卖: G => ((G.肉鸽.RUN.零件) || []).map((p, i) => `黑市卖:${i}`),
  奇遇: G => 事件可选项(G),
  弹窗: (G, 参, 步, 上次弹窗) => {
    const 值 = (步 && Array.isArray(步.可选项) && 步.可选项.length) ? 步.可选项
      : ((上次弹窗 && 上次弹窗.选项) ? 上次弹窗.选项.map(o => o.值) : []);
    return 值.filter(Boolean).map(v => `弹窗:${v}`);
  },
  休整: () => ['休整:耐久', '休整:晋升', '休整:推进剂'],
  前进: () => ['前进:尽头', '前进:小径'],
  方针: G => (G.方针们 || []).map(k => `方针:${k}`),
  点敌人: G => 我方位们(G, 'enemy').map(s => `点敌人:${s}`),
  大招: G => 我方位们(G, 'ally').map(s => `大招:${s}`),
  TRANSAM: G => 我方位们(G, 'ally').map(s => `TRANSAM:${s}`),
  开TRANSAM: G => 我方位们(G, 'ally').map(s => `开TRANSAM:${s}`),
};

/** 分队们（`92-肉鸽界面.js` 的 `分队屏()` 就是这一串：无 + 职业 + 势力）。 */
function 分队们(G) {
  const 出 = ['无'];
  try { for (const k of (G.CLASSES || [])) 出.push(k); } catch (e) { /* 不崩 */ }
  try { for (const f of (G.FACTIONS || [])) 出.push(f); } catch (e) { /* 不崩 */ }
  return 出;
}
function 能去的格们(G) { try { return G.肉鸽.能去的() || []; } catch (e) { return []; } }
/** 招募候选（和 `92-肉鸽界面.js` 的 `招募屏()` 同一套判据：不在队里 + 对得上当前选中的券）。 */
function 招募候选们(G) {
  const R = G.肉鸽.RUN;
  if (!R) return [];
  const 已有 = new Set((R.队伍 || []).map(m => m.键));
  const 券们 = R.券 || [];
  const i = G.肉鸽界面.选中的券;
  const 用中 = (i != null && 券们[i]) ? 券们[i] : null;
  const 出 = [];
  for (const t of (G.ALLY_T || [])) {
    if (已有.has(t.mech)) continue;
    if (用中 && !G.券合(用中, t.mech)) continue;
    出.push(t.mech);
  }
  return 出;
}
/** 黑市那一屏能点的：货 / 刷新 / 离开。 */
function 黑市可选项(G) {
  const 出 = [];
  let 货 = [];
  try { 货 = G.肉鸽.黑市货() || []; } catch (e) { 货 = []; }
  for (const id of 货) 出.push(`黑市买:${id}`);
  if (G.肉鸽.黑市刷新剩余 && G.肉鸽.黑市刷新剩余() > 0) 出.push('黑市刷新');
  出.push('黑市离开');
  return 出;
}
/** 事件选项（当前事件表里那几条；下标与文字两种写法都算「能点的」）。 */
function 事件可选项(G) {
  const 出 = [];
  let ev = null;
  try { ev = G.肉鸽.当前事件(); } catch (e) { ev = null; }
  const 选 = (ev && (ev.选项 || ev.选项们)) || [];
  选.forEach((o, i) => {
    const 文 = (o && (o.选 != null ? o.选 : (o.名 != null ? o.名 : o.动))) || (typeof o === 'string' ? o : null);
    出.push(`奇遇:${i}`);
    if (文) 出.push(`奇遇:${文}`);
  });
  return 出;
}
function 我方位们(G, 方) {
  const ctx = G.界面.ctx;
  if (!G.界面 || !ctx || G.界面.屏 !== '战斗') return [];
  try {
    return (方 === 'ally' ? (G.界面.显示单位 ? G.界面.显示单位.我方 : ctx.allies) : ctx.enemies)
      .filter(u => u.hp == null || u.hp > 0).map(u => u.slot).sort((a, b) => a - b);
  } catch (e) { return []; }
}

/* ---------------------------------------------------------------------------
 * 二、局面摘要（决策行里的「当时的局面」）
 * ------------------------------------------------------------------------- */
function 局面摘要(G) {
  const R = G.肉鸽.RUN;
  if (!R) return { 局面: '没有进行中的局' };
  const 格 = (() => { try { return G.肉鸽.当前格(); } catch (e) { return null; } })();
  const 出 = {
    层: R.层, 场次: R.场次, 等级: R.等级, 经验: R.经验,
    希望: R.希望, 源碳: R.源碳, 耐久: R.耐久, 推进剂: R.推进剂,
    名册: (R.队伍 || []).map(m => `${m.键} Lv${m.等级}`),
    券: ((R.券 || []).map(c => (c && c.名) || '券')),
    藏品: (R.藏品 || []).slice(),
    零件: ((R.零件 || []).map(p => p && p.k)),
    已走步数: (R.已走过 || []).length,
    当前节点: 格 ? { 格号: 格.k, 类型: 格.类型, 名: (G.节点类型表[格.类型] || {}).名 || 格.类型 } : null,
  };
  const 界面 = G.界面, ctx = 界面 && 界面.ctx;
  if (界面 && 界面.屏 === '战斗' && ctx) {
    出.战斗 = {
      回合: ctx.turn, 阶段: 界面.阶段,
      方针: (() => { try { const p = G.当前方针(ctx); return `${p.类型}${p.目标位 == null ? '' : `（目标位 ${p.目标位}）`}`; } catch (e) { return null; } })(),
      单位开关: (() => {
        const 表 = 界面.单位开关 || {};
        const 键 = Object.keys(表).filter(k => { const v = 表[k] || {}; return v.保留大招 || v.TRANSAM === '手动' || v.本回合开TRANSAM; });
        return 键.length ? 键.map(k => `${k}:${表[k].保留大招 ? '保留大招' : ''}${表[k].TRANSAM === '手动' ? '/手动' : ''}${表[k].本回合开TRANSAM ? '/点开' : ''}`) : [];
      })(),
      我方HP: (ctx.allies || []).map(u => `${u.slot}:${Math.max(0, u.hp)}/${u.maxHp}`),
      敌方HP: (ctx.enemies || []).map(u => `${u.slot}:${Math.max(0, u.hp)}/${u.maxHp}`),
      敌人预览: (() => {
        try {
          return (G.算意图(ctx) || []).map(a => `${a.名称} 用【${a.武器 || '—'}】打 ${a.目标名 || '—'}（约 ${a.期望}${a.被挡 ? '，被挡' : ''}）`);
        } catch (e) { return []; }
      })(),
    };
  }
  return 出;
}

/* ---------------------------------------------------------------------------
 * 三、重放
 * ------------------------------------------------------------------------- */
/** 重放一条录像。返回
 *  `{ok, 不一致步, 期望, 实际, 步骤们, 摘要一致, 摘要差异, 决策行们, 战斗记录们, 警告们, 版本}`。
 *  **绝不抛**（每一步都包了 try/catch，出错记成一条「这一步炸了」继续走）。 */
export function 重放(录像, 选项 = {}) {
  const 警告们 = [];
  const 步骤们 = [];
  const 决策行们 = [];
  const 战斗记录们 = [];
  const 出错们 = [];
  if (!录像 || typeof 录像 !== 'object' || !Array.isArray(录像.操作)) {
    return { ok: false, 不一致步: null, 期望: null, 实际: null, 步骤们, 摘要一致: false,
      摘要差异: '录像文件不是一份合法的录像（没有 `操作` 数组）', 决策行们, 战斗记录们, 警告们: ['录像文件形状不对'], 出错们, 版本: null };
  }
  const page = loadPage(join(根, 'index.html'), { quiet: true });
  if (page.errors.length) 警告们.push(`页面加载时报错 ${page.errors.length} 处：${page.errors[0]}`);
  const G = page.sandbox.window.__game;
  const 界面 = G.界面;
  /* 重放**不再录像**（这一步只是复现，不要把重放的结果又录一遍） */
  if (G.录像) G.录像.关 = true;

  const 版本 = G.version;
  if (录像.游戏版本 && String(录像.游戏版本) !== String(版本)) {
    警告们.push(`录像记的游戏版本是 ${录像.游戏版本}，现在跑的是 ${版本} —— 版本不同，照样尽量重放（对不上就报步数）。`);
  }

  /* 弹窗答案：由重放循环在派发每一步**之前**看「下一步是不是 `弹窗`」决定（见文件头）。 */
  let 本次弹窗答案;
  let 上次弹窗 = null;
  界面.对话框钩子 = (标题, 文本, 选项) => {
    上次弹窗 = { 标题, 选项: (选项 || []).map(o => ({ 值: o && o.值 })) };
    if (本次弹窗答案 !== undefined) { const v = 本次弹窗答案; 本次弹窗答案 = undefined; return v; }
    return null;
  };

  /** 播放引擎要手动 tick 完（dom-stub 的 setTimeout 不排计时器，和测试里的做法一样）。 */
  const 播完 = () => {
    let n = 0;
    while (界面.阶段 === '播放' && n++ < 200000) G.播放.tick();
    return n;
  };
  const 读战斗记录 = () => {
    try { return G.战斗记录.读() || []; } catch (e) { return []; }
  };
  let 见过战斗 = 读战斗记录().length;

  const 操作 = 录像.操作;
  let 不一致步 = null, 期望 = null, 实际 = null;

  /* 开局的「选分队」：录像头里也有 `分队`（规范字段），先按它落实一次（幂等）。 */
  if (录像.分队) { try { 界面.动作('选分队', 录像.分队); } catch (e) { /* 不崩 */ } }

  for (let i = 0; i < 操作.length; i++) {
    const 步 = 操作[i] || {};
    const 动作 = String(步.动作 == null ? '' : 步.动作);
    const 参数 = 步.参数 == null ? '' : String(步.参数);
    const 下一步 = 操作[i + 1] || null;
    /* ★ 决策行在**派发之前**算：`可选项` 必须是「下决定的那一刻」能点的那些
       （派发之后就变了 —— 例如招募完，刚招到的那位就从候选里消失了）。
       顺序 = 局面摘要（当时）→ 可选项（当时）→ 派发 → 记下选择。 */
    let 决策 = null;
    if (Object.prototype.hasOwnProperty.call(决策表, 动作)) {
      let 可选项 = [];
      try { 可选项 = 决策表[动作](G, 参数, 步, 上次弹窗) || []; } catch (e) { 可选项 = []; }
      决策 = {
        序号: 步.序号, 屏: 步.屏,
        局面摘要: (() => { try { return 局面摘要(G); } catch (e) { return { 局面: '（摘要算不出来）' }; } })(),
        可选项,
        选择: 参数 ? `${动作}:${参数}` : 动作,
        理由: 步.理由 || null,
        最终结果: null,                    // 整局重放完回填（「这一场 / 这一局的最终结果」）
      };
    }
    /* 弹窗答案：紧跟在父步后面的那一步 */
    本次弹窗答案 = (下一步 && String(下一步.动作) === '弹窗') ? String(下一步.参数 == null ? '' : 下一步.参数) : undefined;
    let 回 = null, 炸 = null;
    try {
      if (动作 === '编队') 回 = 应用编队(G, 参数);
      else if (动作) 回 = 界面.动作(动作, 参数);
    } catch (e) { 炸 = (e && e.message) ? e.message : String(e); }
    if (炸) 出错们.push({ 序号: 步.序号, 动作, 参数, 错: 炸 });
    if (决策) 决策行们.push(决策);

    /* ★ 逐步对账**紧跟在动作之后、播放之前**：录像里的 `对账` 就是「动作刚做完、这一回合还没放」
       那一瞬间（`录像.派发后()` 里算的）—— 顺序错了会假报「对不上」（实测踩过）。 */
    let 现 = null;
    try { 现 = G.录像.对账(界面); } catch (e) { 现 = `（算不出来：${e && e.message}）`; }
    const 记 = { 序号: 步.序号, 屏: 步.屏, 动作, 参数, 期望: 步.对账 == null ? null : String(步.对账), 实际: 现, 一致: null };
    if (步.对账 != null) {
      记.一致 = (记.期望 === 记.实际);
      if (记.一致 === false && 不一致步 == null) { 不一致步 = 步.序号 == null ? (i + 1) : 步.序号; 期望 = 记.期望; 实际 = 记.实际; }
    }
    步骤们.push(记);

    /* 然后把这一回合的播放放完（**下一步的决策是在放完之后做的**，与录像一侧的顺序一致）。
       ⚠ 战斗结束（`到结算()`）就发生在这几行 tick 里 —— 一局的「败 / 通关」多半在这儿落定。 */
    try { 播完(); } catch (e) { 出错们.push({ 序号: 步.序号, 动作: '（播放）', 参数: '', 错: (e && e.message) || String(e) }); }

    /* 这一场战斗的记录（打完一场就新出现一场） */
    const 现记 = 读战斗记录();
    if (现记.length > 见过战斗) {
      for (let k = 见过战斗; k < 现记.length; k++) {
        const 场 = 现记[k] || {};
        战斗记录们.push({ 种子: 场.种子, 结果: 场.结果, 回合数: 场.回合数, 记录: 场.记录 || [] });
      }
      见过战斗 = 现记.length;
    }
  }

  /* 最终校验：重建「最终摘要」，与录像里那一份**逐字比对** */
  const R = (() => { try { return G.肉鸽.RUN; } catch (e) { return null; } })();
  let 现摘要 = null;
  try { 现摘要 = G.录像.摘要(R); } catch (e) { 现摘要 = null; }
  const 记摘要 = 录像.最终摘要 || null;
  const 甲 = JSON.stringify(现摘要), 乙 = JSON.stringify(记摘要);
  const 摘要一致 = (记摘要 != null) && (甲 === 乙);
  const 摘要差异 = 摘要一致 ? null : 第一个不同(记摘要, 现摘要);

  const 结局 = R && R.结局 ? R.结局 : null;
  for (const 行 of 决策行们) 行.最终结果 = `${结局 || '未结束'}${录像.结果 ? `（${录像.结果}）` : ''}`;

  return {
    ok: 摘要一致 && 不一致步 == null && 出错们.length === 0,
    录像: { 种子: 录像.种子, 分队: 录像.分队, 结果: 录像.结果, 游戏版本: 录像.游戏版本, 步数: 操作.length },
    版本, 警告们, 步骤们, 不一致步, 期望, 实际,
    摘要一致, 摘要差异, 现摘要, 记摘要,
    决策行们, 战斗记录们, 出错们,
    最终: R ? { 层: R.层, 场次: R.场次, 希望: R.希望, 源碳: R.源碳, 耐久: R.耐久, 结局: R.结局 || null } : null,
  };
}

/** 把录像里的「编队」（出击名单与站位）写回去 —— 等价于玩家在编队屏上摆好的那个结果。 */
function 应用编队(G, 参数) {
  let 出击 = [];
  try { 出击 = JSON.parse(参数) || []; } catch (e) { 出击 = []; }
  出击 = 出击.filter(x => x && x.键 != null).map(x => ({ 键: x.键, 位: Number(x.位) }));
  G.界面.编队.出击 = 出击.slice();
  const R = G.肉鸽.RUN;
  if (R) { R.出击阵 = 出击.map(x => ({ 键: x.键, 位: x.位 })); R.出击 = 出击.map(x => x.键); }
  return 出击;
}

/** 两个 JSON 结构的**第一个不同**（给人看的「期望 / 实际」）：返回 `{路径, 期望, 实际}`。 */
export function 第一个不同(期望, 实际) {
  const 走 = (a, b, 路) => {
    if (a === b) return null;
    if (a == null || b == null || typeof a !== typeof b || typeof a !== 'object') {
      return { 路径: 路 || '（根）', 期望: a, 实际: b };
    }
    if (Array.isArray(a) || Array.isArray(b)) {
      if (!Array.isArray(a) || !Array.isArray(b)) return { 路径: 路, 期望: a, 实际: b };
      if (a.length !== b.length) return { 路径: `${路}.length`, 期望: a.length, 实际: b.length };
      for (let i = 0; i < a.length; i++) {
        const r = 走(a[i], b[i], `${路}[${i}]`);
        if (r) return r;
      }
      return null;
    }
    const 键 = [...new Set([...Object.keys(a), ...Object.keys(b)])];
    for (const k of 键) {
      if (!(k in a)) return { 路径: `${路}.${k}`, 期望: '（没有这一项）', 实际: b[k] };
      if (!(k in b)) return { 路径: `${路}.${k}`, 期望: a[k], 实际: '（没有这一项）' };
      const r = 走(a[k], b[k], 路 ? `${路}.${k}` : k);
      if (r) return r;
    }
    return null;
  };
  return 走(期望, 实际, '');
}

/* ---------------------------------------------------------------------------
 * 四、CLI（`main()` 返回结果、不打印不退出 —— 测试直接 import 它，见 CLAUDE.md 第 4 节）
 * ------------------------------------------------------------------------- */
export function main(argv = process.argv.slice(2)) {
  const 位置 = argv.filter(a => !a.startsWith('--'));
  const 有 = n => argv.includes(n);
  const 取值 = n => { const a = argv.find(x => x.startsWith(n + '=')); return a ? a.slice(n.length + 1) : null; };
  if (有('--help') || 有('-h') || !位置.length) {
    return { 用法: true, 帮助: '用法：node tools/replay.mjs <录像文件> [--导出决策] [--out=决策.jsonl] [--quiet]' };
  }
  const 文件 = resolve(位置[0]);
  if (!existsSync(文件)) return { ok: false, 错误: `找不到录像文件：${文件}` };
  let 录像 = null;
  try { 录像 = JSON.parse(readFileSync(文件, 'utf8')); } catch (e) {
    return { ok: false, 错误: `录像文件不是合法 JSON：${e && e.message}` };
  }
  const r = 重放(录像, {});
  r.文件 = 文件;
  const 静默 = 有('--quiet');
  if (!静默) 打印(r, { 导出决策: 有('--导出决策'), 位置, 文件 });
  if (有('--导出决策')) {
    const 出 = 取值('--out');
    const jsonl = r.决策行们.map(x => JSON.stringify(x)).join('\n') + '\n';
    if (出) { writeFileSync(resolve(出), jsonl, 'utf8'); console.log(`决策 JSONL 已写入 ${resolve(出)}（${r.决策行们.length} 行）`); }
    else process.stdout.write('———— 决策 JSONL ————\n' + jsonl);
  }
  return r;
}

function 打印(r, o) {
  const 名 = o.文件;
  console.log(`———— 重放 ${名} ————`);
  console.log(`录像：种子 ${r.录像 && r.录像.种子} · ${r.录像 && r.录像.分队}分队 · 游戏版本 ${r.录像 && r.录像.游戏版本} · ` +
    `${r.录像 && r.录像.步数} 步 · 结果 ${(r.录像 && r.录像.结果) || '（没写完）'}`);
  console.log(`现在跑的游戏版本：${r.版本}`);
  for (const w of (r.警告们 || [])) console.log(`⚠ ${w}`);
  console.log(`逐步对账：${r.步骤们.filter(x => x.一致 === true).length} 步一致 / ` +
    `${r.步骤们.filter(x => x.一致 === false).length} 步不一致 / ${r.步骤们.length} 步`);
  if (r.不一致步 == null) {
    console.log('✓ 每一步的对账都一致（重放与录像同步）');
  } else {
    console.log(`✗ 第 ${r.不一致步} 步开始对不上`);
    const 步 = r.步骤们.find(x => x.序号 === r.不一致步) || {};
    console.log(`   那一步：屏=${步.屏} 动作=${步.动作} 参数=${步.参数}${步.理由 ? ` 理由=${步.理由}` : ''}`);
    console.log(`   期望：${r.期望}`);
    console.log(`   实际：${r.实际}`);
  }
  for (const e of (r.出错们 || [])) console.log(`✗ 第 ${e.序号} 步抛异常：${e.动作}(${e.参数}) → ${e.错}`);
  console.log(r.摘要一致
    ? `✓ 最终摘要逐字一致（重放结束后的 RUN 与录像里记的那一份完全一样）`
    : `✗ 最终摘要对不上${r.摘要差异 ? ` —— 第一处不同：${r.摘要差异.路径}` : ''}`);
  if (!r.摘要一致 && r.摘要差异) {
    console.log(`   期望：${短(JSON.stringify(r.摘要差异.期望))}`);
    console.log(`   实际：${短(JSON.stringify(r.摘要差异.实际))}`);
  }
  console.log(`战斗记录：${(r.战斗记录们 || []).length} 场（每场逐条记录都留着，供对账用）`);
  console.log(`结论：${r.ok ? '**逐字一致**（退出码 0）' : '**对不上，别当成可用的录像**（退出码 1）'}`);
}
const 短 = s => { const t = String(s == null ? '—' : s); return t.length > 260 ? t.slice(0, 260) + '…' : t; };

/* 只有直接 `node tools/replay.mjs` 跑时才走 CLI（测试 import 时不打印、不退出） */
const 是直接跑 = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (是直接跑) {
  const r = main();
  if (r && r.用法) { console.log(r.帮助); process.exit(0); }
  if (r && r.错误) { console.log(`✗ ${r.错误}`); process.exit(1); }
  process.exit(r && r.ok ? 0 : 1);
}
