/* ---------- overwatch（方案 5.2）：第一个行动的我方单位会被它先打一下 ---------- */
function runOverwatch(ally, ctx) {
  for (const e of livingOf('enemy', ctx)) {
    if (!hasOverwatch(e) || e.overwatchFiredTurn === ctx.turn) continue;
    if (ally.hp <= 0) return;
    const action = enemyAction(e, ctx);
    if (!action) continue;
    e.overwatchFiredTurn = ctx.turn;
    pushLog(ctx, `〔压制射击〕${e.name} 抢先开火`, Object.assign({ 类型: '压制射击', 单位: e.key, 目标: ally.key }, 谁(e), 谁目标(ally)));
    resolveAction(e, action, ctx);
  }
}

/* ---------- 一个回合 ---------- */
function runTurn(ctx) {
  pushLog(ctx, `—— 第 ${ctx.turn} 回合 ——`, { 类型: '回合' });
  for (const u of actionOrder(ctx)) {
    if (ctx.result) return;
    if (u.hp <= 0) continue;
    if (u.side === 'ally') runOverwatch(u, ctx);     // 我方第一个行动的人会被压制射击
    if (u.hp <= 0) continue;
    actOnce(u, ctx);
    drainAgain(ctx);                                 // 「再动」「连斩」的队友立刻行动
    ctx.result = checkResult(ctx);
    if (ctx.result) return;
  }
}

/* ---------- 再动 / 连斩：被点名的队友立刻行动一次 ---------- */
function drainAgain(ctx) {
  while (ctx.again.length) {
    const g = ctx.again.shift();
    if (g.hp <= 0 || ctx.result) continue;
    actOnce(g, ctx);
    ctx.result = checkResult(ctx);
  }
}

/* ---------- 胜负（方案 3.2） ---------- */
function checkResult(ctx) {
  const alliesAlive = livingOf('ally', ctx).length;
  const enemiesAlive = livingOf('enemy', ctx).length;
  if (!enemiesAlive) return { 结果: '胜', 原因: '敌方全灭' };
  if (!alliesAlive) return { 结果: '败', 原因: '我方全灭' };
  return null;
}

/* ---------- 回合结束：buff / debuff / 冷却计时减 1（方案 3.2） ---------- */
function endTurn(ctx) {
  for (const u of livingUnits(ctx)) {
    for (const e of u.weapons) if (e.cd > 0) e.cd--;
    u.buffs = (u.buffs || []).filter(b => (b.剩余 = (b.剩余 == null ? 1 : b.剩余) - 1) > 0);
    /* ★ **2026-10-11 新加的 debuff 衰减**（势力特色第六件「秘银」带出来的）：
       以前只衰减 `buffs`，`debuffs`（破防 / 破甲那一类，`20-战斗计算.js:43-44` 的 `breakSum()` / `defMul()`）
       **没有任何生产者，也一直不衰减**。这一版把规则补齐成和 buffs **完全一样**：
       `剩余` 默认 1、每回合结束 −1、减到 0 就摘掉。
       ★ 2026-10-11 第二轮：**敌方武器 debuff** 也会挂 `debuffs`（`战斗结构.敌方debuff`）——
         里面 `armorCut`（削装甲，`effArmor()` 减的那一项）是**累加**在 `u.armorCut` 上的标量，
         所以到期时必须**还回去**（和 `barrierLeft` 一样的簿记写法）。
       ★ 没有 debuff 的战斗 `debuffs` 是空数组 → 这一行空转，既有战斗的数值一个字节都不变
         （`tests/sim.js` 的胜率表与公式对照盯着这一条）。 */
    u.debuffs = (u.debuffs || []).filter(b => {
      const 还活着 = (b.剩余 = (b.剩余 == null ? 1 : b.剩余) - 1) > 0;
      if (!还活着 && b.armorCut) u.armorCut = Math.max(0, (u.armorCut || 0) - b.armorCut);
      return 还活着;
    });
    u.defending = false;
  }
  ctx.当前战术 = null;
  ctx.本回合防御气势 = 0;
  for (const u of (ctx.allies || [])) if (u) u.掩护盾 = 0;
  /* 势力特色（框架在 `72-势力.js`）：回合结束的钩子。
     第一件 = 卫星国防军 SEED 的「每回合 +5」—— 战棋挂在**我方阶段开始**（17b:220-226），
     我们挂在回合结束：第 N 回合结束 = 第 N+1 回合开始，加点与次数和战棋一致。 */
  势力回合结束(ctx);
  if (typeof 战术卡牌开 === 'function' && 战术卡牌开(ctx)) {
    for (const c of (ctx.战术手牌 || [])) {
      if (c && c.当前冷却 > 0) c.当前冷却 = Math.max(0, c.当前冷却 - 1);
    }
    if (typeof 检查条件发牌 === 'function') {
      检查条件发牌(ctx, '回合结束', { 回合: ctx.turn, _内部自动: true });
    }
  }
}

/* ---------- 开场 ----------
 * `选项`（可选）：`{ 波次: [{回合, 来:[{键, 等级}…]}…], 方针: 开局那一回合的全队方针 }` ——
 *   波次表 = 敌方增援（编成表里配，`70-编成.js` 的 `编成波次到单位()` 把「第几回合来哪几台」换算好；
 *   不传 = 这一场没有增援，行为和以前一个字节都不变）；
 *   `选项.方针` = `simulate()` 的按回合方针表在第一回合那一条（§1.6：表里没写的回合沿用上一回合）。
 *   ★ `选项.调参` = **调参室专用的注入口**（§3.6 第 6 条；形状与口径全在 `95-调参室.js` 的文件头）：
 *     传了才把敌人全局倍率 / 按敌人键覆盖 / Boss 脚本覆盖 / 回合上限**临时**加到这一场上；
 *     **不传 = 与改动前逐字相同**（调参室之外的任何调用点都不会传它）。
 * 第 4 个参数是**单位开关表**（`设单位开关()` 吃的形状）：`{ 位: {保留大招, TRANSAM, 本回合开TRANSAM} }`。 */
function 开局(我方编成, 敌方编成, 种子, 单位开关表, 选项) {
  const rng = mulberry32((种子 >>> 0) || 1);
  const ctx = {
    turn: 1, 种子: (种子 >>> 0) || 1, rng,
    allies: makeUnits(我方编成, 'ally'), enemies: makeUnits(敌方编成, 'enemy'),
    /* ★ 全队方针（§1.3 第 1 条）：**每一场新战斗开始时是「全军突击」**（Claude 定，§6 第 1 条）——
       这样 `simulate()`、平衡工具和同种子复现都有固定起点。`选项.方针` 只有 `simulate()` 的
       按回合表会传（第一回合那一条），不传 = 全军突击。 */
    方针: 默认方针(),
    /* ★ 杠杆 ④：这一场的回合上限（按敌方阵容里最硬的那一档现算），见 `71-改动.js` 的 `难度调整.回合上限`。
       传**规格**（`{键, 位, 等级}`）就行 —— `回合上限()` 只看键；不重复造一遍单位。 */
    回合上限: 回合上限(敌方编成),
    气势: Number(气势总攻参数().开场气势) || 0,
    预约战术: null,
    当前战术: null,
    本回合防御气势: 0,
    累计防御气势: 0,
    全队憋大招: false,
    曾满气势回合: null,
    自然气势已加回合: 1,
    log: [], result: null, again: [],
    /* `强化` = 敌方强度倍率（`70-编成.js` 的 `编成波次到单位()` 按编成条目的层 × 梯队算好的一程，
       见 `71-改动.js` 的「难度调整」段）；不传 = 1 = 与改前逐字相同。 */
    波次: ((选项 && 选项.波次) || []).map(w => ({ 回合: w.回合, 来: (w.来 || []).map(e => ({ 键: e.键, 等级: e.等级, 强化: e.强化 != null ? e.强化 : 1, 层: e.层 != null ? e.层 : null })) })),
  };
  if (选项 && 选项.方针) 设方针(ctx, 选项.方针);
  /* ★ 2026-10-12 调参室（作者亲手调难度的第 3 件，`协作/方向调整-全队方针与反馈.md` §3.3 / §3.6 第 6 条）：
     **唯一**的注入口 = `选项.调参`（形状与全部口径写在 `95-调参室.js` 的文件头）。
     倍率**不许**写进 `71-改动.js` 的正式表 —— 那会污染正常游戏与「同种子逐字不变」。
     ★ **不传 `选项.调参` 时这一行什么都不做**：`ctx` 上不会多出任何字段，
       走的代码路径与改动前逐字相同（硬验收见 `tests/tuner.js` 第 [1] 段 + 仓库外的「调参室前快照」）。 */
  if (选项 && 选项.调参) { ctx.调参 = 选项.调参; 应用调参(ctx, ctx.调参); }
  /* 藏品（方案第 7 节 · 作者 2026-10-10 要做）：把 `肉鸽.RUN.藏品` 应用到**我方**出击机体
     （HP / 装甲 / 命中 / 暴击 / 闪避 / 伤害 / 减伤）和**敌方**（命中 / 装甲减益）。
     实现在 `93-藏品.js`；`肉鸽.RUN` 为空（菜单里的固定测试战斗、simulate 的单测）时它直接返回，
     所以那些战斗一个字节都不变。★ 这一版新加的接线，出处写在 93-藏品.js 的文件头。 */
  藏品开战(ctx.allies, ctx.enemies);
  /* ★ 2026-10-13（词条层 · `2-N5`【战术烟幕阵】）：整场浓雾之类的**全场效果**在这里铺一次
     （双方都挂 —— 作者拍板「对称」）。没有写 `{键:'全员命中'}` 的编成 → 空转，一个字段都不多。 */
  应用全场词条(ctx);
  for (const u of livingUnits(ctx)) {
    /* 开场冷却**只由 readyTurn 管**（= 1 + startCdOf(w)，规则见 13-武器可用性.js）：
       开场冷却 3 回合 = 第 4 回合才能用；普通冷却 cd 开场一律是 0。 */
    u.weapons = u.weapons.map(e => Object.assign({}, e, { cd: 0 }));
    u.holdUlt = false;
    u.掩护盾 = 0;
    /* 天人 TRANS-AM 的单位级开关（2026-10-11）：默认自动、本回合没点开；
       紧接着的 `设单位开关(ctx, 单位开关表)` 会按表覆盖掉。 */
    u.TRANSAM手动 = false; u.本回合开TRANSAM = false;
  }
  设单位开关(ctx, 单位开关表);
  pushLog(ctx, `战斗开始：我方 ${ctx.allies.length} 台 vs 敌方 ${ctx.enemies.length} 台`, { 类型: '开始' });
  /* 势力特色（作者 2026-10-10；框架在 `72-势力.js`）：开场钩子 —— 本场状态清零 / 开场一次性效果。
     放在最后，所以「战斗开始」永远是第 1 条记录（测试与单点查询的逐条记录按这个数行）。 */
  势力开局(ctx);
  if (选项 && typeof 选项 === 'object' && 选项.战术卡牌 !== undefined) {
    ctx.选项 = Object.assign({}, ctx.选项, { 战术卡牌: !!选项.战术卡牌 });
  }
  if (typeof 战术卡牌开 === 'function' && 战术卡牌开(ctx) && typeof 生成队伍牌池 === 'function') {
    ctx.战术卡牌开 = true;
    if (选项 && Number.isFinite(Number(选项.初始气势))) {
      ctx.气势 = Number(选项.初始气势);
      ctx.战术卡牌写日志 = true;
    } else if (选项 && 选项.战术卡牌 === true) {
      const 默气 = Number(战术卡牌参数().初始默认气力);
      ctx.气势 = Number.isFinite(默气) ? 默气 : 25;
      ctx.战术卡牌写日志 = true;
    }
    const 池 = 生成队伍牌池(ctx.allies, Object.assign({ 补齐基础激励: true }, 选项 || {}));
    ctx.战术牌池 = 池.全部牌池;
    ctx.战术手牌 = 池.初始手牌;
    ctx.待触发战术牌 = 池.待触发牌;
    ctx.已打出战术牌 = [];
    ctx.待写发牌日志 = [];
    ctx.累计未命中段数 = 0;
  }
  return ctx;
}

/* ---------- 敌人意图（方案 5.3）：纯函数，不改任何状态，给界面在指令阶段显示 ----------
 * 说明：这里算的是「如果现在开打，这个敌人会打谁」。目标中途倒下或被**嘲讽**勾走时就按规则改打，
 * 这一点在行动阶段由引擎自己处理。
 * ★ 2026-10-12（§1.6）：**按当前方针算** —— 全军防御 / 前守后攻的前排这一回合按防御结算
 *   （防御值 +50，`20-战斗计算.js` 的 `按防御结算()`），所以敌人挑谁打、期望多少都会跟着变。
 *   默认（全军突击）这条一个字节都不影响 → 「意图和实际行动一致」的现有断言照旧成立。 */
function 算意图(ctx) {
  return livingOf('enemy', ctx).map(u => {
    /* Boss 脚本（61-Boss.js）也在这里生效：间隔 / 阶段会影响「这一回合它要做什么」。
       bossAction 是纯函数，所以指令阶段读它不会改动战斗状态。 */
    const a = bossAction(u, ctx);
    const bp = Boss参数(u);
    /* ★ 2026-10-11 新加：**这一发会打到哪几个位**（作者：「指令阶段的敌人意图要显示将打哪几个位」）。
       范围武器用 `areaSlots()`（`30-射程.js`）按落点算；`pickAreaTarget()` 已经给了一份 `hit`，优先用它。
       单体武器只有一个位。玩家因此能一眼看出「换位到底躲不躲得掉」。 */
    let 落点们 = [];
    if (a && a.weapon) {
      if (isAreaKind(rangeKindOf(a.weapon))) {
        const 位 = a.slot != null ? a.slot : (a.target ? a.target.slot : null);
        if (a.hit && a.hit.length) 落点们 = a.hit.map(t => t.slot);
        else if (位 != null) 落点们 = areaSlots(a.weapon, rowOfSlot(位), colOfSlot(位));
        落点们 = [...new Set(落点们)].sort((x, y) => x - y);
      } else if (a.target) 落点们 = [a.target.slot];
    }
    return {
      单位: u.key, 单位位: u.slot, 名称: u.name,
      武器: a && a.weapon ? a.weapon.name : null,
      目标: a && a.target ? a.target.key : null,
      目标位: a && a.target ? a.target.slot : null,
      目标名: a && a.target ? a.target.name : null,
      期望: a && a.expected ? Math.round(a.expected) : 0,
      压制射击: hasOverwatch(u),
       /* 直射打这个后排位**现在被挡着吗**（阻挡位里还有活人 → 命中 −20；打得到，只是难打）。
          界面上要跟这条规则一致：意图里写「被挡 −20」（作者 2026-10-10 拍板）。 */
      被挡: !!(a && a.被挡),
      命中修正: a && a.被挡 ? -20 : 0,
      落点们,                                   // ★ 2026-10-11：这一发会打到哪几个位（可躲形状用）
      形状: a && a.weapon ? (isAreaKind(rangeKindOf(a.weapon)) ? (a.weapon.area || 'row') : '单格') : null,
      /* Boss：这一发是不是大技能、现在第几阶段、还是这一回合在蓄力（界面上看得见节奏） */
      大技能: !!(a && a.大技能),
      /* ★ 2026-10-11 新加：这一发是不是**大招**（我方 unlock ≥ 20 的那批 + 敌方 `战斗结构.敌方大招`
         装上去的那批，判定在 `50-AI.js` 的 `isUltimate()`）。界面上标 ★，玩家能看到「这一回合要扛住什么」。 */
      大招: !!(a && a.weapon && isUltimate(a.weapon)),
      Boss: !!bp,
      Boss阶段: bp ? bp.第几阶段 : null,
      蓄力: !a && !!bp,
    };
  });
}

/* ---------- 打一个回合 ---------- */
function 打一回合(ctx) {
  const 起 = ctx.log.length;
  回合开始(ctx);
  runTurn(ctx);
  if (!ctx.result) {
    /* ★ 杠杆 ④（`71-改动.js` 的 `难度调整.回合上限`）：上限随敌方档位收紧，`ctx.回合上限` 在 `开局()` 里算好 */
    const 上限 = ctx.回合上限 || MAX_TURN;
    if (ctx.turn >= 上限) ctx.result = { 结果: '败', 原因: `第 ${上限} 回合结束还没分出胜负（按撤退处理）` };
    else {
      endTurn(ctx);
      ctx.turn++;
      if (气势总攻开() && ctx.turn >= 2 && ctx.自然气势已加回合 !== ctx.turn) {
        ctx.自然气势已加回合 = ctx.turn;
        加气势(ctx, Number(气势总攻参数().每回合自然加) || 10);
      }
    }
  }
  return ctx.log.slice(起);
}

/* ---------- simulate（方案第 9 节 M1 的接口；一整场） ----------
 * `方针` 三种写法（§1.6，作者 2026-10-12 拍板）：
 *   ① 一个方针（整场不变）：`'全军突击'` / `'全军防御'` / `{ 类型: '集中攻击', 目标位: 4 }`；
 *   ② **按回合的表**：`{ 1: '全军防御', 2: '全军突击' }` —— 表里没写的回合**沿用上一回合**
 *      （和「保持到改为止」一致，§1.3 第 1 条）；
 *   ③ `{}` / `null` / 不传 = **整场全军突击**。
 * ★ 这条必须保证（§1.6 / §1.8 第 1 条）：传 `{}` 时结果和改动前「全员进攻」**逐字一致**
 *   （守护 / 换位被删，不影响全员进攻的路径）。 */
function 是方针对照表(方针) {
  if (!方针 || typeof 方针 !== 'object' || Array.isArray(方针)) return false;
  if (方针.类型 != null || 方针.目标位 != null) return false;         // 一条方针（含类型 / 目标位）
  return Object.keys(方针).some(k => /^\d+$/.test(k));                // 键是回合号
}
/** 按回合取方针：取「≤ 回合号的最后一条」；表里一个都没有 → 全军突击。 */
function 第几回合的方针(方针, 回合) {
  if (!是方针对照表(方针)) return 方针 || {};
  const 键 = Object.keys(方针).filter(k => /^\d+$/.test(k)).map(Number).sort((a, b) => a - b);
  let 取 = null;
  for (const k of 键) {
    if (k > 回合) continue;
    const v = 方针[String(k)] != null ? 方针[String(k)] : 方针[k];
    if (v === '总攻' || v === '掩护') continue;
    if (v && typeof v === 'object' && v.类型 == null && (v.战术 != null || v.全队憋大招 != null)) continue;
    取 = v;
  }
  return 取 == null ? {} : 取;
}

function 第几回合的战术(方针, 回合) {
  if (!是方针对照表(方针)) return null;
  const v = 方针[String(回合)] != null ? 方针[String(回合)] : 方针[回合];
  if (!v) return null;
  if (v === '总攻' || v === '掩护') return { 战术: v };
  if (typeof v === 'object') {
    const 出 = {};
    if (v.战术 === '总攻' || v.战术 === '掩护') 出.战术 = v.战术;
    if (v.全队憋大招 !== undefined) 出.全队憋大招 = !!v.全队憋大招;
    return Object.keys(出).length ? 出 : null;
  }
  return null;
}

function simulate(我方, 敌方, 方针, 种子, 选项) {
  const 表 = 是方针对照表(方针) ? 方针 : null;
  const 起手 = 第几回合的方针(方针, 1);
  const ctx = 开局(我方, 敌方, 种子, null, Object.assign({ 战术卡牌: false }, 选项 || {}, { 方针: 起手 }));
  /* 按回合的表：每个回合开始前换一次（**没写的回合沿用上一回合** = 表里 ≤ 本回合的最后一条）——
     写进 `ctx.当局方针`，由 `回合开始()` 里的 `方针回合()` 落地（和玩家在指令阶段改方针同一个位置）。 */
  ctx.当局方针 = 表 ? 起手 : null;
  let 护栏 = 0;
  /* ★ 调参室：`选项.调参.回合上限` 可以把这一场的上限调大（试「拖长会怎样」）——
     护栏跟着 `ctx.回合上限` 走，否则会被旧的 `MAX_TURN + 2` 提前砍断。
     **没有调参时 `ctx.回合上限 ≤ MAX_TURN`（难度调整那张表最大 12）→ 护栏顶恒等于 14，与改动前逐字相同。** */
  const 护栏顶 = Math.max(MAX_TURN, ctx.回合上限 || MAX_TURN) + 2;
  while (!ctx.result && 护栏++ < 护栏顶) {
    if (表) {
      ctx.当局方针 = 第几回合的方针(表, ctx.turn);
      const 战 = 第几回合的战术(表, ctx.turn);
      if (战) {
        if (战.全队憋大招 !== undefined) 设全队憋大招(ctx, 战.全队憋大招);
        if (战.战术) ctx.当局战术 = 战.战术;
      }
    }
    打一回合(ctx);
  }
  if (!ctx.result) ctx.result = { 结果: '败', 原因: '超出回合上限' };
  pushLog(ctx, `战斗结束：${ctx.result.结果}（${ctx.result.原因}）`, { 类型: '结束' });
  return {
    结果: ctx.result.结果, 原因: ctx.result.原因, 回合数: ctx.turn,
    记录: ctx.log, 我方: ctx.allies, 敌方: ctx.enemies, 种子: ctx.种子, ctx,
  };
}
