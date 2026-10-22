#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 生成《特技换算待办》
 * ----------------------------------------------------------------------------
 * 方案 6.2：第一期不做任何特技，只做普通伤害武器、修理、能量屏障 / λ 力场 / 护盾。
 * 每个角色的特技、特殊武器先在角色卡上显示「（自动战斗版待设计）」，并且**全部列进
 * 一份表** `docs/特技换算待办.md`；**换算方案由 Claude 设计，DSH 不要自己编**。
 *
 * 这个脚本只做**机械摘录**：把 ALLY_T / ENEMY_T 里的 trait（特技）和 special（特殊武器）
 * 连desc 原文抄出来，外加"在新项目里为什么不能直接用"这一列（都是同一个原因：
 * 它依赖格子地图的机制，或者第一期没有实现对应的代码路径）。**不提换算方案**。
 *
 * 用法：node tools/specials.mjs      （生成 docs/特技换算待办.md）
 * ========================================================================== */
import { writeFileSync, mkdirSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { loadPage } from '../tests/lib/dom-stub.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');

const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
if (page.errors.length) { console.error('页面脚本执行报错，先修好再生成：\n' + page.errors.join('\n')); process.exit(1); }
const G = page.sandbox.__game;

/* 战棋里 special 字段各自需要的那条代码路径（第一期都没实现） */
const SPECIAL_WHY = {
  gamble: '固定伤害 + 反噬机制（15-战斗计算.js:108、17b），第一期不做',
  funnel: '浮游炮：16 段、每段随机方向、目标闪避减半（17-战斗执行.js:63-83），依赖朝向',
  multi: '多段：**这一条第一期做了**（w.hits 段）',
  chain: '连射：命中后继续开火、命中修正递减（17-战斗执行.js:106-125）',
  execute: '斩首：目标剩余 HP 低于阈值直接击破（17-战斗执行.js:139）',
  summon: '召唤物（影之种）：需要格子与召唤单位管理（17b）',
  lock: '多重锁定：一次选多个目标（17-战斗执行.js）',
  smoke: '烟雾弹：改地形 / 视线（第一期没有地形）',
  bounce: '连锁投掷：跳目标搜索（17b）',
  echo: '（已经不用了：作者 2026-10-11 把「残月的余响」的标记换成了 `echoFollow`，见下一条）',
  echoFollow: '**这一条第一期做了**（作者 2026-10-11 **换机制**：不再是范围伤害，改成**队友攻击后追加一发**；'
    + '威力 / 必中 / 物理照数据。实现见 `72-势力.js` 的 `残月追加攻击()` + `60-战斗.js` 的新钩子 `势力友军攻击后`）',
  funnelZone: '依赖朝向判断',
};
/* 第一期已经实现的支援 / 特殊武器（作者 2026-10-10 定） */
const 已实现 = new Set(['月光祝福', '残月的余响']);
const why = k => SPECIAL_WHY[k] || '需要战棋里的机制代码（17-战斗执行.js / 17b-角色机制.js），第一期没有实现';

const lines = [];
lines.push('# 特技换算待办（机甲指挥）');
lines.push('');
lines.push('> 这份表由 `node tools/specials.mjs` **自动生成**，不要手改；要改内容改脚本或改数据。');
lines.push('> 方案 6.2 / 第 10 节第 1 条：**怎么换算由 Claude 设计，DSH 不要自己编。**');
lines.push('> 第一期（M1）不实现任何特技：带 `special` 的特殊武器在战斗里**直接不可用**，');
lines.push('> 角色的 `trait`（个人特技）也完全没有实现。下面只是把「有哪些东西被搁置了」列清楚。');
lines.push('');
lines.push(`生成时点：机甲指挥 ${G.version} · ${G.milestone}｜我方 ${G.ALLY_T.length} 名角色｜敌人 ${Object.keys(G.ENEMY_T).length} 种`);
lines.push('');

/* ---------- 一、个人特技（trait） ---------- */
lines.push('## 一、个人特技（角色模板的 `trait` 字段）');
lines.push('');
lines.push('| 角色 | 机体 | 势力 | 职业 | trait | 战棋里的说明 | 为什么不能直接搬 |');
lines.push('|---|---|---|---|---|---|---|');
const traits = G.ALLY_T.filter(t => t.trait);
for (const t of traits) {
  const 说明 = (t.weapons.find(w => w.desc && w.desc.includes('特技')) || {}).desc || '';
  lines.push(`| ${t.pilot} | ${t.mech} | ${t.tags.势力} | ${t.tags.战斗分类} | \`${t.trait}\` | 见 03-能力与减免管线.js 的 TRAIT_FX / 17b-角色机制.js | 需要格子 / 回合钩子；第一期没有实现任何特技 |`);
}
lines.push('');
lines.push(`合计 ${traits.length} 名角色带特技。`);
lines.push('');

/* ---------- 二、特殊武器（special） ---------- */
lines.push('## 二、特殊武器（武器模板的 `special` 字段）');
lines.push('');
lines.push('| 角色/敌人 | 武器 | fire | 威力 | special | 战棋里的效果（原文 desc） | 为什么不能直接搬 |');
lines.push('|---|---|---|---|---|---|---|');
let n = 0;
const 扫 = (列表, 名字, 是敌人) => {
  for (const t of 列表) {
    for (const w of t.weapons || []) {
      if (!w.special) continue;
      n++;
      const 效果 = String(w.desc || '').replace(/\|/g, '｜').replace(/\n/g, ' ');
      lines.push(`| ${名字(t)} | ${w.name} | \`${w.fire}\` | ${w.power || '—'} | \`${w.special}\` | ${效果 || '（数据里没写 desc）'} | ${why(w.special)} |`);
    }
  }
};
扫(G.ALLY_T, t => `${t.pilot}（${t.mech}）`, false);
扫(Object.entries(G.ENEMY_T).map(([k, t]) => ({ ...t, key: k })), t => `${t.mech}（${t.key}）`, true);
lines.push('');
lines.push(`合计 ${n} 把特殊武器。`);
lines.push('');

/* ---------- 三、非伤害类支援武器（support / passive / device） ---------- */
lines.push('## 三、第一期用不了的支援 / 被动武器（`fire` 为 support / passive / device）');
lines.push('');
lines.push('| 角色 | 武器 | fire | 效果（原文 desc） |');
lines.push('|---|---|---|---|');
let m = 0;
for (const t of G.ALLY_T) {
  for (const w of t.weapons || []) {
    if (!['support', 'passive', 'device'].includes(w.fire)) continue;
    m++;
    const 效果 = String(w.desc || '').replace(/\|/g, '｜').replace(/\n/g, ' ');
    const 标记 = 已实现.has(w.name) ? '**（第一期已实现，作者 2026-10-10 定）** ' : '';
    lines.push(`| ${t.pilot}（${t.mech}） | ${w.name} | \`${w.fire}\` | ${标记}${效果 || '（数据里没写 desc）'} |`);
  }
}
lines.push('');
lines.push(`合计 ${m} 把。`);
lines.push('');

/* ---------- 三b、新项目增删的数据（战棋数据里没有的） ---------- */
lines.push('## 三b、新项目改过 / 新增的数据（不在战棋的数据里）');
lines.push('');
lines.push('改动全部写在 `src/js/71-改动.js`，战棋那份复制件（`src/js/10-数据.js`）一个字都不改。');
lines.push('');
lines.push('| 项目 | 内容 | 出处 |');
lines.push('|---|---|---|');
lines.push('| Feena 新增武器「再动」 | 支援类、大招（`unlock:20`，开场冷却 3 回合）：让本回合已经行动过、期望伤害最高的队友**立刻再行动一次**；同一名队友一回合最多被再动一次 | 作者 2026-10-10 口头定；实现见 `60-战斗.js` 的 `drainAgain` |');
lines.push('| 月光祝福 新范围 | 原「自身中心菱形 4 格内的友军」→ **全体队友（不含自己）**，持续到本回合结束（没有格子了） | 作者 2026-10-10 |');
lines.push('| 残月的余响 换机制 | 原「行动结束后自动放、范围 = 敌方前排」（2026-10-10）→ **队友攻击时追加一次攻击**'
  + '（作者 2026-10-11 拍板；设定：她操作质量加速器丢陨石）：触发点 = **我方队友造成伤害之后**；'
  + '武器 / 威力照数据（Lv30 的「满月·月蚀」冷却好时代替它）；目标 = 队友这一击打的那一台；**每回合上限 = 初稿 1 次**'
  + '（`势力特色.月球王国.残月余响每回合上限`） | 作者 2026-10-11（`协作/势力特色落地决定.md` 第 3 条） |');
lines.push('| 月球王国 新特色 · 月光环绕 | 新增：**Feena 的相邻位**（`05-阵型.js` 的 `相邻位(位)` = 同排左右 + 有阻挡关系的对位）'
  + '上的队友吃到「月光祝福」那一套数值（Lv10 命中 / 闪避 +15；Lv20 再加防御 +20、暴击 +10；Lv30 命中 / 闪避 +20、防御 +30、暴击 +15）；'
  + '范围从战棋的「自身菱形 4 格内的友军」换成 `相邻位()`（**范围换义**），数值照数据 | 作者 2026-10-11 |');
lines.push('');

/* ---------- 四、第一期不做、但属于数值类的东西 ---------- */
lines.push('## 四、战棋里有、第一期新项目里没有实现的数值 / 机制（清单，不换算）');
lines.push('');
lines.push('- 反击、援护攻击、援护防御（方案 6.1：反击第一期取消）；');
lines.push('- 朝向：正面 / 侧面 / 背面（闪避、暴击、无视装甲）、自动转向；');
lines.push('- 地形：防御、闪避、挡直射 / 挡曲射、移动消耗；');
lines.push('- 控制区（ZOC）、压制射击（新项目改成 overwatch「第一个行动的我方单位挨一下」）、');
lines.push('- 变身（FORMS / 纳德雷）、地图炮的方向选择、召唤物（DEBRIS_T / CHEST_T）；');
lines.push('- 战棋的减免条目里属于特技的那些：正面装甲、GN 全盾、光束反射、SEED 防御、λ 驱动器、减伤（特技 / 增益）、地形防御；');
lines.push('- 特技 `steadfast` 的装甲 ×1.3、`gundam` 的相邻加成、压制杂兵（近卫，攻击能力值 +100）、赌神、斩首、连射、浮游炮、多重锁定；');
lines.push('- 藏品（23b）、零件、侵蚀场、肉鸽的词缀 `AFFIXES`（护盾 / 强化 / 抗性 / 疾行 / 再生）——M4 做肉鸽时再处理；');
lines.push('- 敌人 AI 的 Boss 脚本（方案 5.2：第一期只做蓝色大肥鱼一个，等 M4 有 Boss 编成时再做）。');
lines.push('');
lines.push('> 以上都**没有**自己编换算方案，等 Claude（方案第 11 节）。');
lines.push('');

/* ---------- 五、作者提过「以后可以设计」的东西 ---------- */
lines.push('## 五、作者提过「以后可以设计」的东西（现在不做）');
lines.push('');
lines.push('- **特种的「推人」**（作者 2026-10-10）：「推人其实还是可以设计，用来破坏对手的阵型，或者给对方上 DEBUFF」——');
lines.push('  这一版的职业特色只做「命中后给对方挂命中 −20」；推人 / 打乱阵型属于特技性质，等作者给方向再设计。');
lines.push('- **选阵型**（舰娘那种：単縦 = 火力、輪形 = 防空 / 挡枪）：现在只有一种阵型（前 3 后 2），');
lines.push('  但阵型本身是**可扩充的配置**（`src/js/05-阵型.js`），以后要多种阵型从这里长出来。');
lines.push('- **「旗舰 / 主力」与かばう（替旗舰挡枪）**：★ 2026-10-12 起由**重装嘲讽**接手（「守护」指令已随全队方针删掉，§1.4）——');
lines.push('  要不要同时做成重装的被动（舰娘式），以及职业特色要不要和前后排绑定，等作者拍板。');
lines.push('');

mkdirSync(join(ROOT, 'docs'), { recursive: true });
const out = join(ROOT, 'docs', '特技换算待办.md');
writeFileSync(out, lines.join('\n') + '\n', 'utf8');
console.log(`已写出 docs/特技换算待办.md：${lines.length} 行`);
console.log(`  个人特技 ${traits.length} 名角色 / 特殊武器 ${n} 把 / 支援武器 ${m} 把`);
