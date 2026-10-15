  /* ---------------- 战斗 ---------------- */
  战斗屏() {
    if (!this.ctx) return '<section class="card"><p>还没有战斗。回菜单重新开始。</p></section>';
    const 指令阶段 = this.阶段 === '指令';
    const 我方单位 = 指令阶段 ? this.ctx.allies : (this.显示单位 ? this.显示单位.我方 : this.ctx.allies);
    const 敌方单位 = 指令阶段 ? this.ctx.enemies : (this.显示单位 ? this.显示单位.敌方 : this.ctx.enemies);
    const 意图 = 指令阶段 ? 算意图(this.ctx) : [];
    /* ★ 三层反馈的**预告**（作者 2026-10-12 拍板的第 2 件，§2.2 的「预告」列）：
       指令阶段每一屏算一次（全是纯读：`chooseAttack()` / `rowReachable()` / `按防御结算()` ——
       不改战斗状态、不消耗随机数），再交给每张卡片；播放阶段不算（`预告快照()` 自己会拦）。 */
    const 预告 = 指令阶段 ? 预告快照(this.ctx) : null;
    const 排 = (列表, 方, 从后往前) => {
      const 行序 = 从后往前 ? [ROW_BACK, ROW_FRONT] : [ROW_FRONT, ROW_BACK];
      /* ★ 2026-10-13（正交 4×2）：四列固定 —— 两排上下**严格对齐**（`.战斗屏 .row` 也是 `repeat(4,1fr)`）。 */
      return 行序.map(r => `<div class="row" style="--cols:${行列数(r)}">${Array.from({ length: 行列数(r) }, (_, c) => {
        const 位 = slotOf(r, c);
        const u = 列表.find(x => x.slot === 位);
        return u ? this.单位卡(u, 方, 意图.find(i => i.单位位 === 位), 指令阶段, 预告) : `<div class="uc empty"><span class="pos">${位名(位)}</span></div>`;
      }).join('')}</div>`).join('');
    };
    return `<section class="战斗屏">
      ${this.方针栏(指令阶段)}
      <div class="side ally">
        <h3>我方 <span class="small">${指令阶段 ? '点一张卡片改大招开关' : '后排在上 · 前排贴住接触线'}</span></h3>
        ${排(我方单位, 'ally', true)}
      </div>
      <div class="side enemy">
        <h3>敌方 <span class="small">${指令阶段 ? '卡上的箭头 = 它这一回合的意图' : '前排在上'}</span></h3>
        ${排(敌方单位, 'enemy', false)}
      </div>
      <aside class="logcol">
        ${指令阶段 ? this.指令面板() : ''}
        <h3>战斗记录</h3>
        <ol id="log"></ol>
      </aside>
      <!-- ★ 2026-10-13 任务书 §1 模块 4 / 5：战斗屏上点「ⓘ 详情」也要弹得出正文 —— 弹窗控件原来只在
           大地图 / 记录 / 晋升三屏画（界面.弹窗控件Html()），这里补一份，全屏通用才算数。 -->
      ${this.弹窗控件Html()}
    </section>`;
  },

  /* ---------------- 方针栏（作者 2026-10-12 拍板，§1.7） ----------------
   * 战场**上方一条**，5 个按钮，当前方针高亮；**战斗进行中也一直显示**（「玩家随时看得见现在全队在干什么」）。
   * 选「集中攻击」之后进入「点敌人」状态 → 点一张敌方卡片选目标（`点敌人()`）。
   * 五种类型 + 一句代价 / 收益，全部照 §1.2 那张表（**方针本身不带任何加成**）。 */
  方针栏(可点) {
    const p = this.ctx ? 当前方针(this.ctx) : this.方针;
    const 当前 = p.类型;
    const 目标 = this.ctx ? 方针目标(this.ctx) : null;
     const 一句 = {
      全军突击: '每台各自挑目标（代价 / 收益都没有）',
      集中攻击: '打得到的都打它；打不到的照常自由攻击',
      攻击后排: '优先打对面后排；打不到就照突击',
      前守后攻: '前排执行防御规则、后排照突击',
      全军防御: '放弃攻击；非攻击动作照常做，其余执行防御动作',
    };
    /* ★ 三层反馈的**预告**（作者 2026-10-12 拍板第 10 条）：这场打完会回多少血 ——
       肉鸽里（有 `RUN`）才画，练习模式 / 调参室（无 RUN）**一个字都不加**。
       数值一处取：`71-改动.js` 的 `战斗结构.HP继承.战后回血比例`。 */
    const 回血比例 = (() => {
      if (typeof 肉鸽 === 'undefined' || !肉鸽 || !肉鸽.RUN) return 0;
      const c = HP继承参数();
      const v = Number(c.战后回血比例);
      return Number.isFinite(v) && v > 0 ? v : 0;
    })();
    const 回血预告 = 回血比例 > 0
      ? `<p class="small" data-heal-forecast="1">战后休整（预告）：这一场打完，名册上<b>每一台</b>都回 ` +
        `<b>${Math.round(回血比例 * 100)}%</b> 最大 HP —— <b>0 HP 的也会回到 ${Math.round(回血比例 * 100)}%</b>（不会再有人躺在地上不出战）。</p>`
      : '';
    const 气预 = (this.ctx && typeof 气势战术预告 === 'function') ? 气势战术预告(this.ctx) : null;
    const 气势块 = (气预 && 气预.开)
      ? `<div class="cmds morale-bar" data-center="1" data-morale="${气预.气势}" data-morale-max="${气预.上限}">
          <span class="morale-label">气势 <b>${气预.气势} / ${气预.上限}</b></span>
          <div class="bar morale"><i style="width:${Math.max(0, Math.min(100, Math.round(气预.气势 / 气预.上限 * 100)))}%"></i></div>
          <button class="mini${气预.预约战术 === '总攻' ? ' on' : ''}" data-act="战术:总攻"${可点 && 气预.可发动 ? '' : ' disabled'}>⚡ 全军总攻${气预.预约战术 === '总攻' ? '（已预约）' : ''}</button>
          <button class="mini${气预.预约战术 === '掩护' ? ' on' : ''}" data-act="战术:掩护"${可点 && 气预.可发动 ? '' : ' disabled'}>🛡 紧急掩护${气预.预约战术 === '掩护' ? '（已预约）' : ''}</button>
          <button class="mini${气预.全队憋大招 ? ' on' : ''}"${可点 ? ' data-act="全队大招"' : ' disabled'}>全队大招：${气预.全队憋大招 ? '憋住' : '自动'}</button>
        </div>
        <p class="small tactic-forecast" data-tactic-forecast="1">${气预.文本}</p>`
      : '';
    const 手牌开 = !!(this.ctx && typeof 战术卡牌开 === 'function' && 战术卡牌开(this.ctx) && Array.isArray(this.ctx.战术手牌));
    const 手牌块 = 手牌开 ? (() => {
      const 手牌们 = Array.isArray(this.ctx.战术手牌) ? this.ctx.战术手牌 : [];
      const 待触发们 = Array.isArray(this.ctx.待触发战术牌) ? this.ctx.待触发战术牌 : [];
      const 待触发数 = 待触发们.length;
      const 当前气 = Number(this.ctx.气势) || 0;
      const 气上限 = (气预 && 气预.上限) || 100;
      const 上限 = Number(战术卡牌参数().手牌总上限) || 8;
      const 卡Html = 手牌们.map(c => {
        const 耗 = Number(c.耗气) || 0;
        const 回 = Number(c.回气) || 0;
        const 剩 = c.剩余次数 != null ? Number(c.剩余次数) : 1;
        const 冷却 = Number(c.当前冷却) || 0;
        const 够气 = 当前气 >= 耗 && 冷却 <= 0 && 剩 > 0;
        const 可打 = 可点 && 够气;
        const 层类 = c.层级 === '职业' ? 'tier-class' : (c.层级 === '势力' ? 'tier-faction' : (c.层级 === '角色' ? 'tier-char' : 'tier-cmd'));
        const 新类 = c.新触发 ? ' is-triggered' : '';
        const 气标 = 回 > 0 ? (耗 > 0 ? `-${耗}/+${回}气` : `+${回}气`) : `耗${耗}气`;
        const 气类 = 回 > 0 && 耗 === 0 ? ' is-gain' : ' is-cost';
        const 状态文 = !可点 ? '回合播放中' : (冷却 > 0 ? `冷却 ${冷却} 回合` : (当前气 < 耗 ? `需 ${耗} 气势` : '点击发动'));
        return `<button class="tactical-card ${层类}${新类}${可打 ? ' ready' : ''}" data-act="打战术牌:${c.id}" data-card-id="${c.id}" data-tier="${c.层级}"${可打 ? '' : ' disabled'} title="【${c.名}】（${c.层级}·${c.归属}）${c.效果说明}">
          <span class="tc-top"><span class="tc-tag">【${c.精神标签 || c.层级}】</span><span class="tc-sub">${c.层级}·${c.归属}${c.新触发 ? ' · ★新触发' : ''}</span><span class="tc-cost${气类}">${气标}</span></span>
          <b class="tc-name">${c.名}</b>
          <span class="tc-desc">${c.效果说明}</span>
          <span class="tc-foot"><span class="tc-uses">剩余 ${剩} 次</span><span class="tc-state">${状态文}</span></span>
        </button>`;
      }).join('');
      const 待触发Html = 待触发数
        ? 待触发们.map(p => `<span class="tp-chip" title="${p.效果说明}">🔒【${p.名}】<small>${p.触发说明}发牌</small></span>`).join('')
        : '<span class="small">（本场待触发条件牌已全部入牌）</span>';
      return `<div class="tactical-hand-bar" data-tactical-hand="1" data-hand-count="${手牌们.length}" data-pending-count="${待触发数}">
        <div class="th-head"><span>🎴 战术手牌（气势 <b>${当前气}/${气上限}</b> · 手牌 <b>${手牌们.length}/${上限}</b> · 待触发 <b>${待触发数}</b> 张）</span><span class="small">0费【激励】可回气启动连携 · 战中满足条件自动发牌</span></div>
        <div class="th-cards">${卡Html || `<span class="small">（当前手牌已打完 · 待触发条件牌: ${待触发数} 张，满足战况条件自动发牌）</span>`}</div>
        <div class="tactical-pending-row" data-tactical-pending="1"><span class="tp-label">待触发条件牌预览：</span>${待触发Html}</div>
      </div>`;
    })() : '';
    return `<div class="cmdpanel policybar">
      <h3>全队方针 · <b>${当前}</b>${目标 ? ` → ${目标.name}（${位名(目标.slot)}）` : ''}
        <span class="small">保持到改为止 · 单位层只有大招开关</span></h3>
      <div class="cmds" data-center="1">${方针们.map(k => `<button class="mini${当前 === k ? ' on' : ''}"${可点 ? ` data-act="方针:${k}"` : ' disabled title="这一回合正在播放，等它播完才能改（方针保持到改为止）"'}>${k}</button>`).join('')}</div>
      <p class="small">${一句[当前] || ''}${当前 === '集中攻击' ? (目标 ? '　目标已选。' : '　<b>还没点目标</b>：点一张敌方卡片。') : ''}
        ${可点 && this.选目标 ? '　<b>正在选目标：点一个敌人。</b>' : ''}${可点 ? '' : '　<b>播放中不能改方针</b>：这一回合播完就回到指令阶段。'}</p>
      ${气势块}
      ${手牌块}
      ${回血预告}
      ${可点 && this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
    </div>`;
  },

  /** 指令面板（§1.7）：单位卡片上只有「大招：自动 / 保留」（天人另有 TRANS-AM 开关）。
   *  先点一张我方卡片才会出现；没点就写一句提示。 */
  指令面板() {
    const 位 = this.选中位;
    if (位 == null) return `<div class="cmdpanel"><h3>单位开关</h3><p class="small">全队方针在上面那一栏。<b>点一张我方卡片</b>改这一台的大招开关（天人另有 TRANS-AM）。</p></div>`;
    const u = this.ctx.allies.find(x => x.slot === 位);
    if (!u) return '';
    const c = this.当前指令(位);
    const 大招 = (this.ctx && typeof 大招状态 === 'function') ? 大招状态(u, this.ctx) : null;
    const 锁提示 = (大招 && 大招.未解锁大招) ? ` <span class="ult-lock" data-ult-locked="1">大招：Lv${大招.解锁等级 || 20} 解锁</span>` : '';
    return `<div class="cmdpanel">
      <h3>单位开关 · ${u.name}<span class="small">${u.key} · ${u.tags.战斗分类} · ${位名(位)}</span></h3>
      <div class="cmds" data-center="1"><button class="mini${c.保留大招 ? ' on' : ''}" data-act="大招:${位}">大招：${c.保留大招 ? '保留' : '自动'}</button>${锁提示}</div>
      ${this.天人开关(位, u, c)}
      <p class="small">「保留」= 这一回合不放这个大招（推迟，不是作废）。其余交给上面的全队方针。</p>
      ${this.提示 ? `<p class="warn small">${this.提示}</p>` : ''}
    </div>`;
  },

  /** ★ **TRANS-AM 的单位级开关**（作者 2026-10-11 拍板原话「TRANS-AM 应该是单个单位开关的」）：
   *  指令面板上给**每台有 `transAm` 的机体**一个「TRANS-AM：自动 / 手动」开关；
   *  手动档多一个「**开 TRANS-AM**」按钮 —— **CD 没到就 `disabled`，并把为什么写在按钮上与下面那行小字里**
   *  （「为什么」和单位卡那一行**同源**：都读 `72-势力.js` 的 `天人手动可开()`，两处不会说两套话）。
   *  没有 `transAm` 的机体（拉塞 CB5）返回空串 —— 一张卡都不多画。
   *  ★ 开关存进**指令表**（`TRANSAM` / `本回合开TRANSAM`），和「大招：自动 / 保留」同一层、逐回合保留。 */
  天人开关(位, u, c) {
    if (!有TRANSAM(u, 天人参数())) return '';
    const 手 = c || this.当前指令(位);
    const 手动 = 手.TRANSAM === '手动';
    const 判 = 天人手动可开(u, 天人参数());
    const 开 = 手动
      ? `<button class="mini${手.本回合开TRANSAM ? ' on' : ''}" data-act="开TRANSAM:${位}"${判.可以 ? '' : ' disabled'}`
        + ` title="${判.可以 ? '点了就在本回合开' : '开不了：' + 判.原因}">`
        + `开 TRANS-AM${手.本回合开TRANSAM ? '（本回合已点）' : ''}${判.可以 ? '' : `（${判.原因}）`}</button>`
      : '';
    return `<div class="cmds" data-center="1">
        <button class="mini${手动 ? ' on' : ''}" data-act="TRANSAM:${位}">TRANS-AM：${手动 ? '手动' : '自动'}</button>${开}
      </div>
      <p class="small">${手动
        ? `手动档：CD 到了也<b>不会自动开</b>，要在本回合点「开 TRANS-AM」。${判.可以 ? `现在${判.原因}。` : `现在<b>开不了</b>：${判.原因}。`}`
        : '自动档（默认）：CD 一到就在回合开始自动开，不用点。'}</p>`;
  },

  单位卡(u, 方, 意图, 可点, 预告) {
    const 色 = 方 === 'ally' ? 势力色(u.key) : 敌方色;
    const hp = Math.max(0, Math.round(u.hp / u.maxHp * 100));
    const 动 = 可点 ? (方 === 'ally' ? ` data-act="选单位:${u.slot}"` : ` data-act="点敌人:${u.slot}"`) : '';
    const c = 方 === 'ally' ? this.当前指令(u.slot) : null;
    const 大招卡 = (方 === 'ally' && 预告 && 预告.大招) ? 预告.大招[u.slot] : ((方 === 'ally' && this.ctx && typeof 大招状态 === 'function') ? 大招状态(u, this.ctx) : null);
    const 锁行 = (大招卡 && 大招卡.未解锁大招) ? ` · <span class="ult-lock" data-ult-locked="1">大招：Lv${大招卡.解锁等级 || 20} 解锁</span>` : '';
    const 全队憋 = !!(方 === 'ally' && this.ctx && this.ctx.全队憋大招);
    const 指令行 = c ? `大招：${(c.保留大招 || 全队憋) ? '保留' : '自动'}${全队憋 ? '（全队憋住）' : ''}${锁行}` : '';
    /* ★ 2026-10-12（§1.7）：被「集中攻击」点名的敌机卡片上**一直挂标记**，直到它被击破或方针改掉。
       判定读**引擎的当前方针**（`ctx.方针`）—— 目标被击破时引擎会自动回到全军突击，
       界面跟着变，不会出现「界面写集中攻击、实际在自由攻击」。 */
    const 方针现 = this.ctx ? 当前方针(this.ctx) : this.方针;
    const 被点名 = 方 === 'enemy' && 方针现.类型 === '集中攻击' && 方针现.目标位 === u.slot;
    const 点目标中 = 方 === 'enemy' && 可点 && this.选目标 && 方针现.类型 === '集中攻击';
    /* 站桩 Boss（61-Boss.js）：大技能那一下前面标 ★；蓄力时直接写「蓄力中」——
       玩家在指令阶段就能看见 Boss 的节奏（方案 5.3 的意图显示）。
       ★ 2026-10-11：**敌方大招**（精锐 / 头目档的强武器，`战斗结构.敌方大招`）也标 ★ ——
       玩家因此能在指令阶段看到「这一回合必须扛住」的那一发（作者要的「有压力」）。
       ★ 2026-10-11 第二轮：大技能 / 范围武器再写一句**「将打哪几个位」**（`算意图()` 的 `落点们`）——
       形状收窄成 `col`（阻挡束）/ `cross` 之后，玩家能一眼看出「换位躲不躲得掉」（作者要的「可躲」）。 */
    const 落点文字 = 意图 && 意图.落点们 && 意图.落点们.length && 意图.形状 !== '单格'
      ? `　将打：${意图.落点们.map(位名).join('、')}（${意图.形状} 形状）` : '';
    const 意图行 = 意图 && 意图.武器
      ? `${意图.大技能 || 意图.大招 ? '★大技能 ' : ''}→ ${意图.目标名}(${位名(意图.目标位)}) · ${意图.武器} · 约 ${意图.期望}${意图.被挡 ? '（被挡 −20 命中）' : ''}${落点文字}`
      : (意图 ? (意图.蓄力 ? '蓄力中（这一回合不出手）' : '不行动') : '');
    const 选中 = 方 === 'ally' && this.选中位 === u.slot ? ' sel' : '';
    /* 势力特色（作者 2026-10-10；框架在 `72-势力.js`）：单位卡上多一行字，**只多这一行**——
       第一件 = 卫星国防军 SEED「累计 / 还差多少」与觉醒后的加成；没有特色的单位是空串。 */
    const 势力行 = 方 === 'ally' ? 势力卡行(u) : '';
    /* 秘银（势力特色第六件，`72-势力.js`）：**敌机卡**上显示它身上挂的标定（几层 / 谁挂的 / 兑现了没）——
       框架的 `势力卡行()` 只问我方单位（敌人卡走不到那里），所以这一行走 `秘银标定卡行()`；
       **没有标定 = 空串**（一张卡都不多画，别的战斗逐字不变；播放阶段的快照没有 `debuffs` 也走同一条）。 */
    const 标定行 = 方 === 'enemy' ? 秘银标定卡行(u) : '';
    /* ★ 三层反馈的**预告**（作者 2026-10-12 拍板的第 2 件，§2.2 的「预告」列）——
       只在**指令阶段**画（`可点` = 指令阶段；播放阶段传的是「这一回合开始时」的快照，
       那些单位对象没有齐全的武器运行期字段，也不该在播放中改口）。
       判据全部来自 `84-反馈.js` 的 `预告快照()`（纯读，不改状态、不消耗随机数）：
         · 大招开关：冷却剩几回合 / 「保留」时把「保留」标出来（§2.2 第 5 行）；
         · 攻击后排：每台我方标「打得到 / 打不到后排」（§2.2 第 3 行）；
         · 前守后攻 / 全军防御：进入防御的单位挂盾标 + 「防御值 +50」（§2.2 第 4 行）；
         · 集中攻击：被点名的那张敌机卡上写「全队对它的预计伤害合计 X / 它剩 Y HP」（§2.2 第 2 行）。 */
    const 预 = 可点 && 预告 ? 预告 : null;
    const 预告行们 = [];
    if (预 && 方 === 'ally') {
      const g = 预.大招 ? 预.大招[u.slot] : null;
      if (g && g.有大招) 预告行们.push(`大招${g.可放 ? '已就绪' : `冷却剩 ${g.冷却剩} 回合`}${g.保留 ? ' · <b>保留</b>（这一回合不放）' : ''}`);
      if (预.方针 === '攻击后排') 预告行们.push(预.后排我能 && 预.后排我能[u.slot] ? '打得到后排' : '打不到后排');
      if (预.防御位 && 预.防御位.includes(u.slot)) 预告行们.push(`🛡 防御姿态：${预.防御说明 || '防御值 +50'}`);
    }
    if (预 && 方 === 'enemy') {
      if (预.后排位 && 预.后排位.includes(u.slot) && 预.方针 === '攻击后排') 预告行们.push('攻击后排：全队优先打它');
      if (预.集中 && 预.集中.目标位 === u.slot) {
        预告行们.push(`全队对它的预计伤害合计 ${预.集中.预计伤害合计} / 它剩 ${预.集中.剩余HP} HP`
          + `（${预.集中.台数} 台打得到${预.集中.会打 < 预.集中.台数 ? `，这一回合 ${预.集中.会打} 台会打它` : ''}）`);
      }
    }
    /* ★ 敌人卡第一批（作者 2026-10-12 拍板的三张卡）：敌机卡上那几句**预告** ——
       「幻影：...处于隐匿...」「镜甲：打它会被反弹 N% 伤害」「献祭者：濒死自爆：落点 ...」。
       判定与文本都在 `84-反馈.js` 的 `敌人机制预告()`（**纯读**，不改状态、不消耗随机数）；
       只有真带着那三个能力键的敌人才有这一行 → 别的战斗一张卡都不多画。 */
    if (预 && 方 === 'enemy' && 预.敌人机制 && 预.敌人机制[u.slot]) {
      for (const 行 of (预.敌人机制[u.slot].行们 || [])) 预告行们.push(行);
    }
    const 预告行 = 预告行们.length ? `<div class="fb-line" data-forecast="1">${预告行们.join('<br>')}</div>` : '';
    /* ★ 2026-10-13 **标定经济（全职业通用的「传球」机制，作者拍板「OK」）· 预告那一层**：
       **敌机卡**上写「标定 ×N（来自 XX）」+ 一行「将被狙击引爆：暴击段伤害 +30%（暴击那一段 +25 档）」；
       **我方的产标者 / 引爆者**在自己的卡上挂一行 `.标定角标`（「产标：特种命中 +1 层」这种）。
       文本全部来自 `84-反馈.js` 的 `标定经济预告()`（**纯读**：不改状态、不消耗随机数）；
       没有标定 / 开关关掉 → 一个字都不多（一张卡都不多画）。
       ★ 样式**等 CSS 线落地后补**（K3 那条线正在搬 `src/css/main.css`，本线**只挂类名、不写样式**）：
         `标定` = 这张卡上带着标定（敌机）；`标定角标` = 我方的产标 / 引爆者。 */
    const 标定经 = 预 && 预.标定 ? 预.标定 : null;
    const 标定我 = 标定经 ? 标定经['我' + u.slot] : null;
    const 敌标定 = (方 === 'enemy' && 标定经) ? 标定经[u.slot] : null;
    const 标定经济行 = (方 === 'enemy' && 敌标定 && 敌标定.层数)
      ? `标定 ×${敌标定.层数}（来自 ${(敌标定.来源 || []).join('、') || '—'}）`
        + `<br>${敌标定.预告}`
      : ((方 === 'ally' && 标定我) ? 标定我.角标 : '');
    const 标定类 = (方 === 'enemy' && 敌标定 && 敌标定.层数) ? ' 标定' : (标定经济行 ? ' 标定角标' : '');
    /* ★ 敌人卡第一批 · 卡 C「献祭者」：进入**濒死区间**（HP 比例 < 35%，【初稿】）时敌机卡变红。
       判据 `濒死自爆吗()` 是**纯读**的（只读 `abilities` + HP 比例，不挂状态、不改战斗判定，
       配置在 `71-改动.js`）；播放阶段看的是这一回合开始时的快照，所以这回合里一直是红的。
       没有这个键的敌人 → `''`（class 字符串与改前**逐字相同**）。 */
    const 濒死 = 方 === 'enemy' && 濒死自爆吗(u);
    /* ★ 2026-10-13 ③「看见特色」· **战斗内状态角标区**（P1 预告层，本章**唯一的角标槽位**）：
       `<span class="特色角标">…</span>` —— `[重装护卫]` / `[首击闪+20]` / `[狙击免挡]` / `🎰好运暴×3`。
       · 判据全在 `84-反馈.js` 的 `特色角标们()`（**纯读**：只看单位自己 + 敌方阵容，不改状态、
         不消耗随机数、不给 `ctx.log` 加字段）；
       · **绝不占用 `class="faction"`（`.势力行`）** → 各 `tests/faction-*` 的
         `(html.match(/class="faction"/g) || []).length` 断言**一个都不动**（ATX 仍是 2）；
       · 播放阶段的快照没有 `buffs` → `特色角标们()` 返回空数组 → **一个角标都不多画**
         （别的战斗 / 别的阶段逐字不变）。 */
    const 角标们 = (typeof 特色角标们 === 'function') ? 特色角标们(u, 方, this.ctx) : [];
    const 角标行 = 角标们.length
      ? `<div class="特色角标行" data-特色角标="1">${角标们.map(x => `<span class="特色角标">${x}</span>`).join('')}</div>`
      : '';
    return `<div class="uc${u.hp <= 0 ? ' down' : ''}${濒死 ? ' dying' : ''}${选中}${被点名 ? ' marked' : ''}${点目标中 ? ' pickable' : ''}${标定类}" id="u-${方}-${u.slot}" data-side="${方}" data-slot="${u.slot}" style="--fc:${色}"${动}>
      <span class="pos">${位名(u.slot)}</span>
      <div class="head">${图标.卡(u.key, 方, 图标.尺寸.卡)}<div class="nm"><b>${u.name}</b><small>${u.key} · 速 ${speedOf(u)}</small></div></div>
      <div class="bar hp"><i style="width:${hp}%"></i></div>
      <div class="nums">HP ${Math.max(0, u.hp)} / ${u.maxHp}${u.shieldHp ? ` · 盾 ${u.shieldHp}` : ''}</div>
      <div class="tags">${(u.tags && u.tags.战斗分类) || ''}${u.weapons && u.weapons.filter(e => isUltimate(e.t)).length ? ' · 大招' : ''}</div>
      ${角标行}
      ${势力行 ? `<div class="faction">${势力行}</div>` : ''}
      ${标定行 ? `<div class="faction">${标定行}</div>` : ''}
      ${标定经济行 ? `<div class="faction 标定经济卡行" data-标定卡行="1">${标定经济行}</div>` : ''}
      ${被点名 ? `<div class="cmd">集中攻击（全队打它）</div>` : ''}
      ${预告行}
      ${方 === 'ally' && 指令行 ? `<div class="cmd">${指令行}</div>` : ''}
      ${方 === 'enemy' && 意图行 ? `<div class="intent">${意图行}</div>` : ''}
      <!-- ★ 2026-10-13 任务书 §1 模块 5：**战斗屏敌我单位卡**上的「ⓘ 详情」（5 屏入口之一）。
           参用战斗内目标写法 ally_位号 / enemy_位号（机体详情Html() 按 ctx 找那一台），
           所以点它看的是**这一台此刻的等级与状态**（不是图鉴里那份静态数据）。
           .uc 本体是 &lt;div&gt;（指令阶段带 data-act="选单位:N"），里面放 button 是合法的；
           事件委托按 closest('[data-act]') 取最里面那个 → 点详情走「看机体」、点卡片别处照旧选单位。 -->
      <button type="button" class="mech-info-btn" data-act="看机体:${方}_${u.slot}" title="查看 ${u.name} 的机体特性与武器详情">ⓘ 详情</button>
    </div>`;
  },

  /** 播放每应用一条记录就刷一次这张卡：血条、闪白、飘伤害数字、当前行动的人加一圈光。 */
  刷卡(方, 位, 飘) {
    const el = $(`#u-${方}-${位}`);
    if (!el || !el.style) return;
    const s = 播放.单位[方 + ':' + 位];
    if (!s) return;
    const i = el.querySelector ? el.querySelector('.bar.hp i') : null;
    if (i && i.style) i.style.width = Math.max(0, Math.round(s.hp / s.maxHp * 100)) + '%';
    const n = el.querySelector ? el.querySelector('.nums') : null;
    if (n) n.textContent = `HP ${Math.max(0, s.hp)} / ${s.maxHp}${s.shieldHp ? ` · 盾 ${s.shieldHp}` : ''}`;
    el.classList && el.classList.toggle('down', s.死);
    if (飘) {
      /* ★ 2026-10-13 **真 bug · 作者报的「播放到〔嘲讽〕卡住」的根因**（他遇到过两次）：
         这一行原来写的是 `el.classList.add(飘.暴击 ? 'hit crit' : 'hit')` —— **一个 token 里带空格**。
         真浏览器按 DOM 规范（`DOMTokenList.add`：token 不许含 ASCII 空白）直接抛
         `InvalidCharacterError: The token provided ('hit crit') contains HTML space characters...`；
         这个异常从 `播一步()` 冒出去，把 `播放.tick()`（`85-播放.js:76`）末尾那句 `排一次()` **整句跳过**
         → **定时器链断掉、这一回合再也不往下播**。而 `tick()` 是**先把 `位置++` 再叫钩子**的，
         所以画面停在**这一条的前一条**上 —— 暴击那一发前面紧挨着的那条正好是〔嘲讽〕（作者看到的就是它）。
         「跳过动画」能救：`跳到结尾()` 只调一次 `每步(null)`，**不走 `刷卡()`**。
         ⚠ 为什么测试一直没抓住：`tests/lib/dom-stub.mjs` 的 `classList` 不校验 token（吃掉空格照加），
         只有真浏览器会抛 —— 所以 `tests/battle_ui.js` 第 [14] 段现在**给替身补上同款校验**再钉这一条。
         改法：**一个 token 一次调用**（`hit` / `crit` 两个类照旧都挂上，`.uc.hit` 那颗闪白一个字没变；
         `crit` 只当标记类，与 `.float.crit` 同一族），不引入新 helper、不动别的类名。 */
      el.classList && el.classList.add('hit');
      if (飘.暴击 && el.classList) el.classList.add('crit');
      /* ★ 三层反馈的**即时**（作者 2026-10-12 拍板的第 2 件，§2.2 的「即时」列）：
         「伤害数字旁」那一个小标签（`集中` / `被挡 −20` / `防御 少挨 N`）——
         字段来自记录，`反馈标签()` 把记录翻成人话；没有那三个字段时**一个字都不多**（默认路径的显示也不变）。 */
      /* ★ 2026-10-13 ③「看见特色」（Guardian 审查补齐）：即时飘字按短签的**类名**挂上
         `.签-职业` / `.签-势力` / `.签-即时`（样式在 `src/css/main.css`）——
         **文本一个字不改**（还是 `反馈标签()` 拼出来的那一串），只在 `class` 上追加 token。 */
      const 签类 = Array.from(new Set(((飘.签们 || []).map(x => x && x.类).filter(Boolean)))).join(' ');
      const 签 = 飘.标签 ? `<span class="float-tag${飘.暴击 ? ' crit' : ''}${签类 ? ' ' + 签类 : ''}">${飘.标签}</span>` : '';
      if (飘.伤害 || 签) el.innerHTML += `<span class="float${飘.暴击 ? ' crit' : ''}">${飘.伤害 || ''}</span>${签}`;
    }
  },

  /* ---------------- 战斗流程 ---------------- */
  /** 由编队进入战斗：建立引擎状态（不再一次算完整场——玩家的方针每回合都可能改）。
   *  ★ 每一场新战斗开始时是**全军突击**（§1.3 第 1 条 / §6 第 1 条）。 */
  开战(种子) {
    const B = this.编队;
    if (!B.出击.length) return false;
    this.调参模式 = false;      // ★ 练习模式这一条路**永远**不是调参室（出击上限 / 编队同步都照旧）
    const 我方 = B.出击.slice().sort((a, b) => a.位 - b.位).map(x => ({ 键: x.键, 位: x.位, 等级: B.等级 }));
    const 条目 = 编成表[B.编成序号];
    const 敌方 = 敌方规格组(编成到单位(条目, 0));
    this.种子 = 种子 != null ? Number(种子) : Math.floor(Date.now() % 900000) + 100000;
    /* 敌方增援波次（作者 2026-10-10）：编成表里配的波次交给引擎，回合开始时按回合号补人 */
    this.ctx = 开局(我方, 敌方, this.种子, null, { 波次: 编成波次到单位(条目, 0) });
    this.方针 = { 类型: '全军突击', 目标位: null };
    this.单位开关 = {};
    this.选中位 = null;
    this.选目标 = false;
    this.提示 = '';
    this.显示单位 = null;
    this.战报 = null;
    this.阶段 = '指令';
    /* ★ 作战记录（作者 2026-10-12）：把「复现这一场所需要的规格」留一份（`88-战斗记录.js` 读它）。 */
    this.准备记录({ 我方, 敌方, 条目, 波次: 编成波次到单位(条目, 0), 来源: '练习' });
    this.开屏('战斗');
    return this.ctx;
  },

  /** 「开打」：把方针 + 单位开关交给引擎 → 打一回合 → 把这一回合的记录交给播放引擎放出来。 */
  开打() {
    if (!this.ctx || this.阶段 !== '指令') return false;
    /* ★ 「集中攻击」没点目标 = 这一条下不了（引擎也会把它当全军突击）；
       界面上直接写清「先点一个敌人」，不要让玩家以为点了没反应。 */
    if (this.方针.类型 === '集中攻击' && this.方针.目标位 == null) {
      this.提示 = '「集中攻击」要先点一张敌方卡片选目标。';
      this.刷();
      return false;
    }
    /* 记下这一回合**开始时**的状态：播放时血条从这里开始走。
       字段要够单位卡用（`速 ` 读 `speedOf()` 的 `mov` / `eva`）+ 势力特色那一行
       （`abilities` / `awaken` / `势力状态`，`势力卡行()` 读它们，第一件 = SEED 层数）——
       少了就会在播放阶段显示「速 NaN」/ 0 层（**顺手修掉的老问题：「速 NaN」**）。 */
    const 快照 = 列表 => 列表.map(u => ({
      side: u.side, slot: u.slot, key: u.key, name: u.name, maxHp: u.maxHp, hp: u.hp,
      shieldHp: u.shieldHp, tags: u.tags, weapons: u.weapons, abilities: u.abilities,
      mov: u.mov, eva: u.eva, awaken: u.awaken,
      /* ★ 天人的 TRANS-AM 单位级开关也要进快照（作者 2026-10-11 拍板）：不然播放阶段
         单位卡那一行会写回「开关：自动」，和指令阶段看到的不一致。 */
      TRANSAM手动: !!u.TRANSAM手动,
      势力状态: u.势力状态 ? JSON.parse(JSON.stringify(u.势力状态)) : null,
    }));
    this.显示单位 = { 我方: 快照(this.ctx.allies), 敌方: 快照(this.ctx.enemies) };
    设方针(this.ctx, this.方针);                 // 全队层（保持到玩家改为止）
    设单位开关(this.ctx, this.单位开关);          // 单位层（只有大招 / TRANS-AM）
    /* ★ 作战记录：这一回合下的是哪一条方针记进历史 —— 导出文本里的「方针表」就是它，
       同种子 + 同一串方针 = 同一场（作者要拿它复现那场战斗）。 */
    if (!this.方针历史) this.方针历史 = {};
    this.方针历史[this.ctx.turn] = { 类型: 当前方针(this.ctx).类型, 目标位: 当前方针(this.ctx).目标位 };
    const 记录 = 打一回合(this.ctx);
    /* ★ 集中攻击的目标被击破时引擎会**自动回全军突击**（§1.3 第 2 条）——界面跟着走。 */
    this.方针 = { 类型: 当前方针(this.ctx).类型, 目标位: 当前方针(this.ctx).目标位 };
    /* ★ TRANS-AM 的「本回合开」**点一次只管本回合**：打完了就把表里那一位清掉
       （`72-势力.js` 的 `手动开天人()` 读掉之后也会清单位上那一位）；
       开关 `TRANSAM`（自动 / 手动）**留着**——下一回合还是玩家上次选的那一档（逐回合保留）。 */
    for (const k of Object.keys(this.单位开关)) this.单位开关[k].本回合开TRANSAM = false;
    播放.载入({ 记录, 我方: this.显示单位.我方, 敌方: this.显示单位.敌方 });
    播放.手动 = !!this.手动播放;
    播放.快进 = !!this.跳过动画总是;
    this.阶段 = '播放';
    this.刷();
    播放.钩子.每步 = (ev, p) => this.播一步(ev, p);
    播放.钩子.结束 = () => this.回合播完();
    播放.开始();
    this.刷控件(); this.刷顶栏();
    return true;
  },

  /** 这一回合播放完了：分出胜负就去结算，否则回到指令阶段（**方针保持到改为止**）。 */
  回合播完() {
    音乐.回合结束();                 // M5：主题曲只保持到本回合结束（方案 8.2）
    /* ★ 调参室（§3.2 的「简单策略：第 1 回合全军防御 → 之后全军突击」）：这一场挂了按回合的方针表时，
       这里把下一回合该用的方针换成表里那一条（`95-调参室.js` 的 `调参回合播完()`）。
       **正常游戏的战斗 `ctx` 上没有 `调参方针表` → 这一行什么都不做**（播放时序与改动前一致）。 */
    if (typeof 调参回合播完 === 'function') 调参回合播完(this);
    if (this.ctx.result) return this.到结算();
    this.阶段 = '指令';
    this.选中位 = null;
    this.选目标 = false;
    this.提示 = '';
    this.刷();
    return true;
  },

  暂停() { 播放.暂停中 ? 播放.继续() : 播放.暂停(); this.刷控件(); return 播放.暂停中; },
  二倍速() { 播放.切倍速(); this.刷控件(); return 播放.倍速; },
  /** 跳过动画：立刻跳到本回合结尾；记住这个偏好，后面每回合直接到结尾。再按一次取消。 */
  设跳过动画(开) {
    this.跳过动画总是 = !!开;
    if (this.跳过动画总是 && this.阶段 === '播放') { 播放.快进 = true; 播放.跳到结尾(); }
    this.刷控件();
    return this.跳过动画总是;
  },
  跳过() { return this.设跳过动画(!this.跳过动画总是); },

  /** 播放一条记录：攻击者冲一下（并加一圈光）、受击方闪白 + 飘伤害数字，再追一行战斗记录。 */
  播一步(ev, p) {
    音乐.看记录(ev);                 // M5：我方放大招就切这台机体的主题曲（保持到本回合结束）
    /* ★ 三层反馈的**即时**（§2.2 的「即时」列）：这张卡上那一下要不要挂个小标签 ——
       `集中` / `被挡 −20` / `防御 少挨 N`（字段由引擎写在记录上；没有就一个标签都不画）。 */
    /* ★ 结构化短签（`反馈签们()`，`{ 文, 类 }`）：文本仍由 `反馈标签(ev)` 拼（**老断言逐字不变**），
       类名（`签-职业` / `签-势力` / `签-即时`）交给日志尾巴与飘字挂到 DOM 上（`§21.4` 登记的那三个类）。 */
    const 签们 = (ev && typeof 反馈签们 === 'function') ? 反馈签们(ev) : [];
    const 签 = 反馈标签(ev);
    if (ev && ev.目标方 != null) this.刷卡(ev.目标方, ev.目标位, { 伤害: ev.伤害, 暴击: ev.暴击 > 0, 标签: 签, 签们 });
    /* ★ 2026-10-13 **标定经济 · 即时（屏上给两张卡加「可见标记」）**：引爆那一下的记录
       （`类型:'标定'` 的 `引爆连锁` / `狙击连锁`）→ **引爆者**与**目标**两张卡都挂 `标定闪框`。
       ★ 作者 2026-10-13 的边界：**样式先不写死在这条线**（K3 那条线正在搬 `src/css/main.css`）——
        这里**只挂类名**，样式本体等 CSS 线落地后补（写在任务板里）。
       ★ 别的记录（`类型` 不是「标定」）→ 一段都不执行，播放时序与改动前**逐字相同**。 */
    if (ev && ev.类型 === '标定' && (ev.事件 === '狙击连锁' || ev.事件 === '引爆连锁')) {
      for (const [方, 位] of [[ev.单位方, ev.单位位], [ev.目标方, ev.目标位]]) {
        const el = $(`#u-${方}-${位}`);
        if (el && el.classList) el.classList.add('标定闪框');
      }
    }
    const 屏 = $('#screen');
    const 旧的 = 屏 && 屏.querySelectorAll ? 屏.querySelectorAll('.uc.act') : [];
    for (const el of 旧的) el.classList && el.classList.remove('act');
    if (ev && ev.单位方 != null) {
      const 攻击者 = $(`#u-${ev.单位方}-${ev.单位位}`);
      if (攻击者 && 攻击者.classList) 攻击者.classList.add('act');
    }
    const 日志 = $('#log');
    if (日志) {
      const 类 = ev ? (ev.类型 === '攻击' || ev.类型 === '残月余响' ? (ev.单位方 || '') : ev.类型 === '回合' ? 'sys' : 'sys2') : 'sys';
      /* ★ 即时短签的**类名**（`签-职业` / `签-势力` / `签-即时`，`§21.4`）挂到日志尾巴那一个 span 上：
         文本仍是 `反馈标签()` 拼出来的同一串（一个字不改），只在 `class` 上追加 token。 */
      const 签类们 = Array.from(new Set(签们.map(x => x && x.类).filter(Boolean))).join(' ');
      日志.innerHTML += ev ? `<li class="${类}"><span class="t">${ev.回合}</span>${ev.文本}${签 ? ` <span class="tagx${签类们 ? ' ' + 签类们 : ''}">〔${签}〕</span>` : ''}</li>` : '<li class="sys">（本回合播放结束）</li>';
      if (日志.scrollTop != null) 日志.scrollTop = 99999;
    }
    if (p) this.刷顶栏();
  },

  到结算() {
    const c = this.ctx;
    this.战报 = {
      结果: c.result ? c.result.结果 : '败', 原因: c.result ? c.result.原因 : '—',
      回合数: c.turn, 记录: c.log, 我方: c.allies, 敌方: c.enemies, 种子: c.种子,
      曾满气势回合: c.曾满气势回合 || null,
    };
    /* ★ 作战记录（作者 2026-10-12：「作战记录你看看能不能安排保存一下」）：
       **胜 / 败都存一份**完整逐条记录 —— 独立键 `mecha-autobattle-战斗记录`，与肉鸽存档无关
       （不改 `RUN`、不动存档版本号）。三层反馈的「保存」那一层 = `this.记录保存`
       （结算屏上那一条；肉鸽里拼进结果条那一条）。同一场只存一次。 */
    if (this.ctx && this.记录已存的ctx !== this.ctx) { this.记录已存的ctx = this.ctx; this.存本场记录(); }
    /* 肉鸽里的战斗：把结果交回肉鸽（发奖励 / 扣作战耐久 / 出口守军放行 / 追击后换层），
       然后回大地图；本局结束（耐久耗尽 / 通关）就去肉鸽结算屏。
       ★ 2026-10-11「界面体验修复」（作者：「现在很多事情结束以后，结果没有提示」）：
         打完之后**必须**在结果条上留一句「这一场拿到了什么 / 付出了什么」——
         以前这里一个 `提示` 都不设，玩家打赢回大地图只看到推进剂变了。 */
    if (this.肉鸽战斗) {
      const 这次 = this.肉鸽战斗;
      this.肉鸽战斗 = null;
      const r = 肉鸽.战斗结束(this.战报.结果, 这次.格类型, this.战报);
      /* 这一场的**奖励清单**原样存着（大屏上的「战斗结算清单」画它；只读返回值，不改任何奖励逻辑）。 */
      肉鸽界面.战斗结算 = r || null;
      /* ★ 三层反馈的**结算**（作者 2026-10-12 拍板的第 2 件，§2.2 / §2.4）：肉鸽里也照样出这一份 ——
         ① 存进 `肉鸽界面.战斗战报`（大地图与本局结算屏上画它）；
         ② **每一行写进 `RUN.日志`**（前缀 `〔战报〕`，记录屏 / 最近记录卡片上就看得到）。
         数据同样全部从这一场的记录里统计（`战报行们(战报)`），**不另开一套账**。 */
      /* ★ 战后回血（作者 2026-10-12 拍板，三层反馈的「结算」那一层）：**战斗结束屏**上也单独一行。
         数据直接读发动机返回值 `r.回血`（`90-肉鸽.js` 的 `战后回血()` 算的，**不另算一套**）；
         `记战后回血行()` 把那一句挂在 `肉鸽界面.战后休整行` 上 —— `84-反馈.js` 的 `战报行们()`
         会把它并进本场战报，于是**战斗结束屏 / 大地图 / 本局结算屏**三处一起看得见；
         `RUN.日志` 里那一句由 `战后回血()` 自己 `记()`（不重复记）。
         ★ **顺序**：先挂这一行、再算 `战报行们(战报)` —— 这样本场战报里就带着它（不是上一场那一句）。
         ⚠ 没有 RUN（练习模式 / 调参室 / `simulate()`）时 `r.回血` 为 null → **这一行一个字都不加**。 */
      if (r && r.回血) 肉鸽.记战后回血行(r.回血);
      const 战报行 = 战报行们(this.战报);
      肉鸽界面.战斗战报 = 战报行;
      if (肉鸽.RUN) for (const 行 of 战报行) 肉鸽.记(`〔战报〕${行}`);
      const 名 = (节点类型表[这次.格类型] && 节点类型表[这次.格类型].名) || 这次.格类型;
      const 首 = 战斗奖励清单文字(r);
      /* ★ 结算行两处：**战斗结束屏**（`战报行们()` 并进去的那一行）+ **肉鸽结果条**（下面这个 `· 后缀`）。
         ★ 2026-10-13 修「日志重复」（作者报：一份本局日志里每场写 4 行）：**这里原来调两次 `设结果()`** ——
           第一次是 `${名}胜利 —— ${首}…`，紧跟着又拿 `现条.文本 + ' · ' + 记提` 调第二次
           （`92-肉鸽界面.js` 的 `设结果()` 每次都往 `RUN.日志` 记一行）→ 同一句话记两遍、
           第二遍只多「本场记录已保存」那半句。现在**拼进同一次调用**：一次调用 = 一句日志。 */
      const 回血尾 = r && r.回血 ? ` · ${r.回血.文本}` : '';
      /* 存档那句话（三层反馈的「保存」那一层）**拼在同一次结果里**（原句照旧在最前面）。 */
      const 记提 = this.记录保存提示();
      const 存档尾 = (记提 && String(首 || '').indexOf('本场记录') < 0) ? ` · ${记提}` : '';
      /* `去重 = true`：引擎自己已经写过更细的一行（「XX胜利：希望 +N、源碳 +N」等），
         同一句话就不重复记 —— 结果条上那句话玩家照样看得到。 */
      if (r && r.胜) 肉鸽界面.设结果('成功', `${名}胜利 —— ${首}${回血尾}${存档尾}`);
      else if (r && r.结束) 肉鸽界面.设结果('失败', `${名}失败 —— ${首}（本局结束）${回血尾}${存档尾}`);
      else 肉鸽界面.设结果('失败', `${名}失败 —— ${首}${回血尾}${存档尾}`);
      this.阶段 = '结算';
      if (!肉鸽.进行中 || (肉鸽.RUN && 肉鸽.RUN.结局)) this.开屏('肉鸽结算');
      else this.开屏('大地图');
      return r;
    }
    this.阶段 = '结算';
    this.开屏('结算');
  },

