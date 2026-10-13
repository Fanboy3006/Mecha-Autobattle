#!/usr/bin/env node
/**
 * 全量验收（统筹 2026-10-11 写）
 *
 * 用法：
 *   node tools/verify-all.mjs            # 十七条测试 + 生成物同步检查
 *   node tools/verify-all.mjs --quiet    # 只打失败的套件与总结
 *
 * 为什么要有这个：交付前必须跑「**十七条测试全绿 + `--check` 通过**」，
 * 手工一条条敲容易漏套（历史上就漏过 `art_icons` / `audio` 这类新拆出来的套）。
 *
 * ★ 本机的一个坑（写在 CLAUDE.md 第 4 节）：DSH 沙箱**不给子进程开管道**，
 *   所以子进程必须用 `stdio:'inherit'`（`spawnSync` 默认的 `'pipe'` 会 EPERM）。
 *
 * 退出码：全绿 = 0；有任何一条失败 = 1。
 */

import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const 根 = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const 静默 = process.argv.includes('--quiet');

/** 二十条测试（顺序照 CLAUDE.md 第 4 节；加新套件要同步这里与 CLAUDE.md） */
const 套件 = [
  'smoke', 'sim', 'battle_ui', 'commands', 'run', 'comp', 'map',
  'art_icons', 'audio', 'boss', 'heal', 'relic', 'rank', 'balance', 'grid', 'faction',
  'tuner',
  '录像',
  '分析',
  // ★ 2026-10-12 对局上报（客户端）：`上报地址` 默认空 = 关闭 = 与现在完全一致（tests/上报.js 第 [1] 段钉着）
  '上报',
];

const 结果 = [];
let 有失败 = false;

/* ---- ① 生成物同步检查 ---- */
{
  const r = spawnSync(process.execPath, [join(根, 'tools', 'build-src.mjs'), '--check'], {
    cwd: 根, stdio: 'inherit',
  });
  const 通过 = r.status === 0;
  if (!通过) 有失败 = true;
  结果.push({ 名: 'build-src --check', 通过, 行: '生成物与源文件同步' });
  if (!通过) console.log('  ↑ 生成物落后于源文件：先跑 `node tools/build-src.mjs` 再提交');
}

/* ---- ② 十七条测试 ---- */
for (const 名 of 套件) {
  const 文件 = join(根, 'tests', `${名}.js`);
  if (!existsSync(文件)) {
    有失败 = true;
    结果.push({ 名, 通过: false, 行: '文件不存在（CLAUDE.md 第 4 节的套件清单与 tests/ 对不上）' });
    console.log(`✗ ${名}：文件不存在`);
    continue;
  }
  const r = spawnSync(process.execPath, [文件], { cwd: 根, stdio: 静默 ? 'ignore' : 'inherit' });
  const 通过 = r.status === 0;
  if (!通过) 有失败 = true;
  结果.push({ 名, 通过, 行: 通过 ? '通过' : `退出码 ${r.status}` });
  if (静默) console.log(`${通过 ? '✓' : '✗'} ${名}`);
}

/* ---- ③ 总结 ---- */
const 绿 = 结果.filter(x => x.通过).length;
console.log('');
console.log('================ 全量验收 ================');
for (const x of 结果) console.log(`${x.通过 ? '✓' : '✗'} ${x.名.padEnd(22)} ${x.行}`);
console.log('------------------------------------------');
console.log(`绿：${绿} / ${结果.length}    红：${结果.length - 绿}`);
console.log(有失败 ? '结论：**没全绿，别提交**' : '结论：全绿，可以提交');
process.exit(有失败 ? 1 : 0);
