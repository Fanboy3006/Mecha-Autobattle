  /* ---------------- 结算 ---------------- */
  结算屏() {
    /* ★ 对局上报（`src/js/8a-上报.js`）：进结算屏时也顺手传一次（与菜单那一处同一个口子）。
       纯追加：`上报地址` 为空（默认）时 `顺便传()` 第一句就返回 —— 一次 fetch 都不发。 */
    if (typeof 上报 !== 'undefined' && 上报) 上报.顺便传();
    const b = this.战报;
    if (!b) return '<section class="card"><p>这场还没打完。</p></section>';
    const 胜 = b.结果 === '胜';
    const 活 = b.我方.filter(u => u.hp > 0).length, 敌活 = b.敌方.filter(u => u.hp > 0).length;
    /* ★ 三层反馈的**结算**（作者 2026-10-12 拍板的第 2 件，§2.2 的「结算」列 + §2.4）：
       战斗结束屏上那一块「本场战报」——数据**全部**从这一场的记录里统计（`战报行们(this.战报)`），
       不另开一套账。`this.战报` 有 `记录 / 我方 / 敌方`，`84-反馈.js` 两种形状都认。 */
    const 战报行 = 战报行们(b);
    return `<section class="card end ${胜 ? 'win' : 'lose'}">
      <div class="eyebrow">${胜 ? '战斗胜利' : '战斗失败'}</div>
      <h2>${b.结果} · ${b.原因}</h2>
      <ul>
        <li>回合数：<b>${b.回合数}</b></li>
        <li>我方存活：<b>${活} / ${b.我方.length}</b>　敌方存活：<b>${敌活} / ${b.敌方.length}</b></li>
        <li>战斗记录：<b>${b.记录.length}</b> 条</li>
        <li>种子：<b>${b.种子}</b>（同种子同编队同方针重放，结果完全一样）</li>
      </ul>
      ${本场战报Html(战报行, `第 ${b.回合数} 回合 · ${b.结果} · 共 ${b.记录.length} 条记录`)}
      ${this.本场记录Html()}
      ${typeof 录像 !== 'undefined' ? 录像.当前块Html() : ''}
      <div class="acts" data-center="1">
        <button class="primary" data-act="再来一场">再来一场（换种子）</button>
        <button data-act="再来一场:${b.种子}">重放这一场（同种子）</button>
        <button data-act="去编队">改编队</button>
        ${this.ctx && this.ctx.调参 ? '<button data-act="去调参室">回 调参室</button>' : ''}
        <button data-act="回菜单">回菜单</button>
      </div>
    </section>`;
  },
  来一场(同种子) {
    const s = 同种子 ? Number(同种子) : null;
    this.开战(s);
    return this.ctx;
  },

  /* ---------------- ★ 作战记录（作者 2026-10-12：保存 / 查看 / 复制 / 下载） ----------------
   * 作者原话：「**现在这个作战记录你看看能不能安排保存一下**」——他要的是「能把某一场战斗的
   * 完整记录发出来」（当时在查「攻击已经死掉的敌方」那个 bug）。
   * 数据 / 上限 / 坏数据兜底全在 `src/js/88-战斗记录.js`（独立键，与肉鸽存档无关），这里只做：
   *   ① 一场打完存一份；② 画出来（结算屏那一块 + 菜单里「战斗记录（最近 N 场）」那一屏）；
   *   ③ 复制为文本 / 下载 .txt（两条路都有可见的失败兜底）。
   * 三层反馈（`CLAUDE.md` 第 7 节第 10 条）：**保存** → 结果条 / 结算屏一句
   * （`记录保存提示()`）；**查看** → 屏上看得见（`.battle-log` 那一块 / 记录屏）；**导出** →
   * 成功与失败各有一句可见反馈（失败还把整段文本摊在屏上 = 「全选文本」兜底）。 */
  /** ★ 开一场之前把「复现这一场所需要的东西」留一份（`88-战斗记录.js` 的 `做一场()` 读它）。
   *  只放**规格**（我方 / 敌方 / 条目 / 波次 / 层 / 节点类型 / 来源），不放打完之后那些大对象。 */
  准备记录(规) {
    const o = 规 || {};
    this.本场规格 = {
      我方: o.我方 || null, 敌方: o.敌方 || null, 条目: o.条目 || null,
      波次: o.波次 || null, 来源: o.来源 || '练习',
      层: o.层 != null ? o.层 : (o.条目 ? o.条目.层 : null),
      节点类型: o.节点类型 != null ? o.节点类型 : (o.条目 ? o.条目.类型 : null),
    };
    this.本场记录 = null;
    this.记录保存 = null;
    this.记录已存的ctx = null;
    this.记录选 = null;
    this.复制结果 = null;
    this.下载结果 = null;
    this.方针历史 = {};
    return this.本场规格;
  },
  /** 存刚刚打完的这一场（`到结算()` 里调一次）。返回 `战斗记录.存()` 的结果。 */
  存本场记录() {
    const b = this.战报;
    if (!b || !Array.isArray(b.记录)) return null;
    const 规 = this.本场规格 || {};
    /* 条目：优先用开打时留的那一份；练习模式兜底读编队屏当前选的那条编成；
       调参室那一场（`95-调参室.js` 直接建 `ctx`、不走 `开战()`）没有规格 → 用 `ctx.调参` 认出来。 */
    let 条目 = 规.条目 || null;
    if (!条目 && typeof 编成表 !== 'undefined' && this.编队 && 编成表[this.编队.编成序号]) 条目 = 编成表[this.编队.编成序号];
    let 层 = 规.层 != null ? 规.层 : (条目 ? 条目.层 : null);
    let 节点类型 = 规.节点类型 != null ? 规.节点类型 : (条目 ? 条目.类型 : null);
    let 来源 = 规.来源 || '练习';
    if (this.ctx && this.ctx.调参) {
      来源 = '调参室';
      try {
        if (typeof 调参室模型 !== 'undefined' && 调参室模型 && 调参室模型.设置) {
          const s = 调参室模型.设置;
          if (层 == null && s.层 != null) 层 = s.层;
          if (!节点类型 && s.类型) 节点类型 = s.类型;
        }
      } catch (e) { /* 认不出来就算了（不崩） */ }
    }
    const 场 = 战斗记录.做一场({
      战报: b, 我方: 规.我方, 敌方: 规.敌方, 条目,
      层, 节点类型, 来源, 波次: 规.波次,
      方针表: this.方针历史, 单位开关: this.单位开关,
      调参: this.ctx ? this.ctx.调参 : null,
    });
    this.本场记录 = 场;
    const r = 战斗记录.存(场);
    this.记录保存 = r;
    return r;
  },
  /** 保存反馈那一句（三层反馈的「保存」层；例「本场记录已保存（最近 5 场：第 3 场）」）。 */
  记录保存提示() {
    const r = this.记录保存;
    if (!r) return '';
    if (r.提示) return r.提示;
    return r.ok ? `本场记录已保存（最近 ${战斗记录.场数上限} 场：第 ${r.第几场} 场）`
      : `本场记录没存下：${r.why || '写不进去'}`;
  },
  /** 这一下要复制 / 下载哪一场：记录屏里选中的那一场，否则就是刚打完的这一场。 */
  当前记录场() {
    if (this.屏 === '战斗记录' && this.记录选 != null) {
      const 表 = 战斗记录.读();
      const 场 = 表[Number(this.记录选)];
      if (场) return 场;
    }
    return this.本场记录;
  },
  /** 菜单入口：进「作战记录」屏（列表；没有记录时写一句人话，不崩）。 */
  去战斗记录() {
    this.记录选 = null; this.复制结果 = null; this.下载结果 = null;
    this.开屏('战斗记录');
    return 战斗记录.读().length;
  },
  /** 列表里点一场 → 看它的逐条记录（**最新的一场 = 第 N 场**，下标是 `战斗记录.读()` 的下标）。 */
  看战斗记录(参) {
    const i = Number(参);
    const 表 = 战斗记录.读();
    if (!(i >= 0 && i < 表.length)) {
      this.复制结果 = { ok: false, 提示: '这一场不在记录里了（可能被最近 5 场的上限挤掉了）。' };
      this.刷();
      return false;
    }
    this.记录选 = i; this.复制结果 = null; this.下载结果 = null;
    this.开屏('战斗记录');
    return true;
  },
  回战斗记录列表() { this.记录选 = null; this.复制结果 = null; this.下载结果 = null; this.开屏('战斗记录'); return true; },
  /** 「复制为文本」：优先剪贴板；不行就退化成「全选文本」（整段摊在屏上）+ 一句可见提示。 */
  复制本场记录() {
    const 场 = this.当前记录场();
    if (!场) {
      this.复制结果 = { ok: false, 提示: '还没有可以复制的记录：先打完一场（或者从菜单进「战斗记录」挑一场）。' };
      this.刷(); return this.复制结果;
    }
    const 文 = 战斗记录.场文本(场);
    const r = 战斗记录.复制(文);
    this.下载结果 = null;
    this.复制结果 = { ok: r.ok, 方式: r.方式, 字数: r.字数, 提示: r.提示, 文本: r.ok ? '' : 文 };
    this.刷();
    return this.复制结果;
  },
  /** 「下载 .txt」：`Blob` + `a[download]`（文件名带种子与时间）；建不出来就给可见提示 + 摊文本兜底。 */
  下载本场记录() {
    const 场 = this.当前记录场();
    if (!场) {
      this.下载结果 = { ok: false, 提示: '还没有可以下载的记录：先打完一场（或者从菜单进「战斗记录」挑一场）。' };
      this.刷(); return this.下载结果;
    }
    const 文 = 战斗记录.场文本(场);
    const r = 战斗记录.下载(文, 战斗记录.文件名(场));
    this.复制结果 = null;
    this.下载结果 = { ok: r.ok, 文件名: r.文件名, 字数: r.字数, 提示: r.提示, 文本: r.ok ? '' : 文 };
    this.刷();
    return this.下载结果;
  },
  /** 逐条记录（**一行一条，原文照抄**）—— 结算屏与记录屏共用。屏上最多画 `战斗记录.屏条数上限` 条。 */
  记录行Html(场) {
    const 记录 = (场 && Array.isArray(场.记录)) ? 场.记录 : [];
    if (!记录.length) return '<p class="small" data-record-empty="1">这一场没有逐条记录。</p>';
    const 画 = 记录.slice(-战斗记录.屏条数上限);
    const 头 = 记录.length > 画.length
      ? `<p class="small">（这一场 ${记录.length} 条，屏上画最新的 ${画.length} 条；复制 / 下载的是全部 ${记录.length} 条）</p>` : '';
    const 行 = 画.map((x, i) => {
      const 序 = 记录.length - 画.length + i + 1;
      const 回 = x && x.回合 != null ? x.回合 : '?';
      const 文 = x && x.文本 != null ? String(x.文本) : '（这条记录没有文本）';
      return `<div class="logline" data-record-line="1"><span class="tag">第 ${回} 回合</span>` +
        `<span class="idx">#${序}</span><span class="tx">${文}</span></div>`;
    }).join('');
    return `${头}<div class="logbox" data-record-box="1">${行}</div>`;
  },
  /** 复制 / 下载的可见反馈（三层反馈的「导出」层）。
   *  失败时**把整段文本摊在屏上**（`data-copy-out`）= 任务书要的「全选文本」退化。 */
  导出反馈Html() {
    const 条 = this.复制结果 || this.下载结果;
    if (!条) return '';
    const 名 = this.复制结果 ? '复制为文本' : '下载 .txt';
    const 摊 = 条.文本 ? `<textarea class="copyout" data-copy-out="1" readonly rows="8">${条.文本}</textarea>` : '';
    return `<p class="resbar ${条.ok ? 'ok' : 'warn'}" data-export-feedback="1"><b>${条.ok ? '成功' : '警告'}</b>` +
      `<span>${名}：${条.提示}</span></p>${摊}`;
  },
  /** 一场记录的「摘要一行 + 逐条记录 + 两个按钮 + 导出反馈」—— 结算屏与记录屏共用这一块。 */
  记录块Html(场, 副标题) {
    if (!场) return '';
    return `<h3>${副标题 || '本场记录'}<span class="small">逐条记录（原文照抄，共 <b>${(场.记录 || []).length}</b> 条）</span></h3>
      <p class="small" data-log-summary="1">${战斗记录.摘要行(场)}</p>
      ${this.记录行Html(场)}
      <div class="acts" data-center="1">
        <button data-act="复制记录">复制为文本</button>
        <button data-act="下载记录">下载 .txt</button>
      </div>
      ${this.导出反馈Html()}`;
  },
  /** 战斗结算屏上那一块「本场记录」（`data-battle-log`）：一行摘要 + 可滚动的逐条记录 + 两个导出按钮。 */
  本场记录Html() {
    const 场 = this.本场记录;
    if (!场) return '';
    const 存 = this.记录保存;
    const 提 = this.记录保存提示();
    const 条 = 提 ? `<p class="resbar ${存 && 存.ok ? 'ok' : 'warn'}" data-log-saved="1">` +
      `<b>${存 && 存.ok ? '成功' : '警告'}</b><span>${提}</span></p>` : '';
    return `<div class="battle-log" data-battle-log="1">
      ${条}
      ${this.记录块Html(场, '本场记录')}
    </div>`;
  },
  /** 菜单入口那一屏：列表（时间 / 结果 / 回合数 / 种子）→ 点进去看逐条记录。 */
  战斗记录屏() {
    const 表 = 战斗记录.读();
    const 场 = this.记录选 != null ? 表[Number(this.记录选)] : null;
    if (场) {
      return `<section class="card">
        <h3>作战记录<span class="small">第 ${Number(this.记录选) + 1} / ${表.length} 场（最老 = 第 1 场；最新 = 第 ${表.length} 场）</span></h3>
        ${this.记录块Html(场, '这一场')}
        <div class="acts" data-center="1">
          <button class="primary" data-act="回战斗记录">← 回列表</button>
          <button data-act="回菜单">回菜单</button>
        </div>
        <p class="small">存的是**完整逐条记录原文**（一行一条，一个字都没改写）+ 种子 / 编成 / 方针 / 单位开关 ——
          同种子同一串方针重放，结果完全一样。</p>
      </section>`;
    }
    const 卡 = 表.slice().reverse().map((x, i) => {
      const 序 = 表.length - i;          // 最新的一场 = 第 N 场
      const 下标 = 序 - 1;               // `战斗记录.读()` 里的下标（最老 = 0）
      return `<button class="pick" data-act="看战斗记录:${下标}" data-record-item="1">
        <b>第 ${序} 场 · ${x.结果 || '—'}</b>
        <small>${x.时间 || '—'} · ${x.回合数 == null ? '—' : x.回合数} 回合 · 种子 ${x.种子 == null ? '—' : x.种子}</small>
        <small>${x.编成ID || '（没记编成）'} · ${(x.记录 || []).length} 条记录</small>
      </button>`;
    }).join('');
    const 刚打的 = this.本场记录;
    return `<section class="card">
      <h3>作战记录<span class="small">最近 <b>${表.length}</b> 场（最多留 ${战斗记录.场数上限} 场 /
        ${Math.round(战斗记录.容量上限 / 1024)} KB，超了从最老的丢）</span></h3>
      ${表.length
        ? `<div class="picks" data-center="1" data-record-list="1">${卡}</div>`
        : '<p class="small" data-record-empty="1">还没有作战记录。打完一场战斗就会自动存一份（<b>胜 / 败都存</b>）：完整逐条记录 + 种子 / 编成 / 方针 / 单位开关 —— 够复现这一场。</p>'}
      <div class="acts" data-center="1">
        ${刚打的 ? '<button data-act="复制记录">复制刚打完那一场</button><button data-act="下载记录">下载刚打完那一场 .txt</button>' : ''}
        <button data-act="回菜单">回菜单</button>
      </div>
      ${this.导出反馈Html()}
      <p class="small">这个键是<b>独立</b>的：<code>${战斗记录.键}</code> —— 和肉鸽存档
        <code>${typeof 存档键 !== 'undefined' ? 存档键 : '肉鸽存档'}</code> 无关：不改 <code>RUN</code>、
        不动存档版本号；坏数据 / 空数据 / 读到垃圾一律当成「没有记录」，不崩。</p>
    </section>`;
  },

