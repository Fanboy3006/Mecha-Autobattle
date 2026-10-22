/* ============================================================================
 * 剧本校验器（`协作/演出/剧情演出语法.md` 第六节）· STORY-1
 * ----------------------------------------------------------------------------
 * 逐行读剧本 `.md`，按第六节报 E 码（错误）和 W 码（警告）。**只读**，不改任何文件，
 * 也不编译（编译器另写，校验通过后才跑）。不依赖 Godot。
 *
 * 用法：
 *   node godot/tools/check_script.mjs <剧本.md | 目录>… [选项]
 *     --角色表 <路径>   (--roles)  开 W14：说话人不在表里就警告（不给就不查）
 *     --BGM表  <路径>   (--bgm)    开 W22 的 BGM 半边：情绪 / 曲键不在表里就警告
 *     --音效表 <路径>   (--sfx)    开 W22 的音效半边：音效键不在表里就警告
 *     --json  或  --输出 json      输出 JSON（一个对象：files / errors / warnings / free / items）
 *     --扫仓库 (--scan-repo)       保密扫描模式：只查 W50（`协作/私密/` 之外带 `@场景` 的 .md）
 *   退出码：有 E = 1；只有 W 或全对 = 0；用法错 / 文件读不到 = 2。
 *   输出每条：`文件:行号 代码 一句话`。目录会递归找 `.md`（跳过 README.md、点开头目录、node_modules）。
 *   表文件格式：JSON（字符串数组 / 对象的键和字符串值 / 对象数组的 名|name|键|key|id 字段）
 *              或纯文本（一行一个，`#` 开头是注释；markdown 表格行取第一格）。
 *
 * 作为模块：import { 校验文本, 校验文件, 折行, 计字 } from './check_script.mjs'
 *
 * **保守解读**（文档没说死的地方，这里都取「多报」一侧，清单见 `协作/架构/STORY回执/STORY-1.md`）。
 * 零依赖：只用 node:fs / node:path / node:url。
 * ========================================================================== */
import { readFileSync, readdirSync, statSync, existsSync } from 'fs';
import { join, relative, resolve, basename, sep } from 'path';
import { fileURLToPath } from 'url';

/* ---------------- 计字与折行（4.4） ---------------- */
const 行宽半格 = 28;                       // 14 字 = 28 个半角单位
const 避头 = new Set(['。', '，', '、', '！', '？', '……', '」', '）']);
const 是半角 = cp => cp < 0x80 || (cp >= 0xFF61 && cp <= 0xFF9F);

/** 切成折行用的最小单位：`……`、`——` 各是一个 2 字宽的整体（不拆开）。 */
function 分词(s) {
  const cs = Array.from(s);
  const out = [];
  for (let i = 0; i < cs.length; i++) {
    const c = cs[i];
    if ((c === '…' || c === '—') && cs[i + 1] === c) { out.push({ s: c + c, w: 4 }); i++; continue; }
    out.push({ s: c, w: 是半角(c.codePointAt(0)) ? 1 : 2 });
  }
  return out;
}
/** 计字：全角 1、半角 ½，向上取整。 */
export function 计字(s) {
  const h = 分词(s).reduce((a, t) => a + t.w, 0);
  return Math.ceil(h / 2);
}
/** 折行：`／` 是手动断行；每段在第 14 字后自动断，带避头（把前一个字一起挪下去）。返回行数组。 */
export function 折行(text) {
  const lines = [];
  for (const seg of text.split('／')) {
    let cur = [], w = 0;
    for (const t of 分词(seg)) {
      if (w + t.w <= 行宽半格) { cur.push(t); w += t.w; continue; }
      const carry = [];
      if (避头.has(t.s) && cur.length > 1) {
        carry.unshift(cur.pop());
        while (cur.length > 1 && 避头.has(carry[0].s)) carry.unshift(cur.pop());
      }
      lines.push(cur.map(x => x.s).join(''));
      cur = [...carry, t];
      w = cur.reduce((a, x) => a + x.w, 0);
    }
    lines.push(cur.map(x => x.s).join(''));
  }
  return lines;
}

/* ---------------- 小工具 ---------------- */
const 全角数字 = s => s.replace(/[０-９]/g, c => String.fromCharCode(c.charCodeAt(0) - 0xFEE0));
const 冒号 = /[：:]/;
const 箭头 = /→|->/;

/** 在括号外按分隔符切开（`格(3，4)` 里的逗号不切）。 */
function 括号外切(s, 分隔) {
  const out = []; let depth = 0, buf = '';
  for (const c of s) {
    if (c === '(' || c === '（') depth++;
    else if ((c === ')' || c === '）') && depth > 0) depth--;
    if (depth === 0 && 分隔.test(c)) { out.push(buf); buf = ''; continue; }
    buf += c;
  }
  out.push(buf);
  return out.map(x => x.trim()).filter(x => x !== '');
}
/** 括号外第一个冒号的位置；没有返回 -1。 */
function 括号外冒号(s) {
  let depth = 0, i = 0;
  for (const c of s) {
    if (c === '(' || c === '（') depth++;
    else if ((c === ')' || c === '）') && depth > 0) depth--;
    else if (depth === 0 && 冒号.test(c)) return i;
    i += c.length;
  }
  return -1;
}
/** 通用参数：`；` 分段；每段里冒号前的词是位置参数，冒号后整段是值（一段只一个键值）。 */
function 解析参数(rest) {
  const pos = [], kv = new Map(), dup = [];
  for (const seg of 括号外切(rest, /[；;]/)) {
    const c = 括号外冒号(seg);
    if (c < 0) { pos.push(...括号外切(seg, /[\s、，]/)); continue; }
    const head = seg.slice(0, c);
    const parts = 括号外切(head, /[\s、，]/);
    const key = parts.pop() ?? '';
    pos.push(...parts);
    if (kv.has(key)) dup.push(key);
    kv.set(key, seg.slice(c + 1).trim());
  }
  return { pos, kv, dup };
}
const 位置ok = t => !!t && (!t.startsWith('格') || /^格[(（]\s*-?\d+\s*[,，]\s*-?\d+\s*[)）]$/.test(全角数字(t)));
const 帧数ok = v => /^\d+\s*(帧)?$/.test(全角数字(v ?? ''));
const 正整数ok = v => /^\d+$/.test(全角数字(v ?? ''));
const 时长ok = v => /^(\d+帧|\d+(\.\d+)?秒|\d+毫秒)$/.test(全角数字(v ?? ''));

/* ---------------- 表文件 ---------------- */
export function 读键表(p) {
  const raw = readFileSync(p, 'utf8').replace(/^﻿/, '');
  const set = new Set();
  const add = v => { if (typeof v === 'string' && v.trim()) set.add(v.trim()); };
  let j = null;
  try { j = JSON.parse(raw); } catch { /* 不是 JSON，按纯文本 */ }
  if (j !== null && typeof j === 'object') {
    const 取 = o => { for (const k of ['名', '名字', 'name', '键', 'key', 'id']) if (typeof o?.[k] === 'string') add(o[k]); };
    if (Array.isArray(j)) for (const x of j) { if (typeof x === 'string') add(x); else 取(x); }
    else for (const [k, v] of Object.entries(j)) { add(k); if (typeof v === 'string') add(v); else 取(v); }
    return set;
  }
  for (let line of raw.split(/\r?\n/)) {
    line = line.trim();
    if (!line || line.startsWith('#')) continue;
    if (line.startsWith('|')) { if (/^\|[\s\-:|]+\|?$/.test(line)) continue; line = line.split('|')[1] ?? ''; }
    add(line);
  }
  return set;
}

/* ---------------- 指令表（第三节） ---------------- */
const 已知指令 = new Set(['登场', '退场', '移动', '镜头', 'BGM', '音效', '震动', '闪白', '等待', '选择', '战斗', '自由',
  '窗口', '关窗', '淡入', '淡出', '字幕', '标签', '跳转', '设定', '如果', '教学']);
const 表情 = new Set(['普通', '笑', '怒', '惊', '悲', '坚定', '冷淡']);

/**
 * 校验一份剧本的文本。返回 [{line, code, msg}]（按行号排序）。
 * opts: { 角色表?: Set, BGM表?: Set, 音效表?: Set }
 */
export function 校验文本(text, opts = {}) {
  const out = [];
  const 报 = (line, code, msg) => out.push({ line, code, msg });
  const lines = text.replace(/^﻿/, '').split(/\r?\n/);
  let 有场景 = false, 已报E01 = false;
  let 在场 = new Set();
  const 标签定义 = new Map();   // 名 → 首次行号
  const 标签引用 = [];          // {name, line}
  let 自由条数 = 0;

  const 可播放 = ln => { if (!有场景 && !已报E01) { 报(ln, 'E01', '第一条可播放内容之前没有 @场景'); 已报E01 = true; } };
  /** 普通文本里的 `【` 必须在同一行有 `】`（E03）。 */
  const 查配对 = (s, ln) => {
    let i = s.indexOf('【');
    while (i >= 0) {
      const close = s.indexOf('】', i + 1), next = s.indexOf('【', i + 1);
      if (close < 0 || (next >= 0 && next < close)) { 报(ln, 'E03', '`【` 没有配对的 `】`（不允许跨行）'); return false; }
      i = next;
    }
    return true;
  };
  const 查长度 = (正文, ln, 什么) => {
    const n = 折行(正文).length;
    if (n > 2) 报(ln, 'E10', `${什么}折行后 ${n} 行，超过 2 行（每行 14 字，见 4.4）`);
  };
  const W20 = (ln, 名, why) => 报(ln, 'W20', `【${名}】${why}，按「自由」处理`);

  /* ---- 一条指令 ---- */
  function 指令(内容, ln) {
    const m = /^([^\s：:]+)\s*[：:]?\s*([\s\S]*)$/.exec(内容.trim());
    if (!m) { W20(ln, 内容, '是空指令'); return; }
    let 名 = m[1]; const rest = m[2].trim();
    if (/^bgm$/i.test(名)) 名 = 'BGM';
    if (!已知指令.has(名)) { W20(ln, 名, '认不出这个指令'); return; }
    const { pos, kv, dup } = 解析参数(rest);
    const 多余键 = 允许 => [...kv.keys()].filter(k => !允许.includes(k));
    const 坏 = why => { W20(ln, 名, why); return true; };
    const 查键 = (允许) => {
      if (dup.length) return 坏(`键重复：${dup.join('、')}`);
      const x = 多余键(允许); if (x.length) return 坏(`认不出的键：${x.join('、')}`);
      return false;
    };
    const 枚举 = (k, 值们) => kv.has(k) && !值们.includes(kv.get(k)) ? 坏(`${k}「${kv.get(k)}」不在 ${值们.join(' / ')} 之内`) : false;

    switch (名) {
      case '登场': {
        if (查键(['方式', '到'])) return;
        if (pos.length !== 2 || !位置ok(pos[1])) return void 坏('要两个参数：单位 位置');
        if (枚举('方式', ['闪烁', '进入', '传送', '降落'])) return;
        const 进入 = kv.get('方式') === '进入';
        if (进入 && !位置ok(kv.get('到'))) return void 坏('方式：进入 要写 `到：位置`');
        if (!进入 && kv.has('到')) return void 坏('`到：` 只在 方式：进入 时用');
        if (在场.has(pos[0])) 报(ln, 'W30', `登场「${pos[0]}」时它已经在场`);
        在场.add(pos[0]);
        return;
      }
      case '退场': {
        if (查键(['方式'])) return;
        if (pos.length !== 1) return void 坏('要一个参数：单位');
        if (枚举('方式', ['消失', '撤退', '击破', '传送'])) return;
        if (!在场.has(pos[0])) 报(ln, 'W30', `退场「${pos[0]}」时它不在场`);
        在场.delete(pos[0]);
        return;
      }
      case '移动': {
        if (查键(['速度', '经'])) return;
        const p = pos.filter(x => x !== '不等');
        if (p.length !== 2 || !位置ok(p[1])) return void 坏('要两个参数：单位 位置');
        if (枚举('速度', ['慢', '普通', '快'])) return;
        if (kv.has('经')) { const 经 = 括号外切(kv.get('经'), /[\s、，]/); if (!经.length || !经.every(位置ok)) return void 坏('`经：` 的位置写错了'); }
        if (!在场.has(p[0])) 报(ln, 'W30', `移动「${p[0]}」时它不在场`);
        return;
      }
      case '镜头': {
        if (查键(['帧'])) return;
        const ok = (pos.length === 1 && 位置ok(pos[0]) && pos[0] !== '跟随') || (pos.length === 2 && pos[0] === '跟随');
        if (!ok) return void 坏('要「位置」或「跟随 单位」');
        if (kv.has('帧') && !帧数ok(kv.get('帧'))) return void 坏('帧：要写整数');
        return;
      }
      case 'BGM': {
        if (kv.size || dup.length) return void 坏('不带键值');
        let ok = pos.length === 1 && pos[0] !== '淡出';
        if (pos.length === 2 && pos[0] === '淡出' && /^\d+帧$/.test(全角数字(pos[1]))) ok = true;
        if (pos.length === 1 && /^淡出\d+帧$/.test(全角数字(pos[0]))) ok = true;
        if (!ok) return void 坏('要「情绪或曲键」「停」或「淡出 N帧」');
        if (opts.BGM表 && pos.length === 1 && pos[0] !== '停' && !pos[0].startsWith('淡出') && !opts.BGM表.has(pos[0]))
          报(ln, 'W22', `BGM「${pos[0]}」不在音乐线的对照表里`);
        return;
      }
      case '音效': {
        if (kv.size || dup.length || pos.length !== 1) return void 坏('要一个音效键');
        if (opts.音效表 && !opts.音效表.has(pos[0])) 报(ln, 'W22', `音效键「${pos[0]}」不在键名表里`);
        return;
      }
      case '震动': {
        if (查键(['帧'])) return;
        if (pos.length !== 1 || !['小', '中', '大'].includes(pos[0])) return void 坏('要写 小 / 中 / 大');
        if (kv.has('帧') && !帧数ok(kv.get('帧'))) return void 坏('帧：要写整数');
        return;
      }
      case '闪白': {
        if (查键(['次数', '色'])) return;
        if (pos.length) return void 坏('不带位置参数');
        if (kv.has('次数') && !正整数ok(kv.get('次数'))) return void 坏('次数：要写整数');
        if (枚举('色', ['白', '黑', '红'])) return;
        return;
      }
      case '等待': {
        if (kv.size || dup.length || pos.length !== 1 || !时长ok(pos[0])) return void 坏('要写 N帧 / N秒 / N毫秒');
        return;
      }
      case '选择': {
        const 项 = 括号外切(rest, /[；;]/);
        if (项.length < 2 || 项.length > 3) 报(ln, 'E31', `选择项 ${项.length} 个，要 2～3 个`);
        for (const x of 项) {
          const a = x.split(箭头);
          if (a.length !== 2 || !a[0].trim() || !a[1].trim()) { 报(ln, 'E31', `选择项「${x}」格式不对，要写「选项文字 → 标签」`); continue; }
          const 字 = 计字(a[0].trim());
          if (字 > 12) 报(ln, 'E31', `选择项「${a[0].trim()}」${字} 字，超过 12 字`);
          标签引用.push({ name: a[1].trim(), line: ln, 谁: '选择' });
        }
        return;
      }
      case '战斗': {
        // 战斗关系到关卡，坏段只报 W20，其余照查（不整条降级），见回执「保守解读」。
        for (const seg of 括号外切(rest, /[；;]/)) {
          if (括号外冒号(seg) < 0) W20(ln, 名, `「${seg}」不是 键：值`);
        }
        if (dup.length) W20(ln, 名, `键重复：${dup.join('、')}`);
        const x = 多余键(['敌方', '胜利条件', '败北条件', '败北']); if (x.length) W20(ln, 名, `认不出的键：${x.join('、')}`);
        if (!kv.get('敌方')) 报(ln, 'E40', '`战斗` 缺 `敌方`');
        if (!kv.get('胜利条件')) 报(ln, 'E40', '`战斗` 缺 `胜利条件`');
        if (kv.get('败北')) 标签引用.push({ name: kv.get('败北'), line: ln, 谁: '战斗 败北' });
        for (const k of ['敌方', '胜利条件', '败北条件']) {
          const v = (kv.get(k) ?? '').replace(/[×xX*＊]\s*[0-9０-９]+/g, '');
          if (/[0-9０-９]/.test(v)) 报(ln, 'W40', `战斗的「${k}」里写了数字（不写数值，×N 数量除外）`);
        }
        return;
      }
      case '自由': {
        自由条数++;
        报(ln, 'W21', `自由指令：${rest || '（没写描述）'}`);
        return;
      }
      case '窗口': {
        if (kv.size || dup.length || pos.length !== 2 || !['上', '下'].includes(pos[1])) return void 坏('要写「角色名 上 / 下」');
        return;
      }
      case '关窗': {
        if (rest) return void 坏('不带参数');
        return;
      }
      case '淡入': case '淡出': {
        if (查键(['帧', '色'])) return;
        if (pos.length) return void 坏('不带位置参数');
        if (kv.has('帧') && !帧数ok(kv.get('帧'))) return void 坏('帧：要写整数');
        if (枚举('色', ['黑', '白'])) return;
        return;
      }
      case '字幕': {
        if (!rest) return void 坏('没写字幕文字');
        return;
      }
      case '标签': {
        if (!rest || /\s/.test(rest)) return void 坏('要一个标签名（不带空格）');
        if (标签定义.has(rest)) 报(ln, 'E32', `标签「${rest}」重名（第 ${标签定义.get(rest)} 行已定义）`);
        else 标签定义.set(rest, ln);
        return;
      }
      case '跳转': {
        if (!rest || /\s/.test(rest)) return void 坏('要一个标签名');
        标签引用.push({ name: rest, line: ln, 谁: '跳转' });
        return;
      }
      case '设定': {
        if (!/^[^\s=＝]+(\s*[=＝]\s*\S.*)?$/.test(rest)) return void 坏('要写「旗标名」或「旗标名 = 值」');
        return;
      }
      case '如果': {
        const a = rest.split(箭头);
        if (a.length !== 2 || !/^[^\s=＝]+(\s*[=＝]\s*\S.*)?$/.test(a[0].trim()) || !a[1].trim() || /\s/.test(a[1].trim()))
          return void 坏('要写「条件 → 标签」');
        标签引用.push({ name: a[1].trim(), line: ln, 谁: '如果' });
        return;
      }
      case '教学': {
        if (kv.size || dup.length || pos.length !== 1) return void 坏('要一个主题键');
        return;
      }
    }
  }

  /* ---- 逐行 ---- */
  for (let i = 0; i < lines.length; i++) {
    const ln = i + 1;
    const s = lines[i].trim();
    if (!s || s.startsWith('#') || s.startsWith('>') || s.startsWith('//')) continue;

    if (s.startsWith('@场景')) {
      有场景 = true;
      在场 = new Set();                    // 保守：每个场景重新开始数在场单位
      const toks = s.slice(3).trim().split(/\s+/).filter(Boolean);
      const pos = [];
      for (const t of toks) {
        const kv = /^(BGM|bgm|地图|字幕)[：:](.*)$/.exec(t);
        if (!kv) { pos.push(t); continue; }
        const [, k, v] = kv;
        if (!v) 报(ln, 'W01', `场景头的「${k}:」没写值`);
        else if (k === '字幕' && v !== '关') 报(ln, 'W01', `场景头「字幕:${v}」认不出（只认「字幕:关」）`);
        else if (/^bgm$/i.test(k) && opts.BGM表 && !opts.BGM表.has(v)) 报(ln, 'W22', `BGM「${v}」不在音乐线的对照表里`);
      }
      const 章节ok = pos[0] && /^[^\s\-－]+[-－][^\s\-－]+$/.test(pos[0]);
      const 地点ok = pos[1] && /^[^·・]+[·・][^·・]+$/.test(pos[1]);
      if (!章节ok) 报(ln, 'E02', '场景头缺「章-节」（第一段要写成 1-1 这样）');
      if (!地点ok) 报(ln, 'E02', '场景头缺「地点·时间」（第二段要写成 地点·时间）');
      if (pos.length > 2) 报(ln, 'W01', `场景头有认不出的段：${pos.slice(2).join(' ')}`);
      continue;
    }

    if (s.startsWith('【')) {
      可播放(ln);
      let p = 0;
      while (p < s.length) {
        while (p < s.length && /\s/.test(s[p])) p++;
        if (p >= s.length) break;
        if (s[p] !== '【') {
          const tail = s.slice(p);
          if (查配对(tail, ln)) 报(ln, 'W01', `指令后面有认不出的文字「${tail}」`);
          break;
        }
        const close = s.indexOf('】', p + 1), next = s.indexOf('【', p + 1);
        if (close < 0 || (next >= 0 && next < close)) { 报(ln, 'E03', '`【` 没有配对的 `】`（不允许跨行）'); break; }
        指令(s.slice(p + 1, close), ln);
        p = close + 1;
      }
      continue;
    }

    const 旁白 = /^旁白\s*[：:]([\s\S]*)$/.exec(s);
    if (旁白) {
      可播放(ln);
      const 正文 = 旁白[1].trim();
      查配对(正文, ln);
      if (!正文) 报(ln, 'E11', '旁白正文为空');
      else 查长度(正文, ln, '旁白');
      continue;
    }

    const d = /^([^\s（(〈【「：:。！？，、…]+)(?:〈([^〉]*)〉)?(?:[（(]([^）)]*)[）)])?\s*[：:]([\s\S]*)$/.exec(s);
    if (d) {
      可播放(ln);
      const [, 名, 显示名, 括号, 原文] = d;
      if (括号 !== undefined) {
        const 词 = 括号.split(/[·・]/).map(x => x.trim());
        const 表 = 词.filter(x => x !== '心声');
        if (表.length > 1 || (表.length === 1 && !表情.has(表[0])))
          报(ln, 'W12', `表情「${表.join('·') || '（空）'}」不在七种之内，按「普通」`);
      }
      const 名字栏 = 显示名 ?? 名;
      if (计字(名字栏) > 8) 报(ln, 'W13', `名字栏「${名字栏}」${计字(名字栏)} 字，超过 8 字`);
      if (opts.角色表 && !opts.角色表.has(名)) 报(ln, 'W14', `角色「${名}」不在角色表里`);
      查配对(原文, ln);
      let 正文 = 原文.trim();
      if (/[「」（）()]/.test(正文)) { 报(ln, 'W11', '台词里自己写了「」或（），已去掉'); 正文 = 正文.replace(/[「」（）()]/g, '').trim(); }
      if (!正文) 报(ln, 'E11', '台词正文为空');
      else 查长度(正文, ln, '台词');
      continue;
    }

    // 其它：W01，按旁白播（所以也照旁白查 E03 / E10）
    可播放(ln);
    报(ln, 'W01', '认不出类型的行，按旁白播');
    查配对(s, ln);
    查长度(s, ln, '这行（按旁白）');
  }

  /* ---- 收尾：标签 ---- */
  const 被引用 = new Set();
  for (const r of 标签引用) {
    被引用.add(r.name);
    if (!标签定义.has(r.name)) 报(r.line, 'E30', `${r.谁}指向不存在的标签「${r.name}」`);
  }
  for (const [name, ln] of 标签定义) if (!被引用.has(name)) 报(ln, 'W31', `标签「${name}」定义了但没人跳过来`);

  out.sort((a, b) => a.line - b.line);
  out.自由条数 = 自由条数;
  return out;
}

export function 校验文件(p, opts = {}) {
  return 校验文本(readFileSync(p, 'utf8'), opts);
}

/* ---------------- 保密扫描（W50） ---------------- */
const 是私密路径 = p => /(^|[\\/])协作[\\/]私密([\\/]|$)/.test(p);
export function 扫仓库(根们) {
  const out = [];
  for (const f of 收集md(根们, { 含README: true, 跳过私密: true })) {
    const lines = readFileSync(f, 'utf8').split(/\r?\n/);
    const i = lines.findIndex(l => l.trim().startsWith('@场景'));
    if (i >= 0) out.push({ file: f, line: i + 1, code: 'W50', msg: '保密：`协作/私密/` 之外发现带 `@场景` 的文件' });
  }
  return out;
}

/* ---------------- 文件收集 ---------------- */
function 收集md(根们, { 含README = false, 跳过私密 = false } = {}) {
  const out = [];
  const 走 = d => {
    for (const e of readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const p = join(d, e.name);
      if (e.isDirectory()) {
        if (e.name.startsWith('.') || e.name === 'node_modules') continue;
        if (跳过私密 && 是私密路径(resolve(p))) continue;
        走(p);
      } else if (e.isFile() && e.name.toLowerCase().endsWith('.md')) {
        if (!含README && e.name.toLowerCase() === 'readme.md') continue;
        out.push(p);
      }
    }
  };
  for (const r of 根们) {
    const st = statSync(r);
    if (st.isDirectory()) 走(r);
    else if (!(跳过私密 && 是私密路径(resolve(r)))) out.push(r);
  }
  return out;
}

/* ---------------- 命令行 ---------------- */
const 用法 = `用法：node godot/tools/check_script.mjs <剧本.md | 目录>… [--角色表 <路径>] [--BGM表 <路径>] [--音效表 <路径>] [--json] [--扫仓库]`;

export function main(argv) {
  const paths = []; const opts = {}; let json = false, 扫 = false;
  const 取值 = (i) => { if (i + 1 >= argv.length) throw new Error(`${argv[i]} 后面缺路径`); return argv[i + 1]; };
  try {
    for (let i = 0; i < argv.length; i++) {
      const a = argv[i];
      if (a === '-h' || a === '--help') { console.log(用法); return 0; }
      else if (a === '--json') json = true;
      else if (a === '--输出') { if (取值(i) !== 'json') throw new Error('--输出 只认 json'); json = true; i++; }
      else if (a === '--扫仓库' || a === '--scan-repo') 扫 = true;
      else if (a === '--角色表' || a === '--roles') { opts.角色表 = 读键表(取值(i)); i++; }
      else if (a === '--BGM表' || a === '--bgm') { opts.BGM表 = 读键表(取值(i)); i++; }
      else if (a === '--音效表' || a === '--sfx') { opts.音效表 = 读键表(取值(i)); i++; }
      else if (a.startsWith('--')) throw new Error(`认不出的选项 ${a}`);
      else paths.push(a);
    }
    if (!paths.length) throw new Error('没给剧本或目录');
    for (const p of paths) if (!existsSync(p)) throw new Error(`找不到 ${p}`);
  } catch (e) { console.error(`✗ ${e.message}\n${用法}`); return 2; }

  const items = []; let files = 0, free = 0;
  const 显示 = f => relative(process.cwd(), resolve(f)).split(sep).join('/') || f;
  if (扫) {
    for (const it of 扫仓库(paths)) items.push({ ...it, file: 显示(it.file) });
    files = 收集md(paths, { 含README: true, 跳过私密: true }).length;
  } else {
    for (const f of 收集md(paths)) {
      files++;
      const r = 校验文件(f, opts);
      free += r.自由条数;
      for (const it of r) items.push({ file: 显示(f), ...it });
    }
  }
  const errors = items.filter(x => x.code.startsWith('E')).length;
  const warnings = items.length - errors;
  if (json) {
    console.log(JSON.stringify({ files, errors, warnings, free, items: items.map(x => ({ ...x, level: x.code[0] === 'E' ? 'error' : 'warning' })) }, null, 2));
  } else {
    for (const x of items) console.log(`${x.file}:${x.line} ${x.code} ${x.msg}`);
    console.log(`—— ${files} 个文件：错误 ${errors}，警告 ${warnings}${扫 ? '' : `（自由指令 ${free} 条）`}`);
  }
  return errors ? 1 : 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
