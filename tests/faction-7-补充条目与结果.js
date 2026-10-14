/* ========== [15] 最后两条势力特色的补充条目（作者 2026-10-11 已点头；**真的跑**） ==========
 * 任务书（作者点头照做）：
 *   A. **月球王国**：从战棋源码逐字抠出**剩下三条**，接进月球王国条目 ——
 *      ① **不动如山**（阿布拉德 `steadfast`）：战棋「本回合没有移动时，装甲 +30%」（`03-能力与减免管线.js:12`
 *         描述 + `15-战斗计算.js:5` 的 `armor × 1.3`）；**我们没移动力 → 触发条件换义成「本回合没有换位」**
 *         （作者已商定，任务书明写「标换义」）；
 *      ② **战地急救**（Iris `fieldAid`）：修理友军时额外给**被修的那台**防御 +15、持续到下一个我方阶段开始
 *         （`03:13` 描述 + `17-战斗执行.js:268` 的那一行增益）；
 *      ③ **连射 + 残心**（Nagi 的月光狙击枪）：连射每命中一次下一枪命中 −70（`17-战斗执行.js:106-125`），
 *         Lv20 被动「残心」减成 −55、Lv30 起 −45（`17b-角色机制.js:32-33` + `03:20`）；段数 = `CHAIN_MAX = 8`
 *         （`17b:32`），本仓库用 `w.hits` 落。
 *      ★ **不做**（照旧登记理由）：只能带一个技能（没技能槽）、拘束 / 重力网 / 居合（要格子 / 位移前提）。
 *   B. **ATX 好运加护**（艾克赛琳那把 `fire:'support'` 的支援武器）：**暴击倍率 +1、命中 −20**
 *      （`04-武器与机体.js:194` 的 `buff:{critX:1, hit:-20}` + `03:164` 的 `critMul` 读 `critX`）——
 *      **纯武器、不是位置类**（作者 2026-10-11 点头）；**烟雾 / 迷彩** 作者同意先不做，但换义建议要登记。
 * 这一段按任务书来：A 三条各自「生效 / 不生效」+ **真的进公式**（贴前后数字）+ 数值与战棋逐字对账；
 *   B 的武器真的在模板上 / `rangeKindOf` 正确 / 暴击倍率与命中 −20 **真的生效**（贴前后数字）。
 * 用法：`node tests/faction.js`。 */
console.log('\n[15] 最后两条补充条目：月球王国三条（不动如山 / 战地急救 / 连射残心）+ ATX 好运加护');
{
  const 月 = G.势力特色['月球王国'], ATX15参 = G.势力特色['ATX'];
  const 战棋根15 = join(ROOT, '..', 'mecha-tactics', 'Claude hand off', 'src', 'js');
  const 有战棋15 = existsSync(战棋根15);
  const 战棋15 = f => readFileSync(join(战棋根15, f), 'utf8');
  const 试验枪 = { name: '试验·直射枪 15', fire: 'direct', hit: 100, dmgType: '物理', power: 1600, stat: '射击', range: [1, 1], upgrades: [] };
  const 剥甲靶 = () => { const t = G.makeUnit('grunt', 'enemy', 4, 10); t.armor = 0; return t; };
  /* ★ `dmgCore(att, w, def, o)` 的第 1 个参数是**攻击者**、第 3 个是**挨打的那台**
     （`tests/relic.js` 里写成「靶子在前」是那份测试自己的叫法，参数位置是对调的 —— 这里按引擎的签名写）。 */
  const 肉靶15 = () => [{ 键: 'bluefish', 位: 0, 等级: 1 }];
  const 台15 = (ctx, k) => ctx.allies.find(u => u.key === k);

  /* ================= A① 不动如山（换义：本回合没有换位 → 装甲 +30%） ================= */
  /* ---- (a) 参数与战棋逐字对账 + **换义这件事写在明面上** ---- */
  const 不动 = 月.不动如山 || {};
  const 对账15 = [
    ['装甲加成', 'hasTrait(u,\'steadfast\') && !u.movedThisRound ? 1.3 : 1', 30, '15-战斗计算.js:5（×1.3 = 装甲 +30%）'],
    ['特技', "steadfast:{name:'不动如山', desc:'本回合没有移动时，装甲 +30%，援护次数 +1。'}", 'steadfast', '03-能力与减免管线.js:12'],
  ];
  for (const [字段, 战棋名, 值, 出处] of 对账15) {
    if (不动[字段] === 值) ok(`A① 不动如山：\`${字段}\` = ${JSON.stringify(不动[字段])}（战棋 ${战棋名}）　出处 ${出处}`);
    else bad(`A① 不动如山 \`${字段}\` = ${JSON.stringify(不动[字段])}，战棋是 ${JSON.stringify(值)}（${出处}）`);
  }
  /* ★ 2026-10-12：换义的口径从「本回合没有换位」改成「**始终生效**」（§1.5 表第 1 行）——
     换位机制已删（§1.4），所以这里断言的是「换义 + 始终生效」两件事都在参数里写着。 */
  if (typeof 不动.触发 === 'string' && 不动.触发.includes('始终生效') && 不动.触发.includes('换义')) {
    ok(`A① ★ **换义写在参数里**：\`触发\` = 「${不动.触发}」`);
  } else bad(`A① 换义没登记：${JSON.stringify(不动.触发)}`);
  if (typeof 不动.援护次数 === 'string' && 不动.援护次数.includes('不做')) {
    info(`A① 「援护次数 +1」登记为不做：${不动.援护次数}`);
  } else bad(`A① 「援护次数 +1」没登记：${JSON.stringify(不动.援护次数)}`);
  if (有战棋15) {
    const 逐字15 = [
      ['15-战斗计算.js', "hasTrait(u,'steadfast') && !u.movedThisRound ? 1.3 : 1", '装甲 ×1.3 那一行（逐字）'],
      ['03-能力与减免管线.js', "steadfast:{name:'不动如山', desc:'本回合没有移动时，装甲 +30%，援护次数 +1。'}", '描述逐字'],
      ['03-能力与减免管线.js', "fieldAid:{name:'战地急救', desc:'修理友军时，额外给对方防御 +15，持续到下一个我方阶段开始。'}", '战地急救描述逐字'],
      ['17-战斗执行.js', "t.buffs.push({src:'战地急救', def:15})", '战地急救那一行增益（逐字）'],
      ['17b-角色机制.js', 'const CHAIN_MAX = 8;', '连射段数（逐字）'],
      ['17b-角色机制.js', "abilOn(u, 'zanshin') ? (L30(u) ? 45 : 55) : (w.chainStep || 70)", 'chainStepOf（逐字）'],
      ['03-能力与减免管线.js', "zanshin:{name:'残心', lv:20, desc:'（Lv20）月光狙击枪连射的命中惩罚从每次 −70 减为 −55；Lv30 起 −45。'}", '残心描述逐字'],
      ['04-武器与机体.js', "wp({name:'好运加护', fire:'support', range:[0,3], buff:{critX:1, hit:-20}, cd:2, dmgType:'—',", '好运加护武器逐字'],
      ['03-能力与减免管线.js', "const critMul = u => (hasTrait(u,'zero') ? 2.5 : 2) + buffSum(u,'critX');", 'critMul 读 critX（逐字）'],
    ];
    let 缺15 = [];
    for (const [f, 片段, 说明] of 逐字15) {
      if (!战棋15(f).includes(片段)) 缺15.push(`${f}：${片段}`);
      else info(`战棋 ${f} 里确实有（${说明}）：${片段.slice(0, 60)}${片段.length > 60 ? '…' : ''}`);
    }
    if (!缺15.length) ok(`A①/B 与战棋源码逐字对账：${逐字15.length} 条片段全在（旧仓库只读，一个字节都没改）`);
    else bad(`战棋源码里找不到这些片段：${缺15.join('；')}`);
  } else info('（本机没有旧仓库 `F:\\DSH-mecha\\mecha-tactics` → 跳过与战棋源码的逐字核对，只按上面的出处行号对账）');

  /* ---- (b) 生效：本回合没换位 → `effArmor` 1500 → 1950；挨打那一发真的少掉一截 ---- */
  const cA = G.开局([{ 键: 'M2', 位: 0, 等级: 10 }], 肉靶15(), 20261011);
  const A15 = 台15(cA, 'M2');
  /* 基线 = 手动把判定结果翻成 false：`开局()` 里已经判过一次（默认指令「进攻」→ 不动），
     所以不能拿开局后的状态当基线；再调 `判定月球不动()` 按规则判回来。 */
  A15.势力状态.月球王国.不动如山 = false;
  const 甲基 = G.effArmor(A15);
  G.判定月球不动(cA, 月);                                        // 按规则判一次（这一回合没换位）
  const 甲有 = G.effArmor(A15);
  info(`A① 阿布拉德（重装，基础装甲 ${A15.armor}）：判定前 \`effArmor\` ${甲基} → 判定后 ${甲有}`
    + `（= ${A15.armor} × 1.3，战棋 \`15-战斗计算.js:5\` 的 \`× 1.3\` 逐字）`);
  if (甲有 === 1950 && 甲基 === 1500) {
    ok(`A① **生效**：\`effArmor\` 1500 → **1950**（+30%，加数与战棋逐字；\`buffSum(u,'armorPct')\` 那条藏品入口一个字节没动）`);
  } else bad(`A① 装甲没进公式：装甲 ${甲基} → ${甲有}（预期 1500 → 1950）`);
  /* 「装甲加成只作用在**挨打**那一侧」：拿同一发去打「装甲 350」与「装甲 0」的两个 Lv1 量产机，
     伤害必须不同（证明 `effArmor` 真的在 dmgCore 的「威力 − 装甲」那一项里）；
     同时把「攻击者自己的装甲」加成前后各算一次 → **伤害必须一模一样**（加成不是偷偷加在攻击方）。 */
  const 靶一 = (装甲) => { const t = G.makeUnit('grunt', 'enemy', 4, 1); t.armor = 装甲; return t; };
  const 打350 = G.dmgCore(A15, 试验枪, 靶一(350), { power: 1600, preview: true, turn: 1 });
  const 打0 = G.dmgCore(A15, 试验枪, 靶一(0), { power: 1600, preview: true, turn: 1 });
  A15.势力状态.月球王国.不动如山 = false;
  const 打350底 = G.dmgCore(A15, 试验枪, 靶一(350), { power: 1600, preview: true, turn: 1 });
  A15.势力状态.月球王国.不动如山 = true;
  info(`A① 「装甲」这一项真的进「威力 − 装甲」：靶子装甲 0 → ${打0.dmg}、装甲 350 → ${打350.dmg}；`
    + `${打350.steps[0]}`);
  info(`A① 对照（证明加成不是加在攻击方）：阿布拉德自己装甲 1950 时打出去 ${打350.dmg}、装甲 1500 时打出去 ${打350底.dmg}`);
  if (打0.dmg > 打350.dmg && 打350.dmg === 打350底.dmg && 打350.steps.join(' ').includes('装甲 350')) {
    ok(`A① 「装甲」进的是 \`dmgCore()\` 的「威力 − 装甲」那一项（装甲 0 → ${打0.dmg}、350 → ${打350.dmg}，`
      + `差 ${打0.dmg - 打350.dmg}）；而**攻击者自己的装甲**加成前后打出去一模一样（${打350.dmg} = ${打350底.dmg}）—— `
      + '加成加在「这台机体挨打时」的那一侧，不是加在它的输出上');
  } else bad(`A① 装甲那一项没进公式：打 0 装甲 ${打0.dmg} / 打 350 装甲 ${打350.dmg} / 基线 ${打350底.dmg}`);
  if (A15.势力状态.月球王国 && A15.势力状态.月球王国.不动如山 === true) ok('A① 判定缓存写着「不动如山 = true」（单位卡那一行读它）');
  else bad(`A① 判定缓存不对：${JSON.stringify(A15.势力状态 && A15.势力状态.月球王国)}`);

  /* ---- (c) ★ 2026-10-12「始终生效」（§1.5 表第 1 行）：战斗中已经没有任何位移 ——
     **换位**指令与 `kind:'swap'` 动作已删（§1.4），所以判定不再看任何指令字段。
     这里用「上一版会摘掉它」的那两条路做对照：① 不在任何方针下也照样生效（**任意方针**，§1.8 第 8 条）；
     ② 自己手动把缓存翻成 false，`判定月球不动()` 一跑就回 true（说明判定是无条件的，不是「一次性」）。
     ★ 旧断言「下换位指令 + 真的换位 → 装甲回 1500」随机制一起删（方案书 §1.8 明确授权）。 */
  const 队C = [{ 键: 'M2', 位: 0, 等级: 10 }, { 键: 'M1', 位: 4, 等级: 10 }, { 键: 'M3', 位: 5, 等级: 10 }];
  const cC = G.开局(队C, 肉靶15(), 20261011);
  const C15 = 台15(cC, 'M2');
  const 位前C = C15.slot;
  const 装甲们 = [];
  for (const 方针 of G.方针们) {
    G.设方针(cC, { 类型: 方针, 目标位: 方针 === '集中攻击' ? 0 : null });
    C15.势力状态.月球王国.不动如山 = false;                       // 先手动翻掉，看判定跑不跑得回来
    G.判定月球不动(cC, 月);
    装甲们.push(`${方针} → ${G.effArmor(C15)}`);
  }
  info(`A① 五种方针下的 \`effArmor\`：${装甲们.join('　｜　')}`);
  if (装甲们.every(x => x.endsWith('1950')) && C15.slot === 位前C) {
    ok(`A① **始终生效**：五种方针下 \`effArmor\` 都是 **1950**（${C15.armor} × 1.3），`
      + `而且谁也不动位置（位 ${G.位名(C15.slot)} —— 战斗中已经没有换位了）`);
  } else bad(`A① 「始终生效」不对：${装甲们.join('、')} / 位 ${G.位名(C15.slot)}`);
  /* 每回合重判（不是一次性）：再跑一回合，判定照样回 true */
  G.endTurn(cC); cC.turn++;
  G.回合开始(cC);
  if (G.effArmor(C15) === 1950 && G.月球不动(C15) === true) ok(`A① 每回合重判：第 ${cC.turn} 回合照样是 1950（不动 ${G.月球不动(C15)}）`);
  else bad(`A① 第 ${cC.turn} 回合没生效：装甲 ${G.effArmor(C15)} / 不动 ${G.月球不动(C15)}`);
  /* ★ 行动阶段**一个单位都不会位移**（编队摆位保留、战斗中不动）：跑一整回合，位号逐个对一遍 */
  const 位前们 = cC.allies.map(u => u.slot);
  G.打一回合(cC);
  if (cC.allies.every((u, i) => u.slot === 位前们[i])) ok('A① 打完一回合，我方每一台的位号一个都没变（战斗中不再有换位）');
  else bad(`A① 有人位移了：${cC.allies.map((u, i) => `${G.位名(位前们[i])}→${G.位名(u.slot)}`).join('、')}`);

  /* ---- (d) 只对我方生效 + 同种子逐字相同 ---- */
  const cD = G.开局([{ 键: 'M2', 位: 0, 等级: 10 }], [{ 键: 'grunt', 位: 4, 等级: 10 }], 7);
  const 敌D = cD.enemies[0];
  敌D.trait = 'steadfast'; 敌D.tags = Object.assign({}, 敌D.tags, { 势力: '月球王国' });
  G.判定月球不动(cD, 月);
  if (G.effArmor(敌D) === 敌D.armor && G.势力装甲(敌D) === 0) {
    ok(`A① **只对我方生效**：把 \`trait:'steadfast'\` + 势力都挂到敌人身上 → \`effArmor\` 还是 ${G.effArmor(敌D)}（一点不加）`);
  } else bad(`A① 敌人也吃到了：effArmor ${G.effArmor(敌D)}（基础 ${敌D.armor}）、势力装甲 ${G.势力装甲(敌D)}`);
  const 同15 = 种子 => G.simulate([{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'M2', 位: 4, 等级: 20 },
    { 键: 'M3', 位: 5, 等级: 20 }, { 键: 'M4', 位: 2, 等级: 20 }], 肉靶15(), null, 种子);
  const 甲15 = 同15(20261011), 乙15 = 同15(20261011);
  if (JSON.stringify(甲15.记录) === JSON.stringify(乙15.记录)) {
    ok(`A① 同种子跑一整场（月球王国四人 Lv20 vs 大肥鱼），${甲15.记录.length} 条记录逐字相同`);
  } else bad('A① 同种子两次结果不一致');

  /* ================= A② 战地急救（修理后目标防御 +15） ================= */
  const 救 = 月.战地急救 || {};
  if (救.特技 === 'fieldAid' && 救.防御加成 === 15 && 救.每次修理 === true) {
    ok(`A② 战地急救参数逐字对账：\`特技 = fieldAid\`、\`防御加成 = ${救.防御加成}\`（战棋 17-战斗执行.js:268 的 \`def:15\`）、`
      + `\`每次修理 = ${救.每次修理}\`（战棋就是「修理友军时」）`);
  } else bad(`A② 参数不对：${JSON.stringify(救)}`);
  /* 真的修一次：Iris 修一台 40% HP 的队友 */
  const 队E = [{ 键: 'M3', 位: 0, 等级: 10 }, { 键: 'M2', 位: 4, 等级: 10 }];
  const cE = G.开局(队E, 肉靶15(), 20261011);
  const 医E = 台15(cE, 'M3'), 伤E = 台15(cE, 'M2');
  伤E.hp = Math.round(伤E.maxHp * 0.4);
  const 修E = G.usableWeapons(医E, cE).find(e => G.isHealKind(G.rangeKindOf(e.t)));
  const 前HpE = 伤E.hp, 前DefE = 伤E.defense;
  const 记录前E = cE.log.length;
  G.resolveAction(医E, { kind: 'heal', weapon: 修E.t, target: 伤E, entry: 修E }, cE);
  const 救录 = cE.log.slice(记录前E).find(x => x.特色 === '战地急救');
  const 救buff = (伤E.buffs || []).find(b => b.src === '战地急救');
  const 期望回复 = G.healAmount(医E, 修E.t);
  info(`A② Iris 用【${修E.t.name}】修 40% HP 的阿布拉德：回复 ${伤E.hp - 前HpE}（= healAmount ${期望回复}）`);
  if (伤E.hp - 前HpE === 期望回复 && 救buff && 救buff.def === 15 && 救buff.剩余 === 1) {
    ok(`A② **生效**：修完给**被修的那台**挂上 \`{src:'战地急救', def:15}\`（防御加成 ${救buff.def}、剩余 ${救buff.剩余} 回合）`);
  } else bad(`A② 修理后没挂增益：回复 ${伤E.hp - 前HpE} / buff ${JSON.stringify(救buff)}`);
  if (救录 && 救录.文本.startsWith('〔势力〕') && 救录.文本.includes('战地急救') && 救录.防御加成 === 15) {
    ok(`A② 写了一条 \`〔势力〕\` 记录：「${救录.文本}」（字段 防御加成 ${救录.防御加成}）`);
  } else bad(`A② 记录不对：${JSON.stringify(救录)}`);
  /* 真的进公式：防御 +15 走 REDUCTIONS 的「防御增益」（stage 2 加到**挨打那一台**的防御值上）。
     所以这里拿一台**有防御值**的敌人当靶子（`tank` 基础防御 95），把它的装甲剥掉，
     攻击方按引擎签名写（第 1 个参数 = 攻击者、第 3 个 = 挨打的那台）。
     增益的**生产者**是刚修完阿布拉德的 Iris（上面那一条记录就是她写的）——
     这里直接把同一条 `{src:'战地急救', def:15}` 挂到挨打的那台上，验它真的进管线。 */
  const 靶E = G.makeUnit('tank', 'enemy', 4, 10); 靶E.armor = 0;
  const 防基E = 靶E.defense;
  靶E.buffs = [{ src: '战地急救', def: 15, 剩余: 1 }];
  const 打有 = G.dmgCore(A15, 试验枪, 靶E, { power: 1600, preview: true, turn: 1 });
  靶E.buffs = 靶E.buffs.filter(b => b.src !== '战地急救');
  const 打无 = G.dmgCore(A15, 试验枪, 靶E, { power: 1600, preview: true, turn: 1 });
  info(`A② 拿一台防御 ${防基E}、装甲剥掉的敌人挨同一发（威力 1600、攻击方是刚被修过的阿布拉德）：没有增益 ${打无.dmg} → 有增益 ${打有.dmg}`);
  info(`A② ${打有.steps[1]}`);
  if (打有.dmg < 打无.dmg && 打有.steps.join(' ').includes('防御增益 +15')) {
    ok(`A② **真的进公式**：伤害 ${打无.dmg} → ${打有.dmg}（减免管线 stage 2 的「防御增益 +15」）`);
  } else bad(`A② 防御 +15 没进公式：${打无.dmg} → ${打有.dmg}；${JSON.stringify(打有.steps)}`);
  /* 不生效①：关掉 `启用`；不生效②：修理者不是 Iris（维诺 M4 没有 fieldAid） */
  const cF2 = G.开局(队E, 肉靶15(), 20261011);
  const 医F = 台15(cF2, 'M3'), 伤F = 台15(cF2, 'M2');
  伤F.hp = Math.round(伤F.maxHp * 0.4);
  const 修F = G.usableWeapons(医F, cF2).find(e => G.isHealKind(G.rangeKindOf(e.t)));
  try { 月.启用 = false; G.resolveAction(医F, { kind: 'heal', weapon: 修F.t, target: 伤F, entry: 修F }, cF2); }
  finally { 月.启用 = true; }
  if (!(伤F.buffs || []).some(b => b.src === '战地急救') && !cF2.log.some(x => x.特色 === '战地急救')) {
    ok('A② **不生效**（开关对照）：把 `启用` 关掉 → 修完一点防御都不加、一条记录都不写');
  } else bad('A② 关掉开关还在加防御');
  /* 不生效②：按数据查 —— 只有 `trait === 'fieldAid'` 的那台（Iris M3）吃，别人不吃 */
  const 别人 = G.ALLY_T.filter(t => t.tags.势力 === '月球王国' && t.trait !== 'fieldAid').map(t => t.mech);
  const 吃的 = G.ALLY_T.filter(t => t.tags.势力 === '月球王国' && G.有战地急救(G.makeUnit(t.mech, 'ally', 0, 10), 月)).map(t => t.mech);
  if (JSON.stringify(吃的) === JSON.stringify(['M3']) && 别人.length === 4) {
    ok(`A② \`有战地急救()\` 按**数据里的 trait** 查（不手写名单）：月球王国五人里只有 ${吃的.join('、')}（fieldAid）吃；`
      + `另外四人（${别人.join('、')}）\`G.有战地急救()\` = false`);
  } else bad(`A② 「谁吃战地急救」不对：${JSON.stringify(吃的)}`);

  /* ================= A③ 连射 + 残心（hits = 8；逐段 −70 / −55 / −45） ================= */
  const 残 = 月.连射残心 || {};
  const 残账 = [
    ['连射段数', 'const CHAIN_MAX = 8;', 8, '17b-角色机制.js:32'],
    ['连射步长', 'w.chainStep || 70', 70, '17b-角色机制.js:33'],
    ['残心步长', 'L30(u) ? 45 : 55', 55, '17b-角色机制.js:33（Lv20 档）'],
    ['残心步长30', 'L30(u) ? 45 : 55', 45, '17b-角色机制.js:33（Lv30 档）'],
    ['武器特技', "wp({name:'月光狙击枪', …, special:'chain', chainStep:70, …})", 'chain', '04-武器与机体.js:56'],
  ];
  for (const [字段, 战棋名, 值, 出处] of 残账) {
    if (残[字段] === 值) ok(`A③ 连射残心：\`${字段}\` = ${JSON.stringify(残[字段])}（战棋 ${战棋名}）　出处 ${出处}`);
    else bad(`A③ \`${字段}\` = ${JSON.stringify(残[字段])}，战棋是 ${JSON.stringify(值)}（${出处}）`);
  }
  const 枪数 = G.ALLY_T.find(t => t.mech === 'M4').weapons.find(w => w.name === '月光狙击枪');
  if (枪数 && 枪数.hits === 8 && 枪数.special === 'chain' && 枪数.chainStep === 70 && 枪数.power === 2100 && 枪数.hit === 125) {
    ok(`A③ 数据里「月光狙击枪」逐字：威力 ${枪数.power} / 命中 ${枪数.hit} / ${枪数.dmgType} / \`special:'chain'\` / `
      + `\`chainStep:${枪数.chainStep}\` / **\`hits:${枪数.hits}\`**（= 战棋 17b:32 的 \`CHAIN_MAX = 8\`，本仓库用 \`w.hits\` 落）`);
  } else bad(`A③ 月光狙击枪的段数不对：${JSON.stringify(枪数 && { hits: 枪数.hits, special: 枪数.special, chainStep: 枪数.chainStep })}`);
  const 白枪 = { name: '测试·白板直射枪', fire: 'direct', hit: 100, dmgType: '物理', power: 1000, stat: '射击', range: [1, 1], hits: 1, upgrades: [] };
  const 数段 = (lv, 用真枪) => {
    const 台 = G.makeUnit('M4', 'ally', 0, lv);
    const 靶 = G.makeUnit('bluefish', 'enemy', 0, 1);
    靶.hp = 靶.maxHp = 9999999;                     // 打不死 → 8 段全都走完
    /* 势力钩子（`势力逐段未命中` 里的 `势力在场()`）要读 `ctx` 的双方名单 → 这里给一个最小 ctx。 */
    const ctx = { turn: 1, rng: () => 0.5, log: [], allies: [台], enemies: [靶] };
    const w = 用真枪 ? 枪数 : 白枪;
    const r = G.resolveAttack(台, 靶, w, ctx, {});
    return { 文本: r.文本, 段: r.字段.段数, 中: r.字段.命中段数, 详情: r.字段.详情, 伤害: r.字段.伤害, 台 };
  };
  const L10 = 数段(10, true), L20 = 数段(20, true), L30 = 数段(30, true);
  const 步 = lv => G.连射残心(G.makeUnit('M4', 'ally', 0, lv), 枪数, 残);
  info(`A③ 参数表键：${Object.keys(残 || {}).join(',')}；连射段数 ${残 && 残.连射段数}、连射步长 ${残 && 残.连射步长}、`
    + `残心步长 ${残 && 残.残心步长}、残心步长30 ${残 && 残.残心步长30}、残心解锁等级 ${残 && 残.残心解锁等级}`);
  info(`A③ 逐段命中步长（战棋 \`chainStepOf\`）：Lv10 ${步(10)} / Lv20 ${步(20)} / Lv30 ${步(30)}`);
  info(`A③ Lv10（还没解锁残心，每次 −${步(10)}）：${L10.中}/${L10.段} 段命中，伤害 ${L10.伤害}`);
  info(`A③ Lv20（残心 −${步(20)}）：${L20.中}/${L20.段} 段命中，伤害 ${L20.伤害}；逐段「${L20.详情}」`);
  info(`A③ Lv30（残心 −${步(30)}）：${L30.中}/${L30.段} 段命中，伤害 ${L30.伤害}`);
  if (步(10) === 70 && 步(20) === 55 && 步(30) === 45) {
    ok(`A③ **残心按等级减轻惩罚**：逐段命中步长 Lv10 **${步(10)}**（数据里的 \`chainStep:70\`）→ Lv20 **${步(20)}** → `
      + `Lv30 **${步(30)}** —— 战棋 \`chainStepOf\` 的 \`abilOn(u,'zanshin') ? (L30(u) ? 45 : 55) : (w.chainStep || 70)\` 逐字`);
  } else bad(`A③ 逐段步长不对：Lv10 ${步(10)} / Lv20 ${步(20)} / Lv30 ${步(30)}（预期 70 / 55 / 45）`);
  if (L20.段 === 8 && L20.文本.includes('/8 段') && L20.伤害 > L10.伤害 && L30.伤害 > L20.伤害) {
    ok(`A③ 惩罚减轻 → 同一把枪 / 同一个靶 / 同一串固定随机数下输出更高：伤害 Lv10 ${L10.伤害} → `
      + `Lv20 ${L20.伤害} → Lv30 ${L30.伤害}（段数 ${L20.段}，记录里写着「${L20.文本}」）`);
  } else bad(`A③ 残心没让输出变高：Lv10 ${L10.伤害} / Lv20 ${L20.伤害} / Lv30 ${L30.伤害}（段数 ${L20.段}）`);
  /* 逐段命中率真的跟着步长走：挑一台**高闪避**的靶子，把第 1 段的原始命中率压到 100 以下。
     ★ 断言写成「相对关系 + 逐字公式」，不写死绝对数（等级会带 `精准` 的成长，绝对数跟着等级变）：
        原始命中 = 武器命中 125 + round((精准 − 160) / 2) − 闪避，而步长只影响**这一段的基础命中**。 */
  const 第1段 = lv => {
    const 台 = G.makeUnit('M4', 'ally', 0, lv);
    const 靶 = G.makeUnit('phase', 'enemy', 4, 1); 靶.eva = 60;
    const ctx = { turn: 1, rng: () => 0.99, log: [], allies: [台], enemies: [靶] };   // 0.99：一段都不中
    const 期望 = 枪数.hit + Math.round(((台.aim ?? 160) - 160) / 2) - 靶.eva;
    const hr = G.hitRate(台, 枪数, 靶, { baseHit: 枪数.hit, turn: 1 });
    const r = G.resolveAttack(台, 靶, 枪数, ctx, {});
    const 率 = (r.字段.详情.match(/第 \d+ 段（(\d+)%）/g) || []).map(s => Number(s.match(/(\d+)%/)[1]));
    return { 台, 期望, 结算: hr.hit, 率, 步: G.连射残心(台, 枪数, 残) };
  };
  const 段10 = 第1段(10), 段20 = 第1段(20), 段30 = 第1段(30);
  info(`A③ 高闪避靶（闪避 60）下：Lv10 期望原始 ${段10.期望}% / 结算 ${段10.结算}% / 第 1 段写出 ${段10.率[0]}%`
    + `（步长 ${段10.步}）`);
  info(`A③ 同靶：Lv20 期望原始 ${段20.期望}% / 结算 ${段20.结算}% / 第 1 段写出 ${段20.率[0]}%（步长 ${段20.步}）`);
  info(`A③ 同靶：Lv30 期望原始 ${段30.期望}% / 结算 ${段30.结算}% / 第 1 段写出 ${段30.率[0]}%（步长 ${段30.步}）`);
  if (段10.率[0] === 段10.结算 && 段20.率[0] === 段20.结算 && 段30.率[0] === 段30.结算
    && 段20.率[0] > 段10.率[0] && 段30.率[0] > 段20.率[0]) {
    ok(`A③ 第 1 段的命中率**跟着步长走**：Lv10 ${段10.率[0]}% → Lv20 ${段20.率[0]}% → Lv30 ${段30.率[0]}%`
      + `（列出的就是 \`hitRate()\` 的结算值，步长 ${段10.步} / ${段20.步} / ${段30.步}；`
      + `公式 = 命中 ${枪数.hit} + round((精准 − 160)/2) − 闪避 60）`);
  } else bad(`A③ 逐段命中率没跟着步长走：${段10.率[0]}(${段10.结算}) / ${段20.率[0]}(${段20.结算}) / ${段30.率[0]}(${段30.结算})`);
  /* 不生效：别的武器（白板单段枪）走不到这条钩子上；敌人拿着这把枪也不吃 */
  const 白 = 数段(20, false);
  if (白.段 === 1 && G.连射残心(L20.台, 白枪, 残) === 0) {
    ok(`A③ **只对这把连射枪生效**：白板单段枪（\`special\` 是 null）走不到钩子上（\`连射残心()\` = 0、段数 ${白.段}）`);
  } else bad('A③ 白板枪也被算了');
  /* ★ 敌人键表（`ENEMY_T`）里没有角色键，`makeUnit('M4','enemy',…)` 会报错 ——
     所以这里拿一台**我方 M4**再把阵营翻成敌人（势力标签照旧是月球王国，`abilities` 也照旧）。 */
  const 敌枪手 = G.makeUnit('M4', 'ally', 0, 20); 敌枪手.side = 'enemy';
  if (G.连射残心(敌枪手, 枪数, 残) === 0 && G.势力装甲(敌枪手) === 0) {
    ok('A③ **只对我方生效**：同一台「M4」挂到敌人那边（连势力都还是月球王国）→ 步长 0、装甲 0，一个数都不加');
  } else bad('A③ 敌人也吃到了');
  /* 真战斗：第 1 层普通编成，M4 拿主武器（改之前它被 \`weaponPlayable\` 挡着，根本用不出来） */
  const 条15 = G.编成表.filter(x => x.层 === 1 && x.类型 === '普通')[0];
  const 敌队15 = G.敌方规格组(G.编成到单位(条15, 0));
  const 月队15 = [{ 键: 'M1', 位: 0, 等级: 20 }, { 键: 'M2', 位: 4, 等级: 20 }, { 键: 'M3', 位: 5, 等级: 20 }, { 键: 'M4', 位: 2, 等级: 20 }];
  const 真15 = G.simulate(月队15, 敌队15, null, 20261011);
  const 枪录 = 真15.记录.filter(x => x.武器 === '月光狙击枪');
  info(`A③ 真战斗（第 1 层普通，同种子 20261011）：${真15.结果} · ${真15.回合数} 回合；【月光狙击枪】出手 ${枪录.length} 次`);
  if (枪录.length > 0) {
    ok(`A③ 主武器真的用出来了：${枪录.map(x => `${x.命中段数}/${x.段数} 段 ${x.伤害}`).join('；')}`);
  } else bad('A③ 月光狙击枪一次都没出手（`weaponPlayable` 那道门没开？）');
  if (G.weaponPlayable(枪数) === true && G.weaponPlayable({ name: 'x', fire: 'direct', special: 'markBreak', power: 1, upgrades: [] }) === false) {
    ok('A③ 放行的只有 `special:\'chain\'` 这一种：`weaponPlayable(月光狙击枪)` = true，别的 special（例如 `markBreak`）**照旧挡着**');
  } else bad('A③ `weaponPlayable` 放行范围不对');

  /* ================= B. ATX 好运加护（暴击倍率 +1、命中 −20） ================= */
  const 祝武 = G.ALLY_T.find(t => t.mech === 'A2').weapons.find(w => w.name === '好运加护');
  const 已接 = ATX15参.已接好运加护 || {};
  if (祝武 && 祝武.fire === 'support' && 祝武.buff && 祝武.buff.critX === 1 && 祝武.buff.hit === -20 && 祝武.cd === 2) {
    ok(`B 武器真的在模板上（A2 艾克赛琳）：【好运加护】\`fire:'support'\`、\`buff:{critX:${祝武.buff.critX}, hit:${祝武.buff.hit}}\`、`
      + `\`cd:${祝武.cd}\` —— 与战棋 04-武器与机体.js:194 **逐字**`);
  } else bad(`B 好运加护的数值不对：${JSON.stringify(祝武 && { fire: 祝武.fire, buff: 祝武.buff, cd: 祝武.cd })}`);
  if (G.rangeKindOf(祝武) === G.KIND_SUPPORT) ok(`B \`rangeKindOf()\` = 「${G.rangeKindOf(祝武)}」（带 \`buff\` 的支援武器单算一类，不参与「进攻」的武器挑选）`);
  else bad(`B rangeKindOf 不对：${G.rangeKindOf(祝武)}`);
  if (已接.数值 && 已接.数值.critX === 1 && 已接.数值.hit === -20 && 已接.冷却 === 2 && 已接.初稿 === true) {
    ok(`B 参数表里的 \`已接好运加护\` 与战棋逐字：${JSON.stringify(已接.数值)} + 冷却 ${已接.冷却}（范围换义已标初稿）`);
  } else bad(`B 参数表不对：${JSON.stringify(已接)}`);
  if (ATX15参.未接项.length === 6 && !ATX15参.未接项.some(x => x.项.includes('好运加护'))
    && ATX15参.未接项.some(x => x.项.includes('烟雾弹')) && ATX15参.未接项.some(x => x.项.includes('念动迷彩'))) {
    ok(`B 「好运加护」已从 \`未接项\` 移出（搬进 \`已接好运加护\`）；**烟雾弹 / 念动迷彩仍是 6 条未接项里的两条**（作者同意先不做）`);
  } else bad(`B 未接项清单不对：${JSON.stringify(ATX15参.未接项.map(x => x.项.slice(0, 12)))}`);
  /* 真的生效：A2 放一次好运加护 → 队友挂上 critX 1 / hit −20 → 暴击倍率 ×2 → ×3、命中 −20 */
  const cH = G.开局([{ 键: 'A2', 位: 0, 等级: 20 }, { 键: 'A1', 位: 1, 等级: 20 }], 肉靶15(), 20261011);
  const 艾H = 台15(cH, 'A2'), 响H = 台15(cH, 'A1');
  const 靶H = G.makeUnit('grunt', 'enemy', 4, 10);
  const 暴前 = G.critRate(试验枪, 响H);
  const 暴倍前 = G.critMul(响H);
  const 命前 = G.hitRate(响H, 试验枪, 靶H, { turn: 1 }).raw;
  const 伤前 = G.dmgCore(响H, 试验枪, 靶H, { power: 1600, preview: true, turn: 1, crit: true });
  const 祝buff前 = (响H.buffs || []).filter(b => b.src === '好运加护').length;
  const 祝条 = G.usableWeapons(艾H, cH).find(e => e.t.name === '好运加护');
  const 记录前H = cH.log.length;
  if (祝条) G.resolveAction(艾H, { kind: 'buff', weapon: 祝条.t, targets: G.好运加护受益(艾H, cH, 已接), entry: 祝条 }, cH);
  const 祝buff = (响H.buffs || []).find(b => b.src === '好运加护');
  const 暴后 = G.critRate(试验枪, 响H);
  const 暴倍后 = G.critMul(响H);
  const 命后 = G.hitRate(响H, 试验枪, 靶H, { turn: 1 }).raw;
  const 伤后 = G.dmgCore(响H, 试验枪, 靶H, { power: 1600, preview: true, turn: 1, crit: true });
  info(`B 艾克赛琳放一次好运加护（队友：${G.好运加护受益(艾H, cH, 已接).map(u => u.name).join('、')}；她自己不在名单里）`);
  info(`B 同一发【试验·直射枪 15】暴击：暴击倍率 ×${暴倍前} → ×${暴倍后}，伤害 ${伤前.dmg} → ${伤后.dmg}；${伤后.steps[0]}`);
  info(`B 命中原始值：${命前} → ${命后}（hit ${G.buffSum(响H, 'hit')}）；暴击率 ${暴前}% → ${暴后}%（crit 与 critX 是两个口子，` +
    `本次只加倍率、不加暴击率）`);
  if (祝buff前 === 0 && 祝buff && 祝buff.critX === 1 && 祝buff.hit === -20) {
    ok(`B **生效**：放完之后队友（响介）身上挂了 \`{src:'好运加护', critX:1, hit:-20, 剩余:1}\``);
  } else bad(`B 增益没挂上：${JSON.stringify(祝buff)}`);
  if (暴倍前 === 2 && 暴倍后 === 3 && 伤后.dmg > 伤前.dmg) {
    ok(`B **暴击倍率 +1 真的进公式**：\`critMul()\` ×${暴倍前} → **×${暴倍后}**（战棋 03:164 的 \`buffSum(u,'critX')\`）、`
      + `同一发暴击伤害 ${伤前.dmg} → **${伤后.dmg}**（倍率作用在**威力**上：${伤后.steps[0]}）`);
  } else bad(`B 暴击倍率没进公式：×${暴倍前} → ×${暴倍后}、${伤前.dmg} → ${伤后.dmg}`);
  if (命前 - 命后 === 20 && G.buffSum(响H, 'hit') === -20) {
    ok(`B **命中 −20 真的进公式**：原始命中 ${命前} → **${命后}**（走的是早就有的 \`buffSum(u,'hit')\` 入口，不是新口子）`);
  } else bad(`B 命中 −20 没进公式：${命前} → ${命后}（差 ${命前 - 命后}）`);
  if (暴后 === 暴前) ok(`B 只加「倍率」不加「暴击率」：暴击率 ${暴前}% → ${暴后}%（\`crit\` 与 \`critX\` 分开，与战棋一致）`);
  else bad(`B 暴击率也被改了：${暴前}% → ${暴后}%`);
  /* 不生效：范围是「除自己以外」（自己放完自己不吃）；A1 没有这把武器 */
  if (!(艾H.buffs || []).some(b => b.src === '好运加护')) ok('B 受益人**不含艾克赛琳自己**（战棋原话「**其他**友军」；换义后的口径也是「除自己以外」）');
  else bad('B 自己吃到了自己的好运加护');
  if (!G.ALLY_T.find(t => t.mech === 'A1').weapons.some(w => w.name === '好运加护')) ok('B 只有艾克赛琳 A2 有这把武器（按数据查，没有手写名单）');
  else bad('B 响介身上也有好运加护');
  /* 同种子逐字相同（带 vs 不带） */
  const ATX15 = [{ 键: 'A1', 位: 0, 等级: 20 }, { 键: 'A2', 位: 1, 等级: 20 }];
  const 打15 = 种子 => G.simulate(ATX15, 敌队15, null, 种子);
  const 带15 = 打15(20261011), 再15 = 打15(20261011);
  let 不带15 = null;
  try { ATX15参.启用 = false; 不带15 = 打15(20261011); } finally { ATX15参.启用 = true; }
  if (JSON.stringify(带15.记录) === JSON.stringify(再15.记录)) ok(`B 同种子跑一整场（ATX 两人 Lv20 vs 第 1 层普通），${带15.记录.length} 条记录逐字相同`);
  else bad('B 同种子两次结果不一致');
  /* 带 vs 不带：**让艾克赛琳这一回合没有别的武器可打**（把它另外三把清空）→ AI 就会走到 `chooseSupport()` 放好运加护。
     这样「关掉 `启用` 就一条都不放」才是真对照（不清空的话 AI 永远优先开火，`support` 走不到 —— 上面 U 形那段就是证明）。 */
  const 只带加护 = 队 => {
    const 表 = 敌队15.map(u => ({ 键: u.键, 位: u.位, 等级: u.等级 }));
    const ctx = G.开局(队, 表, 20261011);
    const 艾 = ctx.allies.find(u => u.key === 'A2');
    艾.weapons = 艾.weapons.filter(e => e.t.name === '好运加护');
    return ctx;
  };
  const 放一轮 = (ctx, 标签) => {
    G.设单位开关(ctx, {});
    return G.打一回合(ctx);
  };
  const 祝录 = 录 => 录.filter(x => x.类型 === '增益' && x.武器 === '好运加护');
  let 带录 = null, 不带录 = null;
  try { ATX15参.启用 = true; 带录 = 放一轮(只带加护(ATX15), '带'); }
  finally { ATX15参.启用 = true; }
  try { ATX15参.启用 = false; 不带录 = 放一轮(只带加护(ATX15), '不带'); }
  finally { ATX15参.启用 = true; }
  const 带祝 = 祝录(带录), 不带祝 = 祝录(不带录);
  info(`B 带 vs 不带（只关 启用，把艾克赛琳的其他武器清空让 AI 去放支援）：好运加护记录 ${不带祝.length} → ${带祝.length} 条`);
  if (带祝.length > 0) info(`B 带的那一轮：「${带祝[0].文本}」`);
  if (不带祝.length === 0 && 带祝.length > 0 && 带祝[0].文本.includes('好运加护')) {
    ok(`B 真的放得出来、关掉就一条都不放（记录：「${带祝[0].文本}」）—— 对照成立，别的数值一个都没改`);
  } else bad(`B 开关对照不对：带 ${带祝.length} / 不带 ${不带祝.length}`);
  /* 界面上看得见（A2 的卡行 + A2 自己的武器池） */
  界面.手动播放 = true;
  界面.清空();
  界面.编队.出击 = [{ 键: 'A1', 位: 0 }, { 键: 'A2', 位: 1 }];
  界面.开战(20261011);
  const html15 = String(page.byId.get('screen') && page.byId.get('screen').innerHTML || '');
  const 祝卡行 = (html15.match(/好运加护 · 暴击倍率[^<]*/g) || [])[0] || '';
  if (祝卡行.includes('暴击倍率 +1（×3）') && 祝卡行.includes('命中 -20')) {
    ok(`B 战斗屏上看得见：艾克赛琳的卡行写着「${祝卡行}」`);
  } else bad(`B 卡行没写好运加护：「${祝卡行}」`);
  if (!/undefined|NaN/.test(html15)) ok('B 战斗屏 HTML 里没有 undefined / NaN');
  else bad('B 战斗屏 HTML 里出现了 undefined / NaN');
  for (const 文件 of ['src\\js\\10-数据.js', 'src\\js\\20-战斗计算.js', 'src\\js\\60-战斗.js', 'src\\js\\71-改动.js', 'src\\js\\72-势力.js', 'src\\js\\99-boot.js']) {
    if (!/Math\.random/.test(源码(文件))) ok(`${文件} 里一处 \`Math.random\` 都没有`);
    else bad(`${文件} 里出现了 Math.random`);
  }

  /* ================= C. 烟雾 / 迷彩的换义登记（作者同意先不做） ================= */
  const 烟 = ATX15参.未接项.find(x => x.项.includes('烟雾弹')), 迷 = ATX15参.未接项.find(x => x.项.includes('念动迷彩'));
  if (烟 && 烟.换义建议.length > 10) ok(`C 烟雾弹的换义登记（作者同意先不做）：「${烟.换义建议}」`);
  else bad('C 烟雾弹的换义建议没登记');
  if (迷 && 迷.换义建议.length > 10) ok(`C 念动迷彩的换义登记（作者同意先不做）：「${迷.换义建议}」`);
  else bad('C 念动迷彩的换义建议没登记');
  /* 换义建议里「相邻位没有队友 → 被命中 −X」这一条（任务书点名的例子）在两份文档里都写了 */
  const 板 = 源码('协作\\任务板.md');
  if (板.includes('相邻位') && (板.includes('烟雾') || 板.includes('迷彩'))) {
    ok('C `协作/任务板.md` 里也记着这两条的换义建议（本轮追加的那一段）');
  } else info('C 任务板里换义登记的位置见本轮追加段（这一段只在参数表里钉一遍）');
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '势力特色测试全部通过');
process.exit(fails ? 1 : 0);
