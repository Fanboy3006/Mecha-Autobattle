/* ============================================================================
 * 三、能调的数（§3.3）：把设置翻译成 `选项.调参`（注入口）
 * ========================================================================== */

/** **只把真的改过的项写进去** —— 全默认时返回 `{}`（一个键都没有）。
 *  这样「默认设置跑 100 场」与 `simulate(…, {})` 是**同一条代码路径**（可对账）。 */
function 调参调参对象(原始设置) {
  const s = 调参规整(原始设置);
  const 出 = {};
  const 敌 = s.敌人;
  if (敌.HP倍率 !== 1 || 敌.伤害倍率 !== 1 || 敌.装甲倍率 !== 1 || 敌.防御加成 !== 0) {
    出.敌人 = { HP倍率: 敌.HP倍率, 伤害倍率: 敌.伤害倍率, 装甲倍率: 敌.装甲倍率, 防御加成: 敌.防御加成 };
  }
  if (Object.keys(s.覆盖).length) 出.覆盖 = JSON.parse(JSON.stringify(s.覆盖));
  if (Object.keys(s.Boss).length) 出.Boss = JSON.parse(JSON.stringify(s.Boss));
  if (s.回合上限 != null) 出.回合上限 = s.回合上限;
  return 出;
}

/* ---------- 注入口的另一半：真的落到单位上（`开局()` / `增援()` 调它） ---------- */

/** 把 Boss 脚本覆盖**合并**到正式表那一条上（只覆盖写了的字段；`阶段` 整条替换）。 */
function 调参合并Boss脚本(基础, 覆盖) {
  const 出 = Object.assign({}, 基础 || {});
  if (!覆盖) return 出;
  if (覆盖.大技能间隔 != null) 出.大技能间隔 = 覆盖.大技能间隔;
  if (覆盖.伤害倍率 != null) 出.伤害倍率 = 覆盖.伤害倍率;
  if (覆盖.阶段间隔 != null || 覆盖.阶段倍率 != null) {
    const 旧 = (基础 && Array.isArray(基础.阶段) && 基础.阶段[0]) || {};
    出.阶段 = [Object.assign({}, 旧, {
      触发: 旧.触发 != null ? 旧.触发 : '半血',
      大技能间隔: 覆盖.阶段间隔 != null ? 覆盖.阶段间隔 : 旧.大技能间隔,
      伤害倍率: 覆盖.阶段倍率 != null ? 覆盖.阶段倍率 : 旧.伤害倍率,
    })];
  }
  return 出;
}

/** 把调参落到**一组敌方单位**上（`开局()` 里刚造好的那批 / `增援()` 补进来的那几台）。
 *  ★ 只认 `side === 'enemy'`；**一个数值都没改公式本体**，全部是「这一场临时套上去」的覆盖。 */
function 应用调参单位(单位们, 调参) {
  if (!调参 || !单位们) return 单位们;
  const g = 调参.敌人 || {};
  for (const u of 单位们) {
    if (!u || u.side !== 'enemy') continue;
    const 覆 = (调参.覆盖 && 调参.覆盖[u.key]) || null;
    /* 按敌人键覆盖 = **取代**全局那一项（不是叠加）；**没写的那一项回落成全局**
       （`调参规整()` 只记真的写了的项，所以手写的半截 JSON 也能用）。 */
    const 取值 = (覆项, 全局) => (覆项 != null ? 覆项 : 全局);
    const HP倍率 = 取值(覆 && 覆.HP倍率, 调参数(g.HP倍率, 1, 0.1, 10));
    const 装甲倍率 = 取值(覆 && 覆.装甲倍率, 调参数(g.装甲倍率, 1, 0.1, 10));
    const 威力倍率 = 取值(覆 && 覆.威力倍率, 1);
    const 伤害倍率 = 调参数(g.伤害倍率, 1, 0.1, 10);
    const 防御加成 = 调参整数(g.防御加成, 0, -500, 500);

    if (HP倍率 !== 1) {
      const 旧 = u.maxHp;
      u.maxHp = Math.max(1, Math.round(u.maxHp * HP倍率));
      /* HP 按同一比例缩放（`makeUnit()` 里 HP 继承那一步可能让 hp < maxHp） */
      u.hp = Math.max(1, Math.min(u.maxHp, Math.round(u.hp * (u.maxHp / Math.max(1, 旧)))));
    }
    if (装甲倍率 !== 1) u.armor = Math.max(0, Math.round(u.armor * 装甲倍率));
    if (防御加成 !== 0) u.defense = Math.max(0, (u.defense || 0) + 防御加成);
    if (威力倍率 !== 1) {
      u.weapons = (u.weapons || []).map(e => {
        const t = Object.assign({}, e.t);
        if (t.power > 0) t.power = Math.max(1, Math.round(t.power * 威力倍率));
        if (Array.isArray(t.upgrades)) {
          t.upgrades = t.upgrades.map(up => (up && up.power > 0
            ? Object.assign({}, up, { power: Math.max(1, Math.round(up.power * 威力倍率)) }) : up));
        }
        return Object.assign({}, e, { t });
      });
    }
    if (伤害倍率 !== 1) u.调参伤害倍率 = 伤害倍率;
    /* Boss 脚本覆盖（§3.3 第三项）：只对**正式表里有脚本**的那几种敌人有意义 */
    const bs = 调参.Boss && 调参.Boss[u.key];
    if (bs && Boss脚本 && Boss脚本[u.key]) u.调参Boss = 调参合并Boss脚本(Boss脚本[u.key], bs);
  }
  return 单位们;
}

/** 开局那一次：敌方全体 + 回合上限。`ctx` 是 `60-战斗.js` 的 `开局()` 造好的状态。 */
function 应用调参(ctx, 调参) {
  if (!ctx || !调参) return ctx;
  应用调参单位(ctx.enemies, 调参);
  if (调参.回合上限 != null) ctx.回合上限 = 调参整数(调参.回合上限, ctx.回合上限 || MAX_TURN, 1, MAX_TURN + 18);
  return ctx;
}

/* ============================================================================
 * 四、跑（§3.2 场次 / §3.4 分批跑）
 * ========================================================================== */

/** 方针 → `simulate()` 吃的那个参数（§3.2 第一版就两种：整场固定一条 / 「简单策略」）。 */
function 调参方针(原始设置) {
  const s = 调参规整(原始设置);
  if (s.方针 === 调参简单策略) return { 1: '全军防御', 2: '全军突击' };
  return s.方针;
}

/** 这一场下，界面上该显示的那条方针（按回合取；和 `simulate()` 的口径一致）。 */
const 调参回合方针 = (原始设置, 回合) => 第几回合的方针(调参方针(原始设置), 回合);

function 调参新统计() {
  return {
    总场: 0, 胜场: 0, 胜场回合和: 0, 回合和: 0,
    回合分布: {},          // 回合数 → 几场
    阵亡分布: {},          // 我方阵亡台数 → 几场
    先倒: {},              // 最先倒下的我方 → 几次
    我方伤害: {},          // 我方单位键 → 伤害合计
    敌方伤害: {},          // 敌方单位键 → 伤害合计
    明细: [],              // 逐场（对账用）：{种子, 条目下标, 结果, 回合数, 阵亡, 先倒, 我方伤害合计, 敌方伤害合计, 记录条数}
    错误: null,
  };
}

/** 一场战斗 → 小结（**全部从记录与最终单位读**，不另开一套账）。 */
function 调参一场小结(结果, 种子, 条目下标) {
  const 记录 = (结果 && 结果.记录) || [];
  const 我方伤害 = {}, 敌方伤害 = {};
  let 先倒 = null;
  for (const x of 记录) {
    if (!x) continue;
    const 伤 = Number(x.伤害) || 0;
    if (战报伤害类型.includes(x.类型) && x.伤害 != null) {
      if (x.单位方 === 'ally') 我方伤害[x.单位 || '?'] = (我方伤害[x.单位 || '?'] || 0) + 伤;
      else if (x.单位方 === 'enemy') 敌方伤害[x.单位 || '?'] = (敌方伤害[x.单位 || '?'] || 0) + 伤;
    } else if (x.类型 === '镜甲' && x.单位方 === 'enemy') {
      /* 镜甲反弹：`类型` 不在战报伤害白名单里（`84-反馈.js` 的口径），但**这一份血真的掉了**，
         所以「谁是威胁」这一栏把它算在**带镜甲的那台**头上（口径写在任务板里）。 */
      敌方伤害[x.单位 || '?'] = (敌方伤害[x.单位 || '?'] || 0) + 伤;
    }
    if (先倒 == null && x.目标方 === 'ally' && typeof x.目标剩余HP === 'number' && x.目标剩余HP <= 0) {
      先倒 = x.目标 || (x.目标位 != null ? ('位' + x.目标位) : null);
    }
  }
  let 阵亡 = 0;
  const 我方 = (结果 && 结果.我方) || [];
  for (const u of 我方) if (u.hp <= 0) 阵亡++;
  const 合计 = o => Object.values(o).reduce((a, b) => a + b, 0);
  return {
    种子, 条目下标,
    结果: (结果 && 结果.结果) || '败',
    回合数: (结果 && 结果.回合数) || 0,
    阵亡, 先倒, 我方伤害, 敌方伤害,
    我方伤害合计: 合计(我方伤害), 敌方伤害合计: 合计(敌方伤害),
    记录条数: 记录.length,
  };
}

function 调参并进(统计, 一场) {
  统计.总场++;
  if (一场.结果 === '胜') { 统计.胜场++; 统计.胜场回合和 += 一场.回合数; }
  统计.回合和 += 一场.回合数;
  统计.回合分布[一场.回合数] = (统计.回合分布[一场.回合数] || 0) + 1;
  统计.阵亡分布[一场.阵亡] = (统计.阵亡分布[一场.阵亡] || 0) + 1;
  if (一场.先倒) 统计.先倒[一场.先倒] = (统计.先倒[一场.先倒] || 0) + 1;
  for (const [k, v] of Object.entries(一场.我方伤害)) 统计.我方伤害[k] = (统计.我方伤害[k] || 0) + v;
  for (const [k, v] of Object.entries(一场.敌方伤害)) 统计.敌方伤害[k] = (统计.敌方伤害[k] || 0) + v;
  统计.明细.push({
    种子: 一场.种子, 条目下标: 一场.条目下标, 结果: 一场.结果, 回合数: 一场.回合数,
    阵亡: 一场.阵亡, 先倒: 一场.先倒, 记录条数: 一场.记录条数,
    我方伤害合计: 一场.我方伤害合计, 敌方伤害合计: 一场.敌方伤害合计,
  });
  return 统计;
}

/** **跑一场**：用 `simulate()`（和 Node 里对账用的是同一个函数）。
 *  种子 = `种子起 + (第几场 − 1)`（§3.2：从 1 开始连续）。 */
function 调参跑一场(场景, 第几场) {
  const s = 场景.设置;
  const 条目 = 调参本场条目(场景, 第几场);
  if (!条目) return null;
  const 种子 = s.种子起 + (第几场 - 1);
  const 选项 = { 波次: 编成波次到单位(条目.条目, 0) };
  const 调参 = 调参调参对象(s);
  if (Object.keys(调参).length) 选项.调参 = 调参;
  const r = simulate(调参出击(s), 敌方规格组(编成到单位(条目.条目, 0)), 调参方针(s), 种子, 选项);
  return 调参一场小结(r, 种子, 条目.下标);
}

/** 跑 `[从, 到)` 这些场（**同步**；界面用的是 `调参分批跑()`，一次只跑一批）。 */
function 调参跑批(场景, 统计, 从, 到) {
  for (let k = 从; k < 到; k++) {
    const 一场 = 调参跑一场(场景, k + 1);
    if (一场) 调参并进(统计, 一场);
  }
  return 统计;
}

/** ★ §3.4 的硬要求：**跑 100 场不卡死** —— 分批跑（默认每批 10 场），每批之后把主线程让出去。
 *  返回一个句柄：`{ 场景, 统计, 进度, 总场, 完, 继续(), 错误 }`。
 *  · 界面：`setTimeout(句柄.继续, 0)`（`每批后` 回调里排下一批）；
 *  · 测试 / Node：直接反复调 `句柄.继续()`（本机测试的 DOM 替身里 `setTimeout` 是空转的，
 *    所以「分批的进度与总场数」必须能**手工驱动**才测得出来）。 */
function 调参分批跑(原始设置, 每批, 每批后) {
  const 场景 = 调参场景(原始设置);
  const 批 = Math.max(1, Math.round(Number(每批) || 调参每批场次));
  const 句柄 = {
    场景, 统计: 调参新统计(), 进度: 0, 总场: 场景.设置.场次, 每批: 批, 完: false, 错误: null, 每批后: 每批后 || null,
  };
  if (!场景.用们.length) {
    句柄.错误 = '这一层没有这个类型的编成（换一层 / 换一个类型）。';
    句柄.完 = true;
    句柄.统计.错误 = 句柄.错误;
    return 句柄;
  }
  句柄.继续 = () => {
    if (句柄.完) return 句柄;
    const 到 = Math.min(句柄.总场, 句柄.进度 + 句柄.每批);
    调参跑批(场景, 句柄.统计, 句柄.进度, 到);
    句柄.进度 = 到;
    if (句柄.进度 >= 句柄.总场) 句柄.完 = true;
    if (句柄.每批后) 句柄.每批后(句柄);
    return 句柄;
  };
  return 句柄;
}

/** 一次跑完（同步；测试 / Node 用，界面**不用**它 —— 界面走 `调参分批跑()`）。 */
function 调参跑完(原始设置, 每批) {
  const 句柄 = 调参分批跑(原始设置, 每批 || 调参每批场次, null);
  let 护栏 = 0;
  while (!句柄.完 && 护栏++ < 100000) 句柄.继续();
  return 句柄;
}

/* ============================================================================
 * 五、看结果里的几个派生量（§3.4）
 * ========================================================================== */
const 调参占比 = (部分, 全部) => (!全部 ? 0 : Math.round(部分 / 全部 * 1000) / 10);

/** 统计 → 界面上那几行（纯派生，不改统计）。 */
function 调参结果摘要(统计) {
  const t = 统计 || 调参新统计();
  const 胜率 = t.总场 ? Math.round(t.胜场 / t.总场 * 1000) / 10 : 0;
  const 胜场平均回合 = t.胜场 ? Math.round(t.胜场回合和 / t.胜场 * 10) / 10 : 0;
  const 平均回合 = t.总场 ? Math.round(t.回合和 / t.总场 * 10) / 10 : 0;
  const 最大回合 = Math.max(MAX_TURN, ...Object.keys(t.回合分布).map(Number).filter(Number.isFinite), 0);
  const 回合分布 = [];
  for (let i = 1; i <= 最大回合; i++) 回合分布.push({ 回合: i, 场数: t.回合分布[i] || 0 });
  const 阵亡最大 = Math.max(0, ...Object.keys(t.阵亡分布).map(Number).filter(Number.isFinite));
  const 阵亡分布 = [];
  for (let i = 0; i <= 阵亡最大; i++) 阵亡分布.push({ 阵亡: i, 场数: t.阵亡分布[i] || 0 });
  const 排序 = o => Object.entries(o).map(([键, 值]) => ({ 键, 值 })).sort((a, b) => b.值 - a.值 || (a.键 < b.键 ? -1 : 1));
  const 我方总 = Object.values(t.我方伤害).reduce((a, b) => a + b, 0);
  const 敌方总 = Object.values(t.敌方伤害).reduce((a, b) => a + b, 0);
  return {
    总场: t.总场, 胜场: t.胜场, 胜率, 胜场平均回合, 平均回合,
    回合分布, 阵亡分布,
    先倒: 排序(t.先倒),
    我方伤害: 排序(t.我方伤害).map(x => Object.assign(x, { 占比: 调参占比(x.值, 我方总) })),
    敌方伤害: 排序(t.敌方伤害).map(x => Object.assign(x, { 占比: 调参占比(x.值, 敌方总) })),
    我方伤害合计: 我方总, 敌方伤害合计: 敌方总,
  };
}

/* ============================================================================
 * 六、存与交回（§3.5）：localStorage + 复制设置 + 恢复默认
 * ========================================================================== */

/** 读 localStorage（读不到 / 坏 JSON / 没这个环境 → null，**绝不抛**）。 */
function 调参读存档() {
  try {
    if (typeof localStorage === 'undefined' || !localStorage) return null;
    const t = localStorage.getItem(调参存档键);
    if (!t) return null;
    return 调参规整(JSON.parse(t));
  } catch (e) { return null; }
}
function 调参写存档(设置) {
  try {
    if (typeof localStorage === 'undefined' || !localStorage) return false;
    localStorage.setItem(调参存档键, JSON.stringify(调参规整(设置)));
    return true;
  } catch (e) { return false; }
}
function 调参清存档() {
  try { if (typeof localStorage !== 'undefined' && localStorage) localStorage.removeItem(调参存档键); return true; }
  catch (e) { return false; }
}

/** 人话改动清单（§3.5：「复制设置」= 人话改动清单 + JSON）。 */
function 调参改动清单(原始设置) {
  const s = 调参规整(原始设置);
  const 行 = [];
  const 敌 = s.敌人;
  const 有敌 = 敌.HP倍率 !== 1 || 敌.伤害倍率 !== 1 || 敌.装甲倍率 !== 1 || 敌.防御加成 !== 0;
  行.push(`· 敌人全局倍率：${有敌
    ? `HP ×${敌.HP倍率}、伤害 ×${敌.伤害倍率}、装甲 ×${敌.装甲倍率}、防御值 ${敌.防御加成 >= 0 ? '+' : ''}${敌.防御加成}`
    : '默认（HP ×1 / 伤害 ×1 / 装甲 ×1 / 防御值 +0，没改）'}`);
  const 覆键 = Object.keys(s.覆盖);
  行.push(`· 按敌人键覆盖：${覆键.length
    ? 覆键.map(k => {
      const c = s.覆盖[k];
      /* 只列**真的写了的项**（没写的回落成全局，不在这儿重复一遍） */
      const 项 = ['HP倍率', '装甲倍率', '威力倍率'].filter(x => c[x] != null).map(x => `${x.replace('倍率', '')} ×${c[x]}`);
      return `${k}（${项.join('、') || '空'}）`;
    }).join('；')
    : '没有'}`);
  const B键 = Object.keys(s.Boss);
  行.push(`· Boss 脚本：${B键.length
    ? B键.map(k => {
      const b = s.Boss[k], 基础 = (Boss脚本 && Boss脚本[k]) || {};
      return `${k}（大技能间隔 ${b.大技能间隔 != null ? b.大技能间隔 : 基础.大技能间隔}、伤害倍率 ×${b.伤害倍率 != null ? b.伤害倍率 : 基础.伤害倍率}`
        + `、半血阶段间隔 ${b.阶段间隔 != null ? b.阶段间隔 : (基础.阶段 && 基础.阶段[0] ? 基础.阶段[0].大技能间隔 : '—')}`
        + `、阶段倍率 ×${b.阶段倍率 != null ? b.阶段倍率 : (基础.阶段 && 基础.阶段[0] ? 基础.阶段[0].伤害倍率 : '—')}）`;
    }).join('；')
    : '没有（照正式表）'}`);
  行.push(`· 回合上限：${s.回合上限 != null ? `${s.回合上限}（只在调参室里生效）` : '默认（照引擎按档位那套）'}`);
  const 候选 = 调参候选(s);
  行.push(`· 关卡：第 ${调参层(s)} 层 ${s.类型}（${候选.length} 条；`
    + `${s.条目 != null && 候选.some(x => x.下标 === s.条目) ? `只打第 ${s.条目} 条` : '这一类全部'}）`);
  const 出击 = 调参出击(s);
  行.push(`· 我方：Lv${s.等级} ${出击.map(x => `${调参单位名(x.键)}@${位名(x.位)}`).join('、')}（共 ${出击.length} 台）`);
  行.push(`· 方针：${s.方针}`);
  行.push(`· 场次 ${s.场次}（种子 ${s.种子起} – ${s.种子起 + s.场次 - 1}，连续）`);
  return 行;
}
/** 出击名单里那一台的机师名（拿不到就退回键）。 */
function 调参单位名(键) {
  const t = tplOf(键);
  return (t && (t.pilot || t.mech)) || 键;
}

/** §3.5 的「复制设置」：一段文字 = 人话清单 + JSON（JSON 能被 `调参读回文本()` 读回）。 */
function 调参导出文本(原始设置) {
  const s = 调参规整(原始设置);
  return '【调参室 · 改动清单】（作者把这段发给 Claude / DSH；下面的 JSON 可以原样读回）\n'
    + 调参改动清单(s).join('\n')
    + '\n\n【调参室 JSON（键 ' + 调参存档键 + '，可直接读回）】\n'
    + JSON.stringify(s, null, 2);
}

/** 把导出的那段文字读回来（只认第一个 `{` 到最后一个 `}`；认不出来 → null，不抛）。 */
function 调参读回文本(文本) {
  const t = String(文本 == null ? '' : 文本);
  const i = t.indexOf('{'), j = t.lastIndexOf('}');
  if (i < 0 || j <= i) return null;
  try { return 调参规整(JSON.parse(t.slice(i, j + 1))); } catch (e) { return null; }
}

/* ---------- 模型对象（界面与测试都读它；**它自己不碰 DOM**） ---------- */
const 调参室模型 = {
  键: 调参存档键,
  版本: 调参版本,
  设置: 调参默认设置(),
  结果: null,               // 最近一次跑批的句柄
  导出文本: null,           // 「复制设置」上一次导出的那段文字（界面上画在 textarea 里）
  读回框: '',               // 界面上那个「读回」文本框里的内容（测试可以自己塞）
  提示: '',
  默认: 调参默认设置,
  规整: 调参规整,
  当前调参() { return 调参调参对象(this.设置); },
  /** 改设置（补丁）→ 存 localStorage → 返回规整后的设置 */
  设(补丁) {
    const o = (补丁 && typeof 补丁 === 'object') ? 补丁 : {};
    const 深 = k => (o[k] && typeof o[k] === 'object' && !Array.isArray(o[k]))
      ? Object.assign({}, this.设置[k], o[k]) : o[k];
    const 新 = Object.assign({}, this.设置, o, {
      敌人: 深('敌人') || this.设置.敌人,
      覆盖: 深('覆盖') || this.设置.覆盖,
      Boss: 深('Boss') || this.设置.Boss,
    });
    this.设置 = 调参规整(新);
    this.提示 = '';
    调参写存档(this.设置);
    return this.设置;
  },
  载入() { const s = 调参读存档(); if (s) this.设置 = s; return this.设置; },
  保存() { return 调参写存档(this.设置); },
  恢复默认() {
    this.设置 = 调参默认设置();
    this.结果 = null; this.导出文本 = null; this.读回框 = ''; this.提示 = '';
    调参清存档();
    return this.设置;
  },
  清结果() { this.结果 = null; this.导出文本 = null; return null; },
  场景() { return 调参场景(this.设置); },
  统计() { return (this.结果 && this.结果.统计) || 调参新统计(); },
  /** 同步跑一次（测试 / Node 用） */
  跑完() { this.结果 = 调参跑完(this.设置); return this.结果; },
  /** 分批跑（界面用；`每批后` 里排下一批） */
  分批跑(每批后) { this.结果 = 调参分批跑(this.设置, 调参每批场次, 每批后); return this.结果; },
  导出() { this.导出文本 = 调参导出文本(this.设置); return this.导出文本; },
  读回(文本) {
    const s = 调参读回文本(文本 != null ? 文本 : this.读回框);
    if (!s) { this.提示 = '读不回来：没找到能认的调参 JSON。'; return null; }
    this.设置 = s; this.结果 = null; this.导出文本 = null; this.读回框 = ''; this.提示 = '';
    调参写存档(s);
    return s;
  },
};

