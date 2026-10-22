/* ============================================================================
 * 公开包保密检查（`协作/演出/剧情演出语法.md` 剧-10 / 第五节「公开版保密」）· STORY-1
 * ----------------------------------------------------------------------------
 * 扫一个**组装好的站点目录**（GitHub Pages 的 `_site/`、本机 `.tools/smoke/_site/`），
 * 连同里面每个 Godot `.pck` 的文件表，发现下面任何一条就报错、退出码 1：
 *   ① 站点里有路径含 `协作/私密/` 的文件；
 *   ② `.pck` 文件表里有路径含 `协作/私密/` 或 `私密/` 段；`.pck` 原始字节里出现 `协作/私密/` 字样；
 *   ③ 站点 / `.pck` 里有和**私密剧本目录**（默认 `<仓库>/协作/私密/剧情/`）里同名的文件，
 *      或者「同主名 + 别的后缀」（`Ch01_01_x.md` → `Ch01_01_x.story.json`）；
 *   ④ 站点的文本文件 / `.pck` 原始字节里出现私密剧本的完整文件名（文件名本身就是剧透）。
 * 私密目录不存在（例如 CI 上）时，③④ 跳过并明说，①② 照查。
 * 另外把站点和 `.pck` 里所有 `.story.json` 列成「提示」（不算错，人工看一眼是不是占位剧本）。
 *
 * 用法：node godot/tools/check_public_bundle.mjs <站点目录> [--私密目录 <路径>]
 *   退出码：发现泄漏 = 1；干净 = 0；用法错 = 2。
 * `.pck` 解析：认 Godot 4 的 GDPC 格式（格式版本 2：文件表紧跟文件头；≥3：文件表偏移在 0x20），
 *   解析失败或文件表加密时退回「原始字节字符串扫描」，并在输出里注明。
 * 零依赖：只用 node:fs / node:path / node:url。只读。
 * ========================================================================== */
import { readFileSync, readdirSync, statSync, existsSync } from 'fs';
import { join, relative, resolve, basename, dirname, extname, sep } from 'path';
import { fileURLToPath } from 'url';

const HERE = dirname(fileURLToPath(import.meta.url));
const 默认私密目录 = resolve(HERE, '..', '..', '协作', '私密', '剧情');
const 通用文件名 = new Set(['readme.md', 'index.html', 'index.md', '.gitkeep', '.gitignore', '.ds_store', 'thumbs.db']);
const 文本后缀 = new Set(['.md', '.json', '.txt', '.html', '.htm', '.js', '.mjs', '.css', '.cfg', '.yml', '.yaml', '.csv', '.tres', '.tscn', '.svg']);
const 文本上限 = 8 * 1024 * 1024;
const 规范 = p => p.split(sep).join('/').replace(/\\/g, '/');
const 含私密段 = p => /(^|\/)协作\/私密(\/|$)/.test(规范(p));

function 列文件(根) {
  const out = [];
  const 走 = d => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name);
      if (e.isDirectory()) { if (e.name !== '.git') 走(p); }
      else if (e.isFile()) out.push(p);
    }
  };
  走(根);
  return out;
}

/** 解析 Godot 4 `.pck` 的文件表。返回 {ok, paths, why}。 */
export function 解析pck(buf) {
  try {
    if (buf.toString('latin1', 0, 4) !== 'GDPC') return { ok: false, paths: [], why: '没有 GDPC 文件头（可能嵌在可执行文件里）' };
    const fmt = buf.readUInt32LE(4);
    const flags = buf.readUInt32LE(20);
    if (flags & 1) return { ok: false, paths: [], why: '文件表加密' };
    let o;
    if (fmt >= 3) o = Number(buf.readBigUInt64LE(32));
    else if (fmt === 2) o = 32 + 16 * 4;
    else return { ok: false, paths: [], why: `不认识的格式版本 ${fmt}` };
    const n = buf.readUInt32LE(o); o += 4;
    if (n > 1e6) return { ok: false, paths: [], why: '文件数不合理' };
    const paths = [];
    for (let i = 0; i < n; i++) {
      const L = buf.readUInt32LE(o); o += 4;
      if (L > 4096 || o + L > buf.length) return { ok: false, paths, why: '文件表越界' };
      paths.push(buf.toString('utf8', o, o + L).replace(/\0+$/, '').replace(/^res:\/\//, ''));
      o += L + 8 + 8 + 16 + (fmt >= 2 ? 4 : 0);
    }
    return { ok: true, paths, why: `格式版本 ${fmt}，${n} 个文件` };
  } catch (e) {
    return { ok: false, paths: [], why: `解析出错：${e.message}` };
  }
}

/** 私密剧本目录里的文件名 → {全名们, 主名们}。 */
function 读私密名(dir) {
  const 全名 = new Set(), 主名 = new Set();
  for (const f of 列文件(dir)) {
    const b = basename(f);
    if (通用文件名.has(b.toLowerCase())) continue;
    全名.add(b);
    const stem = b.includes('.') ? b.slice(0, b.lastIndexOf('.')) : b;
    if ([...stem].length >= 4) 主名.add(stem);
  }
  return { 全名, 主名 };
}
const 撞名 = (b, 私) => 私 && (私.全名.has(b) || [...私.主名].some(s => b === s || b.startsWith(s + '.')));

export function 检查站点(site, { 私密目录 = 默认私密目录 } = {}) {
  const 错 = [], 提示 = [], 信息 = [];
  const 私 = existsSync(私密目录) && statSync(私密目录).isDirectory() ? 读私密名(私密目录) : null;
  信息.push(私 ? `私密剧本目录 ${私密目录}：${私.全名.size} 个文件名参与比对`
              : `私密剧本目录 ${私密目录} 不存在：跳过文件名比对（③④），只查路径（①②）`);
  const files = 列文件(site);
  let pck数 = 0;
  for (const f of files) {
    const rel = 规范(relative(site, f));
    const b = basename(f);
    if (含私密段(rel)) 错.push(`${rel}：站点里有 \`协作/私密/\` 下的文件`);
    else if (撞名(b, 私)) 错.push(`${rel}：和私密剧本目录里的文件同名 / 同主名`);
    if (b.endsWith('.story.json')) 提示.push(`${rel}：站点里有 .story.json，确认是占位剧本`);
    const ext = extname(b).toLowerCase();
    if (ext === '.pck') {
      pck数++;
      const buf = readFileSync(f);
      const r = 解析pck(buf);
      信息.push(`${rel}：${r.ok ? '文件表已解析，' : '文件表没解析（' }${r.why}${r.ok ? '' : '），退回字符串扫描'}`);
      for (const p of r.paths) {
        if (含私密段(p) || /(^|\/)私密\//.test(p)) 错.push(`${rel} → ${p}：.pck 里打包了私密路径`);
        else if (撞名(basename(p), 私)) 错.push(`${rel} → ${p}：.pck 里有和私密剧本同名 / 同主名的文件`);
        if (p.endsWith('.story.json')) 提示.push(`${rel} → ${p}：.pck 里有 .story.json，确认是占位剧本`);
      }
      const s = buf.toString('utf8');
      const k = s.split('协作/私密/').length - 1;
      if (k) 错.push(`${rel}：.pck 原始字节里出现 ${k} 处 \`协作/私密/\``);
      if (私) for (const n of 私.全名) if (s.includes(n)) 错.push(`${rel}：.pck 原始字节里出现私密剧本文件名「${n}」`);
      if (!r.ok && 私) for (const n of 私.主名) if (s.includes(n + '.')) 错.push(`${rel}：.pck 字符串扫描发现私密剧本主名「${n}.…」`);
    } else if (私 && 文本后缀.has(ext) && statSync(f).size <= 文本上限) {
      const s = readFileSync(f, 'utf8');
      for (const n of 私.全名) if (s.includes(n)) 错.push(`${rel}：文本里出现私密剧本文件名「${n}」`);
    }
  }
  信息.unshift(`扫了 ${files.length} 个文件，其中 .pck ${pck数} 个`);
  return { 错, 提示, 信息 };
}

export function main(argv) {
  let site = null, 私密目录;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--私密目录' || a === '--private-dir') { 私密目录 = argv[++i]; if (!私密目录) site = undefined; }
    else if (a === '-h' || a === '--help') { console.log('用法：node godot/tools/check_public_bundle.mjs <站点目录> [--私密目录 <路径>]'); return 0; }
    else if (!site) site = a;
    else site = undefined;
  }
  if (!site || !existsSync(site) || !statSync(site).isDirectory()) {
    console.error('✗ 用法：node godot/tools/check_public_bundle.mjs <站点目录> [--私密目录 <路径>]（站点目录要存在）');
    return 2;
  }
  const r = 检查站点(resolve(site), 私密目录 ? { 私密目录: resolve(私密目录) } : {});
  for (const x of r.信息) console.log(`· ${x}`);
  for (const x of r.提示) console.log(`提示 ${x}`);
  for (const x of r.错) console.log(`✗ ${x}`);
  console.log(r.错.length ? `—— 剧-10 不通过：${r.错.length} 处泄漏` : '—— 剧-10 通过：没发现私密剧本');
  return r.错.length ? 1 : 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
