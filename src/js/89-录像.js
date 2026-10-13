/* ============================================================================
 * 对局录像（录操作，不录局面）—— 作者 2026-10-12 提出、Claude 出规格
 * ----------------------------------------------------------------------------
 * 作者的长远目的：让 AI 理解并模拟他的打法。现有的两份记录都**只有结果**：
 *   · `RUN.日志`（给人看，上限 300 条）—— 只有「发生了什么」；
 *   · `src/js/88-战斗记录.js`（查 bug 用，最近 5 场）—— 只有一场战斗的逐条记录。
 * 两份都缺「**当时的局面、当时能选什么、作者选了什么**」。
 *
 * 核心思路：**整局随机都来自种子**（测试一直保证「同种子连跑两遍逐字相同」），
 * 所以这一份只记三样：① **种子** ② **游戏版本号**（`__game.version`）③ **按顺序的每一个操作**
 * （动作名 + 参数）。要局面时用工具重放还原（`tools/replay.mjs`）——一局只有几十 KB。
 *
 * ---------------------------------------------------------------------------
 * 文件位置：`88-战斗记录.js` 之后、`80-界面.js` 之前（**纯数据层 + 一小块画面**，
 * 界面只在三个地方接它：动作派发入口那一个钩子、菜单入口、战斗结算屏那一块）。
 *
 * 六条硬规矩（写在文件头，改这个文件前先读）：
 *   1. **独立键**：`localStorage` 键 = `mecha-autobattle-录像` —— 和肉鸽存档（`存档键`，
 *      当前 `mecha-autobattle-run-v4`）、作战记录（`mecha-autobattle-战斗记录`）**完全无关**：
 *      `RUN` 结构不改、存档版本号不动。
 *   2. **只在「有进行中的肉鸽局」时录**：练习模式 / `simulate()` / 平衡工具 / 调参室
 *      （都没有 `RUN`）**一个字节都不写**（`派发后()` 第一句就判）。所以那些路径行为逐字不变。
 *   3. **钩子只有一个**：`80-界面.js` 的 `动作()`（**动作派发的唯一入口**）。
 *      界面上的每一个按钮（`data-act`）都经过它 —— 不每个按钮各记一份。
 *      ⚠ 只认这一个入口：测试 / 探针直接调 `界面.去节点()` 这类方法**不经过入口**（不记）。
 *   4. **保留最近 `录像局数上限 = 20` 局**（FIFO，超了从最老丢）；一局结束
 *      （**胜 / 败 / 放弃都算**）自动封存进 `封存[]`，`进行中` 清空。
 *   5. **进行中的这一局跟着读档继续记**：会话身份 = `种子 + 分队 + 开始时间`
 *      （`开始时间` 取自 `RUN.t0`，读档回来一模一样）→ 读档后**接着往同一份录像里追加**，
 *      不重开一份。
 *   6. **坏数据 / 空数据 / 垃圾一律不崩**：`localStorage` 不给用、JSON 坏了、形状不对、
 *      单条坏 → 一律退化成「没有录像」，一个异常都不抛。
 *
 * ---------------------------------------------------------------------------
 * 录像格式（**登记在 `协作/接口约定.md`，数据集说明在 `对局录像/README.md`**）：
 *   { 格式版本, 游戏版本, 种子, 分队, 开始时间, 结束时间, 结果, 操作: [ 步 ], 决策?: [ 条 ], 决策丢? }
 *   步 = { 序号, 屏, 动作, 参数, 回合?, 理由?, 对账? }
 *   ★ **2026-10-13 升 `格式版本` 1 → 2**：末尾多了一个与 `操作` **平行**的 `决策: […]`
 *     （玩家当时有哪些选项 + 实际选了哪个，紧凑、程序可读；实现在 `8b-决策日志.js`）。
 *     **`操作` 的结构与语义一个字节都没改**；旧录像（`格式版本: 1`，没有 `决策`）照旧能读 ——
 *     读不出 `决策` 就当空数组，不崩（`认场()` 就是这么做的）。
 * 规格里列的是前八个字段 + 步里的六个；这个文件**多加两个**（都写在接口约定里）：
 *   · `操作[].对账`：这一步做完之后那一瞬间的**紧凑局面串**（层 / 资源 / 名册 / 当前格 /
 *     战斗内的回合与双方 HP / 当前方针）。加它的唯一原因是验收 3「故意改坏一步 →
 *     工具要报出**正确的步数** + 当时**期望 / 实际**」—— 没有逐步的期望值就只能报「最后对不上」。
 *     它是**人话串**（不是哈希），所以报出来就能直接读。
 *   · `最终摘要`：这一局结束时 `RUN` 的**规范化投影**（去掉一切随时间变的字段：
 *     日志的时间戳、`t0`、Set 缓存）—— `tools/replay.mjs` 重放完之后重建同一份投影，
 *     两边 `JSON.stringify` **逐字比对**（验收 1）。
 *   · 另有一个 `结果原因`（败 / 放弃的那一句），只为了让人看懂为什么结束。
 *
 * ---------------------------------------------------------------------------
 * 三层反馈（`CLAUDE.md` 第 7 节第 10 条，每一件交付都要写清）：
 *   · **预告**：菜单 / 结算屏上那一块写着「已记 N 步 · 约 X KB · 种子 …」——
 *     作者在做决定之前就知道「这一局正在被录」；理由输入框自己也写着「可以不填」。
 *   · **即时**：每记一步都往 `进行中` 里追加，切屏 / 结算屏那一块的步数与大小**当场变**；
 *     理由填了就挂在那一步上（`理由` 字段）。
 *   · **结算**：一局结束**自动封存**，录像屏上写着「结果 / 步数 / 大小 / 时间」，
 *     并且**复制 / 下载**各有一句可见反馈（失败时把整段 JSON 摊在屏上 = 全选文本的退化）。
 * ========================================================================== */

/** localStorage 键（独立键，和肉鸽存档 / 作战记录都无关）。 */
const 录像键 = 'mecha-autobattle-录像';
/** 录像格式版本（格式变了才动它；不动 `RUN` 的存档版本号）。
 *  ★ 2026-10-13：`1` → `2` —— 一局里新增了与 `操作` 平行的 `决策: […]`（`8b-决策日志.js`）。
 *    读的一侧**不看版本号、只看字段**：旧录像没有 `决策` → 当空数组，照旧能读、能重放。 */
const 录像格式版本 = 2;
/** 保留最近几局（FIFO，超了从最老的丢）。**上限就写在这里，也写在 `对局录像/README.md`。** */
const 录像局数上限 = 20;
/** 录像屏上一次最多画多少步（只影响画面，不影响存下来的内容）。 */
const 录像屏步数上限 = 200;
/** 哪几屏挂「为什么选它？」那个**可以不填**的一行输入框（规格：招募 / 晋升 / 藏品 / 零件选择）。 */
const 录像理由屏们 = ['招募', '晋升', '黑市', '零件'];
/** 录像自己那几个界面动作**不进录像**（它们不是游戏操作，只是「看 / 导出」）。 */
const 录像不记动作 = ['去录像', '回录像', '看录像', '复制录像', '下载录像', '录像理由'];

/** 安全的数字（`null` / `''` / `NaN` / 认不出来的东西 → 兜底值）。 */
const 录像数 = (v, 兜底) => {
  if (v == null || v === '') return 兜底;
  const n = Number(v);
  return Number.isFinite(n) ? n : 兜底;
};
const 录像文字 = v => (v == null ? '' : String(v));
/** 「稳定量」：把任意值化成**只由内容决定**的 JSON 形状（对象键排序、Set / Map / 函数 → null）。
 *  用途 = `摘要()`：同一局重放两遍必须逐字相同，所以不能把 Set 缓存 / 函数带进去。 */
const 稳定量 = v => {
  if (v == null) return null;
  const t = typeof v;
  if (t === 'number') return Number.isFinite(v) ? v : null;
  if (t === 'string' || t === 'boolean') return v;
  if (Array.isArray(v)) return v.map(稳定量);
  if (t === 'object' && v.constructor === Object) {
    const o = {};
    for (const k of Object.keys(v).sort()) o[k] = 稳定量(v[k]);
    return o;
  }
  return null;      // Set / Map / 函数 / 其它（都不进摘要）
};
/** 画到 HTML 里之前转义（理由输入框的值 / JSON 预览都要） */
const 录像转义 = v => 录像文字(v)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const 录像 = {
  键: 录像键,
  格式版本: 录像格式版本,
  局数上限: 录像局数上限,
  步数上限: 录像屏步数上限,
  理由屏们: 录像理由屏们,
  不记动作: 录像不记动作,

  /* ---------------- 运行期状态（都不进存档） ---------------- */
  预备: [],          // 开新局之前「选分队」那一屏上的动作（成为这一局 `操作` 的第 1…步）
  本次: null,        // 正在派发的那一个动作（`派发前` 建、`派发后` 收；弹窗答案挂在它的 `子步` 上）
  理由: '',          // 理由输入框里的文字（跨刷屏保留；填了就挂到**下一步**上，然后清空）
  理由开: false,     // 输入框展开了吗（默认收起 = 不打断作者）
  选: null,          // 录像屏里正在看哪一份：`null` = 列表 / `'进行中'` / 封存下标（字符串）
  复制结果: null,    // 「复制录像」的可见反馈（失败时带整段 JSON → 摊在屏上）
  下载结果: null,    // 「下载 .json」的可见反馈
  接线过: false,     // `接线()` 只做一次（99-boot 调）
  关: false,         // `tools/replay.mjs` 重放时置 true：重放**不再录**（工具自己会用摘要对账）

  /* ==========================================================================
   * ① localStorage：读 / 写（坏数据一律不崩）
   * ======================================================================== */
  /** 拿到 localStorage（没有 / 被禁 → null；**绝不抛**）。 */
  存根() {
    try {
      if (typeof localStorage === 'undefined' || !localStorage) return null;
      return localStorage;
    } catch (e) { return null; }
  },
  /** 原始字符串（读不到 → 空串）。 */
  原文() {
    const L = this.存根();
    if (!L) return '';
    try { return 录像文字(L.getItem(this.键)); } catch (e) { return ''; }
  },
  /** 空表（`{版本, 进行中, 封存}`）。 */
  空表() { return { 版本: this.格式版本, 进行中: null, 封存: [] }; },
  /** 读回整张表：空 / 坏 JSON / 形状不对 / 单条坏 → 一律退化成空表，一个异常都不抛。 */
  读() {
    const 文 = this.原文();
    if (!文) return this.空表();
    let 解 = null;
    try { 解 = JSON.parse(文); } catch (e) { return this.空表(); }
    if (!解 || typeof 解 !== 'object' || Array.isArray(解)) return this.空表();
    const 出 = this.空表();
    出.进行中 = this.认场(解.进行中, true);
    const 封 = Array.isArray(解.封存) ? 解.封存.map(x => this.认场(x, false)).filter(Boolean) : [];
    出.封存 = 封.length > this.局数上限 ? 封.slice(-this.局数上限) : 封;
    return 出;
  },
  /** 认一份录像（形状不对 → null；`操作` 至少要是数组）。 */
  认场(x, 允许进行中) {
    if (!x || typeof x !== 'object' || Array.isArray(x)) return null;
    if (!Array.isArray(x.操作)) return null;
    const 出 = {
      格式版本: 录像数(x.格式版本, this.格式版本),
      游戏版本: 录像文字(x.游戏版本),
      种子: 录像数(x.种子, null),
      分队: 录像文字(x.分队 || '无'),
      开始时间: 录像文字(x.开始时间),
      结束时间: x.结束时间 == null ? null : 录像文字(x.结束时间),
      结果: x.结果 == null ? null : 录像文字(x.结果),
      操作: x.操作.filter(s => s && typeof s === 'object' && !Array.isArray(s)),
      /* ★ 决策日志（`8b-决策日志.js`）：**旧录像没有这个字段 → 当空数组**（照旧能读、能重放，不崩）。 */
      决策: Array.isArray(x.决策)
        ? x.决策.filter(d => d && typeof d === 'object' && !Array.isArray(d))
        : [],
    };
    if (x.决策丢 != null) 出.决策丢 = 录像数(x.决策丢, 0);
    if (x.t0 != null) 出.t0 = 录像数(x.t0, null);      // ★ 会话身份的另一半（毫秒；老录像没有它）
    if (x.结果原因 != null) 出.结果原因 = 录像文字(x.结果原因);
    if (x.最终摘要 && typeof x.最终摘要 === 'object') 出.最终摘要 = x.最终摘要;
    if (允许进行中) 出.进行中 = !!x.进行中;
    return 出;
  },
  /** 一份录像的体积（字符数；序列化不了 → Infinity）。 */
  体积(场) { try { return JSON.stringify(场 == null ? null : 场).length; } catch (e) { return Infinity; } },
  /** 写回整张表：先按**局数**从最老丢；写不进（配额满 / 无痕）→ 再丢最老重试一次。
   *  返回 `{ok, 局数, 体积, 丢了}`（**绝不抛**）。 */
  写(表) {
    const t = (表 && typeof 表 === 'object') ? 表 : this.空表();
    if (!Array.isArray(t.封存)) t.封存 = [];
    let 丢 = 0;
    while (t.封存.length > this.局数上限) { t.封存.shift(); 丢++; }
    const L = this.存根();
    if (!L) return { ok: false, 局数: t.封存.length, 体积: this.体积(t), 丢了: 丢 };
    const 试 = () => { try { L.setItem(this.键, JSON.stringify(t)); return true; } catch (e) { return false; } };
    if (试()) return { ok: true, 局数: t.封存.length, 体积: this.体积(t), 丢了: 丢 };
    /* 写不进去：先丢最老的封存，再试一次（本次的 `进行中` 一定要写下 —— 读档要继续记） */
    if (t.封存.length) { t.封存.shift(); 丢++; if (试()) return { ok: true, 局数: t.封存.length, 体积: this.体积(t), 丢了: 丢 }; }
    return { ok: false, 局数: t.封存.length, 体积: this.体积(t), 丢了: 丢 };
  },
  /** 清掉这个键（玩家 / 测试用；清完读回来就是空表）。 */
  清() {
    const L = this.存根();
    if (L) { try { L.removeItem(this.键); } catch (e) { /* 不崩 */ } }
    this.预备 = []; this.本次 = null; this.理由 = ''; this.理由开 = false; this.选 = null;
    /* ★ 决策日志（`8b-决策日志.js`）：还没开的那一局的「排队决策」也跟着一起清 ——
       它和 `预备` 是同一份东西的两半（`选分队` 那一步），只清一半会写出一条**没有操作步**的决策。 */
    if (typeof 决策录 !== 'undefined' && 决策录 && Array.isArray(决策录.预备)) 决策录.预备 = [];
    return true;
  },
  进行中() { return this.读().进行中; },
  封存们() { return this.读().封存; },
  游戏版本() { try { return (typeof VERSION !== 'undefined') ? String(VERSION) : '—'; } catch (e) { return '—'; } },

  /* ==========================================================================
   * ② 时间文字（和 `88-战斗记录.js` 同款）
   * ======================================================================== */
  /** `2026-10-12 15:04:05`（给「现在」/ 时间戳；不给就现取 —— 测试能钉死它）。 */
  时间文字(现在) {
    const d = (现在 && typeof 现在.getTime === 'function') ? 现在
      : (现在 != null && Number.isFinite(Number(现在)) ? new Date(Number(现在)) : new Date());
    const t = d && typeof d.getTime === 'function' ? d.getTime() : NaN;
    if (!Number.isFinite(t)) return '—';
    const p = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ` +
      `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
  },
  /** 文件名里那一段（不含冒号，Windows 能用）：`20261012-150405`。 */
  文件名时间(现在) {
    const m = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/.exec(this.时间文字(现在));
    return m ? `${m[1]}${m[2]}${m[3]}-${m[4]}${m[5]}${m[6]}` : '00000000-000000';
  },

  /* ==========================================================================
   * ③ 逐步对账（紧凑局面串）+ 最终摘要（规范化投影）
   * --------------------------------------------------------------------------
   * 对账 = 人话串（**不是哈希**）：验收 3 报「第 N 步开始对不上」时，直接把两边这两串贴出来，
   *   一眼看得出差在「希望 / 队伍 / 当前格 / 战斗里的 HP / 方针」哪一项上。
   * 摘要 = 一局结束那一刻 `RUN` 的**规范化投影**：去掉一切随时间变的字段
   *   （`日志[].时间`、`t0`、`已走过集` / `已揭开集` 这两个 Set 缓存），其余**逐字**收进去
   *   （含整本 `RUN.日志` 的文本 —— 它是最强的端到端指纹）。
   * ======================================================================== */
  /** 当前这一瞬间的局面串（没有 RUN → `无局`）。 */
  对账(界面) {
    const R = (typeof 肉鸽 !== 'undefined' && 肉鸽) ? 肉鸽.RUN : null;
    if (!R) return '无局';
    const 们 = (R.队伍 || []).map(m => {
      const 血 = m.hp比 == null ? '' : `@${Math.round(Number(m.hp比) * 100)}`;
      return `${m.键}${m.等级}${血}`;
    }).join(',');
    let 战 = '';
    const ctx = 界面 && 界面.ctx;
    if (界面 && 界面.屏 === '战斗' && ctx) {
      const 血 = 列 => 列.reduce((a, u) => a + Math.max(0, 录像数(u.hp, 0)), 0);
      const 活 = 列 => 列.filter(u => u.hp > 0).length;
      const 方 = (typeof 当前方针 === 'function') ? 当前方针(ctx) : { 类型: '?' };
      战 = ` 战${ctx.turn} 我${活(ctx.allies)}台/${血(ctx.allies)} 敌${活(ctx.enemies)}台/${血(ctx.enemies)}` +
        ` 方针${方.类型}${方.目标位 == null ? '' : `@${方.目标位}`}` +
        ` 结${ctx.result ? ctx.result.结果 : '-'}${this.开关串(界面)}`;
    }
    return `层${R.层} 场${R.场次} Lv${R.等级}/${R.经验} 希望${R.希望} 源碳${R.源碳} 耐久${R.耐久}` +
      ` 推进剂${R.推进剂} 格${R.当前} 队[${们}] 券${(R.券 || []).length}` +
      ` 藏品${(R.藏品 || []).length} 零件${(R.零件 || []).length} 结局${R.结局 || '-'}${战}`;
  },
  /** 单位开关的紧凑串（只收**非默认**的：保留大招 / TRANS-AM 手动 / 本回合开）。 */
  开关串(界面) {
    const 表 = (界面 && 界面.单位开关) || {};
    const 键 = Object.keys(表).filter(k => {
      const v = 表[k] || {};
      return v.保留大招 || v.TRANSAM === '手动' || v.本回合开TRANSAM;
    }).sort((a, b) => Number(a) - Number(b));
    if (!键.length) return '';
    return ` 开关[${键.map(k => {
      const v = 表[k] || {};
      return `${k}:${v.保留大招 ? '留' : ''}${v.TRANSAM === '手动' ? '手' : ''}${v.本回合开TRANSAM ? '开' : ''}`;
    }).join(',')}]`;
  },
  /** **最终摘要**（一局的规范化投影；重放工具重建同一份，两边逐字比对）。 */
  摘要(RUN) {
    const R = (RUN && typeof RUN === 'object') ? RUN : null;
    if (!R) return null;
    return {
      结局: R.结局 == null ? null : 录像文字(R.结局),
      结局原因: R.结局原因 == null ? null : 录像文字(R.结局原因),
      层: 录像数(R.层, null), 场次: 录像数(R.场次, null),
      等级: 录像数(R.等级, null), 经验: 录像数(R.经验, null),
      希望: 录像数(R.希望, null), 源碳: 录像数(R.源碳, null), 耐久: 录像数(R.耐久, null),
      推进剂: 录像数(R.推进剂, null), 当前: 录像数(R.当前, null),
      追击: !!R.追击, 层推进剂修正: 录像数(R.层推进剂修正, null),
      下次晋升减价: !!R.下次晋升减价, 黑市刷新次数: 录像数(R.黑市刷新次数, null),
      队伍: (R.队伍 || []).map(m => [录像文字(m && m.键), 录像数(m && m.等级, null),
        (m && m.hp比 == null) ? null : Math.round(Number(m.hp比) * 1000) / 1000]),
      出击阵: (R.出击阵 || []).map(x => [录像文字(x && x.键), 录像数(x && x.位, null)]),
      券: (R.券 || []).map(c => c ? [录像文字(c.类), 录像文字(c.名), c.档 == null ? null : 录像文字(c.档), 录像文字(c.来源)] : null),
      藏品: (R.藏品 || []).map(录像文字),
      零件: (R.零件 || []).map(p => [录像文字(p && p.k), p && p.uses == null ? null : 录像数(p.uses, null)]),
      已走过: (R.已走过 || []).map(x => 录像数(x, null)).sort((a, b) => a - b),
      已揭开: (R.已揭开 || []).map(x => 录像数(x, null)).sort((a, b) => a - b),
      层出口选择: 稳定量(R.层出口选择), 层出口小径: 稳定量(R.层出口小径),
      事件已选: 稳定量(R.事件已选), 侵蚀源已净化: 稳定量(R.侵蚀源已净化),
      招募站已领券: 稳定量(R.招募站已领券), 黑市货: 稳定量(R.黑市货),
      希望来源: 稳定量(R.希望来源),
      地图: this.地图指纹(R.地图),
      日志: (R.日志 || []).map(x => [录像数(x && x.层, null), 录像文字(x && x.文本)]),
    };
  },
  /** 地图指纹：标量字段（列数 / 行数 / 起点 / 守军 / 最短路…）+ 每一格的 `[格号, 类型, 已过, 关卡]`。 */
  地图指纹(地图) {
    if (!地图 || typeof 地图 !== 'object' || !地图.格) return null;
    const 标量 = {};
    for (const k of Object.keys(地图)) {
      if (k === '格') continue;
      const v = 地图[k];
      const t = typeof v;
      if (t === 'number' || t === 'string' || t === 'boolean') 标量[k] = v;
    }
    const 格 = Object.keys(地图.格).map(Number).filter(Number.isFinite).sort((a, b) => a - b).map(k => {
      const n = 地图.格[k] || {};
      return [k, 录像文字(n.类型), n.已过 ? 1 : 0, n.关卡 == null ? null : 录像文字(n.关卡)];
    });
    return { 标量, 格 };
  },

  /* ==========================================================================
   * ④ 记一步（动作派发的唯一入口调这两个）
   * --------------------------------------------------------------------------
   * `派发前` 干三件事：① 记住这一步的「屏 / 回合 / 理由」；② 分队屏上的 `选分队` 进 `预备`
   *   （那时还没有 RUN，成不了会话）；③ **战斗开打之前**先把「编队（出击名单与站位）」
   *   记成一步 —— 规格要的是「开战那一刻的最终结果」，而摆位是**拖动**出来的（不走动作入口），
   *   不记下来重放就对不上。
   * `派发后` 收尾：新建 / 续用会话 → 追加这一步（+ 派发过程中产生的子步，例如弹窗答案）
   *   → 局面变化对账 → 结束（胜 / 败 / 放弃）就**自动封存**。
   * ======================================================================== */
  派发前(界面, 名, 参) {
    this.本次 = null;
    if (this.关) return false;
    const 动作 = this.拆动作(界面, 名);
    if (this.不记动作.indexOf(动作.名) >= 0) return false;
    const 回合 = (界面 && 界面.屏 === '战斗' && 界面.ctx) ? 录像数(界面.ctx.turn, null) : null;
    this.本次 = {
      名: 动作.名, 参: 动作.参, 屏: 界面 ? 界面.屏 : '', 回合,
      理由: this.读理由(), 子步: [], 子步决策: [],
    };
    /* ★ 决策日志（`8b-决策日志.js`）：**派发前**取一次「当时有哪些选项」（**纯读**）——
       派发之后就变了（例如招募完，刚招到的那位就从候选里消失了），所以必须在这一刻取。
       取到的那一条先挂在这一步上，`派发后()` 再把它写进录像的 `决策`（不是决策动作 → null，一条不记）。 */
    const 有决策录 = (typeof 决策录 !== 'undefined' && 决策录 && typeof 决策录.取 === 'function');
    if (有决策录) this.本次.决策 = 决策录.取(界面, 动作.名, 动作.参, { 屏: this.本次.屏, 回合 });
    /* `弹窗:<值>` 是**真弹窗**那条路（浏览器里点弹窗上的按钮）：答案不经过 `对话框钩子`，
       所以这里顺手把「当时摆出来的选项」抄下来（导出决策时「可选项」要用）。 */
    if (动作.名 === '弹窗' && 界面 && 界面.弹窗) {
      this.本次.弹窗标题 = 录像文字(界面.弹窗.标题);
      const 选 = (界面.弹窗.选项 || []).map(o => 录像文字(o && o.值 != null ? o.值 : o)).filter(Boolean);
      if (选.length) this.本次.可选项 = 选;
    }
    /* ① `选分队` **永远是「下一局的第一步」**（开新局那一刻并进 `操作` / `决策` 的开头）。
       ★ 2026-10-13 修：以前只在「**完全没有 RUN**」时才算预备 —— 上一局的 RUN 还挂着
       （打完没清、或者玩家就是想再开一局）时，这一步会被记进**上一局**的录像、甚至整个丢掉：
       于是「同一个种子连跑两遍、两次导出的决策记录不一样」（`tests/map.js` 第 [23] 段 ⑤ 实测
       **0 条 vs 1 条**）。现在**一律进预备** —— 它天然属于「还没建起来的那一局」；
       对账照旧写 `无局`（重放那一侧也是从零开始重放这一局，两边一致）。 */
    if (动作.名 === '选分队') {
      this.预备.push({
        动作: '选分队', 参数: 录像文字(动作.参), 屏: 界面 ? 界面.屏 : '', 对账: '无局',
      });
      /* 决策也排队（那时那一局还没建起来）：`会话()` 建起它时并进 `决策` 的开头 —— 与 `预备` 同步。 */
      if (有决策录 && this.本次.决策) 决策录.预备.push(this.本次.决策);
      return true;
    }
    /* ② 还没有 RUN：别的动作照旧不记（练习模式 / 调参室那条路） */
    const 有局 = !!(typeof 肉鸽 !== 'undefined' && 肉鸽 && 肉鸽.RUN);
    if (!有局) return true;
    /* ② 开打之前先记「编队」（出击名单与站位 = 开战那一刻的最终结果） */
    if (动作.名 === '开战' || 动作.名 === '打这一场' || 动作.名 === '追击战') {
      const s = this.会话(true);
      if (s) this.追加(s, this.编队步(界面));
    }
    return true;
  },
  派发后(界面, 名, 参) {
    const 本 = this.本次;
    this.本次 = null;
    if (this.关 || !本) return false;
    const R = (typeof 肉鸽 !== 'undefined' && 肉鸽) ? 肉鸽.RUN : null;
    /* ★ 「这一局是不是在**这一步里**结束的」：`通关()` / `失败()` 会把 `肉鸽.进行中` 置 false ——
       那一下（换层通关、耐久耗尽、玩家放弃）必须**照样记下来并封存**，否则最后一局永远封不上。 */
    const 刚结束 = !!(R && R.结局);
    const 活的 = !!(R && 肉鸽.进行中);
    if (!活的 && !刚结束) return false;             // 练习模式 / simulate / 平衡工具 / 调参室：一个字节都不写

    const s = this.会话(活的);                        // 「刚结束」那一步：会话必须已经存在（不新建）
    if (!s) return false;
    /* 主步（参数：`开新局` 记**实际用的种子** —— 界面上点按钮时不传参数，种子是现取的） */
    let 参数 = 录像文字(本.参);
    if (本.名 === '开新局') 参数 = 录像文字(R.种子);
    const 主 = { 动作: 本.名, 参数, 屏: 本.屏, 回合: 本.回合, 理由: 本.理由 || undefined, 对账: this.对账(界面) };
    if (本.弹窗标题) 主.弹窗 = 本.弹窗标题;
    if (本.可选项) 主.可选项 = 本.可选项;
    const 主编 = this.追加(s, 主);
    /* 子步（走 `对话框钩子` 的弹窗答案）紧跟在父步后面：重放时工具靠「下一步是不是 `弹窗`」
       就能把答案按原样喂回 `对话框钩子`（见 `tools/replay.mjs`）。 */
    const 子编们 = 本.子步.map(x => this.追加(s, x));
    /* ★ 决策日志（`8b-决策日志.js`）：**派发后**把「选了什么」记成一条 ——
       主步那一条 + 弹窗子步那几条（弹窗答案不经过动作派发入口，只有这里抓得到）。
       `步` = 对应那一操作步的序号，两份记录靠它对得上；超上限从最早丢（见 `追加决策()`）。 */
    if (typeof 决策录 !== 'undefined' && 决策录 && typeof 决策录.落 === 'function') {
      try { 决策录.落(this, s, 本, 主编, 子编们); } catch (e) { /* 记不上也不能拖垮操作 */ }
    }
    /* 理由用掉就清（下一步默认是空的；「不填完全不影响操作」）——
       连输入框里的字一起清（`设理由('')` 两处都写）。 */
    if (本.理由) { this.设理由(''); this.理由开 = false; }
    /* 一局结束（胜 / 败 / 放弃都算）→ 自动封存 */
    this.封尾();
    return true;
  },
  /** **这一局结束了吗？结束了就封存**（`封尾` = 封上尾巴）。
   *  为什么要单独一个方法：一局可能在**两个地方**结束 ——
   *    ① 动作里（`放弃本局` / 走到出口换层通关 / 招募失败到耐久耗尽…）→ `派发后()` 收尾；
   *    ② **播放引擎 tick 里**（战斗打完 → `到结算()` → `肉鸽.战斗结束()` → 耐久耗尽 / 通关）——
   *       那一下**不经过动作派发入口**，所以 `接线()` 还包了一层 `界面.到结算()`，在这儿收尾。
   *  重复调用无害：`封存()` 第二次看 `进行中` 已经是 null，直接返回。 */
  封尾() {
    if (this.关) return null;
    const R = (typeof 肉鸽 !== 'undefined' && 肉鸽) ? 肉鸽.RUN : null;
    if (!R || !R.结局) return null;
    const 结果 = this.结局到结果(R);
    if (!结果) return null;
    if (!this.读().进行中) return null;
    return this.封存(R, 结果, R.结局原因 || '');
  },
  /** 把 `data-act` 那个字符串拆成 `动作 + 参数`（和 `动作()` 的拆法一致：先整键、再按第一个 `:` 拆）。 */
  拆动作(界面, 名) {
    const n = 录像文字(名);
    if (n.indexOf('弹窗:') === 0) return { 名: '弹窗', 参: n.slice(3) };
    const 表 = (界面 && 界面.动作表) || {};
    if (typeof 表[n] === 'function') return { 名: n, 参: '' };
    const i = n.indexOf(':');
    if (i > 0 && typeof 表[n.slice(0, i)] === 'function') return { 名: n.slice(0, i), 参: n.slice(i + 1) };
    return { 名: n, 参: '' };
  },
  /** 弹窗答案（`接线()` 包了 `界面.对话框`）：**玩家在三选一里选了什么也要进录像**。
   *  · 走 `对话框钩子`（测试 / 探针 / 录像重放）时答案当场就回来了 —— 记成父动作的一个**子步**；
   *  · `对话框()` 在浏览器里返回的是 **Promise**（玩家之后点哪个按钮才 resolve）——
   *    那不是「答案」，**不能当成一步记下来**（真正的答案是稍后那个 `弹窗:<值>` 动作送进来的，
   *    `拆动作` 把它拆成 `动作=弹窗, 参数=X`，这里不重复记）。 */
  记弹窗(标题, 选项, 回) {
    if (this.关 || !this.本次) return null;
    if (回 == null || 回 === '') return null;
    if (回 && typeof 回.then === 'function') return null;      // Promise = 还没选，别把 Promise 记成答案
    const 选项们 = Array.isArray(选项) ? 选项.map(o => 录像文字(o && o.值 != null ? o.值 : o)).filter(Boolean) : [];
    const 步 = {
      动作: '弹窗', 参数: 录像文字(回), 屏: this.本次.屏, 回合: this.本次.回合,
      对账: this.对账((typeof 界面 !== 'undefined') ? 界面 : null),
    };
    if (标题) 步.弹窗 = 录像文字(标题);
    if (选项们.length) 步.可选项 = 选项们;
    this.本次.子步.push(步);
    /* ★ 决策日志：这一下「选了什么」也记一条（选项 = 刚摆出来的那几个按钮）—— 它和 `步` 一一对应。 */
    if (typeof 决策录 !== 'undefined' && 决策录 && typeof 决策录.取弹窗 === 'function') {
      const 条 = 决策录.取弹窗((typeof 界面 !== 'undefined') ? 界面 : null, 标题, 选项们, 回, 步.屏, 步.回合);
      if (条) this.本次.子步决策.push(条);
    }
    return 步;
  },
  /** 编队一步（`开战` 那一刻的出击名单与站位；等级从名册读，写进参数里方便看）。 */
  编队步(界面) {
    const R = 肉鸽.RUN;
    const 名单 = () => {
      if (界面 && 界面.肉鸽编队模式 && 界面.编队 && Array.isArray(界面.编队.出击) && 界面.编队.出击.length) {
        return 界面.编队.出击.map(x => ({ 键: x.键, 位: x.位 }));
      }
      if (R && Array.isArray(R.出击阵) && R.出击阵.length) return R.出击阵.map(x => ({ 键: x.键, 位: x.位 }));
      const 上限 = (typeof 肉鸽.出击上限 === 'function') ? 肉鸽.出击上限() : 3;
      return (R ? (R.队伍 || []).slice(0, 上限) : []).map((m, i) => ({ 键: m.键, 位: i }));
    };
    const 等级 = 键 => {
      const m = R ? (R.队伍 || []).find(x => x.键 === 键) : null;
      return (m && m.等级) || 10;
    };
    const 出击 = 名单().slice().sort((a, b) => a.位 - b.位).map(x => ({ 键: x.键, 位: x.位, 等级: 等级(x.键) }));
    return { 动作: '编队', 参数: JSON.stringify(出击), 屏: 界面 ? 界面.屏 : '', 对账: this.对账(界面) };
  },

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
   * ⑦ 界面（菜单入口 / 录像屏 / 结算屏那一块 / 理由输入框）
   * ======================================================================== */
  去录像() { this.选 = null; this.复制结果 = null; this.下载结果 = null; 界面.开屏('录像'); return this.读().封存.length; },
  回列表() { this.选 = null; this.复制结果 = null; this.下载结果 = null; 界面.开屏('录像'); return true; },
  /** 看某一份：`'进行中'` 或封存的下标（字符串 / 数字都认）。 */
  看录像(参) {
    if (录像文字(参) === '进行中') { this.选 = '进行中'; }
    else {
      const i = 录像数(参, -1);
      if (!(i >= 0 && i < this.读().封存.length)) {
        this.复制结果 = { ok: false, 提示: '这一份不在录像里了（可能被最近 ' + this.局数上限 + ' 局的上限挤掉了）。' };
        界面.刷();
        return false;
      }
      this.选 = String(i);
    }
    this.复制结果 = null; this.下载结果 = null;
    界面.开屏('录像');
    return true;
  },
  /** 这一下要复制 / 下载哪一份（录像屏里选中的那一份；没选就是「进行中」，再没有就是最新封存的那一份）。 */
  当前场() {
    const 表 = this.读();
    if (this.选 === '进行中') return 表.进行中;
    if (this.选 != null && /^\d+$/.test(录像文字(this.选))) {
      const f = 表.封存[Number(this.选)];
      if (f) return f;
    }
    return 表.进行中 || 表.封存[表.封存.length - 1] || null;
  },
  /** 「复制录像」：成功 / 失败各一句可见反馈（失败把整段 JSON 摊在屏上）。 */
  复制当前() {
    const 场 = this.当前场();
    if (!场) {
      this.下载结果 = null;
      this.复制结果 = { ok: false, 提示: '还没有录像：开一局肉鸽（选分队 → 出发）之后就自动开录了。' };
      界面.刷(); return this.复制结果;
    }
    const 文 = this.文本(场);
    const r = this.复制(文);
    this.下载结果 = null;
    this.复制结果 = { ok: r.ok, 方式: r.方式, 字数: r.字数, 提示: r.提示, 文本: r.ok ? '' : 文 };
    界面.刷();
    return this.复制结果;
  },
  /** 「下载 .json」：文件名带种子 / 版本 / 日期 / 结果。 */
  下载当前() {
    const 场 = this.当前场();
    if (!场) {
      this.复制结果 = null;
      this.下载结果 = { ok: false, 提示: '还没有录像：开一局肉鸽（选分队 → 出发）之后就自动开录了。' };
      界面.刷(); return this.下载结果;
    }
    const 文 = this.文本(场);
    const r = this.下载(文, this.文件名(场));
    this.复制结果 = null;
    this.下载结果 = { ok: r.ok, 文件名: r.文件名, 字数: r.字数, 提示: r.提示, 文本: r.ok ? '' : 文 };
    界面.刷();
    return this.下载结果;
  },
  /** 复制 / 下载的可见反馈（失败时把 JSON 摊在屏上）。 */
  导出反馈Html() {
    const 条 = this.复制结果 || this.下载结果;
    if (!条) return '';
    const 名 = this.复制结果 ? '复制录像' : '下载 .json';
    const 摊 = 条.文本 ? `<textarea class="copyout" data-录像-copy-out="1" readonly rows="8">${录像转义(条.文本)}</textarea>` : '';
    return `<p class="resbar ${条.ok ? 'ok' : 'warn'}" data-录像-export-feedback="1"><b>${条.ok ? '成功' : '警告'}</b>` +
      `<span>${名}：${录像转义(条.提示)}</span></p>${摊}`;
  },
  /** 一行摘要（列表 / 结算屏那一块都用它）。 */
  摘要行(场, 第几) {
    if (!场) return '（没有这一份录像）';
    const 步 = (场.操作 || []).length;
    const 字 = this.体积(场);
    const 决 = (场.决策 || []).length;
    return `${第几 ? `第 ${第几} 局 · ` : ''}${场.结果 || '进行中'} · 种子 ${场.种子 == null ? '—' : 场.种子} · ` +
      `${场.分队 || '无'}分队 · ${步} 步 · ${(字 / 1024).toFixed(1)} KB · ${场.结束时间 || 场.开始时间 || '—'}` +
      `${决 ? ` · 决策 ${决} 条` : ''}`;
  },
  /** 录像屏顶上那一块「正在录」的状态（三层反馈的**预告**层）。 */
  状态Html() {
    const 表 = this.读();
    const s = 表.进行中;
    if (!s) {
      return `<p class="small" data-录像-status="1">现在没有在录的局。开一局肉鸽（选分队 → 出发）就自动开录：
        录的是**种子 + 游戏版本 + 按顺序的每一个操作**，不录局面（要局面用 <code>tools/replay.mjs</code> 重放还原）；
        另有一份**决策日志**（<code>决策</code>：当时有哪些选项 + 实际选了哪个，紧凑、程序可读）。</p>`;
    }
    const 决 = (s.决策 || []).length;
    return `<p class="small" data-录像-status="1">正在录：种子 <b>${s.种子 == null ? '—' : s.种子}</b> ·
      游戏版本 <b>${录像转义(s.游戏版本 || '—')}</b> · ${录像转义(s.分队)}分队 · 开始 ${录像转义(s.开始时间)} ·
      已记 <b>${(s.操作 || []).length}</b> 步 · <b>${决}</b> 条决策${s.决策丢 ? `（另有 ${s.决策丢} 条超过上限被丢）` : ''} ·
      约 <b>${(this.体积(s) / 1024).toFixed(1)} KB</b>
      —— 一局结束（胜 / 败 / 放弃）自动封存，保留最近 ${this.局数上限} 局。</p>`;
  },
  /** 录像屏（界面 `屏 = '录像'`）：列表 / 看某一份。 */
  屏Html() {
    const 表 = this.读();
    const 场 = (this.选 != null && this.选 !== '进行中') ? 表.封存[Number(this.选)] : (this.选 === '进行中' ? 表.进行中 : null);
    if (场) return this.详情Html(场);
    const 行 = 表.封存.slice().reverse().map((x) => {
      const 下标 = 表.封存.indexOf(x);
      return `<button class="pick" data-act="看录像:${下标}" data-录像-item="1">
        <b>${录像转义(x.结果 || '进行中')} · 种子 ${x.种子 == null ? '—' : x.种子}</b>
        <small>${录像转义(x.开始时间)} → ${录像转义(x.结束时间 || '—')} · ${录像转义(x.分队)}分队 · 游戏版本 ${录像转义(x.游戏版本 || '—')}</small>
        <small>${(x.操作 || []).length} 步 · ${(this.体积(x) / 1024).toFixed(1)} KB${x.结果原因 ? ` · ${录像转义(x.结果原因)}` : ''}</small>
      </button>`;
    }).join('');
    const 进 = 表.进行中
      ? `<button class="pick" data-act="看录像:进行中" data-录像-item="1" data-录像-live="1">
          <b>进行中 · 种子 ${表.进行中.种子 == null ? '—' : 表.进行中.种子}</b>
          <small>${录像转义(表.进行中.分队)}分队 · 开始 ${录像转义(表.进行中.开始时间)} · 游戏版本 ${录像转义(表.进行中.游戏版本 || '—')}</small>
          <small>已记 ${(表.进行中.操作 || []).length} 步 · ${(this.体积(表.进行中) / 1024).toFixed(1)} KB（读档回来接着记同一份）</small>
        </button>` : '';
    return `<section class="card" data-录像屏="1">
      <h3>对局录像<span class="small">最近 <b>${表.封存.length}</b> / ${this.局数上限} 局（超了从最老的丢）
        —— 录操作、不录局面：<b>种子 + 游戏版本 + 按顺序的每一个操作</b></span></h3>
      ${this.状态Html()}
      ${(进 || 行) ? `<div class="picks" data-录像-list="1">${进}${行}</div>`
        : '<p class="small" data-录像-empty="1">还没有封存的录像。开一局肉鸽走完（胜 / 败 / 放弃都算）就会自动封存一份。</p>'}
      <div class="acts">
        <button data-act="复制录像">复制这一份 JSON</button>
        <button data-act="下载录像">下载 .json</button>
        <button data-act="回菜单">回菜单</button>
      </div>
      ${this.导出反馈Html()}
      <p class="small">存的是**操作流水**（不是局面）：同一个种子 + 同一串操作 = 同一局。
        重放与校验用 <code>node tools/replay.mjs &lt;录像文件&gt;</code>；
        数据集说明见 <code>对局录像/README.md</code>。这个键是<b>独立</b>的：<code>${this.键}</code>
        —— 和肉鸽存档 <code>${typeof 存档键 !== 'undefined' ? 存档键 : '肉鸽存档'}</code>、
        作战记录 <code>${typeof 战斗记录键 !== 'undefined' ? 战斗记录键 : 'mecha-autobattle-战斗记录'}</code> 都无关。</p>
    </section>`;
  },
  /** 看某一份的详情：摘要 + 前 `步数上限` 步 + 复制 / 下载。 */
  详情Html(场) {
    const 操作 = 场.操作 || [];
    const 画 = 操作.slice(0, this.步数上限);
    const 头 = 操作.length > 画.length
      ? `<p class="small">（这一份 ${操作.length} 步，屏上画前 ${画.length} 步；复制 / 下载的是全部 ${操作.length} 步）</p>` : '';
    const 行 = 画.map(x => `<div class="logline" data-录像-step="1"><span class="tag">#${x.序号}</span>` +
      `<span class="idx">${录像转义(x.屏)}${x.回合 == null ? '' : ` · 第 ${x.回合} 回合`}</span>` +
      `<span class="tx">${录像转义(x.动作)}${x.参数 ? `:${录像转义(x.参数)}` : ''}${x.理由 ? `　理由：${录像转义(x.理由)}` : ''}` +
      `${x.对账 ? `<br><small>${录像转义(x.对账)}</small>` : ''}</span></div>`).join('');
    return `<section class="card" data-录像屏="1">
      <h3>对局录像<span class="small">${录像转义(this.摘要行(场, this.选 === '进行中' ? 0 : Number(this.选) + 1))}</span></h3>
      ${this.状态Html()}
      ${头}
      <div class="logbox" data-录像-box="1">${行 || '<p class="small">这一份还没有任何操作。</p>'}</div>
      <div class="acts">
        <button data-act="复制录像">复制为 JSON</button>
        <button data-act="下载录像">下载 .json</button>
        <button class="primary" data-act="回录像">← 回列表</button>
        <button data-act="回菜单">回菜单</button>
      </div>
      ${this.导出反馈Html()}
      ${场.最终摘要 ? `<p class="small" data-录像-final="1">最终摘要：结局 <b>${录像转义(场.最终摘要.结局 || '—')}</b> ·
        第 ${场.最终摘要.层} 层 · ${(场.最终摘要.日志 || []).length} 条日志 ·
        ${(场.最终摘要.地图 && 场.最终摘要.地图.格 ? 场.最终摘要.地图.格.length : 0)} 格地图
        —— 重放完与它**逐字比对**（不一致就报「第 N 步开始对不上」）。</p>` : ''}
    </section>`;
  },
  /** 战斗结算屏上那一块（`80-界面.js` 的 `结算屏()` 调它）—— 三层反馈的**结算**层。 */
  当前块Html() {
    const 表 = this.读();
    const s = 表.进行中;
    const 条 = 录像转义(this.状态Html().replace(/<[^>]+>/g, ''));
    if (!s) {
      return `<div class="vcr-block" data-录像-block="1">
        <h3>对局录像<span class="small">录操作、不录局面</span></h3>
        <p class="small" data-录像-summary="1">这一场没有对局录像（练习模式 / 调参室，或者现在没有进行中的肉鸽局）。</p>
        <div class="acts"><button data-act="去录像">对局录像（最近 ${表.封存.length} 局）</button></div>
        ${this.导出反馈Html()}
      </div>`;
    }
    return `<div class="vcr-block" data-录像-block="1">
      <h3>对局录像<span class="small">正在录这一局（胜 / 败 / 放弃都算，结束自动封存）</span></h3>
      <p class="small" data-录像-summary="1">${条}</p>
      <div class="acts">
        <button data-act="复制录像">复制录像 JSON</button>
        <button data-act="下载录像">下载 .json</button>
        <button data-act="去录像">看录像（最近 ${表.封存.length} 局）</button>
      </div>
      ${this.导出反馈Html()}
    </div>`;
  },

  /* ---------------- 理由输入框（**默认收起、可以不填、不打断作者**） ---------------- */
  读理由() {
    /* 优先读输入框里的字（玩家真的在打）；测试里 `addEventListener` 是空的，所以还有
       `录像.理由` 这个镜像 + `录像.设理由()` 可以写。 */
    try {
      if (typeof document !== 'undefined' && document && typeof document.getElementById === 'function') {
        const el = document.getElementById('录像理由');
        if (el && typeof el.value === 'string' && el.value) return el.value;
      }
    } catch (e) { /* 读不到就用镜像 */ }
    return this.理由 || '';
  },
  设理由(字) {
    this.理由 = 录像文字(字);
    try {
      if (typeof document !== 'undefined' && document && typeof document.getElementById === 'function') {
        const el = document.getElementById('录像理由');
        if (el) el.value = this.理由;
      }
    } catch (e) { /* 不崩 */ }
    return this.理由;
  },
  切理由() { this.理由开 = !this.理由开; 界面.刷(); return this.理由开; },
  /** 这一屏要不要挂理由框（只在 4 个关键选择屏上）。 */
  要理由框() { return 录像理由屏们.indexOf(界面.屏) >= 0 && !!(typeof 肉鸽 !== 'undefined' && 肉鸽 && 肉鸽.RUN); },
  理由框Html() {
    if (!this.要理由框()) return '';
    const 值 = 录像转义(this.理由 || '');
    return `<div class="vcr-reason" data-录像-理由框="1">
      <button class="mini" data-act="录像理由">${this.理由开 ? '收起「为什么选它？」' : '＋ 为什么选它？（可以不填）'}</button>
      ${this.理由开 ? `<input id="录像理由" class="vcr-reason-in" data-录像-理由="1" type="text" value="${值}"
        placeholder="为什么选它？（可以不填；填了会记进这一步的 理由 字段）">` : ''}
      <span class="small">这一步是<b>关键选择</b>：填了就记进录像的那一步（<code>理由</code> 字段），
        不填**完全不影响操作** —— 只是让以后的复盘 / AI 知道「当时为什么这么选」。</span>
    </div>`;
  },
  /** 把理由框追加到这一屏的末尾（`刷()` 之后调；别的屏一个字节都不加）。 */
  刷后() {
    if (!this.要理由框()) return false;
    const 屏 = (typeof $ === 'function') ? $('#screen') : null;
    if (!屏 || typeof 屏.innerHTML !== 'string') return false;
    if (屏.innerHTML.indexOf('data-录像-理由框') >= 0) return false;   // 已经有了（别叠两份）
    屏.innerHTML += this.理由框Html();
    this.接理由输入();
    return true;
  },
  /** 输入框的 `input` 事件 → 镜像（浏览器里唯一需要的那一根线）。 */
  接理由输入() {
    try {
      if (typeof document === 'undefined' || !document || typeof document.getElementById !== 'function') return false;
      const el = document.getElementById('录像理由');
      if (!el || el._接了录像) return false;
      el._接了录像 = true;
      if (typeof el.addEventListener === 'function') {
        el.addEventListener('input', () => { this.理由 = 录像文字(el.value); });
      }
      return true;
    } catch (e) { return false; }
  },

  /* ==========================================================================
   * ⑧ 接线（99-boot.js 调一次；把钩子挂上，**不动 80-界面.js 的刷()**）
   * ======================================================================== */
  接线() {
    if (this.接线过) return false;
    if (typeof 界面 === 'undefined' || !界面) return false;
    this.接线过 = true;
    /* ① 理由输入框：包一层 `刷()`（`刷` 会把 `#screen` 的 innerHTML 整个换掉，
       所以只能在它之后追加；包在我们自己的文件里，不改 80-界面.js 的那一行）。 */
    const 原刷 = 界面.刷;
    if (typeof 原刷 === 'function') {
      界面.刷 = function () {
        const r = 原刷.apply(this, arguments);
        try { 录像.刷后(); } catch (e) { /* 理由框是可选层，绝不拖垮界面 */ }
        return r;
      };
    }
    /* ② 弹窗答案：包一层 `对话框()` —— 「遗迹 / 休整 / 瞭望站 / 隧道 / 侵蚀源」那些三选一
       走的是 `对话框钩子`（测试）或真弹窗（浏览器），答案**不经过动作派发入口**，
       所以只有在这儿才抓得到「玩家选了什么」。 */
    const 原对话框 = 界面.对话框;
    if (typeof 原对话框 === 'function') {
      界面.对话框 = function (标题, 文本, 选项) {
        const 回 = 原对话框.apply(this, arguments);
        try { 录像.记弹窗(标题, 选项, 回); } catch (e) { /* 记不上也不能影响结算 */ }
        return 回;
      };
    }
    /* ③ 一场战斗打完（`到结算()` → `肉鸽.战斗结束()`）：**一局可能就在这儿结束**
       （耐久耗尽 = 败 / 第 4 层通关 = 胜），而那一下**不经过动作派发入口** ——
       所以在这里收尾封存（`封尾()` 自己有幂等判断）。 */
    const 原到结算 = 界面.到结算;
    if (typeof 原到结算 === 'function') {
      界面.到结算 = function () {
        const r = 原到结算.apply(this, arguments);
        try { 录像.封尾(); } catch (e) { /* 封存失败也不能拖垮结算屏 */ }
        return r;
      };
    }
    return true;
  },
};
