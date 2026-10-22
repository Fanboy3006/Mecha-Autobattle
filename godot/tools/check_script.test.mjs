/* 剧本校验器 + 公开包保密检查的测试（STORY-1）。
 * 用法：node godot/tools/check_script.test.mjs        全绿退出 0，有失败退出 1。
 * ① `check_script_fixtures/*.md` 每份样例第一处 `# 期望：E10 W11` 注释写着它**恰好**该报哪些码（`无` = 一个都不报），
 *    三张占位表（`_表/`）都带上跑，所以 W14 / W22 也在查；`ok_全对.md` 就是每个码「不该报」的那一份。
 * ② 折行 / 计字的单元断言；③ 命令行退出码与 --json；④ W50（扫仓库模式，临时目录）；
 * ⑤ check_public_bundle：临时站点 + 手搓的最小 .pck。临时文件都建在系统临时目录，跑完删掉。
 * 样例只用占位角色（甲乙丙丁、敌·杂兵）和占位台词。 */
import { readFileSync, readdirSync, mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'fs';
import { join, dirname } from 'path';
import { tmpdir } from 'os';
import { fileURLToPath } from 'url';
import { spawnSync } from 'child_process';
import { 校验文件, 折行, 计字, 读键表, 扫仓库 } from './check_script.mjs';
import { 检查站点, 解析pck } from './check_public_bundle.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const FIX = join(HERE, 'check_script_fixtures');
const 表 = { 角色表: 读键表(join(FIX, '_表', '角色表.txt')), BGM表: 读键表(join(FIX, '_表', 'BGM表.txt')), 音效表: 读键表(join(FIX, '_表', '音效表.json')) };
let 过 = 0, 败 = 0;
const 断言 = (cond, msg) => { if (cond) 过++; else { 败++; console.log(`✗ ${msg}`); } };
const 同集 = (a, b) => a.length === b.length && a.every(x => b.includes(x));

/* ① 样例 */
const 全部码 = new Set();
const 样例们 = readdirSync(FIX).filter(f => f.endsWith('.md')).sort();
for (const f of 样例们) {
  const 文 = readFileSync(join(FIX, f), 'utf8');
  const m = /^#\s*期望[：:]\s*(.+)$/m.exec(文);
  if (!m) { 断言(false, `${f} 没写「# 期望：」`); continue; }
  const 期望 = m[1].trim() === '无' ? [] : m[1].trim().split(/[\s、，,]+/);
  const 实际 = [...new Set(校验文件(join(FIX, f), 表).map(x => x.code))].sort();
  实际.forEach(c => 全部码.add(c));
  断言(同集(实际, 期望), `${f}：期望 [${期望.join(' ')}]，实际 [${实际.join(' ')}]`);
}
断言(样例们.includes('ok_全对.md'), '缺全对样例 ok_全对.md');
const 应有 = ['E01', 'E02', 'E03', 'E10', 'E11', 'E30', 'E31', 'E32', 'E40',
  'W01', 'W11', 'W12', 'W13', 'W14', 'W20', 'W21', 'W22', 'W30', 'W31', 'W40'];
for (const c of 应有) 断言(全部码.has(c), `没有样例报出 ${c}`);

/* ② 计字与折行（4.4） */
断言(计字('一二三') === 3, '汉字算 1');
断言(计字('abc') === 2, '半角算 ½ 向上取整');
断言(计字('……') === 2 && 计字('——') === 2, '……、—— 各算 2');
断言(折行('一二三四五六七八九十一二三四').length === 1, '14 字一行');
断言(折行('一二三四五六七八九十一二三四五').length === 2, '15 字两行');
断言(折行('a'.repeat(28)).length === 1 && 折行('a'.repeat(29)).length === 2, '28 个半角 = 14 字');
{ const l = 折行('一二三四五六七八九十一二三四。'); 断言(l.length === 2 && l[1] === '四。', `避头：句号不放行首，把前一个字挪下去（得到 ${JSON.stringify(l)}）`); }
{ const l = 折行('一二三四五六七八九十一二三……'); 断言(l.length === 2 && l[1] === '三……', `避头：…… 不放行首（得到 ${JSON.stringify(l)}）`); }
断言(折行('甲／乙').length === 2 && 折行('甲／乙／丙').length === 3, '／ 手动断行');

/* ③ 命令行 */
const 跑 = (...a) => spawnSync(process.execPath, [join(HERE, 'check_script.mjs'), ...a], { encoding: 'utf8' });
断言(跑(join(FIX, 'ok_全对.md')).status === 0, '全对样例退出码 0');
断言(跑(join(FIX, 'w31_标签没人跳.md')).status === 0, '只有警告退出码 0');
{ const r = 跑(join(FIX, 'e10_超过两行.md')); 断言(r.status === 1, '有错误退出码 1'); 断言(/e10_超过两行\.md:3 E10 /.test(r.stdout), `输出格式「文件:行号 代码 说明」（得到 ${r.stdout.split('\n')[0]}）`); }
{ const r = 跑(join(FIX, 'e32_标签重名.md'), '--json'); let j = null; try { j = JSON.parse(r.stdout); } catch { }
  断言(j && j.errors === 1 && j.items[0].code === 'E32' && j.items[0].line === 5 && j.items[0].level === 'error', '--json 输出'); }
{ const r = 跑(join(FIX, 'e32_标签重名.md'), '--输出', 'json'); 断言(r.status === 1 && r.stdout.trim().startsWith('{'), '--输出 json 同义'); }
断言(跑('不存在的文件.md').status === 2, '找不到文件退出码 2');

/* ④ W50 扫仓库 */
const 临时 = mkdtempSync(join(tmpdir(), 'story1-'));
try {
  const 仓 = join(临时, '仓');
  mkdirSync(join(仓, '协作', '私密', '剧情'), { recursive: true });
  mkdirSync(join(仓, '文档'), { recursive: true });
  writeFileSync(join(仓, '协作', '私密', '剧情', 'Ch00_01_占位.md'), '@场景 0-1 某处·某时 BGM:日常\n甲：占位。\n');
  writeFileSync(join(仓, '文档', '漏出来的.md'), '# 说明\n@场景 0-1 某处·某时 BGM:日常\n');
  writeFileSync(join(仓, '文档', '普通说明.md'), '# 只是说明，没有场景头\n');
  const r = 扫仓库([仓]);
  断言(r.length === 1 && r[0].code === 'W50' && r[0].file.endsWith('漏出来的.md') && r[0].line === 2, `W50 只报私密目录之外的那份（得到 ${JSON.stringify(r.map(x => x.file))}）`);

  /* ⑤ check_public_bundle */
  const 私 = join(临时, '私密剧情');
  mkdirSync(私);
  writeFileSync(join(私, 'Ch01_02_占位标题.md'), '占位');
  writeFileSync(join(私, 'README.md'), '通用名不参与比对');
  const 站 = n => { const d = join(临时, n); mkdirSync(join(d, 'godot'), { recursive: true }); writeFileSync(join(d, 'index.html'), '<p>占位</p>'); writeFileSync(join(d, 'README.md'), '公开说明，提到 协作/私密/ 这几个字不算泄漏'); return d; };
  /** 手搓最小 .pck（Godot 4 格式版本 3：文件表偏移在 0x20）。 */
  const 造pck = paths => {
    const head = Buffer.alloc(32 + 16 * 4 + 8);
    head.write('GDPC', 0, 'latin1'); head.writeUInt32LE(3, 4); head.writeUInt32LE(4, 8); head.writeUInt32LE(7, 12); head.writeUInt32LE(2, 16); head.writeUInt32LE(2, 20);
    const ents = paths.map(p => { const b = Buffer.from(p, 'utf8'); const L = Math.ceil(b.length / 4) * 4; const e = Buffer.alloc(4 + L + 8 + 8 + 16 + 4); e.writeUInt32LE(L, 0); b.copy(e, 4); return e; });
    const cnt = Buffer.alloc(4); cnt.writeUInt32LE(paths.length, 0);
    head.writeBigUInt64LE(BigInt(head.length), 32);
    return Buffer.concat([head, cnt, ...ents]);
  };
  断言(同集(解析pck(造pck(['data/a.json', 'main.tscn'])).paths, ['data/a.json', 'main.tscn']), '手搓 pck 能解析');

  const 干净 = 站('干净');
  writeFileSync(join(干净, 'godot', 'index.pck'), 造pck(['data/a.json', 'data/story/占位样例.story.json']));
  { const r = 检查站点(干净, { 私密目录: 私 }); 断言(r.错.length === 0, `干净站点不报错（得到 ${r.错.join('；')}）`); 断言(r.提示.length === 1, '.story.json 列成提示'); }
  { const r = 检查站点(干净, { 私密目录: join(临时, '没有这个目录') }); 断言(r.错.length === 0 && r.信息.some(x => x.includes('不存在')), '私密目录不存在时明说并跳过'); }

  const 路径漏 = 站('路径漏');
  mkdirSync(join(路径漏, '协作', '私密', '剧情'), { recursive: true });
  writeFileSync(join(路径漏, '协作', '私密', '剧情', '随便.md'), '占位');
  断言(检查站点(路径漏, { 私密目录: 私 }).错.length === 1, '站点里有 协作/私密/ 路径 → 报错');

  const 同名漏 = 站('同名漏');
  writeFileSync(join(同名漏, 'Ch01_02_占位标题.story.json'), '{}');
  断言(检查站点(同名漏, { 私密目录: 私 }).错.length === 1, '站点里有私密剧本同主名文件 → 报错');

  const 文本漏 = 站('文本漏');
  writeFileSync(join(文本漏, '交接.md'), '见 Ch01_02_占位标题.md');
  断言(检查站点(文本漏, { 私密目录: 私 }).错.length === 1, '公开文本里写了私密剧本文件名 → 报错');

  const pck漏 = 站('pck漏');
  writeFileSync(join(pck漏, 'godot', 'index.pck'), 造pck(['data/story/Ch01_02_占位标题.story.json', '私密/x.json']));
  { const r = 检查站点(pck漏, { 私密目录: 私 }); 断言(r.错.length === 2, `.pck 文件表里有私密名 / 私密段 → 报错（得到 ${r.错.length} 条）`); }

  const 命令行 = spawnSync(process.execPath, [join(HERE, 'check_public_bundle.mjs'), 路径漏, '--私密目录', 私], { encoding: 'utf8' });
  断言(命令行.status === 1, 'check_public_bundle 发现泄漏退出码 1');
  断言(spawnSync(process.execPath, [join(HERE, 'check_public_bundle.mjs'), 干净, '--私密目录', 私]).status === 0, 'check_public_bundle 干净退出码 0');
} finally {
  rmSync(临时, { recursive: true, force: true });
}

console.log(`—— 样例 ${样例们.length} 份；断言 通过 ${过}，失败 ${败}`);
process.exitCode = 败 ? 1 : 0;
