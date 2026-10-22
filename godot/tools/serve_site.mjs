// M4 本地试玩入口：把 .tools/smoke/_site 用正确的 MIME 静态托管出来。
//   /       → JS 旧版（仓库根的自包含 index.html）
//   /godot/ → Godot M4 版（godot/build/web 导出产物）
// 用法：node serve-site.mjs [站点目录] [端口]
// 为什么需要专门写：`.wasm` 必须是 application/wasm，否则浏览器不做流式实例化（会慢/可能报错）；
// 单线程导出（variant/thread_support=false）不需要 COOP/COEP 响应头。
//
// ★ 2026-10-16 实时监视（作者要「主会话随时看到我在本地网页里的每一步操作、参数、返回结果与完整局面」）：
//   游戏（`presentation/boot/boot.gd` 的 `_发送事件()`）在 Web 版里把整条 payload
//   `JSON.stringify` → `Marshalls.utf8_to_base64()` 变成**纯 ASCII Base64**，直接当 body POST 过来
//   （`body: '<base64>'`）。**为什么这么发**：JSON 不进 JS 代码字面量 → 没有引号 / 换行转义风险；
//   不走 JS 的 `atob()` → 中文不会乱码（`atob` 出的是 latin1 字节）。这里 `Buffer.from(body,'base64')`
//   还原成 UTF-8 JSON。**兼容老的明文 JSON body**（直接以 `{` 开头就按原文解析）。
//
//   落盘两份（目录默认 = `root` 的父目录，即 `F:\DSH-mecha\.tools\smoke`，可用 DSH_UI_LOG_DIR 覆盖）：
//     · `live_actions.jsonl` —— 一行一条事件（`kind = boot | route | click | action`），第一行开始追加；
//       **同时**兼容写一份老的 `ui_clicks.jsonl`（旧工具还在读它，两份内容一致）。
//     · `live_state.json`   —— `{updated_at, latest_event, state, recent_events}`（最新局面 + 最近 40 条摘要）。
//   终端：每来一条就打一行**清晰摘要**（`[UI:click] …` / `[UI:action] #12 recruit_unit({...}) -> ok=true | …`）。
//   新增 `GET /__ui_log`：直接把 `live_state.json` 的内容吐回来（浏览器 / curl / node 随时查）。
//   **只写上面那几个日志文件，不碰仓库里任何别的文件**（静态托管照旧只读）。
import { createServer } from 'http';
import { readFile, writeFile, stat, mkdir, appendFile } from 'fs/promises';
import { extname, join, resolve, dirname } from 'path';

const SITE = resolve(process.argv[2] || 'F:\\DSH-mecha\\.tools\\smoke\\_site');
const PORT = Number(process.argv[3] || 8099);
// 日志目录：默认 = 站点目录的**父目录**（`.tools/smoke/_site` → `.tools/smoke`）。
const LOG_DIR = resolve(process.env.DSH_UI_LOG_DIR || dirname(SITE));
const ACTIONS_FILE = resolve(process.env.DSH_UI_LOG || join(LOG_DIR, 'live_actions.jsonl'));
const LEGACY_FILE = join(LOG_DIR, 'ui_clicks.jsonl');
const STATE_FILE = join(LOG_DIR, 'live_state.json');
/** 内存里最近多少条事件摘要进 `live_state.json`。 */
const RECENT_MAX = 40;
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.woff2': 'font/woff2',
};
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

/** 内存里最近的事件（摘要），每次 `POST /__ui_log` 之后写进 `live_state.json`。 */
const recentEvents = [];
/** 最新一份完整局面快照（`evt.state`）。 */
let latestState = {};
/** 服务端见过多少条事件 / 多少个 `boot`（= 浏览器刷新过几次）。 */
let totalEvents = 0;
let bootCount = 0;

/** 读整个请求体（Base64 / JSON 一行 / 也可能什么都不是 —— 认不出来就原样留在 `原文` 里，绝不 500）。 */
function readBody(req) {
  return new Promise((done) => {
    let raw = '';
    req.on('data', (c) => { raw += c; });
    req.on('end', () => done(raw));
    req.on('error', () => done(raw));
  });
}

/** 请求体 → JSON 对象。Base64（默认）与明文 JSON 两种都认。 */
function decodeBody(raw) {
  const 净 = String(raw || '').trim();
  if (净 === '') return { 原文: '' };
  let 文 = 净;
  if (!净.startsWith('{') && !净.startsWith('[')) {
    try {
      文 = Buffer.from(净, 'base64').toString('utf8');
    } catch {
      文 = 净;
    }
  }
  try {
    const v = JSON.parse(文);
    return (v && typeof v === 'object' && !Array.isArray(v)) ? v : { 原文: 文.slice(0, 2000) };
  } catch {
    return { 原文: 文.slice(0, 2000) };
  }
}

/** 一句话概括 `state`（终端摘要 / `recent_events` 都用它）。 */
function stateLine(st) {
  if (!st || typeof st !== 'object' || Object.keys(st).length === 0) return 'state=(还没有局面)';
  const 段 = [`screen=${st.screen ?? ''}`];
  if (st.modal) 段.push(`modal=${st.modal}`);
  if (st.in_battle) {
    段.push(`battle=第${st.turn ?? '?'}回合`);
    if (st.result) 段.push(`结果=${st.result}`);
  } else {
    if (st.floor != null) 段.push(`第${st.floor}层`);
    if (st.propellant != null) 段.push(`推进剂=${st.propellant}`);
    if (st.tickets) 段.push(`券=${Array.isArray(st.tickets) ? st.tickets.length : 0}`);
    if (st.roster) 段.push(`名册=${Array.isArray(st.roster) ? st.roster.length : 0}`);
    if (st.hope != null) 段.push(`希望=${st.hope}`);
    if (st.carbon != null) 段.push(`源碳=${st.carbon}`);
  }
  const 待选 = st.pending_card_picks;
  if (待选 && typeof 待选 === 'object' && 待选.次数) {
    段.push(`待选牌=${待选.次数}(${(待选.候选 || []).join('/')})`);
  }
  const 券 = st.tickets;
  if (!st.in_battle && Array.isArray(券) && 券.length) {
    段.push(`券名=[${券.map((t) => t && t.名).filter(Boolean).join('、')}]`);
  }
  return 段.join(' ');
}

/** 一条事件 → 终端那一行（每个 `kind` 各有各的写法）。 */
function printEvent(evt) {
  const kind = evt.kind || evt.事件 || '?';
  const 头 = `[UI:${kind}]`;
  if (kind === 'click') {
    const d = evt.disabled === true ? 'true' : 'false';
    const 钮 = `${evt.ctrl_name || '?'}("${evt.ctrl_text || ''}")`;
    const 灰 = Array.isArray(evt.按钮们)
      ? evt.按钮们.filter((b) => b && b.disabled).map((b) => `${b.name}("${b.text}")`).join(' + ')
      : '';
    console.log(`${头} ${stateLine(evt.state)} ctrl=${钮} disabled=${d}`
      + (evt.tooltip ? ` tooltip="${String(evt.tooltip).split('\n')[0].slice(0, 40)}"` : '')
      + (灰 ? ` ★点到灰按钮: ${灰}` : '')
      + (evt.pos ? ` @${evt.pos.x},${evt.pos.y}` : ''));
    return;
  }
  if (kind === 'action') {
    const e = evt.entry || {};
    const r = e.result;
    let 结论 = '';
    if (r === null || r === undefined) 结论 = '-> void';
    else if (typeof r === 'boolean') 结论 = `-> ok=${r}`;
    else if (typeof r === 'object') {
      if (typeof r.ok === 'boolean') 结论 = `-> ok=${r.ok}`;
      else if (typeof r.成功 === 'boolean') 结论 = `-> 成功=${r.成功}`;
      else if (Array.isArray(r)) 结论 = `-> [${r.length} 项]`;
      else 结论 = '-> {...}';
      const 为什么 = r.为什么 || r.原因 || r.why;
      if (为什么) 结论 += ` 为什么="${为什么}"`;
    } else 结论 = `-> ${String(r)}`;
    // ★ 主动作那一栏只放关键参数（完整 args 在 jsonl 里）
    const 参 = e.args && Object.keys(e.args).length ? JSON.stringify(e.args) : '{}';
    console.log(`${头} #${e.seq} ${e.action}(${参}) ${结论} | ${stateLine(e.state)}`);
    return;
  }
  if (kind === 'route') {
    console.log(`${头} ${stateLine(evt.state)} ${evt.动作 || '路由'}${evt.到 ? ` 到=${evt.到}` : ''}${evt.类型 ? ` 类型=${evt.类型}` : ''}`);
    return;
  }
  if (kind === 'boot') {
    console.log(`${头} ★ 浏览器刚打开 / 刷新（第 ${bootCount} 次）· 版本=${evt.版本 || '?'} · ${stateLine(evt.state)}`);
    return;
  }
  console.log(`${头} ${JSON.stringify(evt).slice(0, 400)}`);
}

/** `POST /__ui_log`：解码 → 加服务端时间戳 → 落两份 jsonl + 写 live_state.json + 终端一行。**永远 204**。 */
async function handleUiLog(req, res) {
  const raw = await readBody(req);
  const 解析 = decodeBody(raw);
  const ts = new Date().toISOString();
  const 记录 = (解析 && typeof 解析 === 'object' && !Array.isArray(解析))
    ? { ts, ...解析 }
    : { ts, 原文: String(解析).slice(0, 2000) };
  const kind = 记录.kind || 记录.事件 || '?';
  totalEvents += 1;
  if (kind === 'boot') bootCount += 1;
  // 局面快照：`action` 那一条在 `entry.state` 里（门面 `action_recorded` 的原样转发），
  // 其余（boot / route / click）在顶层 `state` 里。两处都认。
  const 快照 = (记录.state && typeof 记录.state === 'object') ? 记录.state
    : ((记录.entry && 记录.entry.state && typeof 记录.entry.state === 'object') ? 记录.entry.state : null);
  if (快照) latestState = 快照;

  // ① 内存里的最近 N 条摘要（给 live_state.json）
  const 摘要 = { ts, kind, seq: 记录.seq ?? (记录.entry && 记录.entry.seq), action: 记录.action || (记录.entry && 记录.entry.action) };
  if (kind === 'click') {
    摘要.ctrl_name = 记录.ctrl_name || '';
    摘要.ctrl_text = 记录.ctrl_text || '';
    摘要.disabled = 记录.disabled === true;
    摘要.点击了灰按钮 = Array.isArray(记录.按钮们) && 记录.按钮们.some((b) => b && b.disabled);
  } else if (kind === 'action') {
    const e = 记录.entry || {};
    摘要.args = e.args || {};
    摘要.result = e.result ?? null;
  } else if (kind === 'route') {
    摘要.动作 = 记录.动作 || '路由';
    摘要.到 = 记录.到 || '';
    摘要.类型 = 记录.类型 || '';
  }
  摘要.state = stateLine(快照);
  recentEvents.push(摘要);
  while (recentEvents.length > RECENT_MAX) recentEvents.shift();

  // ② 终端一行（先打，落盘失败也看得见）
  printEvent(记录);

  // ③ 落盘：live_actions.jsonl（主）+ ui_clicks.jsonl（兼容老工具）
  const 行 = JSON.stringify(记录) + '\n';
  try {
    await mkdir(LOG_DIR, { recursive: true });
    await appendFile(ACTIONS_FILE, 行, 'utf8');
    if (LEGACY_FILE !== ACTIONS_FILE) await appendFile(LEGACY_FILE, 行, 'utf8');
  } catch (e) {
    console.error('[UI] 写日志失败:', e.message);
  }

  // ④ live_state.json：最新一条事件 + 它带来的完整局面 + 最近 N 条摘要
  try {
    await mkdir(dirname(STATE_FILE), { recursive: true });
    await writeFile(STATE_FILE, JSON.stringify({
      updated_at: ts,
      total_events: totalEvents,
      boot_count: bootCount,
      latest_event: 记录,
      state: latestState,
      recent_events: recentEvents,
    }, null, 2), 'utf8');
  } catch (e) {
    console.error('[UI] 写 live_state.json 失败:', e.message);
  }

  res.writeHead(204, CORS);
  res.end();
}

/** `GET /__ui_log`：把当前 `live_state.json` 的内容直接吐回来（没事件时也给一份**合法骨架**）。 */
async function handleUiLogGet(res) {
  let 文 = '';
  try {
    文 = await readFile(STATE_FILE, 'utf8');
  } catch {
    文 = JSON.stringify({
      updated_at: new Date().toISOString(),
      total_events: 0,
      boot_count: 0,
      latest_event: null,
      state: {},
      recent_events: [],
      说明: '还没有收到任何事件（先在浏览器里打开 /godot/ 并点一下界面）',
    }, null, 2);
  }
  const body = Buffer.from(文, 'utf8');
  res.writeHead(200, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': body.length,
    'Cache-Control': 'no-store',
    ...CORS,
  });
  res.end(body);
}

/**
 * `POST|GET /__ui_log/reset`：把监控状态**清零**（内存 4 个变量 + 磁盘 3 个文件）。
 * 为什么要它：主会话看完一轮想从干净状态重新观察，不必重启服务、也不必手动删文件。
 * 磁盘口径：两份 jsonl 清成**空文件**（读取侧按「一行一条」解析，空 = 0 条）；
 * `live_state.json` 清成 `"{}"`（`GET /__ui_log` 读它就是一份**合法 JSON**，不会 500）。
 */
async function handleUiLogReset(res) {
  recentEvents.length = 0;
  totalEvents = 0;
  bootCount = 0;
  latestState = {};
  try {
    await mkdir(LOG_DIR, { recursive: true });
    await writeFile(ACTIONS_FILE, '', 'utf8');
    if (LEGACY_FILE !== ACTIONS_FILE) await writeFile(LEGACY_FILE, '', 'utf8');
    await writeFile(STATE_FILE, '{}', 'utf8');
  } catch (e) {
    // 落盘失败也不 500：内存已经清了，照实回 200 并打一行错误
    console.error('[UI] 重置日志文件失败:', e.message);
  }
  const body = Buffer.from(JSON.stringify({ ok: true, reset: true }), 'utf8');
  res.writeHead(200, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': body.length,
    'Cache-Control': 'no-store',
    ...CORS,
  });
  res.end(body);
  console.log('[UI] 监控状态已重置：内存清零 + live_actions.jsonl / ui_clicks.jsonl / live_state.json 已清空');
}

const server = createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    if (pathname === '/__ui_log/reset') {
      if (req.method === 'OPTIONS') {
        res.writeHead(204, CORS);
        res.end();
        return;
      }
      // GET / POST 都做重置（浏览器地址栏直接敲也能用）；别的动词（PUT/DELETE…）落到 404
      if (req.method === 'GET' || req.method === 'HEAD' || req.method === 'POST') {
        await handleUiLogReset(res);
        return;
      }
    }
    if (pathname === '/__ui_log') {
      if (req.method === 'OPTIONS') {
        res.writeHead(204, CORS);
        res.end();
        return;
      }
      if (req.method === 'GET' || req.method === 'HEAD') {
        await handleUiLogGet(res);
        return;
      }
      await handleUiLog(req, res);
      return;
    }
    let p = join(SITE, pathname);
    const st = await stat(p);
    if (st.isDirectory()) p = join(p, 'index.html');
    const body = await readFile(p);
    res.writeHead(200, {
      'Content-Type': TYPES[extname(p)] || 'application/octet-stream',
      'Content-Length': body.length,
      'Cache-Control': 'no-store',
    });
    res.end(body);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404');
  }
});
server.listen(PORT, '127.0.0.1', () => {
  console.log(`站点目录：${SITE}`);
  console.log(`JS 旧版  ：http://127.0.0.1:${PORT}/`);
  console.log(`Godot M4 ：http://127.0.0.1:${PORT}/godot/`);
  console.log(`动作日志 ：POST /__ui_log → ${ACTIONS_FILE}（+ ${LEGACY_FILE}）`);
  console.log(`实时局面 ：${STATE_FILE}　·　GET /__ui_log 也能直接读`);
  console.log(`清零     ：GET|POST /__ui_log/reset → 内存 + 上面三个文件全部清空（回 {"ok":true,"reset":true}）`);
  console.log('（Ctrl+C 停；静态托管只读，只往上面那几个日志文件追加行）');
});
