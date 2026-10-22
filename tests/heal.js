#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 奶妈（修理）测试 —— 作者 2026-10-10 拍板的两件事
 * ----------------------------------------------------------------------------
 * 拍板 1：**给「特种」加奶妈** —— B3 维诺（初稿「影之愈」）、M5 苏菲（初稿「牵引维修臂」）
 *         各加一把修理武器（`fire:'heal'`）。数据只改 `src/js/71-改动.js`，
 *         `10-数据.js`（战棋复制件）一个字都不改；两人**保留特种的职业特色**（命中后挂「命中 −20」）。
 * 拍板 2：**修理 AI 的阈值** —— 有人 HP 比例**低于 60%**（`50-AI.js` 顶部的 `修理阈值`）才优先修，
 *         否则这个单位正常输出 / 上 debuff（原来 M1 是「有伤就修」）。
 *
 * 这份测试真的跑（固定种子 + 单回合驱动，结果决定性），盯着五件事：
 *   [1] 两把修理武器真的在模板上、`rangeKindOf` = 修理，而且修理工真拿得到（`usableWeapons`）
 *   [2] 有人掉到 60% 以下时 AI 真的修，**回复的数值 = `healAmount`**（贴出数字）
 *   [3] 没有人低于 60% 时**不修**，而是正常出手
 *   [4] 阈值边界：刚好 60% 不修、61% 不修、59% 修
 *   [5] 同种子两次跑，记录逐字相同
 *
 * 用法：node tests/heal.js
 * ========================================================================== */
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { loadPage } from './lib/dom-stub.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');

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

/** 两把新修理武器的初稿参数（作者要试玩后再调；改数值改 `71-改动.js`，这份测试跟着改） */
const 新武器 = [
  { 键: 'B3', 机师: '维诺', 名字: '影之愈', power: 2600 },
  { 键: 'M5', 机师: '苏菲', 名字: '牵引维修臂', power: 2700 },
];
const 修录 = (ctx, 位) => ctx.log.filter(x => x.类型 === '修理' && x.单位位 === 位);
const 攻录 = (ctx, 位) => ctx.log.filter(x => x.类型 === '攻击' && x.单位位 === 位);

console.log(`奶妈（修理）测试：机甲指挥 ${G.version} · ${G.milestone}\n`);
info(`修理阈值 = ${G.修理阈值}（作者 2026-10-10 拍板，出处写在 50-AI.js 顶部）`);

/* ============================ [1] 两把修理武器真的加上了 ============================ */
console.log('\n[1] 维诺 / 苏菲 身上的修理武器（数据只改 71-改动.js）');
for (const { 键, 机师, 名字, power } of 新武器) {
  const t = G.ALLY_T.find(x => x.mech === 键);
  const 修 = (t ? t.weapons : []).filter(w => w.fire === 'heal');
  if (修.length === 1 && 修[0].name === 名字) ok(`${机师}（${键}）有且只有一把修理武器：【${修[0].name}】fire=${修[0].fire} power=${修[0].power}`);
  else bad(`${机师}（${键}）的修理武器不对：${JSON.stringify(修.map(w => [w.name, w.fire, w.power]))}`);
  const w = 修[0];
  if (!w) continue;
  if (G.rangeKindOf(w) === '修理') ok(`【${w.name}】的 rangeKindOf = 修理（走的是 30-射程.js 的 fire:'heal' 换算，不是手改每把武器）`);
  else bad(`【${w.name}】的 rangeKindOf = ${G.rangeKindOf(w)}，应该是「修理」`);
  if (w.power === power) ok(`【${w.name}】威力 ${w.power}（初稿数值，作者试玩后再调）`);
  else bad(`【${w.name}】威力 ${w.power}，这份测试记的初稿是 ${power}（改了数值就要同步改测试）`);
  /* 职业特色：还是特种，而且没有加别的特色武器 */
  if (t.tags.战斗分类 === '特种') ok(`${机师} 还是「特种」（保留命中后给对方挂「命中 −20」的职业特色，没有加别的特色）`);
  else bad(`${机师} 的战斗分类变成了 ${t.tags.战斗分类}`);
  /* 修理工真的拿得到：weaponPlayable + usableWeapons 两道门都要过 */
  if (G.weaponPlayable(w)) ok(`【${w.name}】过了 weaponPlayable（fire:'heal' 不会被「第一期不做」的条件卡住）`);
  else bad(`【${w.name}】被 weaponPlayable 卡住了——修理工拿不到修理武器`);
  const u = G.makeUnit(键, 'ally', 4, 10);
  const 能用 = G.usableWeapons(u, { turn: 1 }).filter(e => e.t.fire === 'heal');
  if (能用.length === 1) ok(`Lv10 第 1 回合 usableWeapons 里有【${能用[0].t.name}】（unlock ${能用[0].t.unlock} / readyTurn ${能用[0].readyTurn}）`);
  else bad(`Lv10 第 1 回合拿不到修理武器：${JSON.stringify(能用.map(e => e.t.name))}`);
  const 量 = G.healAmount(u, w);
  ok(`${机师} Lv10（射击 ${u.shoot}）的修理量 = ${w.power} × ${u.shoot} ÷ 100 = ${量}（healAmount 公式没改）`);
  /* 已有的两把修理武器做对照，确认量级 */
  if (键 === 'B3') {
    const iris = G.makeUnit('M3', 'ally', 3, 10);
    const iw = G.ALLY_T.find(x => x.mech === 'M3').weapons.find(x => x.fire === 'heal');
    info(`对照：Iris【${iw.name}】power ${iw.power} → Lv10 修理量 ${G.healAmount(iris, iw)}（射击 ${iris.shoot}）`);
  }
}

/* ============================ [2] 有人低于 60% → 真的修 ============================ */
console.log('\n[2] 有人掉到 60% 以下时，AI 真的修（作者 2026-10-10 拍板）');
const 敌重 = [{ 键: 'grunt', 位: 0, 等级: 30 }, { 键: 'grunt', 位: 1, 等级: 30 }, { 键: 'shield', 位: 2, 等级: 30 }];
for (const { 键, 机师, 名字 } of 新武器) {
  const ctx = G.开局([{ 键, 位: 4, 等级: 10 }, { 键: 'B1', 位: 0, 等级: 10 }], 敌重, 222);
  const 奶妈 = ctx.allies.find(u => u.key === 键);
  const 伤 = ctx.allies.find(u => u.key === 'B1');
  伤.hp = Math.round(伤.maxHp * 0.2);          // 20% < 60% → 该修；缺血 5440 > 后排特种奶量 4795 → 回复量不被 maxHp 截断
  const 选 = G.chooseHeal(奶妈, ctx);
  if (选 && 选.weapon.name === 名字 && 选.target.key === 'B1') ok(`${机师} 在 40% 时选了【${选.weapon.name}】→ ${选.target.name}（目标 = HP 比例最低的队友）`);
  else bad(`${机师} 40% 时没选对：${JSON.stringify(选 && [选.weapon.name, 选.kind, 选.target.key])}`);

  G.打一回合(ctx);
  const 录 = 修录(ctx, 奶妈.slot);
  const 量 = G.healAmount(奶妈, 选.weapon);
  if (录.length === 1 && 录[0].回复 === 量 && 录[0].目标 === 'B1') {
    ok(`${机师} 真的修了：${录[0].文本} —— 回复 ${录[0].回复} 与 healAmount ${量} 一致（${选.weapon.name}）`);
  } else bad(`${机师} 的修理记录不对：${JSON.stringify(录)}（healAmount = ${量}）`);
  if (!攻录(ctx, 奶妈.slot).length) ok(`${机师} 这一回合只修、没有出手攻击（修理抢在进攻前面）`);
  else bad(`${机师} 一边修一边攻击了`);
  info(`修完 ${伤.name} 的 HP：${伤.hp}/${伤.maxHp}（${Math.round(伤.hp / 伤.maxHp * 100)}%）—— 没被上限截断，所以回复量就是 healAmount`);
}

/* ============================ [3] 没有人低于 60% → 不修，正常出手 ============================ */
console.log('\n[3] 没有人低于 60% 时不修，而是正常出手');
const 敌弱 = [{ 键: 'grunt', 位: 0, 等级: 1 }, { 键: 'grunt', 位: 1, 等级: 1 }];
for (const { 键, 机师 } of 新武器) {
  const ctx = G.开局([{ 键, 位: 4, 等级: 10 }, { 键: 'B1', 位: 0, 等级: 10 }], 敌弱, 111);
  const 奶妈 = ctx.allies.find(u => u.key === 键);
  const 满血 = ctx.allies.every(u => u.hp / u.maxHp >= G.修理阈值);
  if (满血 && G.chooseHeal(奶妈, ctx) === null) ok(`${机师} 在全员 ≥ 60% 时 chooseHeal 返回 null（不修）`);
  else bad(`${机师} 在全员 ≥ 60% 时还想修：${JSON.stringify(G.chooseHeal(奶妈, ctx) && G.chooseHeal(奶妈, ctx).target.key)}`);
  G.打一回合(ctx);
  if (!修录(ctx, 奶妈.slot).length) ok(`${机师} 这一回合一次都没修`);
  else bad(`${机师} 没人低于 60% 却修了：${JSON.stringify(修录(ctx, 奶妈.slot).map(x => x.文本))}`);
  if (攻录(ctx, 奶妈.slot).length) ok(`${机师} 正常出手了：${攻录(ctx, 奶妈.slot)[0].文本}`);
  else {
    /* 维诺在 10-数据.js 里只有「影之种」（special:'summon'，第一期不做），所以它没有别的可用武器 */
    const 跳过 = ctx.log.filter(x => x.类型 === '跳过' && x.单位 === 键);
    const 别的 = 奶妈.weapons.filter(e => !G.isHealKind(G.rangeKindOf(e.t))).map(e => `${e.t.name}(${e.t.special || e.t.fire})`);
    if (跳过.length && 别的.every(x => x.includes('summon'))) {
      ok(`${机师} 没有别的可用武器可打（${别的.join('、')}，special:'summon' 第一期不做）→ 记录「跳过」`);
      info(`这不是这次改出来的：10-数据.js 的注释写着${机师}「不能攻击」（战棋原设定），第一期它除了修理确实没事可做`);
    } else bad(`${机师} 没有人低于 60% 时既没修也没攻击（记录：${JSON.stringify(ctx.log.filter(x => x.单位 === 键).map(x => x.类型))}）`);
  }
}
/* 特种的职业特色没被顶掉：修理工命中后照样给对方挂「命中 −20」 */
{
  const 苏 = G.makeUnit('M5', 'ally', 4, 10), 靶 = G.makeUnit('grunt', 'enemy', 0, 10);
  const w = 苏.weapons.find(e => e.t.name === '机枪').t;
  const rec = G.resolveAttack(苏, 靶, w, { rng: () => 0, turn: 1 }, {});     // rng 恒 0 → 必中，专门看职业特色
  const 减 = (靶.buffs || []).find(b => b.src === '特种');
  if (减 && 减.hit === -20) ok(`特种特色保留：苏菲命中后对方挂上「命中 −20」（${rec.文本}）`);
  else bad(`苏菲的特种特色丢了：buffs ${JSON.stringify(靶.buffs)}`);
}

/* ============================ [4] 阈值边界（刚好 60% / 61%） ============================ */
console.log('\n[4] 阈值边界：低于 60% 才修（刚好 60% 不算）');
if (G.修理阈值 === 0.6) ok(`修理阈值 = 0.6（50-AI.js 顶部，注释里写了「作者 2026-10-10 拍板」）`);
else bad(`修理阈值 = ${G.修理阈值}，预期 0.6`);
{
  const ctx = G.开局([{ 键: 'M5', 位: 4, 等级: 10 }, { 键: 'B1', 位: 0, 等级: 10 }], 敌重, 333);
  const 奶妈 = ctx.allies.find(u => u.key === 'M5');
  const 伤 = ctx.allies.find(u => u.key === 'B1');
  const 例 = [[0.61, false], [0.6, false], [0.59, true]];
  for (const [比例, 该修] of 例) {
    伤.hp = Math.round(伤.maxHp * 比例);
    const 真比例 = 伤.hp / 伤.maxHp;
    const 选 = G.chooseHeal(奶妈, ctx);
    const 修了 = !!选;
    if (修了 === 该修) ok(`HP ${伤.hp}/${伤.maxHp} = ${(真比例 * 100).toFixed(1)}% → ${修了 ? '修' : '不修'}（预期 ${该修 ? '修' : '不修'}）`);
    else bad(`HP 比例 ${(真比例 * 100).toFixed(1)}% 的行为不对：${修了 ? '修' : '不修'}，预期 ${该修 ? '修' : '不修'}`);
  }
  /* 刚好 60% 是「不小于阈值」，所以一定要不修；真的修一次看看记录 */
  伤.hp = Math.round(伤.maxHp * 0.6);
  G.打一回合(ctx);
  if (!修录(ctx, 奶妈.slot).length) ok(`刚好 60%（${伤.maxHp} 的 60% = ${Math.round(伤.maxHp * 0.6)}）打一回合下来没修（严格「低于」才修）`);
  else bad(`刚好 60% 还是修了：${JSON.stringify(修录(ctx, 奶妈.slot).map(x => x.文本))}`);
  伤.hp = Math.round(伤.maxHp * 0.59);
  const 选59 = G.chooseHeal(奶妈, ctx);
  if (选59) ok(`59%（实测 ${伤.hp}/${伤.maxHp} = ${(伤.hp / 伤.maxHp * 100).toFixed(1)}%）→ 修（${选59.weapon.name} → ${选59.target.name}）`);
  else bad('59% 却不修，阈值判断反了');
}

/* ============================ [5] 同种子两次逐字相同 ============================ */
console.log('\n[5] 带种子的确定性：同种子两次跑逐字相同');
{
  const 队 = [{ 键: 'M5', 位: 4, 等级: 10 }, { 键: 'B3', 位: 3, 等级: 10 }, { 键: 'B1', 位: 0, 等级: 10 }];
  const 敌 = [{ 键: 'grunt', 位: 0, 等级: 20 }, { 键: 'grunt', 位: 1, 等级: 20 }, { 键: 'shield', 位: 2, 等级: 20 }];
  const 跑 = 种子 => {
    const ctx = G.开局(队, 敌, 种子);
    ctx.allies.find(u => u.key === 'B1').hp = 1500;      // 30% < 60%，两次都一样地掉血
    for (let i = 0; i < 3 && !ctx.result; i++) G.打一回合(ctx);
    return ctx;
  };
  const 甲 = 跑(20261010), 乙 = 跑(20261010);
  const s甲 = JSON.stringify(甲.log), s乙 = JSON.stringify(乙.log);
  if (s甲 === s乙) ok(`同种子跑 3 回合，${甲.log.length} 条记录逐字相同（修理 / 特种降命中都走 ctx.rng，没有 Math.random）`);
  else bad('同种子两次结果不一致（有随机数没走 ctx.rng？）');
  const 修 = 甲.log.filter(x => x.类型 === '修理');
  if (修.length) ok(`这一场里奶妈出手修了 ${修.length} 次：${修[0].文本}`);
  else bad('这一场一次都没修（掉血的队友没被修，阈值接错了吗）');
  const 丙 = 跑(20261011);
  if (JSON.stringify(丙.log) !== s甲) ok('换个种子结果就不一样（随机数确实在起作用）');
  else info('换种子结果一样（可能这一场太碾压，不算错）');
}

/* ============================ 结果 ============================ */
console.log(`\nERRS [${errs.join(' | ')}]`);
console.log(fails ? `共 ${fails} 项失败` : '奶妈（修理）测试全部通过');
process.exit(fails ? 1 : 0);
