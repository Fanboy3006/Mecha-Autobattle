/* ============================================================================
 * 肉鸽界面（方案第 7 / 8.1 节）：分队 → 大地图 → 节点（战斗 / 招募 / 补给 / 奇遇）→ 出口
 * ----------------------------------------------------------------------------
 * 大地图不做格子贴图（方案第 2 节：格子地图丢掉），做成**一列一列的节点按钮**：
 *   最上面是层数 / 希望 / 源碳 / 作战耐久，中间是这一层的节点（起点在最左，出口在最右），
 *   只能点「当前节点连着的、还没走过的」节点。
 * 招募 / 战前编队直接用 M3 那套**拖动**（界面.拖动开始 / 拖动放下）。
 * 战斗节点进入自动战斗（M3 的内核），打完回到大地图。
 * ========================================================================== */

const 肉鸽界面 = {
  分队ID: null,
  提示: '',

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

  /* ---------------- 大地图 ---------------- */
  大地图屏() {
    const R = 肉鸽.RUN;
    if (!R) return '<section class="card"><p>还没有进行中的局。</p><a href="#" data-act="回菜单">回菜单</a></section>';
    const 当前 = 肉鸽.当前节点();
    const 可去 = new Set(肉鸽.能去的().map(n => n.id));
    const 列 = [];
    for (let c = -1; c <= 肉鸽数值.每层列数; c++) {
      const 本列 = R.地图.节点.filter(n => n.列 === c).sort((a, b) => a.序 - b.序);
      if (!本列.length) continue;
      列.push(`<div class="rv-col">${本列.map(n => {
        const 型 = 节点类型表[n.类型] || { 名: n.类型, 色: '#8a99ab' };
        const 态 = n.id === R.当前 ? ' here' : (n.已过 ? ' done' : (可去.has(n.id) ? ' can' : ''));
        const 动 = 可去.has(n.id) ? ` data-act="去节点:${n.id}"` : '';
        return `<button class="rv-node${态}" style="--fc:${型.色}"${动} title="${型.名}">
          <b>${型.名}</b><small>${c < 0 ? '起点' : (n.类型 === '出口' ? `去第 ${R.层 + 1} 层` : `第 ${c + 1} 站`)}</small></button>`;
      }).join('')}</div>`);
    }
    const 队伍 = R.队伍.map(m => `${allyName(m.键)}(${m.键} Lv${m.等级})`).join('、');
    const 战斗类 = ['战斗', '精英', 'Boss'].includes(当前 && 当前.类型);
    return `<section class="card">
      <h3>第 ${R.层} 层 · 大地图<span class="small">点一个亮着的节点走过去</span></h3>
      <div class="rv-bar2">
        <span class="rv-chip">希望 <b>${R.希望}</b></span>
        <span class="rv-chip">源碳结晶 <b>${R.源碳}</b></span>
        <span class="rv-chip${R.耐久 <= 30 ? ' warn' : ''}">作战耐久 <b>${R.耐久}</b></span>
        <span class="rv-chip">本层第 <b>${R.场次 + 1}</b> 场</span>
        <span class="rv-chip">种子 <b>${R.种子}</b></span>
      </div>
      <div class="rv-map2">${列.join('')}</div>
      <p class="small">队伍：${队伍}</p>
      <div class="acts">
        ${战斗类 ? `<button class="primary" data-act="备战">编队出战（${节点类型表[当前.类型].名}）→</button>` : ''}
        ${当前 && 当前.类型 === '招募' ? `<button class="primary" data-act="去招募">招募 →</button>` : ''}
        ${当前 && 当前.类型 === '补给' ? `<button class="primary" data-act="补给">领取补给 →</button>` : ''}
        ${当前 && 当前.类型 === '奇遇' ? `<button class="primary" data-act="去奇遇">看看奇遇 →</button>` : ''}
        <button data-act="存个档">存档</button>
        <button data-act="放弃本局">放弃本局</button>
      </div>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
      <p class="small">日志：${R.日志.slice(-3).map(x => x.文本).join('　|　')}</p>
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
      return `<button class="pick" data-act="招募:${t.mech}" data-drag="候选:${t.mech}" style="--fc:${势力色(t.mech)}">
        <span class="pk-top">${图标.卡(t.mech, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${t.pilot}</b><small>${t.mech} · ${t.tags.战斗分类} · ${t.tags.势力}</small></span></span>
        <span class="nums">速 ${p.速度} · HP ${p.hp}</span></button>`;
    }).join('');
    const 队 = R.队伍.map((m, i) => `<div class="rv-row"><span class="pk-top">${图标.卡(m.键, 'ally', 图标.尺寸.列表)}<span class="pk-nm"><b>${allyName(m.键)}</b><small>${m.键} · Lv${m.等级}</small></span></span></div>`).join('');
    return `<section class="card">
      <h3>招募<span class="small">队伍 ${R.队伍.length} / ${肉鸽数值.队伍上限}（满了就不能再招）</span></h3>
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

  /* ---------------- 奇遇 ---------------- */
  奇遇屏() {
    return `<section class="card">
      <h3>奇遇</h3>
      <p>路上遇到一支友军残骸。你要：</p>
      <div class="acts">
        <button class="primary" data-act="奇遇:希望">收拢士气（希望 +${肉鸽数值.奇遇希望}）</button>
        <button class="primary" data-act="奇遇:源碳">回收结晶（源碳 +${肉鸽数值.奇遇源碳}）</button>
        <button data-act="回大地图">离开</button>
      </div>
    </section>`;
  },

  /* ---------------- 本局结束 ---------------- */
  肉鸽结算屏() {
    const R = 肉鸽.RUN;
    if (!R) return '<section class="card"><p>本局已结束。</p></section>';
    return `<section class="card end ${R.耐久 > 0 ? 'win' : 'lose'}">
      <div class="eyebrow">${R.耐久 > 0 ? '本局结束' : '作战失败'}</div>
      <h2>走到第 ${R.层} 层</h2>
      <ul>
        <li>希望：<b>${R.希望}</b>　源碳结晶：<b>${R.源碳}</b>　作战耐久：<b>${R.耐久}</b></li>
        <li>队伍：<b>${R.队伍.length}</b> 台　藏品：<b>${R.藏品.length}</b> 件</li>
        <li>种子：<b>${R.种子}</b></li>
      </ul>
      <div class="acts"><button class="primary" data-act="回菜单">回菜单</button><button data-act="去分队">再来一局</button></div>
    </section>`;
  },
};

/* 小队成员的显示名（肉鸽界面用） */
function allyName(键) { const t = tplOf(键); return t ? t.pilot : 键; }
