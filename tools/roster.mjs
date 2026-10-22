#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 图标覆盖对账（**只读工具，不改游戏的任何文件**）
 * ----------------------------------------------------------------------------
 * 出处：`art/README.md` 第 3 节（战棋那边改完跑 `node tools/roster.mjs` 查缺项，缺项非 0 退出）、
 *       `协作/交接-美术.md` 第 5 节 T6（本仓库没有这个工具，「还差哪些机体没专属图标」只能人肉对表）。
 *
 * 干什么：读 `ALLY_T` / `ENEMY_T` 的 `mech` 字段，对 `MI.ICON_BY_MECH` 打一张覆盖表，
 *         列出「有专属图标 / 借原型剪影」分别是哪些，缺项非 0 退出。
 * 怎么读数据：和 `tests/art_audio.js` 一样，用 `tests/lib/dom-stub.mjs` 在 Node 的 `vm` 里
 *         把 `index.html` 跑起来、从 `window.__game` 取（本机沙箱不给子进程开管道，
 *         所以**不用** `child_process` 抓输出）。
 *
 * 用法：
 *   node tools/roster.mjs              打覆盖表 + 缺项名单
 *   node tools/roster.mjs --quiet      只打缺项与统计行
 *   node tools/roster.mjs --json       打 JSON（给别的脚本吃）
 * 退出码：没有缺项 0（退方块也算缺项）；有缺项 1。
 * ========================================================================== */
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { loadPage } from '../tests/lib/dom-stub.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const 参数 = process.argv.slice(2);
const 静 = 参数.includes('--quiet');
const 出JSON = 参数.includes('--json');

const page = loadPage(join(ROOT, 'index.html'), { quiet: true });
if (page.errors.length) {
  console.error('index.html 跑不起来，先跑 node tools/build-src.mjs：');
  page.errors.forEach(e => console.error('  ' + e));
  process.exit(2);
}
const G = page.sandbox.__game;
const MI = G.MechIcons;
if (!MI || !MI.ICON_BY_MECH) {
  console.error('页面里没有 MechIcons（ART 块没注入？）');
  process.exit(2);
}
const 图标 = G.图标;

/* 一台机体：模板 → 机体名 → 专属图标 id / 借到的原型 id */
function 查(键, 方, 名) {
  const t = 方 === 'ally' ? G.ALLY_T.find(x => x.mech === 键) : G.ENEMY_T[键];
  const mech = (t && t.mech) || 名 || 键;
  const 专属 = MI.ICON_BY_MECH[mech] || null;
  const id = 图标.图标号(键, 方);
  return {
   键, 方, mech,
   短名: (t && (t.short || t.mech)) || mech,
   势力: (t && t.tags && t.tags.势力) || (方 === 'enemy' ? '敌' : '—'),
   分类: (t && t.tags && t.tags.战斗分类) || '—',
   体积: t ? `${(t.w || 1)}×${(t.h || 1)}` : '—',
   飞行: !!(t && t.flying),
   调色板: 图标.调色板(键, 方),
   专属, 实际: id, 借原型: !专属 && !!id, 方块: !id,
  };
}

const 我方 = G.ALLY_T.map(t => 查(t.mech, 'ally', t.pilot));
const 敌方 = Object.keys(G.ENEMY_T).map(k => 查(k, 'enemy', G.ENEMY_T[k].mech));
const 全部 = 我方.concat(敌方);
const 缺 = 全部.filter(r => !r.专属);
const 方块 = 全部.filter(r => r.方块);

if (出JSON) {
  console.log(JSON.stringify({
    版本: G.version, 里程碑: G.milestone,
    图标库: MI.ids.length,
    我方: 我方.length, 敌方: 敌方.length,
    专属: 全部.length - 缺.length, 借原型: 缺.length - 方块.length, 方块: 方块.length,
    缺项: 缺.map(r => ({ mech: r.mech, 方: r.方, 键: r.键, 势力: r.势力, 分类: r.分类, 体积: r.体积, 飞行: r.飞行, 现在借: r.实际 })),
  }, null, 2));
  process.exit(方块.length ? 1 : 0);
}

if (!静) {
  const 打表 = (标题, 行) => {
    console.log(`\n${标题}（${行.length}）`);
    console.log('  ' + '机体名'.padEnd(14) + '键'.padEnd(12) + '势力'.padEnd(12) + '分类'.padEnd(6) + '体积'.padEnd(6) + '图标');
    for (const r of 行) {
      console.log('  ' + String(r.mech).padEnd(14) + String(r.键).padEnd(12) + String(r.势力).padEnd(12)
        + String(r.分类).padEnd(6) + String(r.体积).padEnd(6) + (r.专属 ? `专属 ${r.专属}` : `借 ${r.实际 || '方块'}`));
    }
  };
  打表('我方（ALLY_T）', 我方);
  打表('敌方（ENEMY_T）', 敌方);
}

console.log('');
console.log(`图标库 ${MI.ids.length} 个；我方 ${我方.length} 名 + 敌方 ${敌方.length} 种 = ${全部.length} 台`);
console.log(`专属图标 ${全部.length - 缺.length} 台 / 借原型剪影 ${缺.length - 方块.length} 台 / 退方块 ${方块.length} 台`);
if (缺.length) {
  console.log(`\n缺专属图标的 ${缺.length} 台（按「先敌人后我方、先大件」排）：`);
  for (const r of 缺) {
    console.log(`  ${r.方 === 'ally' ? '我方' : '敌方'}  ${String(r.mech).padEnd(14)} 键 ${String(r.键).padEnd(11)}`
      + ` ${String(r.势力).padEnd(12)} ${String(r.分类).padEnd(4)} ${r.体积}${r.飞行 ? ' 飞行' : ''}  现在画成「${r.实际}」`);
  }
} else {
  console.log('\n缺项 0：数据里每一台机体都有专属图标。');
}
process.exit(方块.length ? 1 : 0);
