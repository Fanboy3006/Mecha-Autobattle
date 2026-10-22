  /* ==========================================================================
   * ⑤ 会话（新建 / 续用 / 封存）
   * ======================================================================== */
  /** 会话身份 = `种子 + 分队 + 开始时间`（`开始时间` 取自 `RUN.t0`：读档回来一模一样）。
   *  ★ 2026-10-13 多带一个 **`t0`（毫秒）**：只比 `开始时间`（**秒**）时，「同一秒里连开两局」
   *    会被当成同一局 —— 操作与决策都往同一份里追加，`tests/map.js` 第 [23] 段 ⑤ 实测
   *    「同种子两遍导出不一样（0 条 vs 1 条）」。旧录像 / 老会话没有这个字段 → 退回只比 `开始时间`
   *    （照旧能读、能接着记）；读档回来 `t0` 是同一个数（它在 `RUN` 里、跟着存档走）→ 仍然是同一份。 */
  会话(允许新建) {
    const R = (typeof 肉鸽 !== 'undefined' && 肉鸽) ? 肉鸽.RUN : null;
    if (!R) return null;
    const 表 = this.读();
    const 种子 = 录像数(R.种子, null);
    const 分队 = 录像文字(R.分队 || '无');
    const 开始 = this.时间文字(R.t0);
    const t0 = 录像数(R.t0, null);
    const 同局 = x => !!x && x.种子 === 种子 && x.分队 === 分队 && x.开始时间 === 开始
      && (t0 == null || x.t0 == null || 录像数(x.t0, null) === t0);
    let s = 表.进行中;
    if (s && !同局(s)) {
      /* 换了一局：上一局没走完就重开了 → 按「放弃」封存（不然它会被覆盖掉） */
      this.落封(表, s, '放弃', '重开了一局');
      s = null;
    }
    if (!s) {
      if (!允许新建) return null;
      s = {
        格式版本: this.格式版本, 游戏版本: this.游戏版本(), 种子, 分队,
        开始时间: 开始, 结束时间: null, 结果: null, 操作: [], 决策: [],
        /* ★ 架构 2.0：把**录的时候那一套规则宇宙**也记下来（`'r1:' + 8 位十六进制`）。
           只有它能把「同一个 `游戏版本` 号、不同的规则参数」这两种录像分开 ——
           DEBT-03 的告警（`tools/replay.mjs` 的跨规则版本诊断）就靠这一个字段。
           它同样是**纯新增字段**：旧录像没有 → 认场时不补，工具走「只比 `游戏版本`」那条旧路。 */
        规则签名: this.规则签名(),
        /* ★ P1.2 §1.1（录像字段契约，CC 修订 #1）：**新录像在创建会话时一律写顶层 `战术卡牌`**
           —— 录的时候「战术卡牌开不开」（`Boolean(战斗结构.战术卡牌?.开)`，现行默认 `true`）。
           重放侧 `tools/replay.mjs` **严格**以「录像对象里有没有 `战术卡牌: true`」为**唯一**判据：
           没有这个字段（P1.2 之前的旧录像）就按**关牌**（`战术卡牌: false`）重放 ——
           **严禁**按「猜录像内容里有没有卡牌操作特征」去分叉。它同样是**纯新增字段**：
           旧录像读回来**一个字节都不补**（见 `认场()`），`tests/上报.js` 第 [6] 段的最小样例与旧录像文本逐字不变。 */
        战术卡牌: Boolean((typeof 战斗结构 !== 'undefined' && 战斗结构 && 战斗结构.战术卡牌)
          ? 战斗结构.战术卡牌.开 : false),
      };
      if (t0 != null) s.t0 = t0;
      for (const x of this.预备) { x.序号 = s.操作.length + 1; s.操作.push(this.编步(x)); }
      this.预备 = [];
      /* ★ 决策日志（`8b-决策日志.js`）：开新局**之前**那几步（`选分队` 那一屏）的决策也并进来 ——
         与 `预备` 同一套做法、**同一个顺序**（两个队列是在同一处一起 push 的，所以下标一一对应），
         `步` = 它在 `操作` 里的序号（**不是**决策自己的序号：中间夹着 `开新局` 这种不算决策的步）。 */
      if (typeof 决策录 !== 'undefined' && 决策录 && Array.isArray(决策录.预备)) {
        const 预备步数 = s.操作.length;
        /* 一一对应：第 i 条决策就是 `操作` 第 i+1 步（两个队列在同一处一起 push）；
           多出来的那几条**没有对应的操作步** → 不记（绝不写一个假的 `步`）。 */
        决策录.预备.slice(0, 预备步数).forEach((条, i) => {
          条.步 = i + 1;
          条.序 = s.决策.length + 1;
          s.决策.push(条);
        });
        决策录.预备 = [];
      }
      表.进行中 = s;
      this.写(表);
    }
    return s;
  },
  /** 追加一步（写回 localStorage —— 「读档继续记」靠它）。 */
  追加(s, 步) {
    if (!s || !步) return null;
    const 表 = this.读();
    const 活的 = 表.进行中;
    if (!活的) return null;
    if (活的.种子 !== s.种子 || 活的.开始时间 !== s.开始时间) return null;
    步.序号 = 活的.操作.length + 1;
    const 编 = this.编步(步);
    活的.操作.push(编);
    this.写(表);
    return 编;
  },
  /** ★ **追加一条决策**（`8b-决策日志.js` 的 `决策录.落()` 调；与 `追加()` 同一套落盘办法）。
   *  · `步` = 对应那一操作步的序号（两份记录靠它对得上）；
   *  · 超过 `决策条数上限`（300）→ **从最早丢**，丢了几条记在 `决策丢`（`序` 重新编成 1 起连续）；
   *  · 坏数据一律不崩（没有这一局 / 形状不对 → 返回 null）。 */
  追加决策(s, 条, 步) {
    if (!s || !条 || typeof 条 !== 'object' || Array.isArray(条)) return null;
    const 表 = this.读();
    const 活的 = 表.进行中;
    if (!活的) return null;
    if (活的.种子 !== s.种子 || 活的.开始时间 !== s.开始时间) return null;
    if (!Array.isArray(活的.决策)) 活的.决策 = [];
    const 上限 = (typeof 选项 !== 'undefined' && 选项 && 录像数(选项.条数上限, 0)) || 300;
    条.步 = 录像数(步, 活的.操作.length);
    活的.决策.push(条);
    while (活的.决策.length > 上限) {
      活的.决策.shift();
      活的.决策丢 = 录像数(活的.决策丢, 0) + 1;
    }
    活的.决策.forEach((x, i) => { x.序 = i + 1; });
    this.写(表);
    return 条;
  },
  /** 这一局对应的那一份录像（**进行中优先**；没有就用最近封存的、**种子对得上**的那一份；再没有 → null）。
   *  `RUN` 不给 / 是坏数据 → 退回「进行中」（或 null）。**纯读**。 */
  当前局(RUN) {
    const R = (RUN && typeof RUN === 'object' && !Array.isArray(RUN)) ? RUN : null;
    const 表 = this.读();
    const 种子 = R ? 录像数(R.种子, null) : null;
    if (表.进行中 && (种子 == null || 录像数(表.进行中.种子, null) === 种子)) return 表.进行中;
    if (种子 == null) return 表.进行中 || null;
    for (let i = 表.封存.length - 1; i >= 0; i--) {
      if (录像数(表.封存[i].种子, null) === 种子) return 表.封存[i];
    }
    return null;
  },
  /** 这一局的**决策记录**（旧录像没有这个字段 → 空数组）。**纯读**（`88-战斗记录.js` 的导出用它）。 */
  当前决策(RUN) {
    const 场 = this.当前局(RUN);
    return (场 && Array.isArray(场.决策)) ? 场.决策 : [];
  },
  /** 这一局超过上限被丢掉的决策条数（没有 → 0）。 */
  当前决策丢(RUN) { const 场 = this.当前局(RUN); return 场 ? 录像数(场.决策丢, 0) : 0; },
  /** 给一步补上 `序号`（1 起）并做形状整理。 */
  编步(步) {
    const x = (步 && typeof 步 === 'object') ? 步 : {};
    const 出 = { 序号: 录像数(x.序号, 0), 屏: 录像文字(x.屏), 动作: 录像文字(x.动作), 参数: 录像文字(x.参数) };
    if (x.回合 != null) 出.回合 = 录像数(x.回合, null);
    if (x.理由) 出.理由 = 录像文字(x.理由);
    if (x.对账 != null) 出.对账 = 录像文字(x.对账);
    if (x.弹窗) 出.弹窗 = 录像文字(x.弹窗);
    if (Array.isArray(x.可选项) && x.可选项.length) 出.可选项 = x.可选项.map(录像文字);
    return 出;
  },
  /** `RUN.结局` → 录像里的 `结果`：通关 = 胜 / 玩家放弃 = 放弃 / 其余 = 败。 */
  结局到结果(R) {
    if (!R || !R.结局) return null;
    if (R.结局 === '通关') return '胜';
    if (R.结局原因 === '玩家放弃') return '放弃';
    return '败';
  },
  /** 封存当前这一局（一局结束那一刻调一次）。 */
  封存(R, 结果, 原因) {
    const 表 = this.读();
    if (!表.进行中) return null;
    const s = 表.进行中;
    s.最终摘要 = this.摘要(R);
    this.落封(表, s, 结果, 原因);
    this.写(表);
    return s;
  },
  /** 把一份录像塞进 `封存[]`（FIFO，上限 `录像局数上限`），`进行中` 清空。 */
  落封(表, s, 结果, 原因) {
    s.结束时间 = s.结束时间 || this.时间文字();
    s.结果 = 结果 || s.结果 || '放弃';
    if (原因) s.结果原因 = 录像文字(原因);
    delete s.进行中;
    表.封存.push(s);
    while (表.封存.length > this.局数上限) 表.封存.shift();
    表.进行中 = null;
    return s;
  },
  /** 序号补齐（读回来的老数据 / 手写的测试数据可能没有序号；屏上要用）。 */
  排序号(场) {
    const 操作 = (场 && Array.isArray(场.操作)) ? 场.操作 : [];
    操作.forEach((x, i) => { if (x && x.序号 == null) x.序号 = i + 1; });
    return 操作;
  },

  /* ==========================================================================
   * ⑥ 导出（复制 / 下载 / 文件名）
   * ======================================================================== */
  /** 一份录像的 JSON 文本（给数据集：**缩进 2 格**，人能读）。 */
  文本(场) {
    if (!场 || typeof 场 !== 'object') return '';
    try { return JSON.stringify(场, null, 2) + '\n'; } catch (e) { return ''; }
  },
  /** 下载文件名（规格：带 **种子 / 版本 / 日期 / 结果**）：
   *  `对局录像-种子20261010-v0.6.2-20261012-150405-放弃.json`。 */
  文件名(场) {
    const 种 = `种子${场 && 场.种子 != null ? 场.种子 : '—'}`;
    const 版 = `v${录像文字(场 && 场.游戏版本) || '—'}`;
    const 日 = this.文件名时间(场 && (场.结束时间 || 场.开始时间));
    const 果 = 录像文字(场 && 场.结果) || '进行中';
    return `对局录像-${种}-${版}-${日}-${果}.json`.replace(/[\\/:*?"<>|\s]/g, '');
  },
  /** 复制（剪贴板 → `execCommand` → 失败退化成「全选文本」；和 `88-战斗记录.js` 同一套兜底）。 */
  复制(文) {
    const 字 = 录像文字(文);
    if (!字) return { ok: false, 方式: null, 提示: '这一份录像没有可复制的文本。' };
    try {
      if (typeof navigator !== 'undefined' && navigator && navigator.clipboard
        && typeof navigator.clipboard.writeText === 'function') {
        const p = navigator.clipboard.writeText(字);
        if (p && typeof p.catch === 'function') p.catch(() => {});
        return { ok: true, 方式: '剪贴板', 字数: 字.length, 提示: `已复制到剪贴板（${字.length} 字）` };
      }
    } catch (e) { /* 落到退路 */ }
    try {
      if (typeof document !== 'undefined' && document && document.createElement && document.body
        && typeof document.execCommand === 'function') {
        const ta = document.createElement('textarea');
        ta.value = 字;
        if (ta.setAttribute) ta.setAttribute('readonly', 'readonly');
        if (ta.style) { ta.style.position = 'fixed'; ta.style.left = '-9999px'; }
        document.body.appendChild(ta);
        if (typeof ta.select === 'function') ta.select();
        const ok = document.execCommand('copy');
        if (document.body.removeChild) document.body.removeChild(ta);
        if (ok) return { ok: true, 方式: 'execCommand', 字数: 字.length, 提示: `已复制到剪贴板（${字.length} 字）` };
      }
    } catch (e) { /* 落到退路 */ }
    return { ok: false, 方式: '全选文本', 字数: 字.length,
      提示: '这个环境不让写剪贴板：退化成「全选文本」—— 整段 JSON 已经摊在屏幕上，手动全选复制就行。' };
  },
  /** 下载 .json（`Blob` + `a[download]`；建不出来 → 可见提示 + 摊文本兜底）。 */
  下载(文, 名) {
    const 字 = 录像文字(文);
    const 文件名 = 录像文字(名) || this.文件名(null);
    if (!字) return { ok: false, 文件名, 提示: '这一份录像没有可下载的文本。' };
    try {
      if (typeof Blob !== 'undefined' && typeof URL !== 'undefined' && URL
        && typeof URL.createObjectURL === 'function'
        && typeof document !== 'undefined' && document && document.createElement && document.body) {
        const 块 = new Blob([字], { type: 'application/json;charset=utf-8' });
        const 址 = URL.createObjectURL(块);
        const a = document.createElement('a');
        a.href = 址;
        a.download = 文件名;
        if (a.style) a.style.display = 'none';
        document.body.appendChild(a);
        if (typeof a.click === 'function') a.click();
        if (document.body.removeChild) document.body.removeChild(a);
        if (typeof URL.revokeObjectURL === 'function') URL.revokeObjectURL(址);
        return { ok: true, 文件名, 字数: 字.length, 提示: `已下载 ${文件名}（${字.length} 字）` };
      }
    } catch (e) { /* 落到兜底 */ }
    return { ok: false, 文件名, 字数: 字.length,
      提示: '这个环境不支持下载（没有 Blob / URL）：用「复制录像」，或者把 JSON 摊出来手动存。' };
  },

  /* ==========================================================================
   * ⑥b ★ 2026-10-13「一键保存录像」（作者：「太复杂了，你再想想还有什么方法可以保存录像」）
   * --------------------------------------------------------------------------
   * 背景（统筹实测 + 作者原话）：作者要「把打的一局给我看」，前面两条路他都嫌麻烦
   *   （导出本局日志复制粘贴 / 把表格发布成 CSV 再存文件）→「**太复杂了，你再想想还有什么方法**」。
   * 统筹实测：`C:\Users\zxwu0\Downloads`（Windows 的浏览器默认下载目录）**能列、能读** ——
   *   所以只要**点一次**、文件落进下载文件夹，统筹自己就能读，作者**什么都不用发**。
   *
   * 五条规矩（改这一节之前先读）：
   *   1. **一键、不打扰**：`<a download>` + `Blob` + `URL.createObjectURL`（用完 `revokeObjectURL`）；
   *      **不用** `showSaveFilePicker` 之类的花哨 API（兼容第一）；**一个对话框 / 二次确认都不弹**。
   *   2. **自包含**：一个文件 = 一局的全部（种子 / 分队 / 结果 / 层 / 场次 / 起止时间 / 操作 /
   *      决策 / `RUN.日志` / 结算字段）—— 不依赖 `tools/replay.mjs` 就能直接读。
   *   3. **不动任何已有导出**：`88-战斗记录.js` 的「复制 / 下载本局日志」、本文件 ⑥ 的
   *      `复制录像 / 下载录像` **一个字节都没改**（新增的是另一条路 + 另一个反馈字段 `保存结果`）。
   *   4. **几十 KB 量级**：只收**文本与数字**，**绝不**把 `audio/` / `art/` 那些巨大资源塞进来。
   *   5. **时间戳可注入**：`现在` 是参数（`Date` / 毫秒 / `2026-10-13 12:00:00` 都认）；
   *      不传就现取。测试里固定它 → **同种子两遍字节逐字相同**。
   *
   * 文件名（**时间戳 + 种子都要有**，方便按最新时间找；只用 Windows 安全字符）：
   *   · 一局：`机甲指挥-录像-<种子>-<YYYYMMDD-HHmmss>.json`
   *   · 全部：`机甲指挥-录像全-<YYYYMMDD-HHmmss>.json`（最近 `局数上限` = 20 局打成一个）
   * ======================================================================== */
  /** 把任意「时刻」（`Date` / 毫秒 / `2026-10-13 12:00:00` 这种串）解析成 `Date`；
   *  认不出来 → `null`（**给测试注入固定时间戳用**）。绝不抛。 */
  时刻(v) {
    if (v == null || v === '') return null;
    try {
      if (typeof v === 'object' && typeof v.getTime === 'function') {
        return Number.isFinite(v.getTime()) ? v : null;
      }
      if (typeof v === 'string') {
        const m = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$/.exec(v.trim());
        if (!m) return null;
        return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), Number(m[6]));
      }
      const n = Number(v);
      return Number.isFinite(n) ? new Date(n) : null;
    } catch (e) { return null; }
  },
  /** 导出这一刻用哪个时间：**注入的优先**（测试固定它），否则现取。
   *  ★ 现取 = 保存的那一瞬间 —— 「按最新时间找文件」靠的就是它。
   *  （一局自己的 `开始时间 / 结束时间` 是**另一回事**：它们取自录像 / `RUN.t0`，见 `自包含()`。） */
  导出时刻(现在) { return this.时刻(现在) || new Date(); },
  /** `RUN` 的日志 → **文本行**数组（`[第N层] 原文`）。
   *  `RUN.日志` 的条目是 `{层, 文本}`；封存录像的 `最终摘要.日志` 是 `[层, 文本]`（旧局走这条）。 */
  日志行们(RUN, 摘) {
    const 源 = (RUN && Array.isArray(RUN.日志)) ? RUN.日志
      : ((摘 && Array.isArray(摘.日志)) ? 摘.日志 : []);
    return 源.map(x => {
      if (Array.isArray(x)) return `[第${x[0] == null ? '?' : x[0]}层] ${录像文字(x[1])}`;
      if (!x || typeof x !== 'object') return 录像文字(x);
      return `[第${x.层 == null ? '?' : x.层}层] ${录像文字(x.文本)}`;
    });
  },
  /** 招募券 → 名字数组（`RUN.券` 是对象、`最终摘要.券` 是 `[类,名,档,来源]` 四元组，两种都认）。 */
  券名们(RUN, 摘) {
    const 们 = (RUN && Array.isArray(RUN.券)) ? RUN.券
      : ((摘 && Array.isArray(摘.券)) ? 摘.券 : []);
    return 们.map(c => {
      const 名 = Array.isArray(c) ? c[1] : (c && c.名);
      const 类 = Array.isArray(c) ? c[0] : (c && c.类);
      return 录像文字(名 || 类);
    }).filter(Boolean);
  },
  /** 藏品 → 键数组（两边形状一样：字符串数组）。 */
  藏品们(RUN, 摘) {
    const 们 = (RUN && Array.isArray(RUN.藏品)) ? RUN.藏品
      : ((摘 && Array.isArray(摘.藏品)) ? 摘.藏品 : []);
    return 们.map(录像文字).filter(Boolean);
  },
  /** 零件 → `[{键, 剩}]`（`RUN.零件` 是 `{k, uses}`、`最终摘要.零件` 是 `[k, uses]`，两种都认）。 */
  零件们(RUN, 摘) {
    const 们 = (RUN && Array.isArray(RUN.零件)) ? RUN.零件
      : ((摘 && Array.isArray(摘.零件)) ? 摘.零件 : []);
    return 们.map(p => {
      if (Array.isArray(p)) return { 键: 录像文字(p[0]), 剩: p[1] == null ? null : 录像数(p[1], null) };
      if (!p || typeof p !== 'object') return null;
      return { 键: 录像文字(p.k), 剩: p.uses == null ? null : 录像数(p.uses, null) };
    }).filter(x => x && x.键);
  },
  /** **一局的自包含 JSON**（纯读；不做任何下载）。`RUN` 可以不给 —— 那时从录像的
   *  `最终摘要` 取结算字段（**以前打过的局**就是这样导出来的，见 `保存全部()`）。 */
  自包含(RUN, 场, 现在) {
    const R = (RUN && typeof RUN === 'object' && !Array.isArray(RUN)) ? RUN : null;
    const f = (场 && typeof 场 === 'object' && !Array.isArray(场)) ? 场 : null;
    if (!R && !f) return null;
    const 摘 = (f && f.最终摘要 && typeof f.最终摘要 === 'object') ? f.最终摘要 : null;
    const 时刻 = this.导出时刻(现在);
    /* 「有就用前面的，没有再退到后面」——RUN 优先、最终摘要兜底（旧局没有 RUN）。 */
    const 取 = (a, b, 兜底) => (a == null || a === '' ? ((b == null || b === '') ? 兜底 : b) : a);
    const 层 = 录像数(取(R && R.层, 摘 && 摘.层, null), null);
    const 场次 = 录像数(取(R && R.场次, 摘 && 摘.场次, null), null);
    const 局 = {
      格式: 录像导出格式,
      版本: 录像文字(this.游戏版本()),
      种子: 录像数(f ? f.种子 : (R && R.种子), null),
      分队: 录像文字(取(f && f.分队, R && R.分队, '无')),
      结果: 录像文字(取(f && f.结果, (R ? this.结局到结果(R) : null), '进行中')),
      层, 战斗场次: 场次,
      开始时间: 录像文字(取(f && f.开始时间, (R ? this.时间文字(R.t0) : ''), '—')),
      /* 结束时间**一定给**：封存局的真结束时间；还没打完的这一局给「导出这一刻」
         （配合可注入的 `时刻` 仍然是确定性的 —— 同种子两遍逐字相同靠的就是它）。 */
      结束时间: 录像文字((f && f.结束时间) || this.时间文字(时刻)),
      /* ---- 本局结算的字段（希望 / 源碳 / 券 / 耐久 / 藏品 / 零件 / 等级 / 经验） ---- */
      希望: 录像数(取(R && R.希望, 摘 && 摘.希望, null), null),
      源碳: 录像数(取(R && R.源碳, 摘 && 摘.源碳, null), null),
      券: this.券名们(R, 摘),
      耐久: 录像数(取(R && R.耐久, 摘 && 摘.耐久, null), null),
      藏品: this.藏品们(R, 摘),
      零件: this.零件们(R, 摘),
      等级: 录像数(取(R && R.等级, 摘 && 摘.等级, null), null),
      经验: 录像数(取(R && R.经验, 摘 && 摘.经验, null), null),
      /* ---- 日志（文本行）---- */
      日志: this.日志行们(R, 摘),
      /* ---- 录像本体 ---- */
      操作: (f && Array.isArray(f.操作)) ? f.操作 : [],
      决策: (f && Array.isArray(f.决策)) ? f.决策 : [],
    };
    if (f && 录像数(f.决策丢, 0)) 局.决策丢 = 录像数(f.决策丢, 0);
    if (f && f.结果原因) 局.结果原因 = 录像文字(f.结果原因);
    return 局;
  },
  /** 一局那份 JSON 的**文本**（缩进 2 格，人能读；末尾一个换行）。 */
  保存文本(RUN, 场, 现在) {
    const 局 = this.自包含(RUN, 场, 现在);
    if (!局) return '';
    try { return JSON.stringify(局, null, 2) + '\n'; } catch (e) { return ''; }
  },
  /** 一局录像的文件名：`机甲指挥-录像-<种子>-<YYYYMMDD-HHmmss>.json`（Windows 安全字符）。 */
  保存文件名(种子, 现在) {
    const 时 = this.文件名时间(现在);
    const 种 = (种子 == null || 种子 === '') ? '无种子' : 录像文字(种子);
    return `机甲指挥-录像-${种}-${时}.json`.replace(/[\\/:*?"<>|\s]/g, '');
  },
  /** 「保存全部录像」的文件名：`机甲指挥-录像全-<YYYYMMDD-HHmmss>.json`。 */
  全部文件名(现在) {
    return `机甲指挥-录像全-${this.文件名时间(现在)}.json`.replace(/[\\/:*?"<>|\s]/g, '');
  },
  /** 这一份封存录像**是不是现在这一局**（会话身份 = 种子 + 分队 + 开始时间 [+ `t0`]，
   *  与 `会话()` 同一套口径）—— 是的话就带上整份 `RUN`（日志 / 结算字段最全）。 */
  同一局(R, f) {
    if (!R || !f) return false;
    const t0 = 录像数(R.t0, null);
    return 录像数(f.种子, null) === 录像数(R.种子, null)
      && 录像文字(f.分队) === 录像文字(R.分队 || '无')
      && 录像文字(f.开始时间) === 录像文字(this.时间文字(R.t0))
      && (t0 == null || f.t0 == null || 录像数(f.t0, null) === t0);
  },
  /** **★ 一键「保存本局录像」**（作者 2026-10-13 要的那一颗按钮就叫这个名字）。
   *  点一次 → 一个自包含 JSON 落到**浏览器默认下载目录**（不弹任何对话框、不问任何东西）。
   *  没有录像 / 这一局还一步都没走 → `ok:false` + 一句人话（屏上可见），**不崩**。 */
  保存本局(现在) {
    const R = (typeof 肉鸽 !== 'undefined' && 肉鸽) ? 肉鸽.RUN : null;
    const 场 = this.当前局(R);
    if (!场 || !(场.操作 || []).length) {
      this.保存结果 = { ok: false, 提示: '这一局还没有录像：先在肉鸽里开一局（选分队 → 出发），'
        + '走一步 / 打一场之后，这个文件里就有东西可读了。' };
      界面.刷();
      return this.保存结果;
    }
    const 时刻 = this.导出时刻(现在);
    const 文 = this.保存文本(R, 场, 时刻);
    const 名 = this.保存文件名(场.种子, 时刻);
    const r = this.下载(文, 名);
    this.保存结果 = { ok: r.ok, 文件名: r.文件名, 字数: r.字数, 提示: r.提示, 文本: r.ok ? '' : 文 };
    界面.刷();
    return this.保存结果;
  },
  /** **★ 一键「保存全部录像」**：`localStorage` 里**最近 `局数上限`（20）局**打成一个 JSON。
   *  以前打过的局就是这样一次交出来的（旧局没有 RUN → 结算字段从录像的 `最终摘要` 取）。
   *  一份都没有 → `ok:false` + 一句人话，**不崩**。 */
  保存全部(现在) {
    const 表 = this.读();
    const 们 = Array.isArray(表.封存) ? 表.封存 : [];
    const R = (typeof 肉鸽 !== 'undefined' && 肉鸽) ? 肉鸽.RUN : null;
    if (!们.length) {
      this.保存结果 = { ok: false, 提示: `还没有存下来的录像：一局走完（胜 / 败 / 放弃都算）就会自动存一份，`
        + `最多留最近 ${this.局数上限} 局。` };
      界面.刷();
      return this.保存结果;
    }
    const 时刻 = this.导出时刻(现在);
    const 录像们 = 们.map(f => this.自包含(this.同一局(R, f) ? R : null, f, 时刻)).filter(Boolean);
    const 包 = {
      格式: 录像导出全格式,
      版本: 录像文字(this.游戏版本()),
      时间: this.时间文字(时刻),
      局数上限: this.局数上限,
      局数: 录像们.length,
      录像: 录像们,
    };
    let 文 = '';
    try { 文 = JSON.stringify(包, null, 2) + '\n'; } catch (e) { 文 = ''; }
    const 名 = this.全部文件名(时刻);
    const r = this.下载(文, 名);
    this.保存结果 = { ok: r.ok, 文件名: r.文件名, 字数: r.字数, 局数: 录像们.length, 提示: r.提示, 文本: r.ok ? '' : 文 };
    界面.刷();
    return this.保存结果;
  },
  /** 那两颗按钮的 HTML（**大地图 / 本局结算屏 / 战斗结算屏共用这一份**）。
   *  `全 = false` 时只画「保存本局录像」（战斗结算屏那一块小一点）。 */
  保存按钮Html(全 = true) {
    const 表 = this.读();
    return `<button class="primary" data-act="保存本局录像" data-录像-保存="1">` +
      `💾 保存本局录像（存到你的下载文件夹）</button>` +
      (全 ? `<button class="mini" data-act="保存全部录像" data-录像-保存全="1">` +
        `💾 保存全部录像（最近 ${表.封存.length} / ${this.局数上限} 局）</button>` : '');
  },
  /** 保存的可见反馈（三层反馈的「结算」层；失败时把 JSON 摊在屏上 = 全选文本的退化）。
   *  ★ 与 ⑥ 的 `导出反馈Html()` **各管各的**（字段也是两个：`保存结果` / `复制结果·下载结果`）。 */
  保存反馈Html() {
    const 条 = this.保存结果;
    if (!条) return '';
    const 名 = (条.局数 != null) ? '保存全部录像' : '保存本局录像';
    const 摊 = 条.文本 ? `<textarea class="copyout" data-录像-保存输出="1" readonly rows="8">${录像转义(条.文本)}</textarea>` : '';
    return `<p class="resbar ${条.ok ? 'ok' : 'warn'}" data-录像-保存反馈="1"><b>${条.ok ? '成功' : '警告'}</b>` +
      `<span>${名}：${录像转义(条.提示)}</span></p>${摊}`;
  },

