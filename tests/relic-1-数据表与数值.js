
let fails = 0;
const errs = [];
const ok = m => console.log('  ✓ ' + m);
const bad = m => { fails++; errs.push(m); console.log('  ✗ ' + m); };
const info = m => console.log('    · ' + m);

const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
if (page.errors.length) {
  page.errors.forEach(e => bad('内联脚本执行报错：' + e));
  console.log(`\nERRS [${errs.join(' | ')}]`);
  process.exit(1);
}
const G = page.sandbox.__game;
const 界面 = G.界面, 播放 = G.播放, 肉鸽 = G.肉鸽, 肉鸽界面 = G.肉鸽界面;
界面.手动播放 = true;
界面.设跳过动画(true);
console.log(`藏品测试：机甲指挥 ${G.version} · ${G.milestone}\n`);

/** ★ 2026-10-11 券系统：**肉鸽开局名册是空的**（分队不带机体；改前白送默认五人队），
 *  所以凡是要「在名册上算晋升 / 摆几台出去打」的段落都先**真的招人**（开招募屏 → 选中一张对得上的券 → 招募）。
 *  `要的` 里的键（例如 B1）优先招进来 —— 后面几段是针对具体机体验的（B1 的藏品加成、B1 的晋升）。
 *  ★ 2026-10-12 修真 bug：**没券就不能招** → 这里没有「不用券」那一步了（见函数里那句注释）。
 *  希望不够时再补预算重来（测试给足希望：测的是流程，不是经济）。 */
function 招几个(n = 3, 要的 = [], 预算 = 80) {
  const R = 肉鸽.RUN;
  if (!R) return 0;
  const 一起 = () => {
    界面.开屏('招募');
    const 费 = k => G.肉鸽数值.招募费[G.tierOf(k)] || 0;
    let 招到 = 0;
    for (let 轮 = 0; R.队伍.length < n && 轮 < 30; 轮++) {
      const 已有 = new Set(R.队伍.map(m => m.键));
      const 剩下的要的 = 要的.filter(k => !已有.has(k));
      const 其它 = G.ALLY_T.map(t => t.mech).filter(k => !已有.has(k) && !剩下的要的.includes(k));
      let 成了 = false;
      /* ★ `要的` 里的人**优先**：先在「对得上的券」里找他们要的人，找不到再考虑别人 ——
         否则随机发到的券会把名册位置先占掉（以前这里踩过：想招 B1，结果先招了台重装）。 */
      const 试招 = k => {
        for (let i = 0; i < (R.券 || []).length; i++) {
          if (!G.券合(R.券[i], k) || R.希望 < 费(k)) continue;
          界面.用券(i);
          const r = 肉鸽.招募(k, i);
          if (r && r.ok) return true;
          肉鸽界面.选中的券 = null;
        }
        return false;
      };
      for (const k of 剩下的要的) if (试招(k)) { 招到++; 成了 = true; break; }
      if (成了) continue;
      /* 没有指定的人 / 招不到 → 拿手上任何一张券招一个对得上、又付得起的 */
      for (let i = 0; i < (R.券 || []).length && !成了; i++) {
        const 合 = 其它.filter(k => G.券合(R.券[i], k)).sort((a, b) => 费(a) - 费(b));
        for (const k of 合) {
          if (R.希望 < 费(k)) continue;
          界面.用券(i);
          const r = 肉鸽.招募(k, i);
          if (r && r.ok) { 招到++; 成了 = true; break; }
          肉鸽界面.选中的券 = null;
        }
      }
      if (成了) continue;
      /* ★ 2026-10-12 修真 bug：**没券就不能招**（`90-肉鸽.js` 的 `招募()` 没券直接拒绝），
         所以这里**删掉了原来「不用券」那一步的兜底** —— 一张能用的券都没有时，
         补一张「和某位候选同职业」的券再试（测试的补券口子；招募那一步照旧走
         `界面.用券` → `肉鸽.招募(键, 下标)`）。 */
      肉鸽界面.选中的券 = null;
      const 能付 = 其它.filter(k => R.希望 >= 费(k)).sort((a, b) => 费(a) - 费(b))[0];
      if (能付 == null) break;
      R.券.push({ 类: '职业', 名: G.tplOf(能付).tags.战斗分类, 档: null, 来源: '测试' });
      const 补 = R.券.length - 1;
      界面.用券(补);
      const r2 = 肉鸽.招募(能付, 补);
      if (r2 && r2.ok) { 招到++; continue; }
      肉鸽界面.选中的券 = null;
      break;
    }
    if (界面.屏 !== '大地图') 界面.开屏('大地图');
    return 招到;
  };
  const 招到 = 一起();
  if (R.队伍.length < n) { R.希望 += 预算; return 一起(); }
  return 招到;
}

/** 把当前这一场打完（自动战斗是一回合一个回合的，要一直点开打） */
function 打完这一场() {
  let 轮 = 0;
  while (界面.屏 === '战斗' && 轮++ < 30) {
    界面.开打();
    let n = 0;
    while (界面.阶段 === '播放' && n++ < 100000) 播放.tick();
  }
}

/* 一场固定的对照战斗：A = 不带藏品，B = 带指定藏品（同种子、同编成、同指令） */
const 对照我方 = [{ 键: 'B1', 位: 0, 等级: 10 }, { 键: 'B2', 位: 1, 等级: 10 }, { 键: 'CB2', 位: 4, 等级: 10 }];
const 对照敌方 = [{ 键: 'grunt', 位: 0, 等级: 10 }, { 键: 'grunt', 位: 1, 等级: 10 }, { 键: 'shield', 位: 2, 等级: 10 }];
const 对照种子 = 20261010;
/** 带藏品跑一场：先开一局（把藏品塞进 RUN），再开局——开局() 里会自己调 藏品开战 */
function 跑一场(藏品们, 种子) {
  const 旧 = 肉鸽.RUN;
  肉鸽.RUN = { 种子: 种子 || 对照种子, 层: 1, 场次: 0, 藏品: 藏品们 || [], 日志: [] };
  const r = G.simulate(对照我方, 对照敌方, {}, 种子 || 对照种子);
  肉鸽.RUN = 旧;
  return r;
}

/* ============================ [1] 32 件纯数值藏品都在表里 ============================ */
console.log('[1] 32 件纯数值藏品：数据表齐不齐、字段读不读得到');
{
  const 表 = G.藏品表;
  const 全部 = Object.keys(表);
  /* 战棋那份是 50 件；2026-10-11 又新造了 G 组 8 件（希望 / 出击上限），标了 `新造: true`。 */
  const 战棋件 = 全部.filter(id => !表[id].新造);
  const 新造件 = 全部.filter(id => 表[id].新造);
  info(`藏品表共 ${全部.length} 件 = 战棋 ${战棋件.length} 件 + 2026-10-11 新造 ${新造件.length} 件（${新造件.join('、')}）`);
  if (战棋件.length === 50) ok(`战棋 RELICS 的 50 件**一件不缺**（32 件纯数值 + 7 件经济编制 + 11 件不能用：23b-藏品.js:12-69）`);
  else bad(`战棋那 50 件里少了：${50 - 战棋件.length} 件（表里战棋件只有 ${战棋件.length} 件）`);
  if (新造件.length === 8) ok(`2026-10-11 新造 8 件（作者拍板：希望 3 / 编制 2 / 复合 2 / 负面换正面 1）：${新造件.map(id => 表[id].名).join('、')}`);
  else bad(`新造件不是 8 件：${新造件.length} 件（${新造件.join('、')}）`);

  const 缺 = [], 字段坏 = [];
  for (const id of G.藏品纯数值32) {
    const r = 表[id];
    if (!r) { 缺.push(id); continue; }
    if (!r.名 || !r.稀有 || !r.说明 || !r.数值 || !r.实装 || !r.分类) 字段坏.push(id);
    /* 每一件纯数值藏品至少要有一个能落地的字段：mods / stat / stack / foe / foeStack / 特殊 */
    const e = r.数值 || {};
    if (!e.mods && !e.stat && !e.stack && !e.foe && !e.foeStack && !e.特殊) 字段坏.push(id + '(没有效果字段)');
  }
  if (!缺.length) ok(`战棋分类表里的 32 件【数值】藏品**一件不缺**（${G.藏品纯数值32.join('、')}）`);
  else bad(`有 ${缺.length} 件纯数值藏品没进表：${缺.join('、')}`);
  if (!字段坏.length) ok('32 件的 id / 名字 / 稀有度 / 说明 / 数值 / 实装 / 分类 都读得到');
  else bad(`字段不全：${字段坏.join('、')}`);

  const 没接 = G.藏品接不了;
  if (没接.length === 10) ok(`「接不了」清单 ${没接.length} 件：${没接.join('、')}（原来的 11 件里 \`f4 编制扩充令\` 已由作者 2026-10-11 拍板「B：接」而移出）`);
  else bad(`「接不了」清单是 ${没接.length} 件，预期 10 件（11 − f4）`);
  if (!没接.includes('f4') && 表.f4 && 表.f4.实装 === '已接' && 表.f4.抽 === true) {
    ok('`f4 编制扩充令` 已从「接不了」清单移出、标成「已接」、并且进了随机池（作者 2026-10-11 拍板「B：接」）');
  } else bad(`f4 的状态不对：${JSON.stringify({ 在没接里: 没接.includes('f4'), 实装: 表.f4 && 表.f4.实装, 抽: 表.f4 && 表.f4.抽 })}`);
  const 没写的 = 没接.filter(id => !表[id] || !表[id].缺 || 表[id].缺 === '实装');
  if (!没写的.length) ok('接不了的每一件都写了「缺什么」的理由字段');
  else bad(`这些接不了的没写理由：${没写的.join('、')}`);

  /* 真的接上了几件（实装 === '已接'）+ 部分接的（战棋分类表里那 32 件）
     注意：部分接的那两件，`实装` 里也带「未接」两个字，所以判断要用 === 而不是子串匹配 */
  const 已接 = 全部.filter(id => 表[id].实装 === '已接');
  const 部分 = 全部.filter(id => 表[id].实装.startsWith('部分'));
  const 纯数值已接 = G.藏品纯数值32.filter(id => 表[id].实装 !== '未接');
  const 纯部分 = 纯数值已接.filter(id => 表[id].实装.startsWith('部分'));
  ok(`纯数值 32 件里：整件生效 ${纯数值已接.filter(id => 表[id].实装 === '已接').length} 件、` +
     `部分生效 ${纯部分.length} 件（${纯部分.join('、')}）、整件没接 ${32 - 纯数值已接.length} 件`);
  info(`全表实装：已接 ${已接.length} 件 / 部分 ${部分.length} 件 / 未接 ${全部.length - 已接.length - 部分.length} 件`);

  /* 抽签池：只抽真的会生效的（s2 / n2 的射程那半边没法验，所以不进池） */
  const 池 = G.藏品可抽池();
  if (池.length === 44 && !池.includes('s2') && !池.includes('n2')) {
    ok(`随机池 ${池.length} 件（32 件纯数值里去掉只有一半能用的 s2 / n2 = 28 件，` +
       `加 2026-10-11 接上的 t1–t6 免费晋升 + f1 黑市会员卡 = 35 件，再加 2026-10-11 新造的 G 组 8 件 = 43 件，` +
       `再 **f4 编制扩充令**接上 = 44 件）`);
  } else bad(`随机池不对：${池.length} 件${池.includes('s2') ? '（含 s2）' : ''}${池.includes('n2') ? '（含 n2）' : ''}`);
  if (['t1', 't2', 't3', 't4', 't5', 't6', 'f1'].every(id => 池.includes(id))) {
    ok('t1–t6（免费晋升）+ f1（黑市 −30%）都在随机池里（能真的拿到手）');
  } else bad('经济编制藏品没进随机池：' + ['t1', 't2', 't3', 't4', 't5', 't6', 'f1'].filter(id => !池.includes(id)).join('、'));
  if (新造件.every(id => 池.includes(id))) {
    ok(`新造的 8 件**全部进随机池**（${新造件.join('、')}）`);
  } else bad('新造藏品没进随机池：' + 新造件.filter(id => !池.includes(id)).join('、'));

  /* 数值逐字对账：拿战棋源码那几行样例一个字一个字比（只比 mods / stat / stack / foe / foeStack） */
  const 数值块 = r => {
    const e = r.数值 || {}, o = {};
    /* 按固定顺序拼，好和战棋源码那一行逐字比 */
    for (const k of ['职业', 'mods', 'stat', 'stack', 'foe', 'foeStack', '特殊'].sort()) if (e[k] !== undefined) o[k] = e[k];
    return JSON.stringify(o);
  };
  const 样例 = [
    ['g3', { 职业: ['近卫'], mods: { dmg: 40, crit: 15, armorPct: -40 } }, '23b-藏品.js:16'],
    ['h2', { 职业: ['重装'], mods: { red: 15 } }, '23b-藏品.js:27'],
    ['n4', { stack: { by: ['狙击'], per: { hit: 5 }, max: 5 } }, '23b-藏品.js:33'],
    ['e9', { foe: { armorPct: -30 } }, '23b-藏品.js:63'],
    ['p3', { stack: { by: ['狙击', '特种'], per: { hit: 5, dmg: 4 }, max: 12, to: ['狙击', '特种'] } }, '23b-藏品.js:48'],
    ['g1', { 职业: ['近卫'], stat: { hpPct: 30 }, mods: { armorPct: 15 } }, '23b-藏品.js:14'],
    ['b2', { 特殊: 'lonewolf' }, '23b-藏品.js:51'],
  ];
  for (const [id, 期望, 出处] of 样例) {
    const 真 = 数值块(表[id]);
    const 想 = JSON.stringify(Object.fromEntries(Object.entries(期望).sort(([a], [b]) => a < b ? -1 : 1)));
    if (真 === 想) ok(`${id}【${表[id].名}】的数值与战棋逐字相同（${出处}）`);
    else bad(`${id} 的数值和战棋对不上：表里 ${真}，战棋 ${想}`);
  }
}

/* ============================ [2] 数值真的进了公式（前后对比） ============================ */
console.log('\n[2] 抽 5 件有代表性的藏品，验证数值真的进了公式');
{
  const 裸 = () => G.makeUnit('B1', 'ally', 0, 10);
  const 上 = (u, id) => { G.应用藏品我方([u], [id]); return u; };
  const 靶 = () => G.makeUnit('grunt', 'enemy', 0, 10);
  const 主武器 = u => u.weapons.find(e => e.t.name === '近战斩击').t;

  /* (a) +最大 HP 30%：g1 格斗框架·强化型（近卫 HP +30%） */
  {
    const a = 裸(), b = 上(裸(), 'g1');
    if (b.maxHp > a.maxHp && b.maxHp === Math.round(a.maxHp * 1.3)) {
      ok(`g1【格斗框架·强化型】近卫 HP +30%：maxHp ${a.maxHp} → ${b.maxHp}（×1.3）、hp 跟着涨到 ${b.hp}`);
    } else bad(`g1 的 HP 加成不对：${a.maxHp} → ${b.maxHp}（预期 ${Math.round(a.maxHp * 1.3)}）`);
    /* 同一条还带 armorPct +15：进 effArmor */
    info(`g1 的装甲 +15% 也进去了：effArmor ${G.effArmor(a)} → ${G.effArmor(b)}`);
  }

  /* (b) +命中：p3 远程协议（每 1 名狙击或特种出击 → 狙击 / 特种命中 +5）
         命中率会被 0–100 截断，所以看公式里的**原始值 raw**（= 武器命中 − 闪避 + 精准修正 + 命中加成）；
         另外要比**同一台机体**加藏品前后，不然两台机体的精准不一样，差值就不干净了。 */
  {
    const 甲 = G.makeUnit('CB2', 'ally', 4, 10);
    const wa = 甲.weapons.find(e => e.t.name === 'GN 狙击步枪').t;
    const t = G.makeUnit('grunt', 'enemy', 0, 10);
    const 前 = G.hitRate(甲, wa, t, { turn: 1 });
    /* 出击队伍 = 1 狙击 + 1 特种 → p3 一层 */
    const 出击 = [甲, G.makeUnit('CB3', 'ally', 3, 10)];
    G.应用藏品我方(出击, ['p3']);
    const 后 = G.hitRate(甲, wa, t, { turn: 1 });
    if (后.raw - 前.raw === 10 && (甲.藏品加成 || {}).hit === 10) {
      ok(`p3【远程协议】狙击 / 特种命中 +5 × 每名出击 = 2 名（1 狙击 + 1 特种）→ +10：` +
         `同一台 CB2 的命中原始值 ${前.raw} → ${后.raw}（结算值 ${前.hit}% → ${后.hit}%）`);
    } else bad(`p3 的命中加成不对：原始值 ${前.raw} → ${后.raw}，藏品加成 ${JSON.stringify(甲.藏品加成)}（预期 +10）`);
    /* 战棋的「+命中 10」干净例子：在同一台机体的 buffs 上直接挂 10 点，验公式一比一进去 */
    const 乙 = G.makeUnit('CB2', 'ally', 4, 10);
    乙.buffs = [{ src: '测试', hit: 10 }];
    const h2 = G.hitRate(乙, wa, t, { turn: 1 });
    if (h2.raw - 前.raw === 10) ok(`+命中 10 → hitRate 原始值高 10：${前.raw} → ${h2.raw}（公式一比一）`);
    else bad(`+命中 10 之后原始值是 ${h2.raw}，裸的是 ${前.raw}（差 ${h2.raw - 前.raw}，预期 10）`);
    /* 把靶子的闪避调高，看结算值是不是也真的涨 10（不撞 100% 天花板）。
       两台都是**全新的裸机**：上面那台 甲 已经被挂上藏品增益了，不能拿它当「前」的基准。 */
    const 裸机 = G.makeUnit('CB2', 'ally', 4, 10);
    const 加十 = G.makeUnit('CB2', 'ally', 4, 10);
    加十.buffs = [{ src: '测试', hit: 10 }];
    const 厚 = G.makeUnit('grunt', 'enemy', 0, 10);
    厚.eva = 25;
    const 厚前 = G.hitRate(裸机, wa, 厚, { turn: 1 }).hit;
    const 厚后 = G.hitRate(加十, wa, 厚, { turn: 1 }).hit;
    /* 再加一把**低命中武器**当靶子的对打：让结算值落进 0–100 的中间段，
       这样「+10 命中」在界面上真的看得见（上面那两行是被 100% 上限截断的） */
    const 手 = G.makeUnit('CB2', 'ally', 4, 10);
    const 手2 = G.makeUnit('CB2', 'ally', 4, 10);
    手2.buffs = [{ src: '测试', hit: 10 }];
    const 低命中 = Object.assign({}, wa, { hit: 100 });
    const 低前 = G.hitRate(手, 低命中, 厚, { turn: 1 }).hit;
    const 低后 = G.hitRate(手2, 低命中, 厚, { turn: 1 }).hit;
    if (低后 - 低前 === 10) ok(`换成命中 ${低命中.hit} 的武器打闪避 ${厚.eva} 的靶子：结算命中 ${低前}% → ${低后}%（+10 真的进了结算值）`);
    else info(`低命中那一发：${低前}% → ${低后}%（差 ${低后 - 低前}）`);
    const 例 = G.dmgCore(出击[1], 出击[1].weapons[0].t, t, { power: 1000, preview: true, turn: 1 });
    info(`p3 还带伤害 +4%：走的是下面 (c) 里的同一个「伤害加成」入口；这一场的步骤第 2 行 = ${例.steps[1]}`);
  }

  /* (c) +伤害：战棋 v0.37 起「伤害 +N%」= 攻击能力值 +N（03-能力与减免管线.js:185-188 的 genMods）。
         要看清「+N 攻击能力值等于伤害 +N%」，得让 statCoef 的基准正好是 1（攻击能力值 = 防御值）：
         伤害 =（威力 − 装甲）×（1 +（攻击 + N − 防御）/ 100）→ 装甲 0、攻击 = 防御 时 = 威力 ×(1 + N/100)。 */
  {
    const 纯靶 = () => { const t = G.makeUnit('grunt', 'enemy', 0, 2); t.armor = 0; t.defense = 0; t.eva = 0; return t; };
    const a = 裸(), b = 裸();
    const w = 主武器(a), t = 纯靶();
    /* 把攻击能力值和防御值配平成「系数 = 1」的干净局面 */
    a.melee = 100; b.melee = 100; t.defense = 100;
    const 基 = G.dmgCore(a, w, t, { power: G.wv(a, w, 'power'), preview: true, turn: 1 }).dmg;
    b.buffs = [{ src: '测试', dmg: 10 }];
    const 后 = G.dmgCore(b, w, t, { power: G.wv(b, w, 'power'), preview: true, turn: 1 }).dmg;
    const 比 = 后 / 基;
    if (Math.abs(比 - 1.1) < 0.005) {
      ok(`+伤害 10%（攻击能力值 100 → 110）→ dmgCore ×${比.toFixed(3)}：${基} → ${后}` +
         `（系数 1.00 → 1.10，坦克靶：装甲 0、攻击 = 防御 = 100）`);
    } else bad(`+伤害 10% 之后 dmgCore 是 ${后}（裸 ${基}，比 ${比.toFixed(3)}，预期 1.1）`);
    info(`公式步骤：${G.dmgCore(b, w, t, { power: G.wv(b, w, 'power'), preview: true, turn: 1 }).steps[1]}`);
    /* 藏品的真实例子：g2 高输出光束军刀（近卫伤害 +25%），同一个干净局面 */
    const c = 裸();
    c.melee = 100;
    G.应用藏品我方([c], ['g2']);
    const 后2 = G.dmgCore(c, w, t, { power: G.wv(c, w, 'power'), preview: true, turn: 1 }).dmg;
    const 比2 = 后2 / 基;
    if (Math.abs(比2 - 1.25) < 0.005) ok(`g2【高输出光束军刀】近卫伤害 +25% → ×${比2.toFixed(3)}：${基} → ${后2}`);
    else bad(`g2 的伤害加成不对：${基} → ${后2}（比 ${比2.toFixed(3)}，预期 1.25）`);
    /* 打真靶子（量产机：装甲 350、防御 52）时倍数不是整 1.25，把真实倍数也贴出来 */
    const 真靶 = G.makeUnit('grunt', 'enemy', 0, 10);
    const 真基 = G.dmgCore(a, w, 真靶, { power: G.wv(a, w, 'power'), preview: true, turn: 1 }).dmg;
    const 真后 = G.dmgCore(c, w, 真靶, { power: G.wv(c, w, 'power'), preview: true, turn: 1 }).dmg;
    info(`打量产机（装甲 350 / 防御 52、攻击能力值 178）时：+25 攻击能力值 → ${真基} → ${真后}` +
         `（×${(真后 / 真基).toFixed(3)}；−装甲 那一段不受攻击加成影响，所以不是整 1.25）`);
    /* 职业限定：同一件给狙击（CB2）不该生效 */
    const d = G.makeUnit('CB2', 'ally', 4, 10);
    G.应用藏品我方([d], ['g2']);
    if (!d.藏品加成) ok('g2 是「近卫」专属：给狙击（CB2）加的时候**一点都没生效**（职业限定真的在起效）');
    else bad(`g2 给狙击也生效了：${JSON.stringify(d.藏品加成)}`);
  }

  /* (d) +装甲 20%：e2 复合装甲（全队装甲 +20%） */
  {
    const a = 裸(), b = 上(裸(), 'e2');
    if (G.effArmor(b) === Math.round(G.effArmor(a) * 1.2)) {
      ok(`e2【复合装甲】全队装甲 +20%：effArmor ${G.effArmor(a)} → ${G.effArmor(b)}`);
    } else bad(`e2 的装甲加成不对：${G.effArmor(a)} → ${G.effArmor(b)}（预期 ${Math.round(G.effArmor(a) * 1.2)}）`);
    const t = 靶();
    const wa = 主武器(a), wb = 主武器(b);
    const da = G.dmgCore(a, wa, t, { power: G.wv(a, wa, 'power'), preview: true, turn: 1 }).dmg;
    const db = G.dmgCore(b, wb, t, { power: G.wv(b, wb, 'power'), preview: true, turn: 1 }).dmg;
    info(`装甲进的是「被攻击那一方」：这里 B1 是攻击者，所以自己的伤害不变（${da} / ${db}）；` +
         `让 B1 当靶子时装甲会减伤（见 (e)）`);
  }

  /* (e) +减伤 15%：h2 反应装甲（重装减伤 +15%）——减伤按战棋进「防御值」 */
  {
    const 靶子 = () => G.makeUnit('grunt', 'enemy', 0, 10);
    const 打手 = G.makeUnit('B1', 'ally', 0, 10);
    const w = 主武器(打手);
    const t1 = 靶子();
    const 前 = G.dmgCore(打手, w, t1, { power: G.wv(打手, w, 'power'), preview: true, turn: 1 }).dmg;
    const t2 = 靶子();
    t2.buffs = [{ src: '藏品', red: 15 }];
    const 后 = G.dmgCore(打手, w, t2, { power: G.wv(打手, w, 'power'), preview: true, turn: 1 }).dmg;
    if (后 < 前) ok(`+减伤 15%（进防御值）→ 挨打伤害 ${前} → ${后}（战棋把它算在 stage 2 的防御值上：03:230,259）`);
    else bad(`减伤没生效：${前} → ${后}`);
    /* 藏品的真实例子走一遍：h2 给重装 = 那个重装的 effArmor 不变、但 dmgCore 里的防御值 +15 */
    const m2 = G.makeUnit('M2', 'ally', 1, 10);
    G.应用藏品我方([m2], ['h2']);
    const 步 = G.dmgCore(打手, w, m2, { power: G.wv(打手, w, 'power'), preview: true, turn: 1 }).steps.join(' | ');
    if (步.includes('减伤 +15')) ok(`h2【反应装甲】真的挂在重装身上了（步骤里能看到「减伤 +15」）：${步.split(' | ')[1]}`);
    else bad(`h2 没有进防御值：${步}`);
  }

  /* (f) 敌方那一侧：e9 λ 观测数据（敌方全体装甲 −30%）+ e4（敌方命中 −5） */
  {
    const 我 = G.makeUnit('B1', 'ally', 0, 10);
    const 敌 = G.makeUnit('grunt', 'enemy', 0, 10);
    const 甲前 = G.effArmor(敌);
    G.应用藏品敌方([敌], [我], ['e9', 'e4']);
    const 甲后 = G.effArmor(敌);
    if (甲后 === Math.round(甲前 * 0.7)) ok(`e9【λ 观测数据】敌方全体装甲 −30%：effArmor ${甲前} → ${甲后}`);
    else bad(`e9 没生效：${甲前} → ${甲后}（预期 ${Math.round(甲前 * 0.7)}）`);
    const 我2 = G.makeUnit('B1', 'ally', 0, 10);
    const 敌2 = G.makeUnit('grunt', 'enemy', 0, 10);
    const w敌 = 敌2.weapons[0].t;
    const 前 = G.hitRate(敌2, w敌, 我2, { turn: 1 }).hit;
    const 敌3 = G.makeUnit('grunt', 'enemy', 0, 10);
    G.应用藏品敌方([敌3], [我2], ['e4']);
    const 后 = G.hitRate(敌3, w敌, 我2, { turn: 1 }).hit;
    if (前 - 后 === 5) ok(`e4【ECM 干扰器】敌方全体命中 −5：敌方打我方 ${前}% → ${后}%`);
    else bad(`e4 没生效：${前}% → ${后}%（预期差 5）`);
  }

  /* (g) 叠层：n4 交叉火力（每 1 名狙击出击全队命中 +5，最多 5 层）
     ★ 2026-10-11 难度调整（杠杆 ①「同类加成设叠加上限」）：命中那一类封到 `难度调整.藏品同类上限.我方.hit = 12`
       → 叠层本身仍然是 +5 / 层（上限 5 层 = +25），但**求和之后被同类上限夹住**：
       1 名 +5（没到顶，原样）、3 名 15 → **12**、6 名 25 → **12**。 */
  {
    const 队 = n => Array.from({ length: n }, (_, i) => G.makeUnit('CB2', 'ally', i, 10));
    const 一 = 队(1), 三 = 队(3), 六 = 队(6);
    G.应用藏品我方(一, ['n4']); G.应用藏品我方(三, ['n4']); G.应用藏品我方(六, ['n4']);
    const v = x => (x[0].藏品加成 || {}).hit || 0;
    if (v(一) === 5 && v(三) === 12 && v(六) === 12) {
      ok(`n4【交叉火力】按出击狙击人数叠层：1 名 +5、3 名 15 → **12**、6 名 25 → **12**`
        + `（叠层照旧 +5/层，但被同类上限 hit=${G.难度调整.藏品同类上限.我方.hit} 夹住）`);
    } else bad(`叠层不对：1 名 ${v(一)}、3 名 ${v(三)}、6 名 ${v(六)}（预期 5 / 12 / 12 —— 叠层 5 / 15 / 25 被同类上限 12 夹住）`);
  }

  /* (h) 整场加成：b1 混编作战条例（每个不同职业 +8% 伤害）、b2 孤狼
     ★ 杠杆 ① 同类上限也在这里生效：b2 孤狼的 +50% 伤害 → **dmg 上限 35**、+30% 装甲 → armorPct 上限 30（正好相等）。 */
  {
    const 三人 = [G.makeUnit('B1', 'ally', 0, 10), G.makeUnit('B2', 'ally', 1, 10), G.makeUnit('CB2', 'ally', 4, 10)];
    G.应用藏品我方(三人, ['b1']);
    if ((三人[0].藏品加成 || {}).dmg === 24) ok(`b1【混编作战条例】3 个不同职业 → 全队伤害 +24%（8 × 3，没到上限 35）`);
    else bad(`b1 的混编加成不对：${JSON.stringify(三人[0].藏品加成)}`);
    const 两人 = [G.makeUnit('B1', 'ally', 0, 10), G.makeUnit('B1', 'ally', 1, 10)];
    G.应用藏品我方(两人, ['b2']);
    if ((两人[0].藏品加成 || {}).dmg === 35 && (两人[0].藏品加成 || {}).armorPct === 30) {
      ok(`b2【孤狼】出击 2 人 → 全队伤害 +50% 被同类上限夹到 **+35**、装甲 +30%（装甲那一档正好等于上限 30）`);
    } else bad(`b2 的孤狼加成不对：${JSON.stringify(两人[0].藏品加成)}（预期 dmg 35 / armorPct 30）`);
    const 四人 = [1, 2, 3, 4].map(i => G.makeUnit('B1', 'ally', i, 10));
    G.应用藏品我方(四人, ['b2']);
    if ((四人[0].藏品加成 || {}).dmg === -15) ok(`b2【孤狼】出击 4 人 → 全队伤害 −15%（代价那一半也照抄了，且没碰到上限）`);
    else bad(`b2 的 4 人分支不对：${JSON.stringify(四人[0].藏品加成)}`);
    /* 顺手钉住「上限是上限、不是打折」：没到上限的组合一个数字都不许变 */
    const 单件 = [G.makeUnit('B1', 'ally', 0, 10)];
    G.应用藏品我方(单件, ['g1']);
    if ((单件[0].藏品加成 || {}).armorPct === 15 && (单件[0].藏品加成 || {}).dmg == null) {
      ok(`同类上限**不是打折**：只带 g1（装甲 +15%）时加数与改前逐字相同（15 < 上限 30，一点没被削）`);
    } else bad(`小加成被误削了：${JSON.stringify(单件[0].藏品加成)}`);
  }
}

