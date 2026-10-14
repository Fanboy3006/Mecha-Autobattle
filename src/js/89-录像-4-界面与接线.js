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
        <div class="acts">${this.保存按钮Html(false)}<button data-act="去录像">对局录像（最近 ${表.封存.length} 局）</button></div>
        ${this.保存反馈Html()}
        ${this.导出反馈Html()}
      </div>`;
    }
    return `<div class="vcr-block" data-录像-block="1">
      <h3>对局录像<span class="small">正在录这一局（胜 / 败 / 放弃都算，结束自动封存）</span></h3>
      <p class="small" data-录像-summary="1">${条}</p>
      <div class="acts">
        ${this.保存按钮Html(true)}
        <button data-act="复制录像">复制录像 JSON</button>
        <button data-act="下载录像">下载 .json</button>
        <button data-act="去录像">看录像（最近 ${表.封存.length} 局）</button>
      </div>
      ${this.保存反馈Html()}
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
