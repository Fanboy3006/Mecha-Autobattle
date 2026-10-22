  /* ---------------- 招募（拖动） ----------------
   * ★ 2026-10-11 招募券（作者拍板「券系统必须要做了才有试玩的意义」）：
   *   · 屏顶一段「手上的招募券（N）」按钮组 —— 点一张**选中**（再点一下取消），
   *     选中后候选池按 `券合(券, 键)` 过滤（照战棋 `27-开局.js:75` 的
   *     `recruitPool().filter(m => ticketOk(cls, m) && !已有)`），价格照旧写希望价
   *     （**券不是免费票**：持券招的也是精锐 5 / 骨干 3 / 普通 0 希望，照 `22-输入.js:431`）；
   *   · **「先留着」= 什么都不点**；**「丢弃这张券」**= 每张券旁边一个小按钮（照 `27:82` 的两个按钮）。
   * ★★ 2026-10-12 修**真 bug**（作者试玩：「一开场我招募了一大堆人，但是应该只有 3 个招募券才对」）：
   *   **不选券 = 不能招**（改前「没选券 / 没券 → 候选池是全部、价格照希望价」那条老口径作废）——
   *   所以这一屏现在是：
   *     · **没有券** → 候选按钮**全部 `disabled`** + 屏上写明「没有可用的券（招募要用掉一张同类券：去战斗 / 招募站拿）」；
   *     · **有券但没选中** → 候选按钮也全部 `disabled`，理由写「先在『手上的招募券』里点『选这张券』」；
   *     · **选中一张券** → 候选池只剩这张券对得上的机师，按钮可点（希望不够的照旧 `disabled` 并写清差多少）；
   *     · 每个候选的 `title` / `.cost` 与屏上的 `<p data-tickets="1">` 都写出**为什么**（三层反馈：屏上说明可见）；
   *     · **手上还有几张券**在 `h3` 与顶栏 `rv-chip` 两处都看得到（0 张时标红并说明去哪拿）。 */
  招募屏() {
    const R = 肉鸽.RUN;
    if (!R) return '';
    const 已有 = new Set(R.队伍.map(m => m.键));
    const 券们 = R.券 || [];
    const 选中 = (this.选中的券 != null && 券们[this.选中的券]) ? this.选中的券 : null;
    if (选中 == null) this.选中的券 = null;
    const 用中 = 选中 != null ? 券们[选中] : null;
    const 没券 = 券们.length === 0;
    /* 「为什么不能招」的两句（和 `90-肉鸽.js` 的 `招募()` 拒绝理由同义；屏上 / title / 结果条三层都出现） */
    const 没券理由 = '没有可用的券（招募要用掉一张同类券：每场战斗后 +1 张、招募站每层 +1 张）';
    const 没选理由 = '先在「手上的招募券」里点「选这张券」—— 招募必须用掉一张同类券';
    /* 候选池：选了券 → 只留这张券对得上的（且不在队里）；**没选券 → 照旧列全部，但每一张都 disabled**
       （列出来是为了让玩家看得见「这些人以后拿券能招」，不是让人现在点）。 */
    const 候选 = ALLY_T.filter(t => !已有.has(t.mech) && (!用中 || 券合(用中, t.mech)));
    /** 这一张候选现在能不能招；不能就返回理由（优先级：先券、再希望 —— 和 `招募()` 的判据顺序一致）。 */
    const 不能招的理由 = 费 => {
      if (!用中) return 没券 ? 没券理由 : 没选理由;
      if (R.希望 < 费) return `希望不够（要 ${费}，只有 ${R.希望}）`;
      return '';
    };
    /* ★ 2026-10-13 带队核心（**预告**那一层）：名册**还是 0 台**时，这一屏招到的第一台就是带队核心
       （`带队核心吗` 的判据 = 名册从 0 台变成 1 台的那一次招募），所以：候选按钮按 Lv20 预览、
       `title` / `.cost` / 屏上说明三处都写明「带队核心：这一台直接 Lv20（分队特权）」。
       ★ 三层反馈的另外两层：**即时** = 结果条 + `RUN.日志`（`招募()` 里那一行，`80-界面.js` 原样透出）；
       **结算** = 「当前队伍」那一行与大地图队伍卡片上的 `带队核心标记`。 */
    const 空名册 = !有带队核心(R.队伍);
    const 卡 = 候选.map(t => {
      const p = 界面.预览(t.mech, 招募等级(R.层));
      /* 名册还是 0 台时**再算一份 Lv20**：候选按钮默认按「正常招募等级」预览（第 1 层 Lv10），
         底下一行写清「第一台是 Lv20」的数值 —— 不然玩家会以为整队都是 Lv20。 */
      const p核 = 空名册 ? 界面.预览(t.mech, 带队核心等级) : null;
      const 费 = 肉鸽数值.招募费[tierOf(t.mech)] || 0;
      const 理由 = 不能招的理由(费);
      /* `disabled` + `title` = 鼠标悬停也看得到理由；`data-drag` 照旧保留（能招时才生效）
         ★ 2026-10-13 任务书 §1 模块 5：候选卡上再挂一个**独立的**「ⓘ 详情」入口
           （`data-act="看机体:<键>"` → `机体详情Html`，5 屏入口之一）。
         ⚠ 为什么用 `<span role="button">` 放在卡片按钮**之外**、外面套一层 `.pick-wrap`：
           ① HTML 规范里 `<button>` 不能嵌 `<button>`（会把 `querySelectorAll('button')` 的计数与结构搞坏）；
           ② 这一屏的候选卡在「还没选券」时**整张 `disabled`** —— 而 disabled 的按钮**不会把点击
              派发给子元素**，详情入口塞在里面就恰好「最需要看的时候点不动」。
         `.pick-wrap{display:flex;flex-direction:column}`（`main.css`）让这层壳**只负责把两颗按钮摞在一起**：
         它是 `.picks` 网格的**同一个格子**（不加壳的话「卡片 + 详情」会被当成两个格子、详情按钮飘到别的列），
         壳自己不画背景 / 边框，卡片本体一个字节都没改。 */
      return `<span class="pick-wrap"><button class="pick" data-act="招募:${t.mech}" data-drag="候选:${t.mech}" style="--fc:${势力色(t.mech)}"${理由 ? ` disabled title="${理由}"` : ` title="用掉一张 ${券名(用中)}${费 > 0 ? `，花 ${费} 希望` : '（普通档，0 希望）'}${空名册 ? `｜${带队核心预告}` : ''}"`}>
        <span class="pk-top">${图标.卡(t.mech, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${t.pilot}</b><small>${t.mech} · ${t.tags.战斗分类} · ${t.tags.势力}</small></span></span>
        <span class="nums">速 ${p.速度} · HP ${p.hp}${p核 ? `　·　Lv${带队核心等级}：HP ${p核.hp}` : ''}</span><span class="cost">${空名册 ? `<b data-lead-core-hint="1">${带队核心预告}</b><br>` : ''}招募 ${费} 希望${用中 ? `（用掉 ${券名(用中)}）` : '（要先选一张券）'}</span>
        ${特色摘要(t).文本 ? `<div class="特色摘要" data-特色摘要="1">${特色摘要(t).文本}</div>` : ''}</button><span class="mech-info-btn" role="button" tabindex="0" data-act="看机体:${t.mech}" title="查看 ${t.pilot} 的机体特性与武器详情">ⓘ 详情</span></span>`;
    }).join('');
    /* ★ 2026-10-13 带队核心（结算那一层）：名册第一台挂 `带队核心标记`。 */
    const 队 = R.队伍.map((m, i) => `<div class="rv-row"><span class="pk-top">${图标.卡(m.键, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${allyName(m.键)}</b><small>${m.键} · Lv${m.等级}${带队核心吗(R.队伍, i) ? ` · <b data-lead-core="1">${带队核心标记}</b>` : ''}</small></span></span></div>`).join('');
    /* 手上的券：每张一个「选中 / 取消」按钮 + 一个「丢弃」按钮（照战棋 27:78-82 的两个动作） */
    const 券卡 = 券们.map((c, i) => {
      const 选中态 = (选中 === i);
      return `<div class="rv-row"><span class="rv-tier">券</span>
        <span class="nm"><b>${券名(c)}</b><small>${券类(c)}${c.来源 ? ` · 来源：${c.来源}` : ''}${c.档 ? ` · 档 ${c.档}` : ''}</small>
          <br><small style="margin-left:0">${券用途说明(R, c)}</small></span>
        <button class="rv-btn${选中态 ? ' primary' : ''}" data-act="用券:${i}">${选中态 ? '取消选中' : '选这张券'}</button>
        <button class="rv-btn" data-act="丢券:${i}">丢弃这张券</button></div>`;
    }).join('') || `<p class="small" style="color:var(--enemy)" data-no-ticket="1">现在手上没有招募券 —— <b>${没券理由}</b>
      （照战棋 <code>31:284,298</code> 每场战斗后 1 张 / <code>30:63-67</code> 招募站 1 张；券也可以留着去晋升）。</p>`;
    return `<section class="card">
      <h3>招募<span class="small">队伍 ${R.队伍.length} / ${肉鸽数值.队伍上限}（满了就不能再招）· 希望 ${R.希望} ·
        <span class="rv-chip${没券 ? ' warn' : ''}" data-tickets="1">招募券 <b>${券们.length}</b>${没券
          ? '<small>（一张都没有 —— 招募 / 晋升都要用券）</small>'
          : `<small>${券汇总文字(R)}</small>`}</span></span></h3>
      ${(typeof 战术卡牌开 === 'function' && 战术卡牌开() && Array.isArray(R.待选战术牌) && R.待选战术牌.length)
        ? `<div class="rv-card tactical-pick-box" data-tactical-pick="1"><h3>🎴 战术卡牌构筑（3 选 1 加入队伍牌库）<span class="small">已收集 ${(R.战术牌库 || []).length} 张 · 选 1 张带入后续全部战斗</span></h3><div class="th-cards">${R.待选战术牌.map(cid => {
            const c = (战术卡牌表 || []).find(x => x && x.id === cid);
            if (!c) return '';
            const 耗 = Number(c.耗气) || 0, 回 = Number(c.回气) || 0;
            const 气标 = 回 > 0 ? (耗 > 0 ? `-${耗}/+${回}气` : `+${回}气`) : `耗${耗}气`;
            const 气类 = 回 > 0 && 耗 === 0 ? ' is-gain' : ' is-cost';
            const 层类 = c.层级 === '职业' ? 'tier-class' : (c.层级 === '势力' ? 'tier-faction' : 'tier-char');
            const 入牌文 = c.入牌 === '初始' ? '⚡ 开战初始入牌' : `🔒 条件触发：${c.触发说明}`;
            return `<button class="tactical-card ${层类} ready" data-act="选战术牌:${c.id}" data-card-id="${c.id}"><span class="tc-top"><span class="tc-tag">【${c.精神标签 || c.层级}】</span><span class="tc-sub">${c.层级}·${c.归属}</span><span class="tc-cost${气类}">${气标}</span></span><b class="tc-name">${c.名}</b><span class="tc-entry">${入牌文}</span><span class="tc-desc">${c.效果说明}</span><span class="tc-foot"><span class="tc-uses">限 ${c.限次 || 1} 次/场</span><span class="tc-state">点击选入牌库 →</span></span></button>`;
          }).join('')}</div></div>` : ''}
      <div class="rv-card"><h3>手上的招募券（${券们.length}）<span class="small">点「选这张券」→ 下面的候选池只留这张券对得上的人；**「先留着」就是什么都不点**（券随时还能用来晋升）</span></h3>
        ${券卡}</div>
      <p class="small" data-tickets="1">${用中
        ? `正在用 <b>${券名(用中)}</b> 招人：候选池只剩 ${候选.length} 名对得上的机师。
           招募**照样花希望**（精锐 5 / 骨干 3 / 普通 0，照战棋 <code>22-输入.js:431</code>），
           招完这张券会被用掉（<code>27-开局.js:84</code>）。`
        : `<b style="color:var(--enemy)" data-no-ticket-why="1">${没券 ? 没券理由 : 没选理由}</b>
           —— **没券就不能招**（2026-10-12 修的：改前不传券时普通档 0 希望可以无限招人）。
           这张券也可以留着去**晋升**：给队里同职业 / 同势力的机师升一档（希望 + 1 张同类券）。`}</p>
      <div class="编队屏">
        <div class="col 候选" data-drop="候选">
          <h3>可招募的机师（${候选.length} 名）<span class="small">${空名册 ? `<b>${带队核心预告}</b>`
            : (用中 ? `点一下或者拖过来就招募（Lv${招募等级(R.层)}，用掉一张 ${券名(用中)}）`
              : '现在一张都点不了：先在上面选一张券')}</span></h3>
          <p class="small">${空名册 ? `<b data-lead-core-hint="1">${带队核心预告}</b>
            —— 作者 2026-10-13 定的「**特色分队的带队核心**」：名册还是空的，
            **本局第一次成功招募**（用哪张券都算：开局券 / 事件给的券 / 战后券 / 招募站券）的那一台
            **直接按 Lv${带队核心等级} 入队**；**不花希望、不吃教范、不影响晋升价格 / 出击上限**，
            第 2 台起照旧 Lv${招募等级(R.层)}（第 2 / 3 层照旧 Lv${招募等级(2)} / Lv${招募等级(3)}）。
            候选按钮上那一行写的就是这台按 Lv${带队核心等级} 的数值（候选默认仍按 Lv${招募等级(R.层)} 预览）。`
            : (用中 ? `点一下或者拖过来就招募（Lv${招募等级(R.层)}，用掉一张 ${券名(用中)}）`
              : '现在一张都点不了：先在上面选一张券')}</p>
          <div class="picks" data-center="1">${卡}</div>
        </div>
        <div class="col 站位">
          <h3>当前队伍（${R.队伍.length} / ${肉鸽数值.队伍上限}）</h3>
          ${队 || '<p class="small">还没有人。</p>'}
          <div class="acts" data-center="1"><button data-act="去晋升">去晋升（用券升级）</button>
            <button data-act="回大地图">先留着券，回大地图</button>
            <!-- ★ 2026-10-13：这一屏原来**只能**用券招人或拿希望换人，玩家站在招募站格上
                 除了招人没有第二条出口（招募站的「节点完成()」原本只在「用券招成」那一下才走）。
                 这颗按钮就是大地图格菜单上那颗「不招，继续前进」的同一件事：标记这一格已过 + 回大地图。
                 （格菜单里那颗按钮的 data-act 原来写成「跳过」—— 动作表里没有这个键，点了没反应，
                  一并改成「跳过节点」，见 90-肉鸽.js 的 格菜单()。） -->
            <button data-act="跳过节点" data-leave-station="1">不招，继续前进</button></div>
        </div>
      </div>
      ${this.结果条Html()}
      <!-- ★ 2026-10-13 任务书 §1 模块 4 / 5：招募屏上点「ⓘ 详情」也要弹得出正文 —— 弹窗控件原来只在
           大地图 / 记录 / 晋升三屏画（界面.弹窗控件Html()），这里补一份，全屏通用才算数。 -->
      ${界面.弹窗控件Html()}
    </section>`;
  },

  /* ---------------- 事件 ----------------
   * ★ 2026-10-11 作者拍板第 5 条：事件换成**有代价**的 —— 前 5 个**逐字搬回战棋原版**
   *   （`mecha-tactics/Claude hand off/src/js/30-移动与节点.js:123-129`），后 3 个照抄黑流树海。
   *   这一屏只负责把 `事件表` 画成按钮：点一下走 `data-act="奇遇:<选项文字>"` → `90-肉鸽.js` 的 `奇遇()`。 */
  奇遇屏() {
    const R = 肉鸽.RUN;
    const 型 = R ? (R.地图.格[R.当前] || {}).类型 : null;
    if (!R || 型 !== '事件') {
      return `<section class="card"><h3>奇遇</h3>
        <p>路上遇到一支友军残骸。你要：</p>
        <div class="acts" data-center="1">
          <button class="primary" data-act="奇遇:收下 3 希望">收拢士气（希望 +3）</button>
          <button class="primary" data-act="奇遇:收下 10 源碳结晶">回收结晶（源碳 +10）</button>
          <button data-act="回大地图">离开</button>
        </div>
        <p class="small">（这一屏现在是**兜底**：正常情况下「事件」节点会直接弹出下面那张事件卡。）</p></section>`;
    }
    const 事 = 肉鸽.当前事件();
    const 已选 = (R.事件已选 || {})[`${R.层}:${R.当前}`];
    /* ★ 2026-10-12 作者点名改「迷路的机师」时加的：选项可以声明「现在做不了」
       （`90-肉鸽.js` 的 `事件选项做不了()`，例如源碳不够 4 就点不了这张随机券）——
       按钮照旧画出来（玩家看得见这条路），但 **`disabled` + `title` 写着为什么**，
       屏上再单独列一行**可见的理由**（照现有事件屏 / 黑市 / 招募屏那套写法：
       `disabled` + 说明，理由由引擎那一份原样给，两层永远同一句话）。 */
    const 选 = 事 ? 事.选.map((o, i) => {
      const 拦 = 事件选项做不了(o, R);
      return `<button class="${i === 0 ? 'primary' : ''}" data-act="奇遇:${o.文}"${拦 ? ` disabled title="${拦}"` : ''}>${o.文}</button>`;
    }).join('') : '';
    const 拦们 = 事 ? 事.选.map(o => ({ 文: o.文, why: 事件选项做不了(o, R) })).filter(x => x.why) : [];
    return `<section class="card">
      <h3>事件${事 ? `：${事.名}` : ''}<span class="small">照抄战棋原版事件（30-移动与节点.js:123-129）/ 黑流树海（方案书 §1.6.2）</span></h3>
      ${事 ? `<p>${事.文}</p><p class="small">出处：<code>${事.出处}</code></p>` : '<p class="small">这一格没有事件。</p>'}
      <div class="acts" data-center="1">${选}<button data-act="回大地图">先不选，回大地图</button></div>
      ${拦们.length ? `<p class="small" data-事件拦="1"><b style="color:var(--enemy)">做不了的选项（按钮已变灰）</b>：${
        拦们.map(x => `「${x.文}」—— ${x.why}`).join('；')}</p>` : ''}
      <p class="small">★ 每一个选项都有代价（或者放弃一部分收益）：推进剂 / 作战耐久 / 源碳 / 经验 里换一样。
        ${已选 ? `<br>这一格已经选过：<b>${已选}</b>` : ''}</p>
      ${this.结果条Html()}
    </section>`;
  },

  /* ---------------- 本局结算（通关 / 失败） ----------------
   *  ★ 2026-10-11：顶上多一条「**最近一条结果**」——通关那一下玩家在结算屏上也看得到
   *    「走出了混沌迷宫 / 作战耐久耗尽」那句话；再往上还在本局里打了一场时，**把那一场的奖励清单
   *     也贴出来**（`战斗奖励清单Html(战斗结算)`，只在有数据时画，不改任何奖励逻辑）。 */
  肉鸽结算屏() {
    const R = 肉鸽.RUN;
    if (!R) return '<section class="card"><p>本局已结束。</p></section>';
    const 通关 = R.结局 === '通关';
    return `<section class="card end ${通关 ? 'win' : 'lose'}">
      <div class="eyebrow">${通关 ? '通关' : '本局结束'}</div>
      <h2>${通关 ? '走出混沌迷宫！' : (R.结局原因 || '作战失败')}</h2>
      ${this.结果条Html()}
      ${战斗奖励清单Html(this.战斗结算)}
      ${有战报() ? 本场战报Html(this.战斗战报, '最后一场战斗的本场战报（本局结束前可以随时在大地图上翻「记录」）') : ''}
      <ul>
        <li>走到第 <b>${R.层}</b> 层${通关 ? '（终点）' : ''}　本层第 <b>${R.场次}</b> 场</li>
        <li>部队：<b>Lv${R.等级}</b>（经验 ${R.经验}）　出击上限：<b>${肉鸽.出击上限()}</b> 台（等级那条 ${出击上限(R.等级)} ＋ 藏品 ${藏品部署位加成(R)}，绝对封顶 ${绝对顶}）</li>
        <li>希望：<b>${R.希望}</b>　源碳结晶：<b>${R.源碳}</b>　作战耐久：<b>${R.耐久}</b></li>
        <li>队伍：<b>${R.队伍.length}</b> 台　藏品：<b>${(R.藏品 || []).length}</b> 件</li>
        ${有带队核心(R.队伍) ? `<li>名册（${R.队伍.length} 台）：${R.队伍.map((m, i) => `${allyName(m.键)} Lv${m.等级}${带队核心吗(R.队伍, i) ? ` <b data-lead-core="1">${带队核心标记}</b>` : ''}`).join('、')}</li>` : ''}
        <li>推进剂：<b>${R.推进剂}</b> / ${推进剂上限(R)}　种子：<b>${R.种子}</b></li>
        <li>记录：<b>${(R.日志 || []).length}</b> 条（本局结束前可以随时在大地图上点「记录」翻）</li>
      </ul>
      <div class="acts" data-center="1"><button class="primary" data-act="回菜单">回菜单</button><button data-act="去分队">再来一局</button>
        <button data-act="去记录">看这局的记录</button>
        <button data-act="记录清结果">清掉上面那条结果</button>
        <!-- ★ 2026-10-13 录像线：本局结算屏（三种收场都走这一屏：走出迷宫 / 作战失败 / 玩家放弃）
             上也要有一键保存 —— 作者打完一局第一眼就在这里，点一次文件就落进下载文件夹。
             同一份「保存按钮Html()」（大地图 / 战斗结算屏用的是同一颗，字面写法一致）。
             ⚠ 这段注释**会进 #screen 的 innerHTML**，所以措辞要避开 tests/map.js:957 /
               tests/run.js:497 那两条「失败结算屏里不许出现某个字样」的既有断言。 -->
        ${录像.保存按钮Html(true)}
      </div>
      ${录像.保存反馈Html()}
    </section>`;
  },
};

/* 小队成员的显示名（肉鸽界面用） */
function allyName(键) { const t = tplOf(键); return t ? t.pilot : 键; }

/** 现在有没有「上一场战斗的本场战报」可画（★ 2026-10-12 三层反馈的结算那一层）。
 *  **没有 / 空数组 → 那一块整块不画**（新开的局、没打过仗的大地图上不该挂一块空战报）；
 *  `本场战报Html()` 自己也能承受 null（它会写一句「没有可结算的数据」），两处各管一层。 */
function 有战报() { return !!(肉鸽界面 && Array.isArray(肉鸽界面.战斗战报) && 肉鸽界面.战斗战报.length); }

/** 只读的「手上的券」一行（大地图 / 晋升屏那些**不用选券**的地方用它）。
 *  返回 `名 ×N` 的纯文本（没券时返回空串，由调用方写「一张都没有」）。 */
function 券行文字(R) {
  const 们 = (R && R.券) || [];
  return 们.length ? 券汇总文字(R) : '';
}

/** 把手上每一张券画成一个小按钮（大地图顶栏 / 晋升屏右上那一行）。
 *  ★ **不在这里写 `data-act` 的下标**：`用券:<下标>` 只由招募屏那一段负责（那边才有「选中」语义），
 *  这里只是**展示**（点它就去招募屏，避免玩家在大地图上不小心把券用掉）。 */
function 券按钮组Html() {
  const R = 肉鸽 && 肉鸽.RUN;
  const 们 = (R && R.券) || [];
  return 们.map((c, i) => `<span class="rv-chip" data-ticket="${i}">${券名(c)}` +
    `<small>${券类(c)}${c.来源 ? ` · ${c.来源}` : ''}</small></span>`).join('');
}

/** 大地图上的「队伍」卡片：每台机体的**当前等级与属性**（晋升之后这里会真的变）。
 *  属性一律问 `重算名册属性()`（它走的是 `makeUnit` → `levelUp`，和战斗里同一套规则）。
 *  ★ 2026-10-11 券系统：这里的快捷晋升按钮也**要走券**（和晋升屏同一个判据）——
 *  缺同类券的按钮 `disabled`，`title` 写清为什么。 */
function 队伍卡片Html() {
  const R = 肉鸽 && 肉鸽.RUN;
  if (!R) return '';
  const 们 = 重算名册属性() || [];
  /* ★ 2026-10-13 带队核心：名册**下标 0** 那一台在**大地图队伍卡片**上也看得出来（作者立的三层反馈
     里「结算」那一层）—— 判据只有一处（`带队核心吗`），名册行 / 战报 / 测试都读它。 */
  const 核 = R.队伍 && R.队伍[0];
  const 行 = 们.map((x, i) => {
    const t = tplOf(x.键) || {};
    /* `们` 与 `R.队伍` 同序（`重算名册属性()` 就是按 `R.队伍` map 出来的）→ 下标 i 直接可用。 */
    const 是核 = 带队核心吗(R.队伍, i);
    const 出击 = (R.出击 || []).includes(x.键);
    const 到 = 晋升目标(x.等级);
    const 价 = 到 ? 晋升要多少(x.键, 到, R) : 0;
    const 找 = 到 ? 找同类券(R, x.键) : null;
    const 能升 = !!到 && R.希望 >= 价 && !!找;
    const 为什么 = !到 ? '已经 Lv30'
      : (!找 ? '没有可用的同类券（战后 / 招募站给券）' : (R.希望 < 价 ? `希望不够（要 ${价}）` : `要用掉一张 ${券名(找.券)}`));
    return `<div class="rv-row"><span class="rv-tier ${tierOf(x.键)}">${TIER_NAME[tierOf(x.键)] || '普通'}</span>
      <span class="nm"><b>${t.pilot || x.键}</b>${是核 ? `<b style="color:var(--accent,#ffd166)" data-lead-core="1"> ${带队核心标记}</b>` : ''}<small>${x.键} · ${(t.tags || {}).战斗分类 || '—'} · ${出击 ? '出击名单' : '待命'}</small>
        <br><small style="margin-left:0">Lv${x.等级}　HP ${x.后.maxHp}　装甲 ${x.后.armor}　防御 ${x.后.defense}　机动 ${x.后.mov}　速度 ${x.后.速度}</small></span>
      ${到 ? `<button class="rv-btn" data-act="晋升:${x.键}" title="${为什么}"${能升 ? '' : ' disabled'}>→Lv${到}（${价} 希望＋1 券）</button>` : '<small>Lv30</small>'}
      <!-- ★ 2026-10-13 任务书 §1 模块 5：**大地图队伍栏**的「ⓘ 详情」（5 屏入口之一）。
           独立一颗按钮（不改卡片本身的晋升按钮）：data-act="看机体:键" → 弹「机体特性与武器详情」。
           .rv-row 是 flex，多这一颗不挤掉原来那些；**原来那些按钮的文字与 data-act 一个字没改**。 -->
      <button type="button" class="mech-info-btn" data-act="看机体:${x.键}" title="查看 ${t.pilot || x.键} 的机体特性与武器详情">ⓘ 详情</button></div>`;
  }).join('') || '<p class="small">名册是空的。</p>';
  const 券们 = (R.券 || []);
  return `<div class="rv-card"><h3>队伍（${R.队伍.length} / ${肉鸽数值.队伍上限}）<span class="small">点右边的按钮直接晋升（**希望 ＋ 1 张同类券**）${核 ? `　·　${带队核心标记} = 本局第一台，招募时直接 Lv${带队核心等级}（分队特权）` : ''}</span></h3>${行}
    <p class="small" data-tickets="1">手上的招募券（<b>${券们.length}</b> 张）：${券行文字(R) || '<b>一张都没有</b>'}　·　
      招募价格：精锐 5、骨干 3、普通免费。晋升价格（战棋 <code>22-输入.js:431</code>）：
      精锐 3 / 4、骨干 2 / 3、普通 1 / 2 希望${R.下次晋升减价 ? '（休整过：下次晋升 −1 希望）' : ''}；
      **晋升还要用掉 1 张同职业 / 同势力的券**（战棋 <code>27-开局.js:84→86</code>）。</p></div>`;
}

/* 格子坐标（1 起数，和战棋 30-移动与节点.js:41 的写法一致） */
function 坐标文字(n) { return `(${n.列 + 1}, ${n.行 + 1})`; }

/** 大地图上那张「最近 5 条」小卡片（作者列的**可选**项，做了）：
 *  只读 `RUN.日志` 的最后 5 条、**最新在前**；一条都没有时返回空串（整张卡片都不画）。
 *  与「记录屏」同一份数据、同一个排序口径，只是条数少 —— 不想翻整本日志时一眼看得到刚发生什么。 */
function 最近记录Html() {
  const R = 肉鸽 && 肉鸽.RUN;
  const 全 = (R && Array.isArray(R.日志)) ? R.日志 : [];
  if (!全.length) return '';
  const 显 = 全.slice(-最近记录条数).reverse();
  return `<div class="rv-card rv-mini" data-log-mini="1"><h3>最近 ${显.length} 条记录
    <span class="small">最新在最上面 · 完整记录点上面那个「记录」按钮（共 ${全.length} 条）</span></h3>
    ${显.map(x => { const p = 肉鸽界面.记录前缀(x); return `<div class="logline"><span class="tag">${p.层} · ${p.类}</span><span class="tx">${x.文本}</span></div>`; }).join('')}</div>`;
}

/** ★ **战斗结算清单的一行字**（结果条 / 日志用）：`希望 +N / 源碳 +N / 券【X】/ 零件【Y】/ 藏品【Z】`。
 *  与 `战斗奖励清单Html()` **同一份字段顺序**（一个是多行块、一个是单行文本），
 *  字段全部来自 `肉鸽.战斗结束()` 的返回值 —— 没有的字段一个都不编。 */
function 战斗奖励清单文字(r) {
  if (!r) return '（这一场没有奖励数据）';
  const 项 = [];
  if (r.胜 === false) {
    if (r.扣 != null) 项.push(`作战耐久 −${r.扣}`);
    if (r.券) 项.push(`券【${券名(r.券)}】`);
    if (r.结束) 项.push('作战耐久耗尽，本局结束');
    if (r.追击结束) 项.push('甩掉了追兵');
  } else {
    if (r.希望 != null) 项.push(`希望 +${r.希望}`);
    if (r.源碳 != null) 项.push(`源碳 +${r.源碳}`);
    if (r.券) 项.push(`券【${券名(r.券)}】`);
    if (r.零件) 项.push(`零件【${r.零件.名}】`);
    if (r.藏品) 项.push(`藏品【${r.藏品.名}】`);
    if (r.额外编制) 项.push(`藏品【${r.额外编制.名}】`);
    if (r.额外 && r.额外.源碳 != null) 项.push(`源碳 +${r.额外.源碳}（侵蚀源额外）`);
    if (r.额外源碳 != null) 项.push(`源碳 +${r.额外源碳}（关口奖励）`);
    if (r.守军已清) 项.push('出口放行');
    if (r.追击结束) 项.push('继续前进');
  }
  return 项.length ? 项.join(' / ') : '（这一场没有奖励）';
}

/** ★ 战斗结算清单（2026-10-11 作者「结果没有提示」那一半）：
 *  把 `肉鸽.战斗结束()` 的**返回值**渲染成一排「希望 +N / 源碳 +N / 券【X】/ 零件【Y】/ 藏品【Z】」。
 *  ★ **只加展示、不改引擎的奖励逻辑**：字段全都从返回值里读（`希望 / 源碳 / 券 / 零件 / 藏品 /
 *     额外源碳 / 额外编制 / 扣`）—— 一个字段都没有就显示「（这一场没有奖励）」，绝不自己编数字。
 *  失败那一场没有奖励字段，改显示「作战耐久 −N」。返回值不在时返回空串（老路径逐字不变）。 */
function 战斗奖励清单Html(r) {
  if (!r) return '';
  const 项 = [];
  if (r.胜 === false) {
    if (r.扣 != null) 项.push(`作战耐久 <b>−${r.扣}</b>`);
    if (r.券) 项.push(`券【${券名(r.券)}】（战后 1 张，败也给）`);
    if (r.结束) 项.push('<b style="color:var(--enemy)">作战耐久耗尽，本局结束</b>');
  } else {
    if (r.希望 != null) 项.push(`希望 <b>+${r.希望}</b>`);
    if (r.源碳 != null) 项.push(`源碳 <b>+${r.源碳}</b>`);
    if (r.券) 项.push(`券【${券名(r.券)}】`);
    if (r.零件) 项.push(`零件【${r.零件.名}】`);
    if (r.藏品) 项.push(`藏品【${r.藏品.名}】`);
    if (r.额外编制) 项.push(`藏品【${r.额外编制.名}】（编制类额外掉落）`);
    if (r.额外 && r.额外.源碳 != null) 项.push(`源碳 <b>+${r.额外.源碳}</b>（侵蚀源额外奖励）`);
    if (r.额外源碳 != null) 项.push(`源碳 <b>+${r.额外源碳}</b>（关口奖励）`);
    if (r.追击结束) 项.push('<b>追击甩掉了</b>，继续前进');
    if (r.守军已清) 项.push('<b>出口守军已击溃</b>，出口放行');
  }
  if (!项.length) 项.push('（这一场没有奖励）');
  const 胜 = r.胜 !== false;
  return `<div class="battle-res${胜 ? '' : ' lose'}" data-battle-res="1">
    <b>${胜 ? '这一场拿到了' : '这一场的账'}</b>：${项.join('　/　')}</div>`;
}

/* 图例（只列这一层地图上真的会出现的类型） */
function 图例Html() {
  const R = 肉鸽.RUN;
  if (!R) return '';
  const 出现 = new Set(Object.values(R.地图.格).map(n => n.类型));
  return [...出现].map(t => {
    const x = 节点类型表[t] || { 名: t, 图标: '?', 色: '#8a99ab' };
    return `<span class="glegend" style="--fc:${x.色}">${x.图标} ${x.名}</span>`;
  }).join('');
}

/* 节点弹窗（隧道 / 瞭望站 / 遗迹 / 休整 / 侵蚀源）。
   ★ **同步值或 Promise 都认**（2026-10-13 修）：`界面.对话框()` 在**浏览器里**返回一个 Promise
   （玩家点哪个按钮，它 resolve 成哪个值），走 `对话框钩子`（测试 / 探针 / 录像重放）时**同步**返回那个值。
   两种都要能跑完节点，所以这里统一：拿到 Promise 就 `答案.then(回调)`（回调的返回值就是这条链的结果），
   拿到同步值就当场 `回调(答案)`。**返回 Promise 时，节点结算是「等一下」才发生的** —— 调用方
   （`80-界面.js` 的 `去节点` / `打这一场`）已经按同一条口径接住（见那里的 `试` / `试了` 两段）。
   为什么要走这个钩子：`90-肉鸽.js` 排在 `80-界面.js` 前面，那里拿不到 `界面.对话框`。 */
function 肉鸽弹窗(标题, 文本, 选项, 回调) {
  const 表 = 选项.map(o => ({ 值: o[0], 名: o[1] }));
  const 答案 = (typeof 界面 !== 'undefined' && 界面 && typeof 界面.对话框 === 'function')
    ? 界面.对话框(标题, 文本, 表)
    : (表.length ? 表[0].值 : null);
  if (typeof 回调 !== 'function') return 答案;
  if (答案 && typeof 答案.then === 'function') return 答案.then(回调);   // 真弹窗（异步）：等玩家点
  return 回调(答案);                                                     // 钩子（同步）：当场结算
}
