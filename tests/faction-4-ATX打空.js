/* ========== [12] ATX · 「打空」按段 → 减大招冷却（作者 2026-10-11 拍板「按段」） ==========
 * 作者原话（`协作/势力特色落地决定.md` 第 5 条）：
 *   「**可以试试看按段，如果太过分继续加初始CD就行**」——
 *   「打空」= 武器没打中；**按段计**：多段武器（`w.hits > 1`）逐段判定，
 *   **每一段未命中都算一次「打空」**（不是「整次攻击全空才算一次」）。
 * 逐字出处（战棋 `Claude hand off/src/js/`，只读，一个字节都没改）：
 *   `17b-角色机制.js:73-91`（`EVADE_START = 10` :76、`evadeN` / `evadeCdCut` :77-78、
 *     每次打空 `cutCd(u, 1)` :79-86、余量一次性抵冷却 :87-91）、
 *   `03-能力与减免管线.js:17`（`gamblerSense` 的逐字描述）、
 *   `13-武器可用性.js:9,12-16`（`cutCd` / `readyTurnOf`）、
 *   `04-武器与机体.js:188`（左轮打桩机 `startCd:10 / cd:3 / evadeCd:true / hits:12`）← 复制件 `10-数据.js:207`。
 * ★ 「整次全空才算一次」的旧口径 ← `协作/势力特色.md:53`（作者这一条改的就是它）。
 * 这一段按任务书的七件事来：① 参数与战棋逐字对账（含「按段」这条是作者改的）；
 *   ② **多段逐段判定**：1 段中 1 段空 = 记 **1** 次（不是 0 也不是 2）；
 *   ③ 全部打空 = 记 `hits` 次；④ 打空**真的减大招冷却**（贴冷启前后的回合数字）；
 *   ⑤ **初始 CD / 每回合上限**真的生效；⑥ **只对我方生效**；⑦ 同种子两次逐字相同。 */
console.log('\n[12] ATX · 「打空」按段 → 减大招冷却（作者 2026-10-11：「可以试试看按段，如果太过分继续加初始CD就行」）');
{
  const p = G.势力特色['ATX'];
  const 打空录 = (ctx, 单位) => ctx.log.filter(x => x.类型 === '势力' && x.特色 === '赌徒的直觉'
    && x.结果 === '打空' && (!单位 || x.单位 === 单位));
  const 造靶 = () => G.makeUnit('bluefish', 'enemy', 0, 1);        // HP 240000：打不死，能一直当靶子
  /** 用一串**指定的随机数**打一发（`resolveAttack()` 的取数顺序：每段先判命中，命中后才判暴击）。 */
  const 一枪 = (ctx, att, w, 队列, t) => {
    const 靶 = t || 造靶();
    let i = 0;
    const 旧 = ctx.rng;
    ctx.rng = () => (i < 队列.length ? 队列[i++] : (队列.length ? 队列[队列.length - 1] : 0));
    const r = G.resolveAttack(att, 靶, w, ctx, {});
    ctx.rng = 旧;
    return r;
  };
  /** 把这一把武器的**结算命中率**调到 50%（这样「中 / 空」各用一个固定随机数就能稳住）。 */
  const 调到五十 = (ctx, att, w, 靶) => {
    const h0 = G.hitRate(att, w, 靶, { baseHit: 0, turn: ctx.turn }).raw;
    w.hit = 50 - h0;
    return G.hitRate(att, w, 靶, { baseHit: w.hit, turn: ctx.turn }).hit;
  };
  /** 一把「必定打空」的枪（结算命中率 0：`rng() * 100 < 0` 永远为假）—— 用来精确数「段」。 */
  const 必空枪 = () => ({ name: '测试·必空枪', fire: 'direct', hit: -999, dmgType: '物理', power: 1, stat: '射击', range: [1, 1], hits: 1, upgrades: [] });

  /* ---- (a) 参数与战棋逐字对账（「按段」这条是作者改的） ---- */
  const 对账 = [
    ['余量起算', 'EVADE_START', 10, '17b-角色机制.js:76'],
    ['每段减冷却', 'cutCd(u, 1)', 1, '17b-角色机制.js:83'],
    ['特技', "abilOn(u,'gamblerSense') / ABIL.gamblerSense", 'gamblerSense', '03-能力与减免管线.js:17'],
    ['武器标记', 'u.weapons.some(w => w.evadeCd && u.lv >= w.unlock)', 'evadeCd', '17b-角色机制.js:81'],
  ];
  for (const [字段, 战棋名, 值, 出处] of 对账) {
    if (p[字段] === 值) ok(`${字段} = ${JSON.stringify(p[字段])}（战棋 ${战棋名}）　出处 ${出处}`);
    else bad(`${字段} = ${JSON.stringify(p[字段])}，战棋是 ${JSON.stringify(值)}（${出处}）`);
  }
  /* ★ 两个「初稿·待作者调」的常量：默认值 + 理由（**不自己发明平衡数值**） */
  if (p.初始CD === 0 && p.每回合上限 === 0 && p.初稿 === true) {
    ok(`两个常量都是初稿且默认「不动数据」：\`初始CD = ${p.初始CD}\`（= 照数据，左轮打桩机的开场冷却 10 在 \`10-数据.js:207\` 原样）、\`每回合上限 = ${p.每回合上限}\`（= 不封顶，照战棋 \`17b:79-86\` 全场累计、没有每回合上限）`);
  } else bad(`两个初稿常量的默认值不对：初始CD ${p.初始CD} / 每回合上限 ${p.每回合上限} / 初稿 ${p.初稿}`);
  info(`出处登记：${p.出处}`);
  info(`未接项 ${p.未接项.length} 条（照抄登记、这一版不接）：${p.未接项.map(x => x.项.split('：')[0].split('（')[0]).join('；')}`);
  if (p.未接项.length === 6 && p.未接项.every(x => x.项 && x.战棋 && x.为什么不接 && x.换义建议)) {
    ok('6 条未接项（烟雾 / 迷彩 / 赌神与四个个人特技 / 双势力 / 随机段数 / 反击那一半）'
      + '都写了战棋出处、不接的理由与**换义建议** —— 位置类（烟雾 / 迷彩）交作者拍板，没有自己发明数值；'
      + '★ 「好运加护」已按作者点头接上（从这张表里移出 → 本表上面的 `已接好运加护`）');
  } else bad(`未接项登记不完整：${JSON.stringify(p.未接项.map(x => x.项))}`);

  /* 「按段」这条**是作者改的**：把战棋的旧口径与我们的新口径都摆出来 */
  const 战棋根12 = join(ROOT, '..', 'mecha-tactics', 'Claude hand off', 'src', 'js');
  if (existsSync(战棋根12)) {
    const 战棋源12 = f => readFileSync(join(战棋根12, f), 'utf8');
    const 逐字 = [
      ['17b-角色机制.js', 'const EVADE_START = 10;', 'EVADE_START（余量起算）逐字'],
      ['17b-角色机制.js', 'const evadeCdCut = u => Math.max(0, evadeN(u) - EVADE_START);', '余量的逐字算法'],
      ['17b-角色机制.js', 'u.evN = evadeN(u) + 1; u.evB = BATTLE_ID;', '记账（本场累计）逐字'],
      ['17b-角色机制.js', 'cutCd(u, 1);', '每次打空减 1 点冷却（逐字）'],
      ['17b-角色机制.js', 'if (cut >= w.cd) w.cdLeft = 0; else if (cut > 0) w.cdLeft = Math.max(0, w.cdLeft - cut);', '余量抵冷却（逐字）'],
      ['13-武器可用性.js', 'if (w.cdLeft > 0) w.cdLeft = Math.max(0, w.cdLeft - n);', 'cutCd 里减普通冷却那一行'],
      ['13-武器可用性.js', 'return et + sc - (u.cdCutB === BATTLE_ID ? u.cdCut : 0);', '开场冷却被 cdCut 抵掉（readyTurnOf）'],
      ['03-能力与减免管线.js', "gamblerSense:{name:'赌徒的直觉'", '能力 key 逐字'],
      ['17-战斗执行.js', "Hooks.emit('strikeResolved', {att, def, w, hit:nh > 0", '战棋旧口径：多段只在**循环外**发一次（整次全空才算一次）'],
    ];
    let 缺 = [];
    for (const [f, 片段, 说明] of 逐字) {
      if (!战棋源12(f).includes(片段)) 缺.push(`${f}：${片段}`);
      else info(`战棋 ${f} 里确实有「${片段}」（${说明}）`);
    }
    if (!缺.length) ok(`与战棋源码逐字对账：${逐字.length} 条片段全在（只读旧仓库，一个字节都没改）`);
    else bad(`战棋源码里找不到这些片段：${缺.join('；')}`);
    /* 数据也对一遍：左轮打桩机的四个键（startCd / cd / evadeCd / unlock）逐字 */
    const 数据源 = 源码(join('src', 'js', '10-数据.js'));
    const 桩数据 = ['左轮打桩机', 'hits:12', 'step:10', 'cd:3', 'unlock:20', 'startCd:10', 'evadeCd:true'].filter(s => 数据源.includes(s));
    if (桩数据.length === 7) ok(`数据逐字对账：\`10-数据.js\` 里左轮打桩机带着 ${桩数据.slice(1).join(' / ')}（照抄战棋 04-武器与机体.js:188，一个字没改）`);
    else bad(`数据里左轮打桩机的字段不全：${JSON.stringify(桩数据)}`);
  } else info('（本机没有旧仓库 `F:\\DSH-mecha\\mecha-tactics` → 跳过与战棋源码的逐字核对，只按上面的出处行号对账）');
  /* 我们自己这一侧：新钩子确实发在「逐段判定」的循环里（不是整次攻击之后） */
  const 计算源 = 源码(join('src', 'js', '20-战斗计算.js'));
  const 未中段 = 计算源.split('第 ${i + 1} 段（${q}%）未中')[1] || '';
  if (未中段.includes('势力逐段未命中(ctx, att, def, w, { 段号: i + 1, 段数: hits')) {
    ok('`20-战斗计算.js` 的**逐段未命中分支**里发了 `势力逐段未命中(…, {段号: i + 1, 段数: hits…})` —— 这就是作者要的「按段」（战棋旧口径是整次攻击只发一次）');
  } else bad('没有在逐段循环里发新钩子（那就退化成战棋的「整次全空才算一次」了）');
  for (const 文件 of [join('src', 'js', '72-势力.js'), join('src', 'js', '71-改动.js'), join('src', 'js', '20-战斗计算.js'), join('src', 'js', '60-战斗.js')]) {
    if (!/Math\.random/.test(源码(文件))) ok(`${文件} 里一处 \`Math.random\` 都没有`);
    else bad(`${文件} 里出现了 Math.random`);
  }

  /* 成员：按 `tags.势力` 查，并与 `协作/势力特色.md` 第 1.2 节的成员表逐行对 */
  const 去括号 = s => String(s).replace(/（.*$/, '').trim();
  const 数据名册 = G.ALLY_T.filter(t => t.tags.势力 === 'ATX').map(t => ({ 键: t.mech, 机师: t.pilot, 分类: t.tags.战斗分类 }));
  const 文档段 = 源码(join('协作', '势力特色.md')).split('### 1.2 这个势力有哪些角色')[1].split('### 1.3')[0];
  const 文档名册 = 文档段.split('\n')
    .map(l => l.match(/^\|\s*(A\d)\s*\|\s*([^|]+?)\s*\|[^|]*\|\s*([^|]+?)\s*\|/))
    .filter(Boolean)
    .map(m => ({ 键: m[1], 机师: m[2], 分类: 去括号(m[3]) }));
  if (数据名册.length === 5 && JSON.stringify(数据名册) === JSON.stringify(文档名册)) {
    ok(`数据里（\`tags.势力 === 'ATX'\`）正好 5 人，且与 \`协作/势力特色.md\` 第 1.2 节的成员表**逐行一致**：${数据名册.map(x => `${x.键} ${x.机师}(${x.分类})`).join('、')}`);
  } else bad(`ATX 成员表对不上：数据 ${JSON.stringify(数据名册)} vs 文档 ${JSON.stringify(文档名册)}`);
  /* 谁吃这条特色：按数据里的 `abilities` 查（**不手写名单**） */
  const 吃得 = 数据名册.map(x => x.键).filter(k => G.有赌徒直觉(G.makeUnit(k, 'ally', 0, 20), p));
  if (JSON.stringify(吃得) === JSON.stringify(['A1'])) {
    ok(`按数据里的 \`abilities\` 查：只有 ${吃得.join('、')} 响介有 \`gamblerSense\`（\`10-数据.js:204\`），其余四人吃不到 —— 不手写名单`);
  } else bad(`有 gamblerSense 的人不对：${JSON.stringify(吃得)}`);
  if (G.是减冷却武器(G.ALLY_T.find(t => t.mech === 'A1').weapons.find(w => w.name === '左轮打桩机'), p)
    && !G.是减冷却武器(G.ALLY_T.find(t => t.mech === 'A1').weapons.find(w => w.name === '三连机炮'), p)) {
    ok('`是减冷却武器()`：左轮打桩机（`evadeCd: true`）吃，三连机炮不吃 —— 按数据里的标记查');
  } else bad('`是减冷却武器()` 判据不对');

  /* ---- (b)(c) 多段武器**逐段**判定：贴数字 ---- */
  const cB = G.开局([{ 键: 'A1', 位: 0, 等级: 20 }], [{ 键: 'bluefish', 位: 0, 等级: 1 }], 20261011);
  const 响 = cB.allies[0];
  const 双段 = { name: '测试·双段枪', fire: 'direct', hit: 100, dmgType: '物理', power: 100, stat: '射击', range: [1, 1], hits: 2, upgrades: [] };
  const q2 = 调到五十(cB, 响, 双段, 造靶());
  const 中2 = (q2 - 20) / 100, 空2 = (q2 + 20) / 100;
  info(`测试武器【${双段.name}】：${双段.hits} 段，结算命中率调到 ${q2}%（第 1 段用一个「中」的随机数 ${中2}、第 2 段用一个「空」的 ${空2}）`);
  const 三发 = [];
  for (const [名, 队列, 期望] of [
    ['两段全中', [中2, 0.999, 中2, 0.999], 0],
    ['**1 段中 1 段空**', [中2, 0.999, 空2], 1],
    ['两段全空', [空2, 空2], 2],
  ]) {
    const 前 = G.ATX打空(响), 录前 = 打空录(cB, 'A1').length;
    const r = 一枪(cB, 响, 双段, 队列);
    const 打 = G.ATX打空(响) - 前, 条 = 打空录(cB, 'A1').length - 录前;
    if (打 === 期望 && 条 === 期望) {
      ok(`②③ ${名} → 记 **${打}** 次打空（记录 ${条} 条）：${r.字段.命中段数}/${r.字段.段数} 段命中 —— 「${r.文本}」`);
    } else bad(`${名} 记成了 ${打} 次（预期 ${期望}）、记录 ${条} 条`);
    三发.push({ 名, 打, 命中段数: r.字段.命中段数, 段数: r.字段.段数, 文本: r.文本 });
  }
  info(`逐段判定的数字：${三发.map(x => `${x.名} ${x.命中段数}/${x.段数} 段命中 → 打空 ${x.打} 次`).join('；')}`);
  if (三发[1].打 === 1) ok('★ 作者要的「按段」成立：**1 段中 1 段空 = 1 次打空**（不是 0 —— 旧口径整次攻击 `hit: 命中段数 > 0` 会算 0；也不是 2 —— 那是把命中段也算进去了）');
  else bad('「1 段中 1 段空」不是 1 次');
  const 四段 = { name: '测试·四段枪', fire: 'direct', hit: -999, dmgType: '物理', power: 1, stat: '射击', range: [1, 1], hits: 4, upgrades: [] };
  const 前4 = G.ATX打空(响), 录前4 = 打空录(cB, 'A1').length;
  const r4 = 一枪(cB, 响, 四段, [0.9]);
  const 打4 = G.ATX打空(响) - 前4, 条4 = 打空录(cB, 'A1').length - 录前4;
  const 段号们 = 打空录(cB, 'A1').slice(-4).map(x => x.段号);
  if (打4 === 4 && 条4 === 4 && JSON.stringify(段号们) === JSON.stringify([1, 2, 3, 4])) {
    ok(`③ 全部打空 → 记 **${打4}** 次 = \`hits\` 段数（${r4.字段.命中段数}/${r4.字段.段数}），记录里段号 ${段号们.join('、')} 逐段都在`);
  } else bad(`全空时记了 ${打4} 次（预期 4）、记录 ${条4} 条、段号 ${JSON.stringify(段号们)}`);

  /* ---- (d) 打空**真的减大招冷却**（贴冷启前后的回合数字） ---- */
  const 新场 = 种子 => {
    const ctx = G.开局([{ 键: 'A1', 位: 0, 等级: 20 }], [{ 键: 'bluefish', 位: 0, 等级: 1 }], 种子);
    const 介 = ctx.allies[0];
    const 枪 = 介.weapons.find(e => e.t.name === '左轮打桩机');
    return { ctx, 介, 枪, 靶: ctx.enemies[0] };
  };
  const 可用吗 = (介, 回合) => G.usableWeapons(介, { turn: 回合 }).some(e => e.t.name === '左轮打桩机');
  const 甲场 = 新场(20261011);
  info(`响介（A1）Lv20 的左轮打桩机（数据 10-数据.js:207：hits:12 / cd:3 / unlock:20 / startCd:10 / evadeCd:true）`
    + ` 开局时：\`readyTurn\` = **${甲场.枪.readyTurn}**（= 1 + startCd 10 → 第 10 回合还不能用、第 11 回合起可用：`
    + `第 10 回合 ${可用吗(甲场.介, 10)}、第 11 回合 ${可用吗(甲场.介, 11)}）`);
  for (let i = 0; i < 10; i++) 一枪(甲场.ctx, 甲场.介, 必空枪(), [0.999], 甲场.靶);
  info(`打空 ${G.ATX打空(甲场.介)} 段之后：\`readyTurn\` = **${甲场.枪.readyTurn}**（第 1 回合起就能用：`
    + `第 1 回合 ${可用吗(甲场.介, 1)}；余量 \`ATX余量()\` = ${G.ATX余量(甲场.介, p)}）`);
  if (甲场.枪.readyTurn === 1 && G.ATX打空(甲场.介) === 10 && 可用吗(甲场.介, 1) && !可用吗(甲场.介, 0)) {
    ok(`④ 开场冷却真的被打空减掉了：\`readyTurn\` **11 → 1**（10 段打空 × 每段 −1 = −10，正好等于 startCd 10）→ 第 1 回合起可用`);
  } else bad(`④ 开场冷却没减对：readyTurn ${甲场.枪.readyTurn}、打空 ${G.ATX打空(甲场.介)}`);
  /* ④-1 规则本体：战棋 `17b:87-91` 的两条支路（`cut >= w.cd` 一次性归零 / 否则抵掉 cut 点）。
     直接调框架钩子 `势力武器用后()`，累计（战棋 `u.evN`）与出手后的 cd（战棋 `w.cdLeft`）都是我们摆好的 → 数字干净。 */
  const 直测 = (打空数, cd前) => {
    const 场 = 新场(9);
    场.ctx.turn = 11;
    G.势力状态(场.介, 'ATX').打空 = 打空数;
    场.枪.cd = cd前;
    G.势力武器用后(场.ctx, 场.介, 场.枪, 场.枪.t);
    return {
      累计: 打空数, cd前, 余量: G.ATX余量(场.介, p), cd: 场.枪.cd,
      录: 场.ctx.log.filter(x => x.特色 === '赌徒的直觉' && x.结果 === '余量抵冷却').length,
    };
  };
  const 余量表 = [[10, 3], [11, 3], [13, 3], [20, 3]].map(([累, cd]) => 直测(累, cd));
  console.log('    本场累计  余量  出手前 cd  出手后 cd  记录');
  for (const x of 余量表) console.log(`    ${String(x.累计).padStart(6)}  ${String(x.余量).padStart(4)}  ${String(x.cd前).padStart(8)}  ${String(x.cd).padStart(9)}  ${x.录 ? '余量抵冷却' : '—'}`);
  if (余量表[0].余量 === 0 && 余量表[0].cd === 3 && 余量表[0].录 === 0
    && 余量表[1].余量 === 1 && 余量表[1].cd === 2 && 余量表[1].录 === 1
    && 余量表[2].余量 === 3 && 余量表[2].cd === 0 && 余量表[2].录 === 1
    && 余量表[3].余量 === 10 && 余量表[3].cd === 0) {
    ok(`④ 余量抵冷却逐字照战棋：累计 10（= 起算 10，余量 0）→ cd **不动**（3 → ${余量表[0].cd}）；`
      + `累计 11（余量 1）→ 抵 1 点（3 → ${余量表[1].cd}）；累计 13（余量 3 ≥ cd 3）→ **一次性归零**（3 → ${余量表[2].cd}，`
      + `「减到 0 后每次行动都能用」）；累计 20（余量 10）也是 0`);
  } else bad(`④ 余量抵冷却不对：${JSON.stringify(余量表.map(x => [x.累计, x.余量, x.cd, x.录]))}`);
  /* ④-2 这条钩子真的接在引擎里（不是只在测试里调得到）：同样打空 13 段、同样真出手一次大招，
     关掉特色 → cd 原样 3；带着特色 → cd 被抵到 0。两边都走 `resolveAction()` 的真实出手路径
     （`spendWeapon()` 把 cd 设上之后才调 `势力武器用后` —— 和战棋 `consume(w)` 先设 cdLeft、
     再在 `strikeResolved` 上算 `evadeCdCut` 的顺序一致）。 */
  const 真出手 = (启用, 累计段) => {
    const 场 = 新场(11);
    try {
      p.启用 = 启用;
      for (let i = 0; i < 累计段; i++) 一枪(场.ctx, 场.介, 必空枪(), [0.999], 场.靶);
      场.ctx.turn = 11;
      const 摇 = 场.ctx.rng; 场.ctx.rng = () => 0;                 // 12 段里能中的都中（剩下的按命中率自然漏）
      G.resolveAction(场.介, { kind: 'attack', weapon: 场.枪.t, target: 场.靶, entry: 场.枪 }, 场.ctx);
      场.ctx.rng = 摇;
    } finally { p.启用 = true; }
    return {
      累计: G.ATX打空(场.介), 余量: G.ATX余量(场.介, p), cd: 场.枪.cd, readyTurn: 场.枪.readyTurn,
      用录: 场.ctx.log.filter(x => x.类型 === '攻击' && x.单位 === 'A1' && x.武器 === '左轮打桩机').length,
    };
  };
  const 不带 = 真出手(false, 13), 带 = 真出手(true, 13);
  info('真出手对照（同样先打空 13 段、同样真出手一次【左轮打桩机】，第 11 回合）：');
  info(`  关掉特色（启用 false）：累计 ${不带.累计}、余量 ${不带.余量}、出手后 cd **${不带.cd}**（= 数据里的 3，没人抵它）、readyTurn ${不带.readyTurn}`);
  info(`  带着特色（默认）      ：累计 ${带.累计}、余量 ${带.余量}、出手后 cd **${带.cd}**（余量 ≥ cd → 一次性归零）、readyTurn ${带.readyTurn}`);
  if (不带.cd === 3 && 不带.累计 === 0 && 带.cd === 0 && 带.累计 >= 13 && 不带.用录 === 1 && 带.用录 === 1 && 带.readyTurn === 1) {
    ok(`④ 钩子真的接在引擎里：同样一次真实出手，**不带特色 → cd ${不带.cd}、带特色 → cd ${带.cd}**`
      + `（走 \`resolveAction()\` 的 \`spendWeapon()\` 之后那一步，战棋 \`strikeResolved\` 的同一个时机）`);
  } else bad(`④ 真出手对照不对：不带 ${JSON.stringify(不带)} / 带 ${JSON.stringify(带)}`);

  /* ---- (e) 初始 CD / 每回合上限 真的生效（两个初稿常量） ---- */
  try {
    p.初始CD = 4;
    const 丙场 = 新场(5);
    const 开录 = 丙场.ctx.log.filter(x => x.特色 === '赌徒的直觉' && x.结果 === '初始CD');
    for (let i = 0; i < 10; i++) 一枪(丙场.ctx, 丙场.介, 必空枪(), [0.999], 丙场.靶);
    info(`\`初始CD = 4\`（初稿常量）：开局 \`readyTurn\` = **${11 + 4}**（= 1 + startCd 10 + 4）；打空 10 段之后 = **${丙场.枪.readyTurn}**`
      + `（第 4 回合还不可用：${可用吗(丙场.介, 4)}；第 ${丙场.枪.readyTurn} 回合起可用：${可用吗(丙场.介, 丙场.枪.readyTurn)}）`);
    if (丙场.枪.readyTurn === 11 + 4 - 10 && !可用吗(丙场.介, 4) && 可用吗(丙场.介, 5) && 开录.length === 1 && 开录[0].初始CD === 4) {
      ok(`⑤ \`初始CD\` 真的生效：先按初稿加 4 回合（总开场冷却 14），再被 10 段打空减 10 → **第 5 回合起可用**`
        + `（默认 0 时是第 1 回合起）—— 作者原话「太强就加初始CD就行」，**一个常量就能调**`);
    } else bad(`⑤ 初始CD 没生效：readyTurn ${丙场.枪.readyTurn}、开局记录 ${开录.length} 条`);
  } finally { p.初始CD = 0; }
  try {
    p.每回合上限 = 2;
    const 丁场 = 新场(6);
    for (let i = 0; i < 5; i++) 一枪(丁场.ctx, 丁场.介, 必空枪(), [0.999], 丁场.靶);
    const 第一回合 = G.ATX打空(丁场.介), 本回合次数 = G.势力状态(丁场.介, 'ATX').本回合次数;
    丁场.ctx.turn = 2;
    for (let i = 0; i < 5; i++) 一枪(丁场.ctx, 丁场.介, 必空枪(), [0.999], 丁场.靶);
    const 第二回合后 = G.ATX打空(丁场.介);
    info(`\`每回合上限 = 2\`（初稿常量）：第 1 回合打 5 段 → 累计 **${第一回合}**（本回合次数 ${本回合次数}）；`
      + `进第 2 回合再打 5 段 → 累计 **${第二回合后}**`);
    if (第一回合 === 2 && 本回合次数 === 2 && 第二回合后 === 4) {
      ok(`⑤ \`每回合上限\` 真的生效：**每台每回合**最多记 2 段（第 1 回合打 5 段只记 2、第 2 回合再记 2）—— `
        + `这是防「一手把冷却减到 0」的旋钮；默认 0 = 不封顶（照战棋）`);
    } else bad(`⑤ 每回合上限没生效：第 1 回合 ${第一回合}（本回合次数 ${本回合次数}）、第 2 回合后 ${第二回合后}`);
  } finally { p.每回合上限 = 0; }
  if (p.初始CD === 0 && p.每回合上限 === 0) ok('⑤ 两个常量都还原成默认值 0 了（后面的段落 / 别的测试不背这个状态）');
  else bad('常量没有还原');

  /* ---- (f) 只对我方生效 ---- */
  const cF = G.开局([{ 键: 'A1', 位: 0, 等级: 20 }, { 键: 'A2', 位: 1, 等级: 20 }],
    [{ 键: 'grunt', 位: 4, 等级: 10 }], 7);
  const 敌F = cF.enemies[0];
  敌F.tags = Object.assign({}, 敌F.tags, { 势力: 'ATX' });      // 连势力也写成 ATX
  敌F.abilities = ['gamblerSense'];                             // 连能力也挂上
  const 敌桩 = { t: { name: '敌方测试打桩机', fire: 'direct', hit: 50, dmgType: '物理', power: 10, stat: '射击', range: [1, 1], hits: 2, upgrades: [], evadeCd: true, cd: 3, unlock: 1 }, cd: 0, uses: null, readyTurn: 4 };
  敌F.weapons = 敌F.weapons.concat([敌桩]);
  G.势力开局(cF);                                                // 重新跑一次势力开局（敌人不在 `势力在场()` 里）
  const 响F = cF.allies.find(u => u.key === 'A1'), 二F = cF.allies.find(u => u.key === 'A2');
  const 敌桩前 = 敌桩.readyTurn, 敌桩cd前 = 敌桩.cd;
  一枪(cF, 响F, 必空枪(), [0.999], 敌F);                          // 我方在打敌人，这一发打空了
  const 敌状 = (敌F.势力状态 || {}).ATX || {};
  if (G.ATX打空(敌F) === 0 && 敌桩.readyTurn === 敌桩前 && 敌桩.cd === 敌桩cd前 && G.ATX减冷却(敌F, 5, p) === 0
    && G.是我方势力(敌F, 'ATX') === false && G.势力卡行(敌F) === '') {
    ok(`⑥ 只对我方生效：敌人的 \`tags.势力\` 写成了 ATX、\`abilities\` 也挂了 \`gamblerSense\`，`
      + `打空**一点没记**（累计 ${G.ATX打空(敌F)}、状态 ${JSON.stringify(敌状)}）、它的打桩机冷却没动`
      + `（readyTurn ${敌桩.readyTurn}、cd ${敌桩.cd}）、直接调 \`ATX减冷却(敌人, 5)\` = 0、卡行「${G.势力卡行(敌F)}」`);
  } else bad(`⑥ 敌人被算了：${JSON.stringify({ 累计: G.ATX打空(敌F), 状: 敌状, readyTurn: 敌桩.readyTurn, cd: 敌桩.cd, 卡行: G.势力卡行(敌F) })}`);
  /* A2 的卡行从 2026-10-11 起不再为空（它多了「好运加护」那一段，作者点头接的）——
     断言改成「**没有赌徒的直觉那一段**」+「好运加护那一段在」。 */
  const A2行 = G.势力卡行(二F);
  if (G.ATX打空(响F) === 1 && G.ATX打空(二F) === 0 && !A2行.includes('赌徒的直觉') && G.ATX减冷却(二F, 5, p) === 0) {
    ok(`⑥ 同一场里：响介（有 \`gamblerSense\`）照常记了 ${G.ATX打空(响F)} 段；艾克赛琳 A2（ATX 但没有这个能力）`
      + `一次都不记、冷却减不动、卡行里**没有**「赌徒的直觉」那一段`
      + `（「${A2行}」—— A2 现在只多「好运加护」，那是 2026-10-11 新接的一条；**不手写名单**，按数据查）`);
  } else bad(`⑥ 我方判定不对：响介 ${G.ATX打空(响F)} / A2 ${G.ATX打空(二F)} / A2 卡行「${A2行}」`);
  /* 战棋还有一道「必中武器不会打空」：`if (c.hit || isSure(c.w)) return;`（17b:80）—— 我们靠「必中不进未中分支」实现 */
  const 必中枪 = { name: '测试·必中范围枪', fire: 'map', hit: 0, dmgType: '物理', power: 100, stat: '射击', range: [0, 9], hits: 3, upgrades: [] };
  const 前必 = G.ATX打空(响F);
  一枪(cF, 响F, 必中枪, [0.999], 敌F);
  if (G.ATX打空(响F) === 前必) ok(`⑥ 必中武器（\`fire:'map'\`，战棋的 \`isSure\`）**一段都不会打空** → 打空累计还是 ${前必}（照战棋 \`17b:80\` 的 \`isSure(c.w)\` 那一道门，我们靠「必中走不进未中分支」天然满足）`);
  else bad(`⑥ 必中武器居然记了打空：${前必} → ${G.ATX打空(响F)}`);

  /* ---- (g) 同种子两次逐字相同 + 一场真战斗的前后数字 ----
     ★ 挑的对照场是**第 4 层 Boss**（大肥鱼那一档，12 回合打满）：Lv20 的 ATX 五人打第 2 层精英是 1 回合碾压、
       一次打空都不会有 —— 要看清「按段」在真战斗里的效果，得挑一场打得久的。 */
  const 编成条12 = G.编成表.filter(x => x.层 === 4 && x.类型 === 'Boss')[0];
  const 敌队12 = G.敌方规格组(G.编成到单位(编成条12, 0));
  const ATX队 = [{ 键: 'A1', 位: 0, 等级: 20 }, { 键: 'A2', 位: 1, 等级: 20 }, { 键: 'A3', 位: 2, 等级: 20 },
    { 键: 'A4', 位: 3, 等级: 20 }, { 键: 'A5', 位: 4, 等级: 20 }];
  const 打一场 = 种子 => G.simulate(ATX队, 敌队12, null, 种子);
  const 甲12 = 打一场(20261011), 乙12 = 打一场(20261011), 丙12 = 打一场(20261012);
  if (JSON.stringify(甲12.记录) === JSON.stringify(乙12.记录)) {
    ok(`⑦ 同种子跑一整场，${甲12.记录.length} 条记录逐字相同（打空计数 / 减冷却全走 \`ctx.rng\` 之外的状态，没有 \`Math.random\`）`);
  } else bad('⑦ 同种子两次结果不一致');
  if (JSON.stringify(丙12.记录) !== JSON.stringify(甲12.记录)) ok('⑦ 换种子结果就不一样（随机数确实在起作用）');
  else info('⑦ 换种子记录一样（这一场太碾压时可能如此，不算错）');
  const 甲打空 = 甲12.ctx.allies.filter(u => u.key === 'A1').map(u => G.ATX打空(u))[0];
  const 甲桩 = 甲12.ctx.allies.find(u => u.key === 'A1').weapons.find(e => e.t.name === '左轮打桩机');
  const 甲势力录 = 甲12.记录.filter(x => x.特色 === '赌徒的直觉');
  info(`对照场：第 4 层 Boss「${编成条12.考点}」（${敌队12.map(x => `${x.键} Lv${x.等级}`).join('、')}；`
    + `我方 ATX 五人 Lv20、不下指令、同种子 20261011）`);
  info(`这一场：${甲12.结果} · ${甲12.回合数} 回合 · 响介本场累计打空 **${甲打空}** 段（左轮打桩机 \`readyTurn\` 从 11 减到 ${甲桩.readyTurn}）`
    + ` · 〔势力〕记录 ${甲势力录.length} 条（打空 ${甲势力录.filter(x => x.结果 === '打空').length} / 余量抵冷却 ${甲势力录.filter(x => x.结果 === '余量抵冷却').length}）`);
  if (甲势力录.length) info(`例如「${甲势力录[0].文本}」`);
  if (甲打空 > 0) ok(`⑦ 一整场真战斗里「打空」真的在记（响介本场累计 ${甲打空} 段，${甲势力录.length} 条 〔势力〕 记录）—— 不是只在单测里能动`);
  else bad('⑦ 一整场打下来一次打空都没记到（按段这条没接上真战斗）');
  /* 带 vs 不带（关掉 `启用` 做对照，不改任何数值） */
  let 带12 = null, 不带12 = null;
  try {
    p.启用 = true; 带12 = 打一场(20261011);
    p.启用 = false; 不带12 = 打一场(20261011);
  } finally { p.启用 = true; }
  const 桩次数 = r => r.记录.filter(x => x.类型 === '攻击' && x.单位 === 'A1' && x.武器 === '左轮打桩机').length;
  const 打空数 = r => r.记录.filter(x => x.特色 === '赌徒的直觉' && x.结果 === '打空').length;
  info(`带 vs 不带：打空记录 ${打空数(不带12)} 条 → ${打空数(带12)} 条；`
    + `响介用【左轮打桩机】${桩次数(不带12)} 次 → ${桩次数(带12)} 次（回合数 ${不带12.回合数} → ${带12.回合数}）`);
  if (打空数(带12) > 0 && 打空数(不带12) === 0) ok('⑦ 关掉 `启用` 时一条打空记录都不写（对照成立，别的数值一个都没改）');
  else bad(`⑦ 开关对照不对：带 ${打空数(带12)} 条 / 不带 ${打空数(不带12)} 条`);

  /* ---- (h) 战斗屏单位卡上的那一行（`80-界面.js` 的 `.faction`） ---- */
  界面.手动播放 = true;
  界面.清空();
  界面.编队.出击 = [{ 键: 'A1', 位: 0 }, { 键: 'A2', 位: 1 }];
  界面.开战(20261011);
  const html12 = String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
  const 行数12 = (html12.match(/class="faction"/g) || []).length;
  const 卡行12 = (html12.match(/赌徒的直觉[^<]*/g) || [])[0] || '';
  /* ★ 2026-10-11：行数从 1 变 2、A2 的卡行多了一段 ——
     艾克赛琳 A2 的卡上多了「好运加护 · 暴击倍率 +1（×3）、命中 -20…」（作者点头接上的那一条）；
     响介 A1 那一行照旧，**A2 仍然没有**「赌徒的直觉」那一段（它的 `abilities` 里没有 `gamblerSense`）。 */
  const A2行12 = (html12.match(/好运加护 · 暴击倍率[^<]*/g) || [])[0] || '';
  if (界面.屏 === '战斗' && 行数12 === 2 && 卡行12.includes('赌徒的直觉 · 打空 0 段')
    && A2行12.includes('好运加护 · 暴击倍率 +1（×3）、命中 -20')) {
    ok(`(h) 战斗屏画了 ${行数12} 行势力特色（响介 A1 =「赌徒的直觉」；艾克赛琳 A2 **没有** \`gamblerSense\`、`
      + `只多一行「${A2行12}」）：「${卡行12}」`);
  } else bad(`(h) 战斗屏的势力行不对：屏 ${界面.屏}、${行数12} 行、「${卡行12}」/「${A2行12}」`);
  if (!/undefined|NaN/.test(html12)) ok('(h) 战斗屏 HTML 里没有 undefined / NaN');
  else bad('(h) 战斗屏 HTML 里出现了 undefined / NaN');
}

