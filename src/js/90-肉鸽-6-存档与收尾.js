  /* ---------------- ★ HP 继承（作者 2026-10-11：「同一次出击的队伍带着伤打下一场」） ----------------
   * 口径与参数在 `71-改动.js` 的 `战斗结构.HP继承`；这里只做四件事：
   *   ① **记比例**：名册每一条一个 `hp比`（0–1，`null` / 缺省 = 满血）；
   *   ② 战斗结束把 `战报` 里每台的 `hp / maxHp` 写回名册（`记战斗HP`）；
   *   ③ **战后回血**（★ 作者 2026-10-12 试玩后拍板）：每场战斗结束后给**名册上每一台**
   *      回 `战后回血比例`（初稿 0.5）—— **0 HP 的也回到 50%**（`战后回血`）；
   *   ④ 休整节点给全名册回血（`休整回血`，初稿也是 50%）。
   * ★ **顺序（硬要求）**：先 `记战斗HP(战报)` 写回本场结果 → 再 `战后回血()`。
   *   反过来的话，回的血会被本场的战报盖掉。
   * ★ **只有这一条链路**：没有 `RUN` 的战斗（菜单固定战斗 / `simulate()` / `tools/balance.mjs` /
   *   调参室 / 录像重放 / 各测试）根本不经过这里 → 仍然是满血（`tests/run.js` 第 [6] 段盯着）。
   * ★ 记**比例**而不是绝对 HP：藏品 / 势力会改 `maxHp`（`93-藏品.js:530-534`），
   *   记比例才能让「伤」在两次战斗之间保持同一个百分比。 */
  /** 名册里这一台现在的 HP 比例（0–1；`null` = 满血 = 老口径）。
   *  坏值（NaN / 越界 / 不是数字）一律当满血，不崩。 */
  名册HP比(键) {
    const R = this.RUN;
    if (!R || !HP继承开()) return null;
    const m = (R.队伍 || []).find(x => x.键 === 键);
    if (!m || m.hp比 == null) return null;
    const v = Number(m.hp比);
    return Number.isFinite(v) ? Math.max(0, Math.min(1, v)) : null;
  },
  /** 名册里每一台现在记着的 HP 比例（0–1；`null` = 满血 = 老口径）。
   *  返回 `[{键, 前, 是满血}]`，顺序 = 名册顺序；坏值（NaN / 越界 / 不是数字）一律当满血，不崩。 */
  名册比例们() {
    const R = this.RUN;
    if (!R || !HP继承开()) return [];
    return (R.队伍 || []).map(m => {
      if (m.hp比 == null) return { 键: m.键, 前: 1, 是满血: true };
      const v = Number(m.hp比);
      const 前 = Number.isFinite(v) ? Math.max(0, Math.min(1, v)) : 1;
      return { 键: m.键, 前, 是满血: 前 >= 1 };
    });
  },
  /** ★ **战后回血**（作者 2026-10-12 试玩后拍板，暂时值）——**每场战斗结束后**都给
   *  **名册上每一台** 做 `hp比 = min(1, hp比 + 战斗结构.HP继承.战后回血比例)`（初稿 50%）。
   *  ★ **0 HP 也必须回到 50%**（这次修复的核心）：写的是「每一台都加」，
   *    **不是**「扣了血的才回」—— 上一场被击坠（`hp比 = 0`）、这一场引擎静默跳过没出战的那几台，
   *    同样要回到 0.5，否则下一场还是「账面上 N 台、实际只有 1 台在打」，败北之后更是死亡螺旋。
   *  ★ 带伤推进仍然有效：回 50% **不等于**满血（封顶 1，`0.2 + 0.5 = 0.7`）。
   *  ★ 没有 `RUN` / 关掉开关 → 返回 `null`，**一个字节都不改**（无 RUN 路径硬要求）。
   *  返回 `{台数, 回复比例, 名字们, 有变化, 文本, 前}`（`前` = 回血前的比例快照，测试与界面用）。 */
  战后回血() {
    const R = this.RUN;
    if (!R || !HP继承开()) return null;
    const c = HP继承参数();
    const 比例 = Number.isFinite(Number(c.战后回血比例)) ? Number(c.战后回血比例) : 0.5;
    const 前 = this.名册比例们();
    const 名字们 = [], 变化 = [];
    for (let i = 0; i < (R.队伍 || []).length; i++) {
      const m = R.队伍[i];
      const 旧 = 前[i] ? 前[i].前 : 1;
      m.hp比 = Math.min(1, 旧 + 比例);
      if (m.hp比 > 旧) { 名字们.push(`${m.键} ${Math.round(旧 * 100)}% → ${Math.round(m.hp比 * 100)}%`); 变化.push(m.键); }
    }
    const 文本 = `战后休整：全队回复 ${Math.round(比例 * 100)}% 最大 HP` +
      (名字们.length ? `（${名字们.join('、')}）` : '（全队已满）');
    /* ★ 三层反馈的**结算**那一层：结果条 / 战斗结束屏 / 大地图都读这一句，
       `RUN.日志` 也记同一句 —— 一处算、几处看，不各写一套。 */
    this.记(文本);
    return { 台数: 名字们.length, 回复比例: 比例, 名字们, 变化, 有变化: 变化.length > 0, 文本, 前 };
  },
  /** 三层反馈的**结算**那一层要画的那几行（`80-界面.js` 的 `到结算()` 调一次）：
   *  「战后休整」那一句 → 写进 `肉鸽界面.战后休整行`（战斗结束屏 / 大地图 / 本局结算屏的战报都读它）
   *  + `RUN.日志`（引擎日志已经由 `战后回血()` 记过一句，这里只补 `〔战报〕` 那一份）。
   *  **没有 RUN（练习模式 / 调参室 / `simulate()`）→ 返回 null、一个字节都不加**（无 RUN 路径硬要求）。 */
  记战后回血行(结) {
    const R = this.RUN;
    if (!R || !结 || !结.文本) return null;
    if (typeof 肉鸽界面 !== 'undefined' && 肉鸽界面) 肉鸽界面.战后休整行 = [结.文本];
    return [结.文本];
  },
  /** 名册里现在有几台是**倒下的**（`hp比 <= 0`）。
   *  ★ 直接教训（作者 2026-10-12）：「名册里 0 HP 的单位**不会被移出队伍、也不会自动回一点** →
   *    下一场引擎**静默跳过**它们（不写任何记录）」→ 玩家账面上 4 台、实际只有 1 台在打。
   *    所以大地图上要**显眼写一句**「X 台已倒下（本场不会出战）」。没有 RUN → 0。 */
  倒下单位数() {
    const R = this.RUN;
    if (!R || !HP继承开()) return 0;
    return this.名册比例们().filter(x => x.前 <= 0).length;
  },
  /** 战斗结束：把 `战报`（`{我方: 参战的单位[]}`）里每台的 `hp / maxHp` 写回名册。
   *  返回写回去的台数。**修理**在战斗里加的血就在这个 `hp` 里 → 修理真的能带回大地图。 */
  记战斗HP(战报) {
    const R = this.RUN;
    if (!R || !HP继承开() || !战报 || !战报.我方) return 0;
    let n = 0;
    for (const u of 战报.我方) {
      const m = (R.队伍 || []).find(x => x.键 === u.key);
      if (!m) continue;
      const 满 = u.maxHp > 0 ? u.maxHp : 1;
      m.hp比 = Math.max(0, Math.min(1, Math.max(0, u.hp) / 满));
      n++;
    }
    return n;
  },
  /** 休整节点：给**名册上每一台**回 `战斗结构.HP继承.休整回血比例`（初稿 50%，作者 2026-10-12「全部回 50%」）。
   *  ★ 口径（初稿·待作者调）：**在名册里就算**（没出击的也一起休息），回血按「比例」加，
   *    所以满血的不会被回超过 100%。返回 `{台数, 回复比例, 名字们}`。 */
  休整回血() {
    const R = this.RUN;
    if (!R || !HP继承开()) return null;
    const c = HP继承参数();
    const 比例 = Number.isFinite(Number(c.休整回血比例)) ? Number(c.休整回血比例) : 0.5;
    const 名字们 = [];
    for (const m of (R.队伍 || [])) {
      const 前 = m.hp比 == null ? 1 : Math.max(0, Math.min(1, Number(m.hp比)));
      if (前 >= 1) continue;
      m.hp比 = Math.min(1, 前 + 比例);
      名字们.push(`${m.键} ${Math.round(前 * 100)}% → ${Math.round(m.hp比 * 100)}%`);
    }
    this.记(`休整：全队回血 ${Math.round(比例 * 100)}% 最大 HP${名字们.length ? `（${名字们.join('、')}）` : '（全队本来就是满血）'}`);
    return { 台数: 名字们.length, 回复比例: 比例, 名字们 };
  },
  /** 大地图 / 编队屏那一行「队伍状态」：`N/M 台满血 · 最惨的一台剩 X%`（满血时返回 null）。 */
  队伍HP行() {
    const R = this.RUN;
    if (!R || !HP继承开()) return null;
    const 队 = R.队伍 || [];
    if (!队.length) return null;
    const 比 = this.名册比例们().map(x => x.前);
    const 满 = 比.filter(x => x >= 0.999).length;
    if (满 === 队.length) return null;
    const 最惨 = Math.min(...比);
    return `带伤 ${队.length - 满}/${队.length} 台 · 最惨的一台剩 ${Math.round(最惨 * 100)}%（每场战斗后回 50%，休整 / 修理还能再回）`;
  },

  /* ---------------- 日志 ----------------
   * ★ 2026-10-11「记录显示」那一版：`RUN.日志` 从此**有上限**（作者要「记录也要显示」，
   *   但整本日志跟着存档一起进 localStorage 会让存档无限长大）。
   *   口径（写清楚，进任务板）：**内存里只留最近 `日志上限` 条**，超了就从**最老的**那一头截掉
   *   （`splice(0, 多出来的)`）—— 存档存的就是这个数组，所以**存档大小天然被封住**，
   *   不需要在 `存档()` 里再截一次。`日志上限 = 300`：比一局真实条数（几十条）宽得多，
   *   正常玩一局一条都不会丢；界面「记录屏」只画最近 `记录屏条数上限 = 200` 条（更早的仍在 `RUN.日志` 里）。 */
  日志上限: 肉鸽日志上限,
  /** ★ 2026-10-13「日志瘦身」（任务书 §(b)）：**战斗结算的行先在内存里攒着**，
   *  `收合并()` 时用 ` · ` 连成一行再写进日志 —— 一场战斗从 6 行结算变成 1 行。
   *  `合并中` 为 `null`（默认）时 `记()` 的行为**一个字节都没变**。 */
  合并中: null,
  /** 开一次合并（`战斗结束()` 用；嵌套调用时后者赢 —— 现在没有嵌套）。 */
  开合并() { this.合并中 = []; return this.合并中; },
  /** 收口：把攒着的行合并成**一行**写进日志（没攒到东西 → 返回 `null`、日志不动）。
   *  连字符 ` · ` 与「结果条」上那句的写法一致（同一件事在两处看起来一样）。
   *  ★ 合并出来的这一行会挂 `战报可并` 标记 —— 紧跟其后的 `〔战报〕…` 行会**并进这一行**
   *    （见 `记()`），所以「一场战斗」在日志里就是**一条结算 + 最多一条战报**（合并后是同一行）。 */
  收合并() {
    const 行 = this.合并中;
    this.合并中 = null;
    if (!行 || !行.length) return null;
    const 条 = this.记(行.map(x => String(x)).join(' · '));
    if (条) 条.战报可并 = true;
    return 条;
  },
  记(文字, 层) {
    if (!this.RUN) return null;
    /* ★ 合并中：先攒着（`收合并()` 合成一行；`战斗结束()` 的 `finally` 保证一定收口）。 */
    if (Array.isArray(this.合并中)) { this.合并中.push(String(文字 == null ? '' : 文字)); return null; }
    if (!Array.isArray(this.RUN.日志)) this.RUN.日志 = [];      // 坏存档兜底（不是数组也不会崩）
    const 文本 = String(文字 == null ? '' : 文字);
    const 尾 = this.RUN.日志[this.RUN.日志.length - 1];
    /* ★ 2026-10-13「日志瘦身」（任务书 §(b)：一场战斗 ≤2 行 = 一条结算 + 最多一条战报行）：
       **`〔战报〕` 并进紧挨着的战斗结算那一行**（`收合并()` 立的 `战报可并` 标记）——
       战报的每一行（全军突击 / 大招 / 站位 / 敌人卡 / 战后休整）都还在，只是同一条里用 ` · ` 连着，
       不再各占一行（作者那份日志里 300 条有 40% 是这种重复）。
       ★ 「结果条 + 本场记录已保存」原来会写两行 —— 那一次重复在**界面线 2026-10-13 的提交
       （`ea4418a` / `f14b468`，`80-界面.js:967` 那段注释）里已经合掉**（现在只调一次 `设结果()`），
       所以本线不用再管；本线这边只剩「引擎结算 + 战报」这一处重复。 */
    if (尾 && 尾.战报可并 && /^〔战报〕/.test(文本)) { 尾.文本 = `${尾.文本} · ${文本}`; return 尾; }
    const 条 = { 层: 层 == null ? this.RUN.层 : 层, 文本: String(文字 == null ? '' : 文字), 时间: Date.now() };
    this.RUN.日志.push(条);
    const 多 = this.RUN.日志.length - this.日志上限;
    if (多 > 0) this.RUN.日志.splice(0, 多);                     // 最老的先走（最新在最后，记录屏倒着画）
    return 条;
  },

  /* ---------------- 存档（关掉页面能继续） ---------------- */
  /* 版本 v3（阵型 9 格）：结构变了，所以**换键**。读到旧版本的存档一律**丢弃并提示**，
     不崩、也不把旧阵型硬读成新阵型（`位 3` 的语义从「后1」变成了「前4」）。 */
  存档() {
    if (!this.RUN) return false;
    try {
      /* ★ 2026-10-13（任务书 §1 模块 2 · ③）：自然物（血蕈 / 浪花）的**动态估价** `p.value`
         就在 `RUN.零件` 的每一个元素上，所以 `JSON.stringify(存)` **天然把它一起存了** ——
         这里不需要（也不应该）另做一层序列化：元素的形状仍然是 `{ k, uses, value }`，
         `R.零件.map(p => p.k + ':' + p.uses)` 那条断言照旧成立（改的只是 `value` 的数字）。 */
      const 存 = { RUN: this.RUN, 进行中: this.进行中 };
      if (typeof localStorage !== 'undefined' && localStorage.setItem) localStorage.setItem(存档键, JSON.stringify(存));
      return true;
    } catch (e) { return false; }
  },
  /** 旧版本（v1 / v2）的存档还在不在：界面用它决定要不要提示「旧存档已作废」。 */
  有旧存档() {
    try {
      if (typeof localStorage === 'undefined' || !localStorage.getItem) return false;
      return 旧存档键们.some(k => !!localStorage.getItem(k));
    } catch (e) { return false; }
  },
  /** 把旧版本的存档清掉（读档时顺手丢，避免菜单上一直提示）。 */
  清旧存档() {
    let n = 0;
    try {
      if (typeof localStorage !== 'undefined' && localStorage.removeItem) {
        for (const k of 旧存档键们) if (localStorage.getItem(k)) { localStorage.removeItem(k); n++; }
      }
    } catch (e) { /* 读不到 localStorage 就算了 */ }
    return n;
  },
  读存档() {
    try {
      if (typeof localStorage === 'undefined' || !localStorage.getItem) return null;
      const s = localStorage.getItem(存档键);
      if (!s) { this.清旧存档(); return null; }              // 只有旧版本的存档 → 丢掉，别读错阵型
      const 存 = JSON.parse(s);
      if (!存 || !存.RUN || !存.RUN.地图 || !存.RUN.地图.格) return null;
      /* 版本不对（未来版本 / 旧版本混进来）：丢弃并记一句提示，不让它把界面弄崩 */
      if (存.RUN.版本 != null && 存.RUN.版本 !== 存档版本) { this.清存档(); return null; }
      this.RUN = 存.RUN;
      this.进行中 = !!存.进行中;
      /* 旧存档（v3 键里、加 `等级` / `经验` 之前存的那一版）**缺这两个字段** ——
         安全补默认值（战棋 `27-开局.js:33` 的 `lvl:1, exp:0`），不崩、也不把上限算成 NaN。 */
      const 旧等级 = Number(this.RUN.等级);
      if (!Number.isFinite(旧等级) || 旧等级 < 1) this.RUN.等级 = 1;
      const 旧经验 = Number(this.RUN.经验);
      if (!Number.isFinite(旧经验) || 旧经验 < 0) this.RUN.经验 = 0;
      /* Set 不能进 JSON：读回来补上（界面用） */
      this.RUN.已走过集 = new Set(this.RUN.已走过 || []);
      this.RUN.已揭开集 = new Set(this.RUN.已揭开 || []);
      /* ★ HP 继承（2026-10-11）：旧存档（加 `hp比` 之前存的那一版）**没有这个字段** →
         安全补成「满血」；坏值（NaN / 越界）也一并夹回来，不崩、也不会把 HP 算成 NaN。 */
      for (const m of (this.RUN.队伍 || [])) {
        if (m.hp比 == null) { m.hp比 = null; continue; }
        const v = Number(m.hp比);
        m.hp比 = Number.isFinite(v) ? Math.max(0, Math.min(1, v)) : null;
      }
      /* ★ 2026-10-13 带队核心：**不新增存档字段** —— 「名册第一台」这个事实本身就在
         `RUN.队伍[0]` 里（口径见 `带队核心吗()` 上面那一段）。
         所以这里**只补一条日志**（结算层要看得见、读档后行为与不读档一致），
         **不把已经 Lv10 的老存档追认成 Lv20**（作者那一局的名册就是 3 台 Lv10 ——
         旧存档读回来该什么样还是什么样，只是从这一刻起「下标 0」照样是带队核心）。
         坏数据（`队伍` 不是数组）由下面那段 HP 继承的循环兜着，这里不碰。 */
      if (Array.isArray(this.RUN.队伍) && this.RUN.队伍.length) {
        const 核 = this.RUN.队伍[0];
        const 等级 = Number(核 && 核.等级);
        if (核 && typeof 核 === 'object') {
          this.记(`读档：名册第一台 ${核.键} 是这一局的【${带队核心标记}】（Lv${Number.isFinite(等级) ? 等级 : 肉鸽数值.招募等级}）`
            + `${Number.isFinite(等级) && 等级 === 带队核心等级 ? '' : ` —— 这一局是在带队核心设定之前开的，不追认成 Lv${带队核心等级}`}`);
        }
      }
      /* ★ 招募券（2026-10-11 作者拍板）：旧存档**没有 `券` 这个字段** ——
         按【初稿】补 **3 张（含 1 张本分队券）**（任务书 §7 最后一行 / §6 第 3 条），
         而不是补 0 张（理由：老存档进游戏手上还有默认五人队，补 3 张券才不会「一队都没有」）。
         写坏的值（不是数组 / 元素是字符串 / `{名:'不存在'}` / `券: 7`）**一律归一**（`归一券们()`），
         坏条目丢掉、不崩；`类` 不认识按名字归一、`档` 不在 S/A/B → `null`（见 `归一券()`）。
         ★ **版本号不升**（还是 v3 / 同一个键）：只加字段 + 补默认值，照加 `等级` / `经验` 那次。 */
      {
        const 原券 = this.RUN.券;
        const 归一过 = 归一券们(原券);
        if (!Array.isArray(原券)) {
          this.RUN.券 = [];
          发开局券(this.RUN);                 // 缺字段 / 不是数组 → 按开局口径补 3 张（第 1 张 = 本分队券）
          for (const c of this.RUN.券) c.来源 = '旧存档补发';
          if (this.RUN.券.length) this.记(`旧存档没有「券」字段：按开局口径补发 ${this.RUN.券.length} 张（${券汇总文字(this.RUN)}）`);
        } else if (归一过.length !== 原券.length) {
          this.RUN.券 = 归一过;
          this.记(`旧存档里有认不出来的券：丢掉坏条目，留下 ${归一过.length} 张（${券汇总文字(this.RUN)}）`);
        } else {
          this.RUN.券 = 归一过;
        }
      }
      /* ★ 召回站给券（2026-10-11）：旧存档没有 `招募站已领券` → 补空数组（坏值也补空）。 */
      if (!Array.isArray(this.RUN.招募站已领券)) this.RUN.招募站已领券 = [];
      else this.RUN.招募站已领券 = this.RUN.招募站已领券.filter(x => typeof x === 'string');
      /* ★ 2026-10-13（任务书 §1 模块 2 · ③）：手上零件的**动态估价**读回来时归一 ——
         `存档()` 存的是整个 `RUN`，所以 `value` 本来就在 JSON 里；这里只做三件事：
           ① 坏数据兜底（`零件` 不是数组 → 空数组；元素认不出 `k` → 丢掉）；
           ② `uses` 归一（缺 / 坏 → 表里的 `次数`；`null` 的照旧 `null`）；
           ③ **自然物**的 `value` 缺 / 坏 → 回退表里的 `估价`（血蕈 3 / 浪花 4），
              加工品 / 概念体的 `value` 归 `null`（它们的参考价走表里的 `价`）。
         ⚠ 元素形状**一个字都没变**（还是 `{ k, uses, value }`），
           所以 `tests/rank-3` 的 `R.零件.map(p => p.k + ':' + p.uses)` 断言照旧成立。 */
      if (!Array.isArray(this.RUN.零件)) this.RUN.零件 = [];
      else this.RUN.零件 = this.RUN.零件
        .filter(p => p && typeof p === 'object' && 零件表[p.k])
        .map(p => {
          const P = 零件表[p.k];
          const 数 = Number(p.uses);
          const 估 = Number(p.value);
          const 默认次数 = P.次数 != null ? P.次数 : null;
          return {
            k: p.k,
            uses: p.uses == null ? 默认次数 : (Number.isFinite(数) ? Math.max(0, Math.floor(数)) : 默认次数),
            value: P.类 === '自然物'
              ? (Number.isFinite(估) && 估 > 0 ? Math.floor(估) : (Number(P.估价) || null))
              : (Number.isFinite(估) && 估 > 0 ? Math.floor(估) : null),
          };
        });
      重算推进剂加成();                     // 坏 / 缺的祭祈被丢掉时，推进剂上限要跟着回退
      /* ★ 节点改造（2026-10-11）新增的**五个**字段：旧存档**一个都没有** —— 全部补默认值，不崩。
         坏值也一并夹回来（照上面 `hp比` / `等级` 的同一套做法）：
           · `黑市刷新次数`：非负整数（缺 / 坏 → 0）；
           · `层出口选择`：层号 → '尽头' | '小径'（缺 / 坏 → 空对象；没选过就按「尽头」算，见 下一层()）；
           · `层出口小径`：层号数组（缺 / 坏 → 空数组；里面只留能认出是数字的项）；
           · `事件已选` / `侵蚀源已净化`：对象（缺 / 坏 → 空对象）。 */
      this.RUN.黑市刷新次数 = 黑市刷新次数(this.RUN);
      if (!(this.RUN.层出口选择 && typeof this.RUN.层出口选择 === 'object') || Array.isArray(this.RUN.层出口选择)) this.RUN.层出口选择 = {};
      if (!Array.isArray(this.RUN.层出口小径)) this.RUN.层出口小径 = [];
      else this.RUN.层出口小径 = this.RUN.层出口小径.filter(x => Number.isFinite(Number(x))).map(Number);
      if (!(this.RUN.事件已选 && typeof this.RUN.事件已选 === 'object') || Array.isArray(this.RUN.事件已选)) this.RUN.事件已选 = {};
      if (!(this.RUN.侵蚀源已净化 && typeof this.RUN.侵蚀源已净化 === 'object') || Array.isArray(this.RUN.侵蚀源已净化)) this.RUN.侵蚀源已净化 = {};
      /* ★ 2026-10-13 新增（修 bug「出口守军打输了却还是通关了」）：`待换层` = 「守军没清、
         但出口那一步已经走成了」的那一趟（打赢守军时当场补换层，见 `换层()`）。
         旧存档没有这个字段 → 补 `null`（= 没有欠账）；坏值（不是对象 / 缺层号）也一律清成 `null`，不崩。 */
      {
        const 欠 = this.RUN.待换层;
        this.RUN.待换层 = (欠 && typeof 欠 === 'object' && !Array.isArray(欠) && Number.isFinite(Number(欠.层)))
          ? { 层: Number(欠.层), 追击: !!欠.追击 } : null;
      }
      return this.RUN;
    } catch (e) { return null; }
  },
  有存档() { return !!this.读存档(); },
  清存档() {
    try { if (typeof localStorage !== 'undefined' && localStorage.removeItem) localStorage.removeItem(存档键); } catch (e) {}
  },
};

/** 这一格走过了吗（战棋 moveTargets 会滤掉走过的格；新项目里「已过」还要看 node.cleared）。
 *  ★ 2026-10-13（任务书 §1 模块 1）：**未走过的 `类型 === '空'` 格现在是合法落脚点** ——
 *    对齐黑流树海【林间空地】（走进去休整片刻、不遭遇敌情）。
 *    旧 → 新 → 为什么：
 *      · 旧：`if (n.已过 || n.类型 === '空') return false;` —— 所有「空」格（含**还没走到过的**）
 *        一起被滤掉，所以地图上大片空地是死的（玩家只能走「有事件的那几格」）；
 *      · 新：`if (n.已过) return false;` —— 起点在生成时就已标 `已过: true`（`91-地图.js` 的
 *        `已过: k === 起点`），所以起点仍然点不动；**结算完的空节点**由 `已过` 挡住；
 *        只有 `!n.已过 && !RUN.已走过.includes(k)` 的空格才会被放进 `肉鸽.能去的()`。
 *      · 为什么：作者要「空地能落脚」；`已过` 本来就是「这一格的事做完了」的**唯一**判据
 *        （`清空格()` / 节点结算都写它），拿 `类型` 再判一次是把「空地」和「做完的事」混为一谈。
 *    ⚠ 边界（**一个字没改**）：`91-地图.js` 的 `移动距离` 仍然是普通徒步 BFS 跨格能力，
 *      每走 1 格照常扣 1 推进剂；出口类型照旧可以再点（层没换掉的话）。 */
function 格没走过(RUN, k) {
  if (k === RUN.当前) return false;
  const n = RUN.地图.格[k];
  if (!n) return false;
  if (n.已过) return false;                         // 结算完的节点（含起点）不再作为目标
  if (是出口类型(n.类型)) return true;              // 出口（尽头 / 小径）永远可以再点（层没换掉的话）
  return !RUN.已走过.includes(k);
}

/* ---------------------------------------------------------------------------
 * 名册属性重算（晋升之后要**真的**变强）
 * ---------------------------------------------------------------------------
 * 为什么要重算：名册（`RUN.队伍`）里只存 `{键, 等级}`（照战棋 `27-开局.js:41,87` 的 `{mech, lv}`），
 * 属性是每次开战时由 `makeUnit(键, 'ally', 位, 等级)` **现算**的（`40-单位.js:43-57` → `levelUp`）。
 * 所以晋升完只要改了 `等级`，下一次开战就自动是新数值 —— 这个函数额外现算一份**给界面和测试看**，
 * 保证「名册上写的数字」和「战斗里真的会用的数字」是同一个来源（不是这里自己算的公式）。
 * ------------------------------------------------------------------------- */

/** 重算名册里某一台的属性（`键` 省略 = 全名册）。返回 `{键, 等级, 前, 后}`；
 *  `前` 用 `键@Lv10` 那一档当基准（战棋的招募等级），`后` = 这名队员现在的真实数值。 */
function 重算名册属性(键) {
  const R = 肉鸽 && 肉鸽.RUN;
  if (!R || !R.队伍) return null;
  const 台 = 键 ? R.队伍.filter(m => m.键 === 键) : R.队伍;
  const 取 = u => ({
    lv: u.lv, maxHp: u.maxHp, armor: u.armor, defense: u.defense, eva: u.eva, aim: u.aim,
    melee: u.melee, shoot: u.shoot, awaken: u.awaken, mov: u.mov, 速度: speedOf(u),
  });
  const 们 = 台.map(m => {
    const u = makeUnit(m.键, 'ally', 0, m.等级);
    return { 键: m.键, 等级: m.等级, 前: 取(makeUnit(m.键, 'ally', 0, 肉鸽数值.招募等级)), 后: 取(u) };
  });
  return 键 ? (们[0] || null) : 们;
}

