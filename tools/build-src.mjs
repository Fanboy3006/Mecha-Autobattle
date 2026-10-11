/* ============================================================================
 * 单文件游戏的「同步生成」脚本（M5 起多了 ART / AUDIO 素材注入）。
 * ----------------------------------------------------------------------------
 * 这个项目有两份 HTML，内容必须逐字相同（除了外层包装）：
 *   - `src/artifact-fragment.html`：片段版，以后发布到 claude.ai Artifact 用；
 *   - `index.html`（仓库根）：完整页面，作者**双击就能玩**。
 * 为了不出现三份互相不同步的代码，规定：
 *   - `src/shell.html` + `src/css/` + `src/js/` 是**唯一可编辑的源文件**；
 *   - `art/mech-icons.js`、`audio/local-music.js`、`audio/music-room.js` 是**素材源文件**，
 *     由本脚本**原样**内联进两份 HTML 的 ART / AUDIO 块（照搬战棋 tools/build-src.mjs 的做法）；
 *   - 上面两份 HTML 都是**生成物**，由本脚本写出来。
 *
 * 游标（两份 HTML 里靠它们定位，**标记文字不要改**）：
 *   - index.html ：「游戏主体 BEGIN / END」之间 = 整段生成区；
 *   - shell.html ：「ART:mech-icons BEGIN / END」「AUDIO BEGIN / END」之间 = 素材注入区，
 *     在 src/shell.html 里先写好这对空标记，本脚本再往里塞素材。
 *
 * 素材里如果出现 `</script`，内联进 HTML 会把脚本提前截断 —— 这时直接报错退出，不写文件。
 *
 * 用法：node tools/build-src.mjs           生成（拼 fragment，再同步 index.html）
 *       node tools/build-src.mjs --check   只检查，不写文件（改完记得跑这个）
 * 也可以 import { 拼接主体 } —— tests/smoke.js 用它算「生成物应该长什么样」。
 * ========================================================================== */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath, pathToFileURL } from 'url';
import { assemble } from './assemble-src.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const SRC_DIR = join(ROOT, 'src');
const FRAG = join(SRC_DIR, 'artifact-fragment.html');
const INDEX = join(ROOT, 'index.html');

const BEGIN = '<!-- ===== 游戏主体 BEGIN（自动生成，请勿手改；源文件 src/shell.html + src/css + src/js）===== -->';
const END = '<!-- ===== 游戏主体 END ===== -->';

/* 素材块的标记（名字照搬战棋，方便对着旧项目找） */
export const ART_BEGIN = '<!-- ===== ART:mech-icons BEGIN（自动生成，请勿手改；源文件 art/mech-icons.js）===== -->';
export const ART_END = '<!-- ===== ART:mech-icons END ===== -->';
export const AUDIO_BEGIN = '<!-- ===== AUDIO BEGIN（自动生成，请勿手改；源文件 audio/local-music.js + audio/music-room.js）===== -->';
export const AUDIO_END = '<!-- ===== AUDIO END ===== -->';

const lf = s => s.replace(/\r\n/g, '\n');

/* ---------- 读一个素材文件（原样），顺便挡住 </script ---------- */
function 读素材(rel, 说明) {
  const p = join(ROOT, rel);
  if (!existsSync(p)) throw new Error(`缺少素材文件 ${rel}（${说明}）`);
  const s = lf(readFileSync(p, 'utf8'));
  if (s.includes('</script')) throw new Error(`${rel} 里出现了 </script，无法安全内联进 HTML`);
  return s.replace(/\n+$/, '');
}

/** 把一段代码包成 `<script>` 块（注释里写出处，和战棋一样）。 */
const 脚本块 = (rel, 说明, 代码) =>
  ['<script>', `/* ${说明} · 源文件 ${rel} · 由 tools/build-src.mjs 注入 */`, 代码, '</script>'].join('\n');

/** 生成 ART 块（机体图标矢量素材） */
export function ART块() {
  return [ART_BEGIN, 脚本块('art/mech-icons.js', '机体图标矢量素材（原创）', 读素材('art/mech-icons.js', 'M5 美术')), ART_END].join('\n');
}

/** 生成 AUDIO 块（本地音乐播放层 + 音乐鉴赏页）。
 *  作者 2026-10-08 的决定照旧：DSH 的合成器（audio/score.js、mech-audio.js）不打包，
 *  只用 audio/local-music.js：读作者本地的版权 mp3 与 audio/SUNO/ 的曲子，读不到就整体静音、隐藏声音按钮。 */
export const AUDIO_ON = true;
export function AUDIO块() {
  if (!AUDIO_ON) return [AUDIO_BEGIN, '<!-- 音频关闭，见 tools/build-src.mjs 的 AUDIO_ON -->', AUDIO_END].join('\n');
  return [
    AUDIO_BEGIN,
    脚本块('audio/local-music.js', '音乐播放层 MechAudio（Suno 曲子 + 作者本地的版权曲）', 读素材('audio/local-music.js', 'M5 音乐')),
    脚本块('audio/music-room.js', '音乐鉴赏页（开场菜单进入，作者试听、调整用）', 读素材('audio/music-room.js', 'M5 音乐')),
    AUDIO_END,
  ].join('\n');
}

/** 把 text 里夹在 begin / end 之间的那一段换成 block（找不到标记就报错，不猜位置）。 */
function 换块(text, begin, end, block, 名字) {
  const i = text.indexOf(begin);
  if (i < 0) throw new Error(`找不到「${名字}」的 BEGIN 标记，请先在 src/shell.html 里写好这对标记：\n      ${begin}`);
  const j = text.indexOf(end, i);
  if (j < 0) throw new Error(`「${名字}」有 BEGIN 但没有 END 标记：\n      ${end}`);
  return text.slice(0, i) + block + text.slice(j + end.length);
}

/** 源文件（shell + css + js + art + audio）→ 一份完整的游戏主体文本。生成物和检查都用它。 */
export function 拼接主体() {
  let body = lf(assemble(SRC_DIR));
  body = 换块(body, ART_BEGIN, ART_END, ART块(), 'ART:mech-icons');
  body = 换块(body, AUDIO_BEGIN, AUDIO_END, AUDIO块(), 'AUDIO');
  return body.replace(/\n+$/, '') + '\n';
}

/* ============================ 命令行入口 ============================ */
function 主程序() {
  const checkOnly = process.argv.includes('--check');
  let problems = 0, changed = 0;
  const ok = m => console.log('  ✓ ' + m);
  const fail = m => { problems++; console.error('  ✗ ' + m); };

  console.log('build-src：');

  /* ---------- 1. 由源文件拼出游戏主体（含 ART / AUDIO 素材注入） ---------- */
  let body;
  try {
    body = 拼接主体();
    const art行 = ART块().split('\n').length, audio行 = AUDIO块().split('\n').length;
    ok(`游戏主体由 src/shell.html + css + js 拼出，并注入 ART（${art行} 行）+ AUDIO（${audio行} 行）；共 ${body.split('\n').length - 1} 行`);
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
}

/* 被 import 时不要跑命令行（tests/smoke.js 会 import 拼接主体） */
if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) 主程序();
