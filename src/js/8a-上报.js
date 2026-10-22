/* ============================================================================
 * 对局上报（客户端）—— 作者 2026-10-12 拍板：「网页端任何人玩了以后都留下一条游戏记录」
 * ----------------------------------------------------------------------------
 * 接收端 = **Google Apps Script + Google 表格**（规格与部署说明 = `协作/上报-接收端-AppsScript.md`，
 * 那是**只读规格**，本文件只按它的第三节协议 POST，**不碰接收端**）。
 * 上传策略（作者拍板）= **默认开启 + 页面明确告知 + 菜单里可关**。
 *
 * ---------------------------------------------------------------------------
 * ★ 为什么是「读存档键、不挂封存回调」：
 *   正在跑的「回血」线也动 `89-录像.js` 那几个文件，**挂封存回调就是撞车**。
 *   所以这个文件**一个字节都不改** `src/js/89-录像.js` / `90-肉鸽.js` / `71-改动.js` /
 *   `91-地图.js` / `88-战斗记录.js`，做法是：
 *     · **读**录像的 localStorage 键（`mecha-autobattle-录像`）里的 `封存[]`；
 *     · 自己在**另一个独立键**里记「哪些对局ID已经上报过」（`mecha-autobattle-已上报`）；
 *     · 触发点只加在 `80-界面.js` 的**菜单渲染**与**结算屏渲染**里各一句 `上报.顺便传()`（纯追加）。
 *   后果：录像那条线**感知不到**这个文件；回血线改 `89-录像.js` 也不会踩到这里。
 *
 * ---------------------------------------------------------------------------
 * ★ 只报肉鸽整局（`协作/上报-接收端-AppsScript.md` 第三节）：
 *   练习模式 / 调参室 / 单场战斗**不报**。怎么分辨来源？**录像里本来就能分辨**：
 *   `89-录像.js` 只在**有进行中的肉鸽局**（`肉鸽.RUN` 存在）时才录（它的文件头第 2 条硬规矩），
 *   练习模式 / `simulate()` / 平衡工具 / 调参室**一个字节都不写**；
 *   而且只有**整局结束**（胜 / 败 / 放弃）才从 `进行中` 挪进 `封存[]`。
 *   ⇒ 口径 = **「只报 `封存[]` 里的那一种」=「有 RUN 才报」= 肉鸽整局**，
 *     不需要给录像加字段、也不需要碰录像那条线。
 *
 * ---------------------------------------------------------------------------
 * ★ 配置（拿到 Apps Script 的 Web 应用 URL 之后**只改这一行**）：
 *     const 上报地址 = '';   →   const 上报地址 = 'https://script.google.com/macros/s/AKfy…/exec';
 *   **空字符串 = 关闭 = 与现在完全一致**：`顺便传()` 第一句就返回、一次 fetch 都不发；
 *   菜单上也不加任何一行（连告知 / 开关 / 试传按钮都不出现）—— 没有地址时那条告知是句假话。
 *   `上报默认开 = true` = 拿到地址之后**默认就传**（玩家可以在菜单里关掉）。
 *
 * ---------------------------------------------------------------------------
 * ★ 协议（照 `协作/上报-接收端-AppsScript.md` 第三节，字段名一个都不改）：
 *   POST {对局ID, 时间, 种子, 版本, 分队, 结果, 层, 回合数, 时长秒, 操作数, 录像}
 *   `对局ID` = `种子-开始时间`（`604292-20261012-2340`）= 去重用，**不是身份**；
 *   `录像` **原样带上**（格式见 `协作/接口约定.md` 的「对局录像」一节，不截断、不改写）。
 *
 *   · Apps Script **不给 CORS 头** → 必须 `mode:'no-cors'` + `Content-Type: text/plain;charset=utf-8`
 *     （no-cors 只允许 CORS-safelisted 的 Content-Type，`application/json` 会被预检挡下）；
 *   · no-cors **读不到响应** → **一律当成功**（真正的去重由接收端按对局ID做，见规格第四节）。
 *
 * ---------------------------------------------------------------------------
 * ★ 失败不打扰（三条硬规矩，写在这里，改这个文件前先读）：
 *   1. **绝不 throw**：整个 `顺便传()` 包在 try 里；`fetch` 抛了 / reject 了 / 没有 `fetch` /
 *      地址为空 / `localStorage` 坏了 —— 一律吞掉，返回一句统计；
 *   2. **绝不弹窗、绝不动玩法**：不写 `RUN`、不改 `ctx`、不调 `界面.刷()`（只有**玩家手点**
 *      「试传一条」才会刷一下菜单，为了给他看见结果）；
 *   3. **失败的那一局留在队列里**：只有**成功**才写 `已上报`，失败的下次进页面自动重试。
 *
 * ---------------------------------------------------------------------------
 * ★ 隐私（规格第三节 + 作者拍板）：
 *   只发**游戏数据**（种子 / 版本 / 分队 / 结果 / 层 / 回合 / 时长 / 操作数 / 录像）
 *   + 一个**随机对局ID**（种子 + 开始时间，用于去重）。
 *   **不采集设备信息、不采集账号、不发任何身份字段**（这个文件里一处 `navigator` / cookie /
 *   指纹 / 用户 ID 都没有）。
 *
 * ---------------------------------------------------------------------------
 * 三层反馈（`CLAUDE.md` 第 7 节第 10 条）：
 *   · **预告**：菜单上一行告知「本局结束后会**自动上传对局记录**（只含你的操作与结果，不含个人信息），
 *     可在菜单里关闭」+ 状态行写着「待传 N 局 / 已上报 M 局 / 现在是开着的还是关着的」；
 *   · **即时**：点「自动上传：开 / 关」按钮 → 按钮文字**当场**变成「关 / 开」；
 *     点「试传一条」→ 先出「发送中…」，请求落地后那一条**当场**变成「已发出 / 没发出去」；
 *   · **结算**：自动上传是**静默**的（不打扰玩法）；可见的结算只有「试传一条」那一行
 *     —— 它明确写着「这是 no-cors 请求，浏览器读不到接收端的回复，一律按成功；
 *     去 Google 表格里看有没有这一行」，并给出**对局ID**（表格里能对着找）。
 * ========================================================================== */

/** ★ 上报地址：**拿到 Apps Script 的 Web 应用 URL 之后填这里**（形如
 *  `https://script.google.com/macros/s/AKfy…/exec`）。**空字符串 = 关闭 = 与现在完全一致**：
 *  一次 fetch 都不发，菜单上一个字节都不加。部署 5 步见 `协作/上报-接收端-AppsScript.md` 第一节。
 *  ★ 2026-10-13：作者已部署并给出 URL，这里**填好了**（上报随之变为可用 + 默认开）。 */
const 上报地址 = 'https://script.google.com/macros/s/AKfycbxTiNEJbwDRJGqwqNx5zFOha45pZ_RGd2_Zn6lZnIAVrvn-64CwAySbqTlTbfSuIalidQ/exec';
/** 拿到地址之后**默认就传**（作者拍板「默认开启 + 页面告知 + 可关」）；玩家在菜单里关掉就写进 localStorage。 */
const 上报默认开 = true;
/** 「哪些对局ID已经上报过」的**独立** localStorage 键（和录像键、肉鸽存档、作战记录都无关）。 */
const 已上报键 = 'mecha-autobattle-已上报';
/** 开关（开 / 关）自己的 localStorage 键。 */
const 上报开关键 = 'mecha-autobattle-上报开关';
/** 「已上报」最多记多少条（录像只留最近 20 局，500 远远够；超了从最老丢）。 */
const 已上报上限 = 500;

/** 一串字的安全转义（画进 HTML 之前的唯一出口）。 */
const 上报转义 = v => (v == null ? '' : String(v))
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const 上报 = {
  键: { 已上报: 已上报键, 开关: 上报开关键 },
  已上报键, 开关键: 上报开关键, 已上报上限,
  默认开: 上报默认开,
  协议字段: ['对局ID', '时间', '种子', '版本', '分队', '结果', '层', '回合数', '时长秒', '操作数', '录像'],

  /* ---------------- 运行期状态（都不进存档） ---------------- */
  发送器: null,          // ★ **可注入的发送口子**：`(载荷, 地址, 体文字) => Promise|任意`；测试 / 以后换传输层用
  地址覆盖: null,        // `设地址()` 写的临时地址（`null` = 用常量 `上报地址`；测试用，也给控制台应急）
  在传中: new Set(),     // 正在传的对局ID（同一局连调两次 `顺便传()` 只发一次靠它）
  发送链: null,          // 最近一次发送链的 Promise（测试 `await 上报.等发送()` 用；永远 resolve）
  试传结果: null,        // 「试传一条」的可见反馈（`{ok, 状态, 对局ID, 提示}`）
  试传等待: null,        // 最近一次试传的 Promise（测试 `await 上报.等试传()` 用；永远 resolve）
  统计: { 顺便传调用: 0, 检查: 0, 发出: 0, 跳过: 0, 原因: '' },

  /* ==========================================================================
   * ① 小工具：localStorage 读 / 写（坏数据一律不崩）
   * ======================================================================== */
  存根() {
    try {
      if (typeof localStorage === 'undefined' || !localStorage) return null;
      return localStorage;
    } catch (e) { return null; }
  },
  读键(键) {
    const L = this.存根();
    if (!L) return '';
    try { const v = L.getItem(键); return v == null ? '' : String(v); } catch (e) { return ''; }
  },
  写键(键, 值) {
    const L = this.存根();
    if (!L) return false;
    try { L.setItem(键, String(值)); return true; } catch (e) { return false; }
  },
  错文字(e) {
    try { return String(e && e.message ? e.message : e); } catch (e2) { return '未知错误'; }
  },

  /* ==========================================================================
   * ② 配置：地址 / 开关
   * ======================================================================== */
  /** 现在的上报地址（默认 = 顶部常量；`设地址()` 可以临时盖住它）。 */
  地址() {
    const 址 = (this.地址覆盖 != null) ? this.地址覆盖 : 上报地址;
    return 址 == null ? '' : String(址).trim();
  },
  /** 临时换地址（测试用；`设地址(null)` = 回到常量）。返回生效后的地址。 */
  设地址(址) {
    this.地址覆盖 = (址 == null || 址 === '') ? (址 === '' ? '' : null) : String(址);
    return this.地址();
  },
  /** 地址配好了吗（= 整条上报线存在吗）。**空地址 = 关闭 = 与现在完全一致。** */
  配好了() { return !!this.地址(); },
  /** 自动上传开关（localStorage 里没记过 → 用 `上报默认开`）。 */
  开关() {
    const 文 = this.读键(上报开关键);
    if (文 === '1') return true;
    if (文 === '0') return false;
    return !!上报默认开;
  },
  设开关(开) {
    this.写键(上报开关键, 开 ? '1' : '0');
    return this.开关();
  },
  /** 现在到底传不传（地址 + 开关都要过）。 */
  启用() { return this.配好了() && this.开关(); },
  /** 菜单按钮那一句（三层反馈的**即时**层：点一下文字当场变）。 */
  开关文字() { return this.开关() ? '自动上传：开（点一下关掉）' : '自动上传：关（点一下打开）'; },
  /** 切开关（菜单按钮走它）。开着 → 关掉（队列里的一条都不再传）；关着 → 打开。 */
  切开关() {
    const 新 = this.设开关(!this.开关());
    this.刷菜单();
    return 新;
  },
  /** 这一条不许在 `tools/replay.mjs` 重放时联网（重放工具会置 `录像.关 = true`）。 */
  重放中() {
    try { return !!(typeof 录像 !== 'undefined' && 录像 && 录像.关); } catch (e) { return false; }
  },

  /* ==========================================================================
   * ③ 「已上报」表（独立键：`{版本, 已上报: [对局ID…]}`）
   * ======================================================================== */
  已上报集() {
    const 文 = this.读键(已上报键);
    if (!文) return [];
    let 解 = null;
    try { 解 = JSON.parse(文); } catch (e) { return []; }
    if (Array.isArray(解)) return 解.map(String).filter(Boolean);
    if (解 && typeof 解 === 'object' && Array.isArray(解.已上报)) return 解.已上报.map(String).filter(Boolean);
    return [];
  },
  写已上报(们) {
    const 列 = (们 || []).map(String).filter(Boolean);
    const 截 = 列.length > 已上报上限 ? 列.slice(-已上报上限) : 列;
    this.写键(已上报键, JSON.stringify({ 版本: 1, 已上报: 截 }));
    return 截.length;
  },
  /** 记一条「这一局已经上报过了」（**只有成功才调**；失败的那一局留在队列里下次重试）。 */
  标记已上报(对局ID) {
    const 键 = 对局ID == null ? '' : String(对局ID);
    if (!键) return false;
    const 们 = this.已上报集();
    if (们.indexOf(键) >= 0) return false;
    们.push(键);
    this.写已上报(们);
    return true;
  },
  已上报数() { return this.已上报集().length; },
  已上报过(对局ID) { return this.已上报集().indexOf(String(对局ID)) >= 0; },

  /* ==========================================================================
   * ④ 读录像（**只读**它的存档键：不碰 `89-录像.js`、不挂封存回调）
   * ======================================================================== */
  录像表() {
    try {
      if (typeof 录像 !== 'undefined' && 录像 && typeof 录像.读 === 'function') return 录像.读();
    } catch (e) { /* 读不到就当没有 */ }
    return { 进行中: null, 封存: [] };
  },
  /** 还没上报过的**肉鸽整局**（= `封存[]` 里、对局ID 不在 `已上报` 里的那些）。纯读，不改任何东西。 */
  待传() {
    const 表 = this.录像表();
    const 已 = this.已上报集();
    return (表.封存 || []).filter(场 => {
      const id = this.对局ID(场);
      return !!id && 已.indexOf(id) < 0;
    });
  },
  待传数() { return this.待传().length; },

  /* ==========================================================================
   * ⑤ 载荷（照协议逐字段拼；`录像` 原样带上）
   * ======================================================================== */
  /** `2026-10-12 23:40:57` → `20261012-2340`（对局ID 里那一段；解析不出来 → 空串）。 */
  短时间(文) {
    const m = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/.exec(String(文 == null ? '' : 文));
    return m ? `${m[1]}${m[2]}${m[3]}-${m[4]}${m[5]}` : '';
  },
  /** `2026-10-12 23:40:57` → 毫秒（本机时区；解析不出来 → null）。 */
  解析时间(文) {
    const m = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?/.exec(String(文 == null ? '' : 文));
    if (!m) return null;
    const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]),
      Number(m[4]), Number(m[5]), Number(m[6] || 0));
    const t = d.getTime();
    return Number.isFinite(t) ? t : null;
  },
  /** 带本机时区偏移的 ISO（协议样例 `2026-10-12T23:40:57+08:00`）。 */
  本地ISO(d) {
    const p = n => String(n).padStart(2, '0');
    const 偏 = -d.getTimezoneOffset();                    // 分钟（东八区 = +480）
    const 号 = 偏 >= 0 ? '+' : '-';
    const 绝 = Math.abs(偏);
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}` +
      `T${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}` +
      `${号}${p(Math.floor(绝 / 60))}:${p(绝 % 60)}`;
  },
  /** 协议的 `时间` 字段：**开始时间**（协议样例里 `对局ID` 的 2340 与它同源）→ 结束时间 → 现在。 */
  时间ISO(场) {
    const f = 场 || {};
    const t = this.解析时间(f.开始时间);
    if (t != null) return this.本地ISO(new Date(t));
    const t2 = this.解析时间(f.结束时间);
    if (t2 != null) return this.本地ISO(new Date(t2));
    return this.本地ISO(new Date());
  },
  /** **对局ID** = `种子-开始时间`（照规格第三节：`604292-20261012-2340`）。去重用，不是身份。 */
  对局ID(场) {
    const f = 场 || {};
    const 种 = (f.种子 == null || f.种子 === '') ? '' : String(f.种子);
    const t = this.短时间(f.开始时间) || this.短时间(f.结束时间);
    if (!种 && !t) return '';
    return t ? `${种}-${t}` : 种;
  },
  /** 时长秒 = 结束时间 − 开始时间（有一个解析不出来 → 0）。 */
  时长秒(场) {
    const f = 场 || {};
    const a = this.解析时间(f.开始时间), b = this.解析时间(f.结束时间);
    if (a == null || b == null) return 0;
    return Math.max(0, Math.round((b - a) / 1000));
  },
  /** 回合数 = 操作流水里出现过的**最大回合号**（录像只记操作、不单独记回合数；没有 → 0）。 */
  回合数(场) {
    const 操 = (场 && Array.isArray(场.操作)) ? 场.操作 : [];
    let 大 = 0;
    for (const x of 操) {
      const n = Number(x && x.回合);
      if (Number.isFinite(n) && n > 大) 大 = n;
    }
    return 大;
  },
  层(场) {
    const 摘 = (场 && 场.最终摘要 && typeof 场.最终摘要 === 'object') ? 场.最终摘要 : null;
    const n = 摘 ? Number(摘.层) : NaN;
    return Number.isFinite(n) ? n : ((场 && Number.isFinite(Number(场.层))) ? Number(场.层) : '');
  },
  /** 游戏版本（场里没有 → 读 `__game.version`）。 */
  游戏版本() {
    try { return (typeof VERSION !== 'undefined' && VERSION) ? String(VERSION) : ''; } catch (e) { return ''; }
  },
  /** ★ **协议的载荷**（字段名一个都不改；`录像` = 那一份录像**原样**）。 */
  载荷(场) {
    const f = (场 && typeof 场 === 'object') ? 场 : {};
    const 版本 = (f.游戏版本 == null || f.游戏版本 === '') ? this.游戏版本() : String(f.游戏版本);
    return {
      对局ID: this.对局ID(f),
      时间: this.时间ISO(f),
      种子: (f.种子 == null || f.种子 === '') ? '' : f.种子,
      版本,
      分队: (f.分队 == null || f.分队 === '') ? '无' : String(f.分队),
      结果: f.结果 == null ? '' : String(f.结果),
      层: this.层(f),
      回合数: this.回合数(f),
      时长秒: this.时长秒(f),
      操作数: (Array.isArray(f.操作) ? f.操作 : []).length,
      录像: f,
    };
  },

  /* ==========================================================================
   * ⑥ 发送（**绝不 throw、绝不 reject**）
   * ======================================================================== */
  /** 注入发送器（测试 / 以后换传输层）。`设发送(null)` = 回到全局 `fetch`。 */
  设发送(fn) { this.发送器 = (typeof fn === 'function') ? fn : null; return this.发送器; },
  /**
   * 发一条。**永远返回一个 resolve 的 Promise**：`{ok, 方式, 字数, 提示}`（ok = 请求已发出）。
   *  · 优先走**注入的发送器**（测试 / 换传输层）；
   *  · 否则走全局 `fetch(地址, {method:'POST', mode:'no-cors', headers:{'Content-Type':'text/plain;charset=utf-8'}, body})`
   *    —— Apps Script 不给 CORS 头，no-cors 读不到响应，**一律按成功**（去重靠接收端）。
   */
  发送(载荷) {
    const 址 = this.地址();
    if (!址) return Promise.resolve({ ok: false, 方式: null, 提示: '上报地址为空（整条线关着）' });
    let 体;
    try { 体 = JSON.stringify(载荷); } catch (e) {
      return Promise.resolve({ ok: false, 方式: null, 提示: '载荷序列化失败：' + this.错文字(e) });
    }
    const 自定 = this.发送器;
    if (typeof 自定 === 'function') {
      try {
        return Promise.resolve(自定(载荷, 址, 体)).then(
          () => ({ ok: true, 方式: '注入', 字数: 体.length, 提示: '注入的发送器已收下这一条' }),
          e => ({ ok: false, 方式: '注入', 字数: 体.length, 提示: '注入的发送器报错：' + this.错文字(e) }));
      } catch (e) {
        return Promise.resolve({ ok: false, 方式: '注入', 字数: 体.length, 提示: '注入的发送器抛了：' + this.错文字(e) });
      }
    }
    if (typeof fetch !== 'function') {
      return Promise.resolve({ ok: false, 方式: null, 字数: 体.length, 提示: '这个环境没有 fetch（留在待传队列里，下次再试）' });
    }
    try {
      const r = fetch(址, {
        method: 'POST',
        mode: 'no-cors',
        headers: { 'Content-Type': 'text/plain;charset=utf-8' },
        body: 体,
      });
      return Promise.resolve(r).then(
        () => ({ ok: true, 方式: 'fetch-no-cors', 字数: 体.length,
          提示: '已发出（no-cors：浏览器读不到接收端的回复，一律按成功；接收端按对局ID去重）' }),
        e => ({ ok: false, 方式: 'fetch-no-cors', 字数: 体.length, 提示: '网络失败：' + this.错文字(e) }));
    } catch (e) {
      return Promise.resolve({ ok: false, 方式: 'fetch-no-cors', 字数: 体.length, 提示: 'fetch 抛了：' + this.错文字(e) });
    }
  },
  /** 发一条（不 await）：成功了才写 `已上报`，失败就留在队列里。`在传中` 挡住重复发送。 */
  发一条(载荷) {
    const id = 载荷 && 载荷.对局ID ? String(载荷.对局ID) : '';
    if (!id) return false;
    this.在传中.add(id);
    let p = null;
    try { p = this.发送(载荷); } catch (e) { p = null; }
    const 收 = r => {
      this.在传中.delete(id);
      if (r && r.ok) this.标记已上报(id);
    };
    if (p && typeof p.then === 'function') {
      const 链 = p.then(收, () => { this.在传中.delete(id); });
      this.发送链 = (this.发送链 && typeof this.发送链.then === 'function')
        ? this.发送链.then(() => 链).then(() => null, () => null)
        : 链.then(() => null, () => null);
    } else 收(null);
    return true;
  },
  /** 等一等最近这一串发送（测试用；永远 resolve）。 */
  等发送() {
    const p = this.发送链;
    return (p && typeof p.then === 'function') ? p.then(() => true, () => true) : Promise.resolve(true);
  },

  /* ==========================================================================
   * ⑦ 顺便传（**唯一的自动上传口**：菜单渲染 / 结算屏渲染各调一次）
   * --------------------------------------------------------------------------
   * 一次调用 = 检查 `封存[]` → 把还没上报过的逐条 POST 走。
   * **同步返回一句统计，绝不 throw、绝不等网络、绝不刷屏**（`{检查, 发出, 跳过, 原因}`）。
   * ======================================================================== */
  顺便传() {
    const 出 = { 检查: 0, 发出: 0, 跳过: 0, 原因: '' };
    this.统计.顺便传调用++;
    try {
      if (this.重放中()) { 出.原因 = '重放中（不联网）'; this.记统计(出); return 出; }
      if (!this.地址()) { 出.原因 = '上报地址为空（整条线关着）'; this.记统计(出); return 出; }
      if (!this.开关()) { 出.原因 = '自动上传被关掉了'; this.记统计(出); return 出; }
      const 待 = this.待传();
      出.检查 = 待.length;
      for (const 场 of 待) {
        const 载荷 = this.载荷(场);
        const id = 载荷 && 载荷.对局ID;
        if (!id || this.在传中.has(String(id))) { 出.跳过++; continue; }
        出.发出++;
        this.发一条(载荷);
      }
    } catch (e) {
      出.原因 = '异常已吞：' + this.错文字(e);
    }
    this.记统计(出);
    return 出;
  },
  记统计(出) {
    this.统计.检查 = 出.检查;
    this.统计.发出 = 出.发出;
    this.统计.跳过 = 出.跳过;
    this.统计.原因 = 出.原因;
    return 出;
  },

  /* ==========================================================================
   * ⑧ 「试传一条」（菜单里的验证按钮：给作者 / 我验证接收端到底通不通）
   * --------------------------------------------------------------------------
   * 样本 = **最新封存的一局录像** → **进行中的那一局** → **一条最小样例**（一局录像都没有时）。
   * 三层反馈：动作（点按钮）→ 可见结果（`试传结果` 那一行：发送中 → 已发出 / 没发出去）。
   * **开关关着 = 连试传也不发**（「关掉后不再上传」按最严的口径办），但**照样给一句可见反馈**。
   * ======================================================================== */
  试传样本() {
    const 表 = this.录像表();
    const 封 = Array.isArray(表.封存) ? 表.封存 : [];
    for (let i = 封.length - 1; i >= 0; i--) if (this.对局ID(封[i])) return { 场: 封[i], 是录像: true, 来源: '最新封存的一局' };
    if (表.进行中 && this.对局ID(表.进行中)) return { 场: 表.进行中, 是录像: true, 来源: '进行中的那一局' };
    return { 场: this.最小样例(), 是录像: false, 来源: '最小样例（还没有任何录像）' };
  },
  /** 一局录像都没有时用的最小样例（**种子取当前秒数** → 连点两次不会被接收端当成同一局去重掉）。 */
  最小样例() {
    const d = new Date();
    const p = n => String(n).padStart(2, '0');
    const 时间 = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ` +
      `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
    return {
      格式版本: (typeof 录像 !== 'undefined' && 录像 && 录像.格式版本) ? Number(录像.格式版本) || 1 : 1,
      游戏版本: this.游戏版本(), 种子: Math.floor(d.getTime() / 1000) % 1000000, 分队: '无',
      开始时间: 时间, 结束时间: 时间, 结果: '试传', 操作: [], 试传样例: true,
    };
  },
  试传一条() {
    const 出 = { ok: false, 状态: '没发', 对局ID: '', 来源: '', 提示: '' };
    try {
      if (!this.地址()) {
        出.提示 = '`上报地址` 还是空的：先把它填成 Apps Script 的 Web 应用 URL（`src/js/8a-上报.js` 顶部），这里才能试传。';
        this.试传结果 = 出; this.刷菜单(); return 出;
      }
      if (!this.开关()) {
        出.状态 = '被开关挡下';
        出.提示 = '「自动上传」现在是**关着**的，试传也一并停用 —— 这一条没有发出去。先在菜单里打开「自动上传」再试。';
        this.试传结果 = 出; this.刷菜单(); return 出;
      }
      const 样 = this.试传样本();
      const 载荷 = this.载荷(样.场);
      const id = 载荷.对局ID;
      出.状态 = '发送中'; 出.对局ID = id; 出.来源 = 样.来源;
      出.提示 = `正在发送一条试传（${样.来源}，对局ID ${id}）……`;
      this.试传结果 = 出;
      let p = null;
      try { p = this.发送(载荷); } catch (e) { p = null; }
      const 落地 = r => {
        const 结 = {
          ok: !!(r && r.ok),
          状态: (r && r.ok) ? '已发出' : '没发出去',
          对局ID: id, 来源: 样.来源,
          提示: (r && r.ok)
            ? `已发出（${样.来源}，对局ID ${id}，${r && r.字数 ? r.字数 : 0} 字）。这是 no-cors 请求，` +
              `浏览器读不到接收端的回复 —— 一律按成功；去 Google 表格里看一眼有没有这一行` +
              `（同一个对局ID 再点不会写第二行）。`
            : `没发出去：${(r && r.提示) ? r.提示 : '未知原因'}。不影响玩法；失败的那一局**不会**记成已上报，下次进页面会自动重试。`,
        };
        if (结.ok && 样.是录像 && !(样.场 && 样.场.试传样例)) this.标记已上报(id);
        this.试传结果 = 结;
        this.刷菜单();
        return 结;
      };
      const 链 = Promise.resolve(p).then(落地, e => 落地({ ok: false, 提示: this.错文字(e) }));
      this.试传等待 = 链.then(() => true, () => true);
      this.刷菜单();
    } catch (e) {
      出.提示 = '试传时出了个内部错（已经吞掉，不影响玩法）：' + this.错文字(e);
      this.试传结果 = 出;
      try { this.刷菜单(); } catch (e2) { /* 刷不动就算了 */ }
    }
    return this.试传结果 || 出;
  },
  /** 等一等最近一次「试传一条」落地（测试用；永远 resolve）。 */
  等试传() {
    const p = this.试传等待;
    return (p && typeof p.then === 'function') ? p.then(() => true, () => true) : Promise.resolve(true);
  },
  /** 只有「现在就在菜单屏」才刷一下（试传 / 切开关的可见反馈靠它；自动上传**绝不**刷屏）。 */
  刷菜单() {
    try {
      if (typeof 界面 === 'undefined' || !界面) return false;
      if (界面.屏 !== '菜单') return false;
      if (typeof 界面.刷 !== 'function') return false;
      界面.刷();
      return true;
    } catch (e) { return false; }
  },

  /* ==========================================================================
   * ⑨ 菜单那一块（告知 + 开关 + 试传 + 状态 + 反馈）
   * --------------------------------------------------------------------------
   * ★ **地址为空 → 返回空串**：菜单上一个字节都不加 = 与现在完全一致。
   *   （没有地址时那句「会**自动上传**」是句假话，所以整块一起不出现。）
   * ======================================================================== */
  菜单块() {
    try {
      if (!this.地址()) return '';
      const 开 = this.开关();
      const 待 = this.待传数();
      const 已 = this.已上报数();
      const r = this.试传结果;
      const 类 = r ? (r.ok ? 'ok' : (r.状态 === '发送中' ? 'info' : 'warn')) : '';
      const 反馈 = (r && r.提示)
        ? `<p class="resbar ${类}" data-上报-反馈="1"><b>${r.ok ? '成功' : (r.状态 === '发送中' ? '发送中' : '警告')}</b>` +
          `<span>${上报转义(r.提示)}</span></p>`
        : '';
      return `<div class="vcr-block" data-上报-块="1">
      <p class="small" data-上报-告知="1">本局结束后会<b>自动上传对局记录</b>（只含你的操作与结果，不含个人信息），可在菜单里关闭。</p>
      <div class="acts">
        <button data-act="上报开关" data-上报-开关="1">${上报转义(this.开关文字())}</button>
        <button data-act="上报试传" data-上报-试传="1">试传一条</button>
      </div>
      <p class="small" data-上报-状态="1">上报地址已配好（<code>${上报转义(this.地址())}</code>）·
        待传 <b>${待}</b> 局 · 已上报 <b>${已}</b> 局${开 ? '' : ' · <b>现在是关着的：一局都不会上传</b>'}
        —— 只发游戏数据（种子 / 版本 / 分队 / 结果 / 层 / 回合 / 时长 / 操作数 / 录像）+ 一个去重用的对局ID，
        不采集设备信息 / 账号 / 任何身份字段。</p>
      ${反馈}
    </div>`;
    } catch (e) { return ''; }
  },
};
