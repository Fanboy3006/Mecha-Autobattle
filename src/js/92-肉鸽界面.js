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

  /* ---------------- 菜单上的入口 ---------------- */
  最近存档() { return 肉鸽.读存档(); },

  /* ---------------- 分队选择 ---------------- */
  分队屏() {
    const 表 = [{ 名: '无', 说明: '不挑分队：招募券完全随机。' }]
      .concat(CLASSES.map(k => ({ 名: k, 说明: `${k}分队：招募券一半概率出「${k}」券。` })))
      .concat(FACTIONS.map(f => ({ 名: f, 说明: `${f}分队：招募券一半概率出「${f}」券。` })));
    const 卡 = 表.map(x => `<button class="pick${this.分队ID === x.名 ? ' on' : ''}" data-act="选分队:${x.名}">
      <b>${x.名}</b><small>${x.说明}</small></button>`).join('');
    return `<section class="card">
      <h3>选分队（方案第 7 节）<span class="small">分队决定招募券的倾向；队伍上限 ${肉鸽数值.队伍上限} 台（前 3 后 2）</span></h3>
      <div class="picks">${卡}</div>
      <div class="acts">
        <button class="primary" data-act="开新局"${this.分队ID ? '' : ' disabled'}>出发（新的一局）→</button>
        <button data-act="回菜单">回菜单</button>
      </div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
      <p class="small">开局队伍是默认五人队（雷萨 / 蕾卡 / 提耶利亚 / 洛克昂 / Feena，Lv10）。</p>
    </section>`;
  },

  /* ---------------- 网格大地图 ---------------- */
  大地图屏() {
    const R = 肉鸽.RUN;
    if (!R) return '<section class="card"><p>还没有进行中的局。</p><a href="#" data-act="回菜单">回菜单</a></section>';
    const 当前格 = 肉鸽.当前格();
    const 距离 = 全距离(R);                                  // 不算推进剂上限，用来提示「走过去要几步」
    const 能去 = new Set(肉鸽.能去的().map(n => n.k));
    const 已走过 = new Set(R.已走过 || []);
    const 已揭开 = new Set(R.已揭开 || []);
    const 守军已清 = (() => { const 守 = R.地图.格[R.地图.守军]; return !守 || 守.已过 || 守.类型 === '空'; })();
    const 格按钮 = k => {
      const n = R.地图.格[k];
      if (!n) return '<button class="gcell none" disabled><i>·</i><small>不存在</small></button>';
      const 型 = 节点类型表[n.类型] || { 名: n.类型, 图标: '?', 色: '#8a99ab' };
      const 步 = 距离.get(k);
      const 是当前 = k === R.当前;
      const 可 = 能去.has(k);
      const 态 = 是当前 ? ' here' : (n.已过 ? ' done' : (可 ? ' can' : (已走过.has(k) ? ' walked' : '')));
      const 动 = 可 ? ` data-act="去节点:${k}"` : '';
      let 小字 = '';
      if (是当前) 小字 = '你在这里';
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
    return `<section class="card">
      <h3>第 ${R.层 === 4 ? '终点' : R.层 + ' / 3'} 层 · 网格大地图
        <span class="small">点一个亮着的格子走过去（可以跳格：一次点远的格子就按最短路径走）</span></h3>
      <div class="rv-bar2">
        <span class="rv-chip${R.推进剂 <= 0 ? ' warn' : ''}">推进剂 <b>${R.推进剂}</b> / ${推进剂上限(R)}</span>
        <span class="rv-chip">层数 <b>${R.层 === 4 ? '终点' : R.层 + ' / 3'}</b></span>
        <span class="rv-chip">希望 <b>${R.希望}</b></span>
        <span class="rv-chip">源碳结晶 <b>${R.源碳}</b></span>
        <span class="rv-chip${R.耐久 <= 3 ? ' warn' : ''}">作战耐久 <b>${R.耐久}</b></span>
        <span class="rv-chip">藏品 <b>${(R.藏品 || []).length}</b></span>
        <span class="rv-chip">本层第 <b>${R.场次 + 1}</b> 场</span>
        <span class="rv-chip">种子 <b>${R.种子}</b></span>
      </div>
      ${R.推进剂 <= 0 ? '<p class="warn small">推进剂已经用光：这一格结算完就会触发<b>追击战</b>（战棋 30:34）。</p>' : ''}
      <div class="gmap">${行们.join('')}</div>
      <p class="small">当前格：<b>${当前格 ? (节点类型表[当前格.类型] || {}).名 : '—'}</b>${当前格 ? `（${坐标文字(当前格)}）` : ''}${守军已清 ? '' : '　·　出口守军还没打掉，打掉它出口才放行'}　·　图例：${图例Html()}</p>
      <div class="acts">${按钮 || '<span class="small">这一格没有可做的事，往别的格子走吧。</span>'}
        <button data-act="存个档">存档</button><button data-act="放弃本局">放弃本局</button></div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
      <p class="small">队伍（${R.队伍.length} / ${肉鸽数值.队伍上限}）：${队伍}</p>
      ${藏品卡片Html()}
      ${界面.弹窗控件Html()}
      <p class="small">日志：${R.日志.slice(-4).map(x => `第${x.层}层 ${x.文本}`).join('　|　')}</p>
    </section>`;
  },

  /* ---------------- 黑市 ---------------- */
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
    }).join('') || '<p class="small">这一层的黑市卖完了。下层的黑市会换新货。</p>';
    return `<section class="card">
      <h3>黑市<span class="small">源碳结晶 <b>${R.源碳}</b> · 价格照战棋：普通 8 / 稀有 12 / 传说 16（23b-藏品.js:10）</span></h3>
      <p class="small">战棋的黑市还卖「零件」（30-移动与节点.js:99-113）；方案第 7 节说零件第一期只带大地图上用的那几个，
        本仓库还没做零件，所以这里**只卖藏品**（记进任务板的差异清单）。</p>
      <div class="picks">${卡}</div>
      <div class="acts"><button class="primary" data-act="黑市离开">离开黑市</button><button data-act="回大地图">回大地图</button></div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
    </section>`;
  },

  /* ---------------- 招募（拖动） ---------------- */
  招募屏() {
    const R = 肉鸽.RUN;
    if (!R) return '';
    const 已有 = new Set(R.队伍.map(m => m.键));
    const 候选 = ALLY_T.filter(t => !已有.has(t.mech));
    const 卡 = 候选.map(t => {
      const p = 界面.预览(t.mech, 招募等级(R.层));
      const 费 = 肉鸽数值.招募费[tierOf(t.mech)] || 0;
      return `<button class="pick" data-act="招募:${t.mech}" data-drag="候选:${t.mech}" style="--fc:${势力色(t.mech)}"${R.希望 < 费 ? ' disabled' : ''}>
        <span class="pk-top">${图标.卡(t.mech, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${t.pilot}</b><small>${t.mech} · ${t.tags.战斗分类} · ${t.tags.势力}</small></span></span>
        <span class="nums">速 ${p.速度} · HP ${p.hp}</span><span class="cost">招募 ${费} 希望</span></button>`;
    }).join('');
    const 队 = R.队伍.map(m => `<div class="rv-row"><span class="pk-top">${图标.卡(m.键, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${allyName(m.键)}</b><small>${m.键} · Lv${m.等级}</small></span></span></div>`).join('');
    return `<section class="card">
      <h3>招募<span class="small">队伍 ${R.队伍.length} / ${肉鸽数值.队伍上限}（满了就不能再招）· 希望 ${R.希望}</span></h3>
      <div class="编队屏">
        <div class="col 候选" data-drop="候选">
          <h3>可招募的机师（${候选.length} 名）<span class="small">点一下或者拖过来就招募（Lv${招募等级(R.层)}）</span></h3>
          <div class="picks">${卡}</div>
        </div>
        <div class="col 站位">
          <h3>当前队伍（${R.队伍.length} / ${肉鸽数值.队伍上限}）</h3>
          ${队 || '<p class="small">还没有人。</p>'}
          <div class="acts"><button data-act="回大地图">回大地图</button></div>
        </div>
      </div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
    </section>`;
  },

  /* ---------------- 事件 ---------------- */
  奇遇屏() {
    const R = 肉鸽.RUN;
    const 型 = R ? (R.地图.格[R.当前] || {}).类型 : null;
    return `<section class="card">
      <h3>${型 === '事件' ? '事件' : '奇遇'}</h3>
      <p>路上遇到一支友军残骸。你要：</p>
      <div class="acts">
        <button class="primary" data-act="奇遇:希望">收拢士气（希望 +${肉鸽数值.奇遇希望}）</button>
        <button class="primary" data-act="奇遇:源碳">回收结晶（源碳 +${肉鸽数值.奇遇源碳}）</button>
        <button data-act="回大地图">离开</button>
      </div>
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
