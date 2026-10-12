/* ============================================================================
 * 肉鸽界面（方案第 7 / 8.1 节）
 * ----------------------------------------------------------------------------
 * 作者 2026-10-10 拍板：大地图从「一列列节点」换成**战棋那套 6×4 网格 + 推进剂**。
 * 这一版的画面：
 *   分队屏 → **网格大地图屏**（6 列 × 4 行格子按钮，类型配色 + 已过 / 可去 / 当前三态，
 *   顶栏显示推进剂 / 层数 / 希望 / 源碳 / 作战耐久 / 藏品数，格子上写「走过去要几步、花几点推进剂」）
 *   → 节点屏（战斗先编队、招募（拖动）、黑市、休整、隧道、瞭望站、遗迹、事件、出口守军、侵蚀源）
 *   → 通关 / 失败结算屏。
 *
 * 交互沿用现有那套：`#screen` 上的 `data-act="动作:参数"` 事件委托（鼠标和手指都能点，
 * 拖动还是 `data-drag` 的 pointer 那套）；`肉鸽弹窗()` 在没有界面时（节点测试）直接返回第一个选项。
 * ========================================================================== */

const 肉鸽界面 = {
  分队ID: null,
  提示: '',
  最近格: null,          // 上一次点的格子（悬停说明用）
  用零件中: null,         // 正在使用中的零件下标（null = 没在用）—— 点了之后地图上高亮它的目标格
  /* ★ 2026-10-11 招募券：**当前选中的券的下标**（`null` = 没选券）。
     为什么不写在 `data-act` 里：`界面.动作()` 只按**第一个 `:` 拆一次**（`80-界面.js:195-199`），
     写 `data-act="券招募:0:B1"` 会被当成「动作 `券招募`、参数 `0:B1`」——
     所以选中状态放在这里，按钮照旧写 `data-act="招募:<键>"`，由 `界面.招募()` 读这个值。 */
  选中的券: null,

  /* ---------------- 菜单上的入口 ---------------- */
  最近存档() { return 肉鸽.读存档(); },

  /* ---------------- 分队选择 ---------------- */
  分队屏() {
    const 表 = [{ 名: '无', 说明: '不挑分队：开局 3 张招募券完全随机（含势力券）。' }]
      .concat(CLASSES.map(k => ({ 名: k, 说明: `${k}分队：开局第 1 张券固定是「${k}招募券」，另 2 张随机。` })))
      .concat(FACTIONS.map(f => ({ 名: f, 说明: `${f}分队：开局第 1 张券固定是「${f}势力招募券」，另 2 张随机。` })));
    const 卡 = 表.map(x => `<button class="pick${this.分队ID === x.名 ? ' on' : ''}" data-act="选分队:${x.名}">
      <b>${x.名}</b><small>${x.说明}</small></button>`).join('');
    return `<section class="card">
      <h3>选分队（方案第 7 节）<span class="small">分队决定**开局第一张券**与招募券的倾向；队伍上限 ${肉鸽数值.队伍上限} 台（上阵 9 格阵型，出击上限 ${出击上限初值} 台起、肉鸽部队每 ${每几级加一台} 级 +1，**等级那条最多 ${等级成长顶} 台**；7–9 台只能靠藏品的「出击上限 +1/+2」，**绝对封顶 ${绝对顶} 台**）</span></h3>
      <div class="picks">${卡}</div>
      <div class="acts">
        <button class="primary" data-act="开新局"${this.分队ID ? '' : ' disabled'}>出发（新的一局）→</button>
        <button data-act="回菜单">回菜单</button>
      </div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
      <p class="small">★ 开局：**名册是空的（分队不带机体）**，发 **${肉鸽数值.开局券数} 张招募券**
        —— 第 1 张固定是「〈分队〉」券（选「无」则 3 张全随机），另 ${肉鸽数值.开局券数 - 1} 张随机职业券；
        发完**直接进招募屏**（照战棋 <code>27-开局.js:50</code> 的「选完分队立刻依次弹券」）。
        券的用处：**招募**一名该类别机师（Lv10，照花希望：精锐 5 / 骨干 3 / 普通 0）
        <b>或</b> 给队里**同类**机师**晋升**（希望 + 1 张同类券，照战棋 <code>27-开局.js:78-86</code>）。</p>
    </section>`;
  },

  /* ---------------- 网格大地图 ---------------- */
  大地图屏() {
    const R = 肉鸽.RUN;
    if (!R) return '<section class="card"><p>还没有进行中的局。</p><a href="#" data-act="回菜单">回菜单</a></section>';
    const 当前格 = 肉鸽.当前格();
    const 距离 = 全距离(R);                                  // 不算推进剂上限，用来提示「走过去要几步」
    const 能去 = new Set(肉鸽.能去的().map(n => n.k));
    /* 正在用零件：地图上高亮这件零件能去的格（走这些格不花推进剂，见 94-零件.js 的 用零件） */
    const 用中 = (this.用零件中 != null) ? (R.零件 || [])[this.用零件中] : null;
    const 零件可去 = new Set(用中 ? 零件目标(用中) : []);
    const 已走过 = new Set(R.已走过 || []);
    const 已揭开 = new Set(R.已揭开 || []);
    const 守军已清 = (() => { const 守 = R.地图.格[R.地图.守军]; return !守 || 守.已过 || 守.类型 === '空'; })();
    const 出口们 = [R.地图.出口尽头, R.地图.出口小径].filter(k => k != null && R.地图.格[k]);
    const 格按钮 = k => {
      const n = R.地图.格[k];
      if (!n) return '<button class="gcell none" disabled><i>·</i><small>不存在</small></button>';
      const 型 = 节点类型表[n.类型] || { 名: n.类型, 图标: '?', 色: '#8a99ab' };
      const 步 = 距离.get(k);
      const 是当前 = k === R.当前;
      const 可 = 能去.has(k);
      const 件可 = 零件可去.has(k);
      const 态 = 是当前 ? ' here' : (n.已过 ? ' done' : (件可 ? ' can' : (可 ? ' can' : (已走过.has(k) ? ' walked' : ''))));
      const 动 = (件可 || 可) ? ` data-act="去节点:${k}"` : '';
      let 小字 = '';
      if (是当前) 小字 = '你在这里';
      else if (件可) 小字 = `零件 →（不花推进剂）`;
      else if (可 && 步 != null) 小字 = `${步} 步 · ${步} 推进剂`;
      else if (n.已过) 小字 = '已通过';
      else if (步 != null) 小字 = `太远（${步} 步 > ${R.推进剂}）`;
      else if (!n.已过 && (已揭开.has(k) || 已走过.has(k))) 小字 = '到不了';
      return `<button class="gcell${态}" style="--fc:${型.色}"${动} data-k="${k}"
        title="${坐标文字(n)} · ${型.名}${小字 ? '｜' + 小字 : ''}${n.关卡 ? `｜${n.关卡}` : ''}">
        <i>${型.图标}</i><b>${型.名}</b><small>${小字 || 坐标文字(n)}</small></button>`;
    };
    const 行们 = [];
    for (let 行 = 0; 行 < R.地图.行数; 行++) {
      const 本行 = [];
      for (let 列 = 0; 列 < R.地图.列数; 列++) 本行.push(格按钮(格号(列, 行)));
      行们.push(`<div class="grow">${本行.join('')}</div>`);
    }
    const 队伍 = R.队伍.map(m => `${allyName(m.键)}(${m.键} Lv${m.等级})`).join('、');
    const 菜单 = 肉鸽.格菜单();
    const 按钮 = 菜单.map(a => `<button class="${a.灰 ? '' : 'primary'}" data-act="${a.动}"${a.灰 ? ' disabled' : ''}>${a.名}</button>`).join('');
    /* 肉鸽等级（+ 藏品部署位加成）→ 出击上限：**两级封顶**（2026-10-11）——
       等级那条线封顶 6、加藏品绝对封顶 9，7–9 台只能靠藏品。 */
    const 上限 = 出击上限提示(R.等级, 藏品部署位加成(R));
    /* ★ HP 继承（作者 2026-10-11）：队伍带着伤走（满血时这一行不显示）。 */
    const HP行 = 肉鸽.队伍HP行 ? 肉鸽.队伍HP行() : null;
    const 上限说明 = 上限.到顶
      ? `出击上限 <b>${上限.上限}</b> 台 <small>（已顶到绝对封顶 ${上限.绝对顶} 台）</small>`
      : `出击上限 <b>${上限.上限}</b> 台 <small>（等级那条 ${上限.等级上限} / ${上限.等级成长顶} 台` +
        `${上限.等级到顶 ? '，已到顶' : `，再升到 Lv${上限.解锁等级} 加 1 台`}；` +
        `藏品 +${上限.藏品加成} 台，最多加到 ${上限.绝对顶} 台）</small>`;
    return `<section class="card">
      <h3>第 ${R.层 === 4 ? '终点' : R.层 + ' / 3'} 层 · 网格大地图
        <span class="small">点一个亮着的格子走过去（可以跳格：一次点远的格子就按最短路径走）</span></h3>
      <div class="rv-bar2">
        <span class="rv-chip${R.推进剂 <= 0 ? ' warn' : ''}">推进剂 <b>${R.推进剂}</b> / ${推进剂上限(R)}</span>
        <span class="rv-chip">层数 <b>${R.层 === 4 ? '终点' : R.层 + ' / 3'}</b></span>
        <span class="rv-chip">部队 <b>Lv${R.等级}</b> <small>${R.经验} / ${升级门槛(R.等级) ?? '—'}</small></span>
        <span class="rv-chip">出击上限 <b>${上限.上限}</b> 台</span>
        <span class="rv-chip">希望 <b>${R.希望}</b></span>
        <span class="rv-chip">源碳结晶 <b>${R.源碳}</b></span>
        <span class="rv-chip${R.耐久 <= 3 ? ' warn' : ''}">作战耐久 <b>${R.耐久}</b></span>
        <span class="rv-chip">藏品 <b>${(R.藏品 || []).length}</b></span>
        <span class="rv-chip${(R.券 || []).length ? '' : ' warn'}" data-tickets="1">招募券 <b>${(R.券 || []).length}</b>${(R.券 || []).length ? `<small>${券汇总文字(R)}</small>` : '<small>（去招募 / 晋升都用不了券）</small>'}</span>
        <span class="rv-chip">本层第 <b>${R.场次 + 1}</b> 场</span>
        ${HP行 ? `<span class="rv-chip warn" data-hp-carry="1">${HP行}</span>` : ''}
        <span class="rv-chip">种子 <b>${R.种子}</b></span>
      </div>
      <p class="small" data-deploy-cap="1">${上限说明}　·　出击上限 = <b>等级那条线</b>（每 ${每几级加一台} 级 +1、最多 ${等级成长顶} 台）＋ <b>藏品</b>（「出击上限 +1/+2」的件拿到就永久加、允许突破 ${等级成长顶}），绝对封顶 <b>${绝对顶}</b> 台；现在手里有 ${藏品编制件数(R)} 件编制类藏品。</p>
      ${R.推进剂 <= 0 ? '<p class="warn small">推进剂已经用光：这一格结算完就会触发<b>追击战</b>（战棋 30:34）。</p>' : ''}
      <p class="small" data-hope-src="1">${希望来源说明(R)}
        <br>战斗胜利 <b>+${肉鸽数值.胜利希望}</b> / 精英 <b>+${肉鸽数值.精英希望}</b> / Boss <b>+${肉鸽数值.Boss希望}</b>；
        出口尽头 <b>剩余推进剂 ×${肉鸽数值.出口换希望} → 希望</b>（照抄黑流树海「险路尽头」）；
        升级按原作分级表 <b>+4…+8</b>（Lv2 +4 / Lv3 +4 / Lv4 +5 / Lv5 +6 / Lv6 +6 / Lv7 +6 / Lv8 +7 / Lv9 +8 / Lv10 +8；
        等级 &gt; 10 沿用 +8）—— 作者 2026-10-11 拍板「照原作 4–8」，逐级给，出处见 CLAUDE.md 第 6 节；
        藏品里的 <b>t1–t6 教范</b>是「免费晋升 1 名该职业」= 省下本来要花的 1–4 希望（战棋 23b:39-44）。</p>
      ${用中 ? `<p class="warn small">正在使用零件【${零件表[用中.k].名}】：点地图上<b>高亮的格子</b>落下去（不花推进剂）。
        再点一次「使用」可以取消。</p>` : ''}
      <div class="gmap">${行们.join('')}</div>
      <p class="small">当前格：<b>${当前格 ? (节点类型表[当前格.类型] || {}).名 : '—'}</b>${当前格 ? `（${坐标文字(当前格)}）` : ''}${守军已清 ? '' : '　·　出口守军还没打掉，打掉它两个出口才放行'}　·　出口：${出口们.map(k => `${(节点类型表[R.地图.格[k].类型] || {}).名} ${坐标文字(R.地图.格[k])}`).join('、')}（<b>二选一</b>：尽头 = 剩余推进剂 ${R.推进剂} → 希望 +${R.推进剂 * 肉鸽数值.出口换希望}；小径 = 第 ${R.层 + 1} 层推进剂上限 +${肉鸽数值.出口小径加成}）　·　图例：${图例Html()}</p>
      <div class="acts">${按钮 || '<span class="small">这一格没有可做的事，往别的格子走吧。</span>'}
        <button data-act="去晋升">晋升（希望 ${R.希望}）</button>
        <button data-act="存个档">存档</button><button data-act="放弃本局">放弃本局</button></div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
      <p class="small">队伍（${R.队伍.length} / ${肉鸽数值.队伍上限}）：${队伍}</p>
      ${队伍卡片Html()}
      ${零件卡片Html()}
      ${藏品卡片Html()}
      ${界面.弹窗控件Html()}
      <p class="small">日志：${R.日志.slice(-4).map(x => `第${x.层}层 ${x.文本}`).join('　|　')}</p>
    </section>`;
  },

  /* ---------------- 晋升（10 → 20 → 30） ----------------
     照战棋 `29-渲染.js:62-70` 的 `teamCard()`：名册每行一个「→Lv20（N）」按钮，
     `N > RUN.hope` 时 `disabled`；底部一行写「晋升价格：精锐 3 / 4，骨干 2 / 3，普通 1 / 2 希望」。
     每一行**把升完之后的属性变化列出来**（HP / 装甲 / 防御 / 机动 / 速度），点一下就升。
     ★ 2026-10-11 券系统：价格之外还**必须有一张同类券**（照战棋 `27-开局.js:78-86`：券与希望同时消耗）
       —— 缺券的按钮 `disabled` 并把「没有可用的同类券」写清；顶上多一行「手上的券」。 */
  晋升屏() {
    const R = 肉鸽.RUN;
    if (!R) return '<section class="card"><p>还没有进行中的局。</p><a href="#" data-act="回菜单">回菜单</a></section>';
    const 清单 = 肉鸽.晋升清单();
    const 行 = 清单.map(x => {
      const 变 = x.属性
        ? `HP ${x.属性.前.maxHp} → <b>${x.属性.后.maxHp}</b>　装甲 ${x.属性.前.armor} → <b>${x.属性.后.armor}</b>` +
          `　防御 ${x.属性.前.defense} → <b>${x.属性.后.defense}</b>　机动 ${x.属性.前.mov} → <b>${x.属性.后.mov}</b>` +
          `　速度 ${x.属性.前.速度} → <b>${x.属性.后.速度}</b>`
        : '（Lv30 到顶，没有下一档）';
      const 动 = ` data-act="晋升:${x.键}"`;
      const 券注 = x.到
        ? (x.有券 ? `　券：<b>${x.券名}</b>（用掉 1 张）` : '　券：<b style="color:var(--enemy)">没有可用的同类券</b>')
        : '';
      return `<div class="rv-row"><span class="rv-tier ${x.档}">${x.档名}</span>
        <span class="nm"><b>${x.名}</b><small>${x.键} · Lv${x.等级}${x.到 ? ` → Lv${x.到}` : ''}${券注}</small>
          <br><small style="margin-left:0">${变}</small></span>
        ${x.到 ? `<button class="rv-btn"${动}${x.能升 ? '' : ' disabled'}>晋升（${x.价} 希望 ＋ 1 张同类券）</button>`
               : '<button class="rv-btn" disabled>已到顶</button>'}
        ${x.理由 && x.到 ? `<small style="color:var(--enemy)">${x.理由}</small>` : ''}</div>`;
    }).join('') || '<p class="small">名册是空的。</p>';
    const 次序 = 清单.filter(x => x.到).sort((a, b) => a.价 - b.价);
    return `<section class="card">
      <h3>晋升<span class="small">部队 Lv${R.等级}（出击上限 ${肉鸽.出击上限()} 台 = 等级那条 ${出击上限(R.等级)} ＋ 藏品 ${藏品部署位加成(R)}） · 希望 <b>${R.希望}</b> · 10 → 20 → 30，一次一档，不能跳级</span></h3>
      <p class="small" data-tickets="1">手上的招募券（<b>${(R.券 || []).length}</b> 张）：
        ${券按钮组Html() || '<b>一张都没有</b>（战后每场给 1 张、招募站给 1 张 —— 照战棋 31:284,298 / 30:63-67）'}</p>
      <p class="small">价格照战棋（<code>22-输入.js:431</code> 的 <code>PRICE</code>）：
        <b>精锐 3 / 4</b>（S）、<b>骨干 2 / 3</b>（A）、<b>普通 1 / 2</b>（B）希望
        ${R.下次晋升减价 ? '　·　<b>休整过：这次晋升 −1 希望</b>' : ''}。
        战棋的晋升**还要用掉一张同类招募券**（<code>27-开局.js:84→86</code>：先删券、再扣希望），
        所以按钮上写「N 希望 ＋ 1 张同类券」；**缺券点不动**（券与希望同时消耗 —— 券不是免费票，是类别选择权）。</p>
      <div class="rv-card"><h3>名册（${R.队伍.length} / ${肉鸽数值.队伍上限}）</h3>${行}</div>
      <p class="small">全场最便宜的下一档：${次序.length ? `${次序[0].名} Lv${次序[0].等级} → Lv${次序[0].到}（${次序[0].价} 希望 ＋ 1 张同类券）` : '（都已经 Lv30 了）'}</p>
      <div class="acts"><button data-act="去招募">去招募（用券招人）</button>
        <button class="primary" data-act="回大地图">回大地图</button>
        <button data-act="存个档">存档</button></div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
      ${界面.弹窗控件Html()}
    </section>`;
  },

  /* ---------------- 零件（大地图上用的那几个） ----------------
     持有数 + 每件一句效果 + 点「使用」→ 回大地图点高亮格（见 94-零件.js 的 零件目标 / 用零件）。 */
  零件屏() {
    const R = 肉鸽.RUN;
    if (!R) return '<section class="card"><p>还没有进行中的局。</p></section>';
    const 们 = R.零件 || [];
    const 上限 = R.零件箱 || 零件箱初值;
    const 行 = 们.map((p, i) => {
      const P = 零件表[p.k] || { 名: p.k, 类: '—', 效果: '' };
      const 目标数 = 零件目标(p).length;
      return `<div class="rv-row"><span class="nm"><b>${P.名}</b>
        <small> · ${P.类}${p.uses != null ? ` · 剩 ${p.uses} 次` : (p.value != null ? ` · 估价 ${p.value}` : '')}</small>
        <br><small style="margin-left:0">${P.说明}</small>
        <br><small style="margin-left:0">→ ${P.效果}${P.用 ? `（现在能去 ${目标数} 格）` : '【这一版用不了】'}</small></span>
        <button class="rv-btn" data-act="使用零件:${i}"${P.用 ? '' : ' disabled'}>使用 →</button></div>`;
    }).join('') || '<p class="small">还没有零件。</p>';
    const 全 = Object.keys(零件表).map(k => {
      const P = 零件表[k];
      return `<div class="rv-row"><span class="nm"><b>${P.名}</b><small> · ${P.类} · ${P.价} 源碳</small>
        <br><small style="margin-left:0">${P.说明}</small>
        <br><small style="margin-left:0">${P.用 ? '✓ ' + P.效果 : (P.可卖 ? '¥ ' + P.效果 : '✗ ' + (P.用不了 || '这一版不做'))}</small>
        ${P.换义 ? `<br><small style="margin-left:0">换义：${P.换义}</small>` : ''}</span></div>`;
    }).join('');
    return `<section class="card">
      <h3>零件<span class="small">零件箱 ${们.length} / ${上限} · 照战棋 <code>23-零件.js:4-18</code></span></h3>
      <p class="small">战棋的零件<b>全是大地图上用的</b>（移动 / 传送 / 理财），战斗里一件都没有 ——
        所以这一版做的就是这一批。来源照战棋：<b>精英 / Boss 战必给 1 件</b>、
        <b>普通战 35%</b>（<code>31-战斗.js:293</code>）、<b>遗迹给 1 件</b>（<code>30:79</code>）。
        ★ 2026-10-11：黑市接上「<b>卖零件</b>」之后，两件理财类自然物（血蕈 / 浪花）也进了随机池 ——
        它们在地图上没有「用」这个动作，只能拿去黑市变现（照战棋 <code>30:117-120</code>）。</p>
      <div class="rv-card"><h3>手上的零件</h3>${行}</div>
      <p class="small">用法：点「使用」→ 回大地图 → 点高亮的格子（<b>不花推进剂</b>，照战棋 <code>30:6-16</code>；
        次数用光就自动消失）。</p>
      <div class="acts"><button class="primary" data-act="回大地图">回大地图</button>
        <button data-act="去晋升">晋升</button><button data-act="存个档">存档</button></div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
      <details><summary class="small">战棋零件全表（13 件，逐条标了能不能用）</summary><div class="rv-card">${全}</div></details>
    </section>`;
  },

  /* ---------------- 黑市 ----------------
   * ★ 2026-10-11 作者拍板第 4 条：把「**买 + 卖零件 + 刷新**」三个动作都接上。
   *   出处（照抄）：原作诡意行商「初始消耗 4 源石锭，每次刷新 +4，每个节点最多刷新 4 次」；
   *   战棋 `30-移动与节点.js:105-113`（卖零件 / 空间租赁）、`94-零件.js` 的 `零件价()` / `卖零件()`。 */
  黑市屏() {
    const R = 肉鸽.RUN;
    if (!R) return '';
    const 货 = 肉鸽.黑市货();
    const 卡 = 货.map(id => {
      const 件 = 藏品表[id] || { 名: id, 说明: '', 稀有: '—' };
      const 价 = 肉鸽.黑市价(id);
      const 买得起 = R.源碳 >= 价;
      return `<button class="pick" data-act="黑市买:${id}"${买得起 ? '' : ' disabled'}>
        <b>${件.名}</b><small>${件.稀有}${件.分类 ? ' · ' + 件.分类 : ''}${件.实装 && 件.实装 !== '已接' ? ` · ${件.实装}` : ''}</small>
        <small>${件.说明}</small><span class="cost">${价} 源碳结晶${价 !== (肉鸽数值.黑市价格[件.稀有] || 0) ? '（会员卡 −30%）' : ''}</span></button>`;
    }).join('') || '<p class="small">这一层的黑市卖完了。刷新一次或者下层的黑市会换新货。</p>';
    /* 卖零件：手上的零件一件一行（自然物按估价、其他一律 2 源碳 —— 战棋 30:101,119） */
    const 零件们 = R.零件 || [];
    const 卖行 = 零件们.map((p, i) => {
      const P = 零件表[p.k] || { 名: p.k, 类: '—' };
      const 价 = 肉鸽.零件卖价(i);
      return `<button class="rv-btn" data-act="黑市卖:${i}">卖【${P.名}】（+${价} 源碳）</button>`;
    }).join('');
    /* 刷新：4 / 8 / 12 / 16，上限 4 次（逐字照抄原作诡意行商） */
    const 次 = 黑市刷新次数(R), 剩 = 肉鸽.黑市刷新剩余(), 价 = 肉鸽.黑市刷新价();
    const 刷行 = 剩 > 0
      ? `<button class="primary" data-act="黑市刷新"${R.源碳 < 价 ? ' disabled' : ''}>刷新库存（${价} 源碳 · 第 ${次 + 1} / ${肉鸽数值.黑市刷新上限} 次）</button>`
      : `<button disabled>刷新库存（这一格已经刷满 ${肉鸽数值.黑市刷新上限} 次了）</button>`;
    return `<section class="card">
      <h3>黑市<span class="small">源碳结晶 <b>${R.源碳}</b> · 价格照战棋：普通 8 / 稀有 12 / 传说 16（23b-藏品.js:10）
        · 刷新 ${肉鸽数值.黑市刷新基价}/${肉鸽数值.黑市刷新基价 + 肉鸽数值.黑市刷新加价}/${肉鸽数值.黑市刷新基价 + 肉鸽数值.黑市刷新加价 * 2}/${肉鸽数值.黑市刷新基价 + 肉鸽数值.黑市刷新加价 * 3}（照抄原作诡意行商）</span></h3>
      <p class="small">★ 2026-10-11 节点改造：把战棋黑市的<b>卖零件</b>（<code>30-移动与节点.js:105-113</code>；
        <code>94-零件.js</code> 的 <code>卖零件()</code> 早就写好了，这一版才接上界面）与
        原作的<b>刷新</b>（初始 4、每次 +4、每格最多 4 次）都做进来了；货架从 2 件提到 <b>${肉鸽数值.黑市货件数} 件</b>
        （原作诡意行商满档 4 件，见方案书 §3.4）。</p>
      <div class="picks">${卡}</div>
      <div class="acts">${刷行}<button class="primary" data-act="黑市离开">离开黑市</button><button data-act="回大地图">回大地图</button></div>
      <div class="rv-card"><h3>卖零件（${零件们.length} / ${R.零件箱 || 零件箱初值}）</h3>
        <p class="small">战棋 <code>30:105,119</code>：<b>自然物按估价</b>卖出，<b>其他零件一律 2 源碳结晶</b>。
          零件箱满了的时候，这是腾位置的地方。</p>
        <div class="acts">${卖行 || '<span class="small">手上没有零件。</span>'}</div></div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
    </section>`;
  },

  /* ---------------- 招募（拖动） ----------------
   * ★ 2026-10-11 招募券（作者拍板「券系统必须要做了才有试玩的意义」）：
   *   · 屏顶一段「手上的招募券（N）」按钮组 —— 点一张**选中**（再点一下取消），
   *     选中后候选池按 `券合(券, 键)` 过滤（照战棋 `27-开局.js:75` 的
   *     `recruitPool().filter(m => ticketOk(cls, m) && !已有)`），价格照旧写希望价
   *     （**券不是免费票**：持券招的也是精锐 5 / 骨干 3 / 普通 0 希望，照 `22-输入.js:431`）；
   *   · **「先留着」= 什么都不点**；**「丢弃这张券」**= 每张券旁边一个小按钮（照 `27:82` 的两个按钮）；
   *   · **没选券 / 没券** → 与改前**逐字相同**（候选池是全部、价格照希望价）。 */
  招募屏() {
    const R = 肉鸽.RUN;
    if (!R) return '';
    const 已有 = new Set(R.队伍.map(m => m.键));
    const 券们 = R.券 || [];
    const 选中 = (this.选中的券 != null && 券们[this.选中的券]) ? this.选中的券 : null;
    if (选中 == null) this.选中的券 = null;
    const 用中 = 选中 != null ? 券们[选中] : null;
    /* 候选池：选了券 → 只留这张券对得上的（且不在队里）；没选券 → 全部（改前的老口径） */
    const 候选 = ALLY_T.filter(t => !已有.has(t.mech) && (!用中 || 券合(用中, t.mech)));
    const 卡 = 候选.map(t => {
      const p = 界面.预览(t.mech, 招募等级(R.层));
      const 费 = 肉鸽数值.招募费[tierOf(t.mech)] || 0;
      return `<button class="pick" data-act="招募:${t.mech}" data-drag="候选:${t.mech}" style="--fc:${势力色(t.mech)}"${R.希望 < 费 ? ' disabled' : ''}>
        <span class="pk-top">${图标.卡(t.mech, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${t.pilot}</b><small>${t.mech} · ${t.tags.战斗分类} · ${t.tags.势力}</small></span></span>
        <span class="nums">速 ${p.速度} · HP ${p.hp}</span><span class="cost">招募 ${费} 希望${用中 ? '（用券）' : ''}</span></button>`;
    }).join('');
    const 队 = R.队伍.map(m => `<div class="rv-row"><span class="pk-top">${图标.卡(m.键, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${allyName(m.键)}</b><small>${m.键} · Lv${m.等级}</small></span></span></div>`).join('');
    /* 手上的券：每张一个「选中 / 取消」按钮 + 一个「丢弃」按钮（照战棋 27:78-82 的两个动作） */
    const 券卡 = 券们.map((c, i) => {
      const 选中态 = (选中 === i);
      return `<div class="rv-row"><span class="rv-tier">券</span>
        <span class="nm"><b>${券名(c)}</b><small>${券类(c)}${c.来源 ? ` · 来源：${c.来源}` : ''}${c.档 ? ` · 档 ${c.档}` : ''}</small>
          <br><small style="margin-left:0">${券用途说明(R, c)}</small></span>
        <button class="rv-btn${选中态 ? ' primary' : ''}" data-act="用券:${i}">${选中态 ? '取消选中' : '选这张券'}</button>
        <button class="rv-btn" data-act="丢券:${i}">丢弃这张券</button></div>`;
    }).join('') || '<p class="small">现在手上没有招募券（战后每场给 1 张、招募站给 1 张 —— 照战棋 <code>31:284,298</code> / <code>30:63-67</code>）。</p>';
    return `<section class="card">
      <h3>招募<span class="small">队伍 ${R.队伍.length} / ${肉鸽数值.队伍上限}（满了就不能再招）· 希望 ${R.希望} · 招募券 ${券们.length} 张</span></h3>
      <div class="rv-card"><h3>手上的招募券（${券们.length}）<span class="small">点「选这张券」→ 下面的候选池只留这张券对得上的人；**「先留着」就是什么都不点**（券随时还能用来晋升）</span></h3>
        ${券卡}</div>
      <p class="small" data-tickets="1">${用中
        ? `正在用 <b>${券名(用中)}</b> 招人：候选池只剩 ${候选.length} 名对得上的机师。
           招募**照样花希望**（精锐 5 / 骨干 3 / 普通 0，照战棋 <code>22-输入.js:431</code>），
           招完这张券会被用掉（<code>27-开局.js:84</code>）。`
        : `没选券（或手上没券）→ 候选池是全部机师，价格照希望价（**改前的老口径**）。
           这张券也可以留着去**晋升**：给队里同职业 / 同势力的机师升一档（希望 + 1 张同类券）。`}</p>
      <div class="编队屏">
        <div class="col 候选" data-drop="候选">
          <h3>可招募的机师（${候选.length} 名）<span class="small">点一下或者拖过来就招募（Lv${招募等级(R.层)}）</span></h3>
          <div class="picks">${卡}</div>
        </div>
        <div class="col 站位">
          <h3>当前队伍（${R.队伍.length} / ${肉鸽数值.队伍上限}）</h3>
          ${队 || '<p class="small">还没有人。</p>'}
          <div class="acts"><button data-act="去晋升">去晋升（用券升级）</button>
            <button data-act="回大地图">回大地图</button></div>
        </div>
      </div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
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
        <div class="acts">
          <button class="primary" data-act="奇遇:收下 3 希望">收拢士气（希望 +3）</button>
          <button class="primary" data-act="奇遇:收下 10 源碳结晶">回收结晶（源碳 +10）</button>
          <button data-act="回大地图">离开</button>
        </div>
        <p class="small">（这一屏现在是**兜底**：正常情况下「事件」节点会直接弹出下面那张事件卡。）</p></section>`;
    }
    const 事 = 肉鸽.当前事件();
    const 已选 = (R.事件已选 || {})[`${R.层}:${R.当前}`];
    const 选 = 事 ? 事.选.map((o, i) =>
      `<button class="${i === 0 ? 'primary' : ''}" data-act="奇遇:${o.文}">${o.文}</button>`).join('') : '';
    return `<section class="card">
      <h3>事件${事 ? `：${事.名}` : ''}<span class="small">照抄战棋原版事件（30-移动与节点.js:123-129）/ 黑流树海（方案书 §1.6.2）</span></h3>
      ${事 ? `<p>${事.文}</p><p class="small">出处：<code>${事.出处}</code></p>` : '<p class="small">这一格没有事件。</p>'}
      <div class="acts">${选}<button data-act="回大地图">先不选，回大地图</button></div>
      <p class="small">★ 每一个选项都有代价（或者放弃一部分收益）：推进剂 / 作战耐久 / 源碳 / 经验 里换一样。
        ${已选 ? `<br>这一格已经选过：<b>${已选}</b>` : ''}</p>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
    </section>`;
  },

  /* ---------------- 本局结算（通关 / 失败） ---------------- */
  肉鸽结算屏() {
    const R = 肉鸽.RUN;
    if (!R) return '<section class="card"><p>本局已结束。</p></section>';
    const 通关 = R.结局 === '通关';
    return `<section class="card end ${通关 ? 'win' : 'lose'}">
      <div class="eyebrow">${通关 ? '通关' : '本局结束'}</div>
      <h2>${通关 ? '走出混沌迷宫！' : (R.结局原因 || '作战失败')}</h2>
      <ul>
        <li>走到第 <b>${R.层}</b> 层${通关 ? '（终点）' : ''}　本层第 <b>${R.场次}</b> 场</li>
        <li>部队：<b>Lv${R.等级}</b>（经验 ${R.经验}）　出击上限：<b>${肉鸽.出击上限()}</b> 台（等级那条 ${出击上限(R.等级)} ＋ 藏品 ${藏品部署位加成(R)}，绝对封顶 ${绝对顶}）</li>
        <li>希望：<b>${R.希望}</b>　源碳结晶：<b>${R.源碳}</b>　作战耐久：<b>${R.耐久}</b></li>
        <li>队伍：<b>${R.队伍.length}</b> 台　藏品：<b>${(R.藏品 || []).length}</b> 件</li>
        <li>推进剂：<b>${R.推进剂}</b> / ${推进剂上限(R)}　种子：<b>${R.种子}</b></li>
      </ul>
      <div class="acts"><button class="primary" data-act="回菜单">回菜单</button><button data-act="去分队">再来一局</button></div>
    </section>`;
  },
};

/* 小队成员的显示名（肉鸽界面用） */
function allyName(键) { const t = tplOf(键); return t ? t.pilot : 键; }

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
  const 行 = 们.map(x => {
    const t = tplOf(x.键) || {};
    const 出击 = (R.出击 || []).includes(x.键);
    const 到 = 晋升目标(x.等级);
    const 价 = 到 ? 晋升要多少(x.键, 到, R) : 0;
    const 找 = 到 ? 找同类券(R, x.键) : null;
    const 能升 = !!到 && R.希望 >= 价 && !!找;
    const 为什么 = !到 ? '已经 Lv30'
      : (!找 ? '没有可用的同类券（战后 / 招募站给券）' : (R.希望 < 价 ? `希望不够（要 ${价}）` : `要用掉一张 ${券名(找.券)}`));
    return `<div class="rv-row"><span class="rv-tier ${tierOf(x.键)}">${TIER_NAME[tierOf(x.键)] || '普通'}</span>
      <span class="nm"><b>${t.pilot || x.键}</b><small>${x.键} · ${(t.tags || {}).战斗分类 || '—'} · ${出击 ? '出击名单' : '待命'}</small>
        <br><small style="margin-left:0">Lv${x.等级}　HP ${x.后.maxHp}　装甲 ${x.后.armor}　防御 ${x.后.defense}　机动 ${x.后.mov}　速度 ${x.后.速度}</small></span>
      ${到 ? `<button class="rv-btn" data-act="晋升:${x.键}" title="${为什么}"${能升 ? '' : ' disabled'}>→Lv${到}（${价} 希望＋1 券）</button>` : '<small>Lv30</small>'}</div>`;
  }).join('') || '<p class="small">名册是空的。</p>';
  const 券们 = (R.券 || []);
  return `<div class="rv-card"><h3>队伍（${R.队伍.length} / ${肉鸽数值.队伍上限}）<span class="small">点右边的按钮直接晋升（**希望 ＋ 1 张同类券**）</span></h3>${行}
    <p class="small" data-tickets="1">手上的招募券（<b>${券们.length}</b> 张）：${券行文字(R) || '<b>一张都没有</b>'}　·　
      招募价格：精锐 5、骨干 3、普通免费。晋升价格（战棋 <code>22-输入.js:431</code>）：
      精锐 3 / 4、骨干 2 / 3、普通 1 / 2 希望${R.下次晋升减价 ? '（休整过：下次晋升 −1 希望）' : ''}；
      **晋升还要用掉 1 张同职业 / 同势力的券**（战棋 <code>27-开局.js:84→86</code>）。</p></div>`;
}

/* 格子坐标（1 起数，和战棋 30-移动与节点.js:41 的写法一致） */
function 坐标文字(n) { return `(${n.列 + 1}, ${n.行 + 1})`; }

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

/* 节点弹窗（隧道 / 瞭望站 / 遗迹 / 休整）。
   ★ **同步版**：给了 `回调` 就直接 `回调(答案)` 并返回它的结果（界面里那些动作都是同步的，
   测试「点一下 → 结算 → 回大地图」在同一个调用里就能看到结果）；没给 `回调` 就返回答案本身。
   为什么要走这个钩子：`90-肉鸽.js` 排在 `80-界面.js` 前面，那里拿不到 `界面.对话框`。 */
function 肉鸽弹窗(标题, 文本, 选项, 回调) {
  const 表 = 选项.map(o => ({ 值: o[0], 名: o[1] }));
  const 答案 = (typeof 界面 !== 'undefined' && 界面 && typeof 界面.对话框 === 'function')
    ? 界面.对话框(标题, 文本, 表)
    : (表.length ? 表[0].值 : null);
  if (typeof 回调 !== 'function') return 答案;
  if (答案 && typeof 答案.then === 'function') return 答案.then(回调);   // 真弹窗（异步）时的兜底
  return 回调(答案);
}
