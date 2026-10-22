/* ============================================================================
 * 七、界面层（§3.1：**左选战斗 / 中调数 / 右看结果**）
 * ----------------------------------------------------------------------------
 * 全部画在一块 `界面.调参室屏()` 里（3 列），动作走 `data-act="调参室:<子动作>"`
 * （`80-界面.js` 的动作表里只多一个转发口 `调参室`）。
 * 滑条（`<input type="range" data-tune="…">`）走**自己的**事件委托：`input` 时只改模型 + 改那个数字，
 * **不整屏重画**（否则拖动会被打断）；`change`（松手）时才重画一次。
 * 自己挑人 / 摆位直接复用现成的编队交互（`data-act="选人:" / "放位:" / "取回:"` + `data-drag` / `data-drop`）——
 * 调参模式下 `界面.当前出击上限()` 固定 6（§3.2「从全角色里挑 3–6 台」）。
 * ========================================================================== */

/** 一个滑条（`data-tune` = `"路径:键"`，例如 `敌人:HP倍率` / `覆盖:captain:HP倍率`）。
 *  `范围` 里的 `最小 / 最大 / 步` 决定 input 的属性，`值` 是当前值。 */
function 调参滑条Html(路径, 标签, 值, 范围, 后缀) {
  const v = Number(值);
  return `<div class="tune-row" data-tune-row="${路径}">
    <label>${标签}</label>
    <input type="range" data-tune="${路径}" min="${范围.最小}" max="${范围.最大}" step="${范围.步}" value="${v}">
    <span class="val" data-tune-val="${路径}">${v}${后缀 || ''}</span>
  </div>`;
}

/** 调参室里那一块「我方出击」：等级 + 势力筛选 + 候选 + 9 格（复用编队交互）。 */
function 调参编队Html(界面对象) {
  const B = 界面对象.编队;
  const 势力们 = ['全部'].concat(FACTIONS);
  const 候选 = ALLY_T.filter(t => B.势力 === '全部' || inFaction(t, B.势力));
  const 列表 = 候选.filter(t => t && t.mech).map(t => {
    const p = 界面对象.预览(t.mech, B.等级);
    const 已上 = B.出击.some(x => x.键 === t.mech);
    return `<button class="pick${B.选中 === t.mech ? ' on' : ''}${已上 ? ' used' : ''}" data-act="选人:${t.mech}" data-drag="候选:${t.mech}" style="--fc:${势力色(t.mech)}">
      <span class="pk-top"><span class="pk-nm"><b>${t.pilot}</b><small>${t.mech} · ${t.tags.战斗分类} · ${t.tags.势力}</small></span></span>
      <span class="nums">速 ${p.速度} · HP ${p.hp}</span></button>`;
  }).join('');
  const 行格 = new Map();
  for (let r = ROWS - 1; r >= 0; r--) {
    for (let c = 0; c < 行列数(r); c++) {
      const 位 = slotOf(r, c);
      if (!行格.has(r)) 行格.set(r, []);
      const 占 = B.出击.find(x => x.位 === 位);
      if (占) {
        const p = 界面对象.预览(占.键, B.等级);
        行格.get(r).push(`<button class="slot filled" data-act="取回:${位}" data-drag="位:${位}" data-drop="${位}" style="--fc:${势力色(占.键)}">
          <span class="pos">${位名(位)}</span><span class="pk-top"><span class="pk-nm"><b>${界面对象.单位名(占.键, 'ally')}</b><small>${占.键} · 速 ${p.速度}</small></span></span>
          <span class="nums">HP ${p.hp}</span></button>`);
      } else {
        行格.get(r).push(`<button class="slot" data-act="放位:${位}" data-drop="${位}"><span class="pos">${位名(位)}</span><b>空位</b><small>${行名(r)}</small></button>`);
      }
    }
  }
  const 格 = [...行格.entries()].map(([r, 列表2]) => `<div class="row" style="--cols:${最大列数}">${列表2.join('')}</div>`).join('');
  return `<h4>我方（${B.出击.length} / ${调参出击上限}）<span class="small">拖到格子里，或点一名再点格子</span></h4>
    <div class="filters" data-center="1">
      ${[10, 20, 30].map(n => `<button class="mini${B.等级 === n ? ' on' : ''}" data-act="等级:${n}">Lv${n}</button>`).join('')}
      <span class="sep"></span>
      ${势力们.map(f => `<button class="mini${B.势力 === f ? ' on' : ''}" data-act="势力:${f}">${f}</button>`).join('')}
    </div>
    <div class="acts" data-center="1"><button data-act="默认五人队">默认五人队</button><button data-act="清空">清空</button></div>
    <div class="tune-grid">${格}</div>
    <div class="picks" data-center="1">${列表}</div>`;
}

/** 左列：选战斗（§3.2）。 */
function 调参左列Html(界面对象) {
  const s = 调参室模型.设置;
  const 候选 = 调参候选(s);
  const 层按钮 = [1, 2, 3, 4].map(k =>
    `<button class="mini${s.层 === k ? ' on' : ''}" data-act="调参室:层:${k}">第 ${k} 层</button>`).join('');
  const 类型按钮 = 调参节点类型们.map(t => {
    const 数 = 调参候选(Object.assign({}, s, { 类型: t })).length;
    const 现 = s.类型 === t;
    return `<button class="mini${现 ? ' on' : ''}" data-act="调参室:类型:${t}"${数 ? '' : ' disabled'}
      title="${数 ? `${数} 条编成` : '这一层没有这个类型的编成'}">${t}${数 ? `（${数}）` : '（—）'}</button>`;
  }).join('');
  const 条目按钮 = [`<button class="mini${s.条目 == null ? ' on' : ''}" data-act="调参室:条目:全部">这一类全部（${候选.length} 条）</button>`]
    .concat(候选.map(x => {
      const 选中 = s.条目 === x.下标;
      const 名 = `第${x.条目.层}层 ${x.条目.类型} #${x.下标}｜前 ${(x.条目.前 || []).join('+') || '—'} / 后 ${(x.条目.后 || []).join('+') || '—'}`;
      return `<button class="mini${选中 ? ' on' : ''}" data-act="调参室:条目:${x.下标}" title="${x.条目.考点 || ''}">${名}</button>`;
    })).join('');
  const 方针钮 = 调参方针们().map(p =>
    `<button class="mini${s.方针 === p ? ' on' : ''}" data-act="调参室:方针:${encodeURIComponent(p)}">${p === 调参简单策略 ? '简单策略（第 1 回合全军防御 → 之后全军突击）' : p}</button>`).join('');
  return `<div class="col">
    <h3>① 选战斗</h3>
    <h4>层</h4><div class="cmds" data-center="1">${层按钮}</div>
    <h4>节点类型</h4><div class="cmds" data-center="1">${类型按钮}</div>
    <h4>具体编成条目</h4><div class="cmds" data-center="1">${条目按钮}</div>
    ${候选.length ? '' : '<p class="warn small">这一层没有这个类型的编成：换一层或换一个类型。</p>'}
    <p class="small">${s.类型 === '终点'
      ? '「终点」= **第 4 层**的 Boss（蓝色大肥鱼那一档），层选择对它无效。'
      : `第 ${s.层} 层 ${s.类型}：${候选.length} 条编成（选「这一类全部」时，按场次轮着抽：第 1 场第 1 条、第 2 场第 2 条…）。`}</p>
    <h4>方针（整场）</h4><div class="cmds" data-center="1">${方针钮}</div>
    ${调参编队Html(界面对象)}
  </div>`;
}

/** 中列：调数（§3.3）。 */
function 调参中列Html() {
  const s = 调参室模型.设置;
  const 敌 = s.敌人;
  const 覆盖键 = Object.keys(s.覆盖);
  const Boss键 = Object.keys(Boss脚本 || {});
  const 覆盖行 = 覆盖键.map(k => {
    const c = s.覆盖[k];
    return `<div class="tune-row"><label>${k}</label>
      <span class="small">HP ×${c.HP倍率}、装甲 ×${c.装甲倍率}、威力 ×${c.威力倍率}</span>
      <button class="mini" data-act="调参室:覆盖去掉:${k}">去掉</button></div>`;
  }).join('');
  const Boss行 = Boss键.map(k => {
    const b = s.Boss[k] || {};
    const 基础 = Boss脚本[k] || {};
    const 阶段 = (基础.阶段 && 基础.阶段[0]) || {};
    return `<div class="tune-card">
      <h4>${k}<span class="small">（正式表：间隔 ${基础.大技能间隔}、倍率 ×${基础.伤害倍率}；半血后 ${阶段.大技能间隔} / ×${阶段.伤害倍率}）</span></h4>
      ${调参滑条Html(`Boss:${k}:大技能间隔`, '大技能间隔', b.大技能间隔 != null ? b.大技能间隔 : 基础.大技能间隔, { 最小: 0, 最大: 12, 步: 1 }, ' 回合')}
      ${调参滑条Html(`Boss:${k}:伤害倍率`, '伤害倍率', b.伤害倍率 != null ? b.伤害倍率 : 基础.伤害倍率, 调参倍率范围, '×')}
      ${调参滑条Html(`Boss:${k}:阶段间隔`, '半血后间隔', b.阶段间隔 != null ? b.阶段间隔 : (阶段.大技能间隔 != null ? 阶段.大技能间隔 : 0), { 最小: 0, 最大: 12, 步: 1 }, ' 回合')}
      ${调参滑条Html(`Boss:${k}:阶段倍率`, '半血后倍率', b.阶段倍率 != null ? b.阶段倍率 : (阶段.伤害倍率 != null ? 阶段.伤害倍率 : 1), 调参倍率范围, '×')}
      <div class="acts" data-center="1"><button class="mini" data-act="调参室:Boss清:${k}">这一台恢复正式表</button></div>
    </div>`;
  }).join('');
  const 敌人键们 = Object.keys(ENEMY_T).sort();
  const 当前键 = 调参室模型.选中敌人键 && ENEMY_T[调参室模型.选中敌人键] ? 调参室模型.选中敌人键 : 敌人键们[0];
  /* 「待加」的草稿优先（拖滑条时还没按「加上」；不然一重画就跳回旧值）。
     草稿的起点 = **当前的全局值**（这样「加上覆盖」在没拖之前是个空操作）。 */
  const 覆盖底 = (调参室模型.草稿 || {})[当前键] || s.覆盖[当前键]
    || { HP倍率: s.敌人.HP倍率, 装甲倍率: s.敌人.装甲倍率, 威力倍率: 1 };
  const 场次钮 = 调参场次们.map(n =>
    `<button class="mini${s.场次 === n ? ' on' : ''}" data-act="调参室:场次:${n}">${n} 场</button>`).join('');
  return `<div class="col">
    <h3>② 调数</h3>
    <h4>敌人全局倍率<span class="small">（默认 1 / 1 / 1 / 0）</span></h4>
    ${调参滑条Html('敌人:HP倍率', 'HP ×', 敌.HP倍率, 调参倍率范围, '×')}
    ${调参滑条Html('敌人:伤害倍率', '伤害 ×', 敌.伤害倍率, 调参倍率范围, '×')}
    ${调参滑条Html('敌人:装甲倍率', '装甲 ×', 敌.装甲倍率, 调参倍率范围, '×')}
    ${调参滑条Html('敌人:防御加成', '防御值 +', 敌.防御加成, 调参防御加成范围, '')}
    <p class="small">「伤害 ×」作用在**公式之后**的敌方伤害上（和 Boss 阶段倍率同一个口子）；「防御值 +」是**加法**。</p>

    <h4>按敌人键覆盖<span class="small">（取代全局那一项，不是叠加）</span></h4>
    <select class="sel" data-act="调参选敌人键">${敌人键们.map(k =>
      `<option value="${k}"${k === 当前键 ? ' selected' : ''}>${k}${ENEMY_T[k].mech ? ` · ${ENEMY_T[k].mech}` : ''}（${tierOfEnemy(k)}）</option>`).join('')}</select>
    ${调参滑条Html(`覆盖底:${当前键}:HP倍率`, 'HP ×', 覆盖底.HP倍率, 调参倍率范围, '×')}
    ${调参滑条Html(`覆盖底:${当前键}:装甲倍率`, '装甲 ×', 覆盖底.装甲倍率, 调参倍率范围, '×')}
    ${调参滑条Html(`覆盖底:${当前键}:威力倍率`, '威力 ×', 覆盖底.威力倍率, 调参倍率范围, '×')}
    <div class="acts" data-center="1"><button class="mini" data-act="调参室:覆盖加上:${当前键}">加上「${当前键}」的覆盖</button></div>
    ${覆盖行 || '<p class="small">还没有任何按键覆盖。</p>'}

    <h4>Boss 脚本</h4>
    ${Boss行 || '<p class="small">正式表里没有 Boss 脚本。</p>'}

    <h4>回合上限<span class="small">（只在调参室里生效）</span></h4>
    ${调参滑条Html('回合上限', '上限', s.回合上限 != null ? s.回合上限 : 0, 调参回合上限范围, '')}
    <p class="small">0 = 用引擎自己那套（按敌方档位：杂兵/精锐 12、头目 11、Boss 11）。</p>

    <h4>场次</h4><div class="cmds" data-center="1">${场次钮}</div>
    <p class="small">种子从 1 开始连续（第 1 场种子 ${s.种子起}，共 ${s.场次} 场 → 到 ${s.种子起 + s.场次 - 1}）。</p>
    <div class="acts" data-center="1">
      <button class="primary" data-act="调参室:跑">跑 ${s.场次} 场</button>
      <button data-act="调参室:清结果">清空结果</button>
      <button data-act="调参室:存储存">存进 localStorage</button>
      <button data-act="调参室:恢复默认">恢复默认</button>
    </div>
    <p class="small">存 localStorage（键 <code>${调参存档键}</code>），**只在调参室里生效**，正常游戏读都不读它。</p>
  </div>`;
}

/** 结果区里那一行「键 / 名 / 数字 / 占比 + 条形」。 */
function 调参条形行(名, 值, 占比, 最大) {
  const w = 最大 > 0 ? Math.round(值 / 最大 * 100) : 0;
  return `<div class="stat"><span class="nm">${名}</span><span class="n">${值}</span><span class="pc">${占比 != null ? 占比 + '%' : ''}</span></div>
    <div class="bar2"><i style="width:${w}%"></i></div>`;
}

/** 右列：看结果（§3.4）。 */
function 调参右列Html() {
  const s = 调参室模型.设置;
  const 句柄 = 调参室模型.结果;
  const 统计 = (句柄 && 句柄.统计) || 调参新统计();
  const 摘要 = 调参结果摘要(统计);
  const 进度 = 句柄 ? `${句柄.进度} / ${句柄.总场}` : `0 / ${s.场次}`;
  const 进度百 = 句柄 && 句柄.总场 ? Math.round(句柄.进度 / 句柄.总场 * 100) : 0;
  const 分布行 = 摘要.回合分布.map(x => 调参条形行(`${x.回合} 回合`, x.场数, null, Math.max(1, ...摘要.回合分布.map(y => y.场数)))).join('');
  const 阵亡行 = 摘要.阵亡分布.map(x => 调参条形行(`${x.阵亡} 台`, x.场数, null, Math.max(1, ...摘要.阵亡分布.map(y => y.场数)))).join('');
  const 先倒最大 = 摘要.先倒.length ? 摘要.先倒[0].值 : 1;
  const 先倒行 = 摘要.先倒.slice(0, 6).map(x => 调参条形行(`${调参单位名(x.键)}（${x.键}）`, x.值, null, 先倒最大)).join('');
  const 我伤最大 = 摘要.我方伤害.length ? 摘要.我方伤害[0].值 : 1;
  const 我伤行 = 摘要.我方伤害.slice(0, 8).map(x => 调参条形行(`${调参单位名(x.键)}（${x.键}）`, x.值, x.占比, 我伤最大)).join('');
  const 敌伤最大 = 摘要.敌方伤害.length ? 摘要.敌方伤害[0].值 : 1;
  const 敌伤行 = 摘要.敌方伤害.slice(0, 8).map(x =>
    `<div class="stat"><span class="nm">${ENEMY_T[x.键] ? ENEMY_T[x.键].mech : x.键}（${x.键}）</span><span class="n">${x.值}</span><span class="pc">${x.占比}%</span></div>
     <div class="bar2"><i style="width:${Math.round(x.值 / Math.max(1, 敌伤最大) * 100)}%"></i></div>`).join('');
  const 导出块 = 调参室模型.导出文本
    ? `<textarea data-tune="导出文本" readonly>${调参室模型.导出文本}</textarea>`
    : '<p class="small">点「复制设置」会在这里给出一段文字（人话改动清单 + JSON），发给我就行。</p>';
  return `<div class="col">
    <h3>③ 看结果</h3>
    ${句柄 && 句柄.错误 ? `<p class="warn small">${句柄.错误}</p>` : ''}
    <div class="tune-row"><label>进度</label><span class="small" data-tune-progress="1">${进度}（每批 ${调参每批场次} 场让出一次主线程）</span></div>
    <div class="bar2"><i style="width:${进度百}%"></i></div>
    <p class="small">${统计.总场 ? `这一批真的跑完 ${统计.总场} 场` : `还没跑（点中间的「跑 ${s.场次} 场」）`}</p>
    ${统计.总场 ? `
      <div class="tune-card">
        <h4>胜负</h4>
        <p><b>胜率 ${摘要.胜率}%</b>（${摘要.胜场} / ${摘要.总场}）　胜场平均回合 <b>${摘要.胜场平均回合}</b>　总平均 ${摘要.平均回合}</p>
      </div>
      <div class="tune-card"><h4>回合数分布</h4>${分布行}</div>
      <div class="tune-card"><h4>每场我方阵亡数</h4>${阵亡行}</div>
      <div class="tune-card"><h4>最常先倒下的是谁</h4>${先倒行 || '<p class="small">一场都没倒人。</p>'}</div>
      <div class="tune-card"><h4>我方每台伤害占比<span class="small">（合计 ${摘要.我方伤害合计}）</span></h4>${我伤行 || '<p class="small">没有输出记录。</p>'}</div>
      <div class="tune-card"><h4>敌方每台对我方的伤害占比<span class="small">（谁是威胁；合计 ${摘要.敌方伤害合计}）</span></h4>${敌伤行 || '<p class="small">没挨打。</p>'}</div>
    ` : ''}
    <div class="tune-card">
      <h4>看一场<span class="small">（用正常战斗界面播这一场，带记录）</span></h4>
      <div class="tune-row"><label>种子</label>
        <input type="number" data-tune="看一场种子" min="1" max="999999" value="${调参室模型.看一场种子 || s.种子起}">
        <button class="mini" data-act="看一场">看这一场 ▶</button></div>
      <p class="small">「这一类全部」时看的是第一条（${(调参候选(s)[0] || { 下标: '—' }).下标}）。看完点「回调参室」回来，结果与设置都还在。</p>
    </div>
    <div class="tune-card">
      <h4>交回给作者 / Claude</h4>
      <div class="acts" data-center="1">
        <button class="primary" data-act="调参室:复制设置">复制设置</button>
        <button data-act="调参室:读回">读回这段文字</button>
      </div>
      ${导出块}
      <div class="tune-row"><label>读回框</label>
        <input type="text" data-tune="读回框" value="" placeholder="把导出的那段文字粘到这里，再点「读回」"></div>
      ${调参室模型.提示 ? `<p class="warn small">${调参室模型.提示}</p>` : ''}
    </div>
  </div>`;
}

/** 调参室这一屏（3 列）。`刷()` 走 `this['调参室屏']()`。 */
界面.调参室屏 = function () {
  调参接线();          // 滑条 / 输入框的事件委托（只接一次，#screen 上）
  return `<section class="调参室屏">${调参左列Html(this)}${调参中列Html()}${调参右列Html()}</section>`;
};

/** 滑条 / 输入框的**事件委托**：`#screen` 只接一次（`刷()` 换 innerHTML 不会丢）。
 *  · `input`  → 只改模型 + 改那个数字（**不重画**，拖动不会被打断）；
 *  · `change` → 改完再重画一次（导出的文字 / 派生显示跟着更新）。 */
function 调参接线() {
  if (typeof document === 'undefined' || !document || !document.querySelector) return false;
  const 屏 = $('#screen');
  if (!屏 || !屏.addEventListener || 屏._接了调参) return false;
  屏._接了调参 = true;
  const 读 = e => {
    const t = e && e.target;
    if (!t || !t.getAttribute) return null;
    const 路径 = t.getAttribute('data-tune');
    if (!路径) return null;
    const 值 = t.value != null ? t.value : '';
    if (t.tagName === 'INPUT' || t.tagName === 'SELECT') 调参设滑条(路径, 值);
    else if (t.tagName === 'TEXTAREA' && 路径 === '导出文本') 调参室模型.读回框 = 调参室模型.读回框 || '';
    else if (t.tagName === 'TEXTAREA') 调参室模型.读回框 = 值;
    return 路径;
  };
  屏.addEventListener('input', e => { const p = 读(e); if (p) 调参刷数字(p); });
  屏.addEventListener('change', e => { const p = 读(e); if (p) 刷调参屏(); });
  return true;
}

/** 把一个滑条的值写进设置（`路径` 形如 `敌人:HP倍率` / `覆盖底:captain:HP倍率` / `Boss:bluefish:伤害倍率`）。 */
function 调参设滑条(路径, 值) {
  const 段 = String(路径 || '').split(':');
  const 组 = 段[0];
  const 数 = Number(值);
  if (!Number.isFinite(数)) return false;
  if (组 === '敌人') return !!调参室模型.设({ 敌人: { [段[1]]: 数 } });
  if (组 === '覆盖底') {
    const 键 = 段[1];
    if (!ENEMY_T[键]) return false;
    const s0 = 调参室模型.设置;
    const 旧 = 调参室模型.设置.覆盖[键]
      || { HP倍率: s0.敌人.HP倍率, 装甲倍率: s0.敌人.装甲倍率, 威力倍率: 1 };
    /* 只是「待加」的草稿：真的加上要按「加上这一台的覆盖」 */
    调参室模型.草稿 = Object.assign({}, 调参室模型.草稿 || {}, { [键]: Object.assign({}, 旧, { [段[2]]: 数 }) });
    return true;
  }
  if (组 === 'Boss') {
    const 键 = 段[1], 项 = 段[2];
    if (!Boss脚本 || !Boss脚本[键]) return false;
    return !!调参室模型.设({ Boss: { [键]: Object.assign({}, 调参室模型.设置.Boss[键] || {}, { [项]: 数 }) } });
  }
  if (组 === '回合上限') { 调参室模型.设({ 回合上限: 数 > 0 ? 数 : null }); return true; }
  if (组 === '看一场种子') { 调参室模型.看一场种子 = Math.max(1, Math.round(数)); return true; }
  if (组 === '读回框') { 调参室模型.读回框 = String(值); return true; }
  return false;
}

/** `input` 时只改那个数字（不重画）。 */
function 调参刷数字(路径) {
  if (typeof document === 'undefined' || !document || !document.querySelector) return false;
  const 屏 = $('#screen');
  const el = 屏 && 屏.querySelector ? 屏.querySelector(`[data-tune-val="${路径}"]`) : null;
  if (!el) return false;
  const 段 = String(路径).split(':');
  const 后缀 = (段[段.length - 1] === '防御加成') ? '' : (段[0] === '回合上限' || 段[2] === '大技能间隔' || 段[2] === '阶段间隔') ? ' 回合' : '×';
  el.textContent = String(调参滑条现值(路径)) + 后缀;
  return true;
}

/** 滑条当前该显示的值（从设置里现取）。 */
function 调参滑条现值(路径) {
  const 段 = String(路径).split(':');
  const s = 调参室模型.设置;
  if (段[0] === '敌人') return s.敌人[段[1]];
  if (段[0] === '覆盖底') {
    const 键 = 段[1];
    const s0 = 调参室模型.设置;
    const 草 = (调参室模型.草稿 || {})[键] || s0.覆盖[键]
      || { HP倍率: s0.敌人.HP倍率, 装甲倍率: s0.敌人.装甲倍率, 威力倍率: 1 };
    return 草[段[2]];
  }
  if (段[0] === 'Boss') {
    const 键 = 段[1], 项 = 段[2];
    const b = (s.Boss[键] || {})[项];
    if (b != null) return b;
    const 基础 = Boss脚本[键] || {}, 阶段 = (基础.阶段 && 基础.阶段[0]) || {};
    if (项 === '大技能间隔') return 基础.大技能间隔;
    if (项 === '伤害倍率') return 基础.伤害倍率;
    if (项 === '阶段间隔') return 阶段.大技能间隔 != null ? 阶段.大技能间隔 : 0;
    if (项 === '阶段倍率') return 阶段.伤害倍率 != null ? 阶段.伤害倍率 : 1;
  }
  if (段[0] === '回合上限') return s.回合上限 != null ? s.回合上限 : 0;
  return '';
}

function 刷调参屏() {
  if (界面.屏 === '调参室') 界面.刷();
  return true;
}

/** 调参室的「我方出击」直接把**编队屏那一套状态**（`界面.编队`）当输入 ——
 *  所以要把它同步回设置里（不然点完「放位」跑批用的还是进来时那张名单）。
 *  ★ 只有调参模式（`界面.调参模式`）下才写；**刚好等于默认五人队就写成 `null`**（导出 JSON 保持干净）。 */
function 调参同步编队() {
  if (!界面 || !界面.调参模式 || !界面.编队) return false;
  const 击 = (界面.编队.出击 || []).map(x => ({ 键: x.键, 位: x.位 })).sort((a, b) => a.位 - b.位);
  /* 「清空」之后一台都没有 → 跑批没法跑：**屏幕和设置一起回到默认五人队**（两处不许说两套话）。 */
  if (!击.length) { 界面.默认五人队(); return false; }
  const 默 = 默认五人队.map(x => ({ 键: x.键, 位: x.位 })).sort((a, b) => a.位 - b.位);
  const 是默认 = 击.length === 默.length && 击.every((x, i) => x.键 === 默[i].键 && x.位 === 默[i].位);
  调参室模型.设({ 等级: 界面.编队.等级, 出击: 是默认 ? null : 击 });
  return true;
}
/** 编队那 7 个动作在调参模式下会改到我方名单 → 事后同步一次（正常游戏里这一句立刻返回）。 */
for (const 名 of ['选人', '放位', '取回', '默认五人队', '清空', '等级', '势力']) {
  const 原 = 界面.动作表[名];
  界面.动作表[名] = function (参) { const r = 原.call(this, 参); 调参同步编队(); return r; };
}

/** 进调参室（菜单上那个入口）：载入 localStorage → 开屏。 */
function 去调参室() {
  调参室模型.载入();
  /* 编队区沿用现成的编队交互：默认把「默认五人队」摆上（调参模式下上限固定 6，见 `当前出击上限()`） */
  界面.调参模式 = true;
  界面.编队.等级 = 调参室模型.设置.等级;
  if (调参室模型.设置.出击) 界面.编队.出击 = 调参室模型.设置.出击.map(x => ({ 键: x.键, 位: x.位 }));
  else 界面.默认五人队();
  界面.提示 = '';
  界面.开屏('调参室');
  return 界面.屏 === '调参室';
}

/** ★「看一场」（§3.4）：用**正常的战斗界面**播这一场 —— 建 ctx（带调参）→ 开屏（战斗）→
 *  剩下的交给现成的「开打 ▶ / 播放 / 回合播完 / 结算」，**`85-播放.js` 的时序一个字节没动**。 */
function 调参开一场(种子) {
  调参同步编队();
  const 场景 = 调参场景(调参室模型.设置);
  if (!场景.用们.length) {
    调参室模型.提示 = '这一层没有这个类型的编成，先换一层 / 换一个类型。';
    刷调参屏();
    return false;
  }
  const s = 场景.设置;
  const 条目 = 场景.用们[0];
  const 种子号 = Math.max(1, Math.round(Number(种子 != null ? 种子 : (调参室模型.看一场种子 || s.种子起)) || s.种子起));
  const 选项 = { 波次: 编成波次到单位(条目.条目, 0) };
  const 调参 = 调参调参对象(s);
  if (Object.keys(调参).length) 选项.调参 = 调参;
  const 起手 = 调参回合方针(s, 1);
  界面.ctx = 开局(调参出击(s), 敌方规格组(编成到单位(条目.条目, 0)), 种子号, null, 选项);
  /* 「简单策略」在**播放过程中**自动换方针（第 1 回合全军防御 → 第 2 回合起全军突击）：
     表挂在 ctx 上，`80-界面.js` 的 `回合播完()` 会调 `调参回合播完()` 落地（正常游戏没有这张表）。 */
  if (typeof 调参方针(s) === 'object') 界面.ctx.调参方针表 = 调参方针(s);
  const 起手方针 = { 类型: 规整方针(起手), 目标位: (起手 && 起手.目标位 != null) ? 起手.目标位 : null };
  /* 「集中攻击」在调参室里没有「点一张敌机卡」这一步：目标位默认取**敌方前 1**（0 号位）——
     编成表每条编成都至少有 1 台前排，那一格开局一定有活人（§3.2 只给了「整场固定一条」）。 */
  if (起手方针.类型 === '集中攻击' && 起手方针.目标位 == null) 起手方针.目标位 = 0;
  界面.方针 = 起手方针;
  设方针(界面.ctx, 起手方针);
  界面.单位开关 = {};
  界面.选中位 = null;
  界面.选目标 = false;
  界面.提示 = '';
  界面.显示单位 = null;
  界面.战报 = null;
  界面.种子 = 种子号;
  界面.肉鸽战斗 = null;          // 调参室这一场不是肉鸽节点 → 打完回**战斗结算屏**
  界面.调参模式 = true;
  界面.阶段 = '指令';
  界面.开屏('战斗');
  return true;
}

/** ★ §3.4 的「**看一场**」按钮：任选一个种子，用**正常的战斗界面**播这一场（带记录）。 */
function 看一场(种子) { return 调参开一场(种子); }

/** ★ 「简单策略」的自动换方针（`80-界面.js` 的 `回合播完()` 里那一个**空转**钩子）。
 *  正常游戏的战斗没有 `ctx.调参方针表` → 立刻返回，什么都不做。 */
function 调参回合播完(界面对象) {
  const ctx = 界面对象 && 界面对象.ctx;
  if (!ctx || !ctx.调参方针表) return false;
  const p = 第几回合的方针(ctx.调参方针表, ctx.turn);
  const 类型 = 规整方针(p);
  界面对象.方针 = { 类型, 目标位: (p && p.目标位 != null) ? p.目标位 : null };
  return true;
}

/** 「按敌人键覆盖」那个下拉（`<select data-act="调参选敌人键">`）：换一个要调的敌人键。
 *  ⚠ 为什么下拉**不能**写 `data-act="调参室:选敌人键"`：`80-界面.js` 的接线对 `SELECT` 传的是**它的 value**
 *  当「参」用（`选分队:近卫` 那套老约定）—— 那样 `调参室动作()` 收到的「参」会变成敌人键、被当成子动作名。
 *  所以下拉单独用一个动作名（值就是敌人键）。 */
function 调参选敌人键(键) {
  if (ENEMY_T[键]) 调参室模型.选中敌人键 = 键;
  if (界面.屏 === '调参室') 界面.刷();
  return true;
}

/** 调参室的所有按钮都走这里（`data-act="调参室:<子动作>[:参数]"`）。 */
function 调参室动作(参) {
  const 名 = String(参 == null ? '' : 参);
  const i = 名.indexOf(':');
  const 头 = i < 0 ? 名 : 名.slice(0, i);
  const 尾 = i < 0 ? '' : 名.slice(i + 1);
  const M = 调参室模型;
  switch (头) {
    case '层': M.设({ 层: Number(尾), 条目: null }); break;
    case '类型': M.设({ 类型: 尾, 条目: null }); break;
    case '条目': M.设({ 条目: 尾 === '全部' ? null : Number(尾) }); break;
    case '方针': M.设({ 方针: decodeURIComponent(尾) }); break;
    case '场次': M.设({ 场次: Number(尾) }); break;
    case '选敌人键': M.选中敌人键 = 尾; break;    case '覆盖加上': {
      const 键 = 尾;
      if (!ENEMY_T[键]) { M.提示 = '认不出的敌人键：' + 键; break; }
      const 草 = (M.草稿 || {})[键] || M.设置.覆盖[键] || { HP倍率: 1, 装甲倍率: 1, 威力倍率: 1 };
      M.设({ 覆盖: { [键]: 草 } });
      if (M.草稿) delete M.草稿[键];
      break;
    }
    case '覆盖去掉': {
      const 覆 = Object.assign({}, M.设置.覆盖);
      delete 覆[尾];
      M.设置 = M.规整(Object.assign({}, M.设置, { 覆盖: 覆 }));
      M.保存();
      break;
    }
    case 'Boss清': {
      const B = Object.assign({}, M.设置.Boss);
      delete B[尾];
      M.设置 = M.规整(Object.assign({}, M.设置, { Boss: B }));
      M.保存();
      break;
    }
    case '跑': 开始跑批(); return M.结果;
    case '清结果': M.清结果(); break;
    case '存储存': M.保存(); M.提示 = '已存进 localStorage（键 ' + 调参存档键 + '）。'; break;
    case '恢复默认': M.恢复默认(); 界面.默认五人队(); break;
    case '复制设置': {
      调参同步编队();
      const 文 = M.导出();
      /* 真的复制一份（浏览器给不给是它的事，失败也不抛 —— 文本框里照样看得到） */
      try {
        const nv = (typeof navigator !== 'undefined') ? navigator : null;
        if (nv && nv.clipboard && nv.clipboard.writeText) nv.clipboard.writeText(文);
      } catch (e) { /* 忽略：文本框才是唯一可靠的交付方式 */ }
      M.提示 = '已导出（下面那个框：人话清单 + JSON，Ctrl+C 或直接发给我）。';
      break;
    }
    case '读回': {
      const s = M.读回(null);
      if (s) { 界面.编队.等级 = s.等级; 界面.编队.出击 = 调参出击(s).map(x => ({ 键: x.键, 位: x.位 })); }
      break;
    }
    default: M.提示 = '认不出的调参室动作：' + 名;
  }
  if (界面.屏 === '调参室') 界面.刷();
  return true;
}

/** 跑批（§3.4 的分批跑）：每批 10 场，批间用 `setTimeout(…, 0)` 让出主线程。
 *  ★ 句柄同时留在 `调参室模型.结果` 里 —— 测试可以**手工**驱动它（DOM 替身里 `setTimeout` 是空转的），
 *    这一条保证「分批跑的进度与总场数」真的测得出来。 */
function 开始跑批() {
  const M = 调参室模型;
  调参同步编队();          // 屏幕上那张名单就是这一次跑的名单
  M.提示 = '';
  const 句柄 = M.分批跑(句 => {
    /* 进度先画到 DOM 上（**不整屏重画**：重画会把进度条换掉） */
    调参画进度(句);
    if (!句.完) 排下一批(句);
    else 刷调参屏();
  });
  调参画进度(句柄);
  if (句柄.完 || 句柄.错误) 刷调参屏();
  return 句柄;
}

/** 排下一批：让出一次主线程（`setTimeout(…, 0)`）；没有定时器（测试替身）就同步跑完。 */
function 排下一批(句柄) {
  if (typeof setTimeout === 'function') setTimeout(() => { 句柄.继续(); }, 0);
  else 句柄.继续();
  return 句柄;
}

function 调参画进度(句柄) {
  if (typeof document === 'undefined' || !document || !document.querySelector) return false;
  const 屏 = $('#screen');
  const el = 屏 && 屏.querySelector ? 屏.querySelector('[data-tune-progress="1"]') : null;
  if (!el) return false;
  el.textContent = `${句柄.进度} / ${句柄.总场}（每批 ${句柄.每批} 场让出一次主线程）`;
  const bar = 屏.querySelector ? 屏.querySelector('.bar2 i') : null;
  if (bar && bar.style && 句柄.总场) bar.style.width = Math.round(句柄.进度 / 句柄.总场 * 100) + '%';
  return true;
}

