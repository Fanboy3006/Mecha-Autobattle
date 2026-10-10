/* ============================================================================
 * 单文件游戏的「同步生成」脚本。
 * ----------------------------------------------------------------------------
 * 这个项目有两份 HTML，内容必须逐字相同（除了外层包装）：
 *   - `src/artifact-fragment.html`：片段版，以后发布到 claude.ai Artifact 用；
 *   - `index.html`（仓库根）：完整页面，作者**双击就能玩**。
 * 为了不出现三份互相不同步的代码，规定：
 *   - `src/shell.html` + `src/css/` + `src/js/` 是**唯一可编辑的源文件**；
 *   - 上面两份 HTML 都是**生成物**，由本脚本写出来。
 *
 * index.html 里夹在「游戏主体 BEGIN / END」标记之间的那一段，就是生成出来的。
 *
 * 用法：node tools/build-src.mjs           生成（拼 fragment，再同步 index.html）
 *       node tools/build-src.mjs --check   只检查，不写文件（改完记得跑这个）
 * ========================================================================== */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { assemble } from './assemble-src.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const SRC_DIR = join(ROOT, 'src');
const FRAG = join(SRC_DIR, 'artifact-fragment.html');
const INDEX = join(ROOT, 'index.html');

const BEGIN = '<!-- ===== 游戏主体 BEGIN（自动生成，请勿手改；源文件 src/shell.html + src/css + src/js）===== -->';
const END = '<!-- ===== 游戏主体 END ===== -->';

const checkOnly = process.argv.includes('--check');
let problems = 0, changed = 0;
const ok = m => console.log('  ✓ ' + m);
const fail = m => { problems++; console.error('  ✗ ' + m); };
const lf = s => s.replace(/\r\n/g, '\n');

console.log('build-src：');

/* ---------- 1. 由源文件拼出游戏主体 ---------- */
let body;
try {
  body = lf(assemble(SRC_DIR)).replace(/\n+$/, '') + '\n';
  ok(`游戏主体由 src/shell.html + src/css + src/js 拼出（${body.split('\n').length - 1} 行）`);
} catch (e) {
  fail(`拼接失败：${e.message}`);
  console.log(`\n${problems} 项需要处理`);
  process.exit(1);
}

/* ---------- 2. 写 src/artifact-fragment.html（片段版） ---------- */
const fragDisk = existsSync(FRAG) ? lf(readFileSync(FRAG, 'utf8')) : '';
if (fragDisk === body) ok('src/artifact-fragment.html 已是最新');
else if (checkOnly) fail('src/artifact-fragment.html 与源文件不同步（跑一次 node tools/build-src.mjs）');
else { writeFileSync(FRAG, body, 'utf8'); changed++; ok('src/artifact-fragment.html 已更新'); }

/* ---------- 3. 把游戏主体同步进 index.html ---------- */
if (!existsSync(INDEX)) fail('找不到 index.html');
else {
  const idx = lf(readFileSync(INDEX, 'utf8'));
  const i = idx.indexOf(BEGIN), j = idx.indexOf(END);
  if (i < 0 || j < 0 || j < i) fail('index.html 里找不到「游戏主体 BEGIN / END」标记');
  else {
    const at = i + BEGIN.length;
    const cur = idx.slice(at, j);
    const want = '\n' + body + '\n';
    if (cur === want) ok('index.html 的游戏主体与源文件一致');
    else if (checkOnly) fail('index.html 的游戏主体与源文件不一致（跑一次 node tools/build-src.mjs）');
    else {
      writeFileSync(INDEX, idx.slice(0, at) + want + idx.slice(j), 'utf8');
      changed++;
      ok(`index.html 的游戏主体已同步（${body.split('\n').length - 1} 行）`);
    }
  }
}

/* ---------- 输出 ---------- */
if (problems) { console.log(`\n${problems} 项需要处理`); process.exit(1); }
console.log(checkOnly ? '\n检查通过：两份 HTML 都与源文件同步' : `\n两份 HTML 已同步${changed ? `（改了 ${changed} 个文件）` : '（没有改动）'}`);
