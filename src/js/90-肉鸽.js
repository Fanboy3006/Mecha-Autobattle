/* ============================================================================
 * 肉鸽外壳（方案第 7 节）· 从机甲战棋复制 + 简化
 * ----------------------------------------------------------------------------
 * 带过来的：分队、招募券、希望、源碳结晶、作战耐久、层与节点大地图、藏品框架、存档。
 * 换掉的：节点里的「战斗 / 精英 / Boss」不再进战棋，而是进**自动战斗**（M3 的内核）。
 * 第一期不做的：侵蚀场、战斗里的零件、涉及格子 / 移动 / 地形的藏品（都列在 docs/特技换算待办.md）。
 *
 * ⚠ 数值：下面的 `肉鸽数值` 是按战棋那套抄的**初稿**（出处写在注释里），等作者看过再调。
 *
 * 状态全在 `RUN` 里，能整个 JSON 存进 localStorage —— 这就是「关掉页面能继续」。
 * ========================================================================== */

const 存档键 = 'mecha-autobattle-run-v1';

/* 数值初稿（出处：战棋 27-开局.js / 28-层.js / 30-移动与节点.js 的同类数值；等作者确认） */
const 肉鸽数值 = {
  /* 初始值抄战棋 27-开局.js:33：希望 8、源碳结晶 20、作战耐久 10 */
  起始希望: 8,
  起始源碳: 20,
  起始耐久: 10,
  /* 地图：这里是**简化版**（一列一列的节点），战棋是 6×4 网格 + 四邻接 BFS + 推进剂，见任务板的说明 */
  每层列数: 2,
  每列节点数: 3,
  /* 奖励 / 消耗（战棋同类处的数值，先按这一版定，等作者看） */
  胜利希望: 3,
  精英希望: 6,
  Boss希望: 10,
  胜利源碳: 5,
  补给源碳: 8,
  队伍上限: 12,              // 战棋：队伍上限 12（出击另有上限，见 出击上限）
  出击上限: 5,               // 我们的阵型只有 5 格（前 3 后 2）
  招募等级: 10,              // 战棋：招到的机师 Lv10
  招募费: { S: 5, A: 3, B: 0 },   // 战棋：精锐 5 / 骨干 3 / 普通 0 希望
  奇遇希望: 4,
  奇遇源碳: 10,
};

const 节点类型表 = {
  战斗: { 名: '作战', 色: '#4f95e0' },
  精英: { 名: '精英作战', 色: '#e9a23b' },
  Boss: { 名: 'Boss', 色: '#d9564b' },
  招募: { 名: '招募', 色: '#5cc08a' },
  补给: { 名: '补给', 色: '#7fb3d5' },
  奇遇: { 名: '奇遇', 色: '#cfa8ff' },
  出口: { 名: '层出口', 色: '#ffffff' },
};

/** 队伍成员的等级：按层数涨（第 1 层 Lv10、第 2 层 Lv20、第 3 层 Lv30） */
const 招募等级 = 层 => Math.min(30, 10 * Math.max(1, Math.min(3, 层)));

const 肉鸽 = {
  RUN: null,
  进行中: false,

  /* ---------------- 开局 ---------------- */
  新的一局(分队, 种子) {
    const 种 = (种子 >>> 0) || (Math.floor(Date.now() % 900000) + 100000);
    const rng = mulberry32(种);
    const RUN = {
      版本: 1, 种子: 种, t0: Date.now(),
      分队: 分队 || '无',
      层: 1, 场次: 0,
      希望: 肉鸽数值.起始希望,
      源碳: 肉鸽数值.起始源碳,
      耐久: 肉鸽数值.起始耐久,
      队伍: 默认五人队.map(x => ({ 键: x.键, 等级: 10 })),   // 队伍（名册，上限 12）
      出击: 默认五人队.map(x => x.键),                        // 出击名单（最多 5 台，前 3 后 2）
      券: 2,                                                // 战棋：开局送 2 张招募券 + 1 名免费 Lv20
      藏品: [], 券: [],
      日志: [],
      当前: null,            // 当前所在节点 id
      地图: null,
    };
    this.RUN = RUN;
    this.进行中 = true;
    RUN.地图 = this.生成层(RUN, rng);
    RUN.当前 = RUN.地图.起点;
    this.记(`第 ${RUN.层} 层：出发（${RUN.队伍.length} 台机体）`);
    return RUN;
  },

  /* ---------------- 战斗节点：抽一条编成 ---------------- */
  /** 当前节点对应的**编成表类型**（普通 / 精英 / Boss）。
   *  注意：节点类型叫「战斗」，编成表里叫「普通」——两边名字必须在这里对齐，
   *  否则战斗节点会抽不到编成（M4 交付时的真 bug，测试也一起补上了）。 */
  当前战斗类型() {
    const n = this.当前节点();
    if (!n) return '普通';
    if (n.类型 === '精英') return '精英';
    if (n.类型 === 'Boss') return 'Boss';
    return '普通';
  },
  是战斗节点() { const n = this.当前节点(); return !!n && ['战斗', '精英', 'Boss'].includes(n.类型); },
  /** 抽这一场用的编成（层 + 类型 + 场次 + 节点，全部进种子，所以同一局同一节点每次一样） */
  抽当前编成() {
    const R = this.RUN;
    if (!R) return null;
    const n = this.当前节点() || { 序: 0 };
    const rng = mulberry32((R.种子 + R.层 * 131 + R.场次 * 17 + (n.序 || 0) * 7) >>> 0);
    return 抽编成(R.层, this.当前战斗类型(), rng);
  },

  /* ---------------- 层与节点地图 ----------------
     每层：起点 → 第 1 列（3 个节点）→ 第 2 列（3 个）→ 出口。
     玩家每次只能移动到「当前节点连着的、还没走过的」节点。 */
  生成层(RUN, rng) {
    const r = rng || mulberry32(RUN.种子 + RUN.层 * 7919);
    const 节点 = [];
    const 加 = (列, 序, 类型) => {
      const id = `L${RUN.层}-${列}-${序}`;
      节点.push({ id, 列, 序, 类型, 通: [], 已过: false });
      return id;
    };
    const 起点 = 加(-1, 0, '起点');
    const 列们 = [];
    for (let c = 0; c < 肉鸽数值.每层列数; c++) {
      const 本列 = [];
      for (let i = 0; i < 肉鸽数值.每列节点数; i++) 本列.push(加(c, i, this.抽节点类型(c, RUN.层, r)));
      列们.push(本列);
    }
    /* 出口：最后一列的每个节点都能去（第 3 层以上是 Boss 关，见 出口类型()） */
    const 出口类型 = this.出口类型(RUN.层);
    const 出口 = 加(肉鸽数值.每层列数, 0, 出口类型);

    连(起点, 列们[0]);
    for (let c = 0; c + 1 < 列们.length; c++) 连(列们[c], 列们[c + 1]);
    连(列们[列们.length - 1], [出口]);

    function 连(从们, 到们) {
      const 源 = Array.isArray(从们) ? 从们 : [从们];
      for (const a of 源) {
        const 甲 = 节点.find(n => n.id === a);
        if (!甲) continue;
        /* 每个节点连到下一列的 1–2 个节点（带上一点随机，但不至于全连） */
        const 目标 = 到们.filter(() => r() < 0.75);
        const 选 = 目标.length ? 目标 : [到们[Math.floor(r() * 到们.length)]];
        for (const b of 选) if (!甲.通.includes(b)) 甲.通.push(b);
      }
      /* 保证下一列每个节点都至少有一条入边（不然会出现到不了的节点） */
      for (const b of 到们) {
        const 乙 = 节点.find(n => n.id === b);
        if (!节点.some(n => n.通.includes(b))) {
          const 随便 = 节点.find(n => 源.includes(n.id));
          if (随便) 随便.通.push(b);
        }
      }
    }
    /* 出口永远可达：最后一列的每个节点都连出口（上面的规则可能漏掉） */
    for (const n of 节点.filter(n => n.列 === 肉鸽数值.每层列数 - 1)) if (!n.通.includes(出口)) n.通.push(出口);
    return { 节点, 起点, 出口 };
  },
  /* 战棋：3 层航区 + 第 4 层终点（蓝色大肥鱼）。这里：前 3 层走到出口就上一层，第 4 层的出口是终点 Boss。 */
  出口类型(层) { return 层 >= 4 ? 'Boss' : '出口'; },
  抽节点类型(列, 层, r) {
    const 表 = 列 === 0
      ? [['战斗', 6], ['招募', 2], ['补给', 2]]
      : [['战斗', 4], ['精英', 4], ['奇遇', 2]];
    const 总 = 表.reduce((a, [, w]) => a + w, 0);
    let x = r() * 总;
    for (const [类型, w] of 表) { if ((x -= w) < 0) return 类型; }
    return '战斗';
  },

  /* ---------------- 移动 ---------------- */
  当前节点() { const R = this.RUN; return R && R.地图 ? R.地图.节点.find(n => n.id === R.当前) : null; },
  能去的() {
    const n = this.当前节点();
    if (!n) return [];
    return n.通.map(id => this.RUN.地图.节点.find(x => x.id === id)).filter(x => x && !x.已过);
  },
  /** 走到一个相邻节点，并结算它。返回节点类型（给界面决定开哪个屏）。 */
  移动(id) {
    const R = this.RUN;
    if (!R) return null;
    const 可 = this.能去的().map(n => n.id);
    if (!可.includes(id)) return null;
    const n = R.地图.节点.find(x => x.id === id);
    R.当前 = id;
    this.存档();
    return n.类型;
  },
  /** 节点结算完成（战斗打完 / 招募完 / 补给完）：标记已过，准备去下一层或继续走 */
  节点完成() {
    const R = this.RUN;
    const n = this.当前节点();
    if (!n) return;
    n.已过 = true;
    if (n.类型 === '出口') this.下一层();
    this.存档();
  },

  /* ---------------- 战斗节点的结果 ---------------- */
  /** 战斗结束（从界面回调）：胜 → 奖励；败 → 按剩下的敌人数扣作战耐久（战棋的规则）。 */
  战斗结束(结果, 类型, 战报) {
    const R = this.RUN;
    if (!R) return null;
    const 是胜 = 结果 === '胜';
    if (是胜) {
      const 希望 = 类型 === 'Boss' ? 肉鸽数值.Boss希望 : (类型 === '精英' ? 肉鸽数值.精英希望 : 肉鸽数值.胜利希望);
      R.希望 += 希望;
      R.源碳 += 肉鸽数值.胜利源碳;
      R.场次++;
      this.记(`${节点类型表[类型] ? 节点类型表[类型].名 : 类型}胜利：希望 +${希望}、源碳 +${肉鸽数值.胜利源碳}`);
      this.节点完成();
      return { 胜: true, 希望, 源碳: 肉鸽数值.胜利源碳 };
    }
    const 扣 = this.失败耐久(战报);
    R.耐久 -= 扣;
    this.记(`战斗失败：作战耐久 −${扣}（按剩下的敌人数算，剩 ${R.耐久}）`);
    if (R.耐久 <= 0) { this.失败('作战耐久耗尽'); return { 胜: false, 结束: true, 扣 }; }
    /* 失败不通过节点：留在原地（可以再挑别的路，或者再打一次） */
    this.存档();
    return { 胜: false, 扣 };
  },

  /* ---------------- 招募 / 补给 / 奇遇 ---------------- */
  /** 招募（战棋：花希望——精锐 5 / 骨干 3 / 普通 0；招到 Lv10；队伍上限 12；不能重复） */
  招募(键) {
    const R = this.RUN;
    if (!R) return { ok: false, why: '没有进行中的局' };
    if (R.队伍.length >= 肉鸽数值.队伍上限) return { ok: false, why: `队伍已经满了（${肉鸽数值.队伍上限} 台）` };
    if (R.队伍.some(m => m.键 === 键)) return { ok: false, why: '这位机师已经在队里了' };
    const 费 = 肉鸽数值.招募费[tierOf(键)] || 0;
    if (R.希望 < 费) return { ok: false, why: `希望不够（要 ${费}，只有 ${R.希望}）` };
    R.希望 -= 费;
    R.队伍.push({ 键, 等级: 肉鸽数值.招募等级 });
    if (R.出击.length < 肉鸽数值.出击上限) R.出击.push(键);
    this.记(`招募 ${键}（Lv${肉鸽数值.招募等级}，花希望 ${费}）`);
    this.节点完成();
    return { ok: true, 费 };
  },
  /** 出击名单（最多 5 台，前 3 后 2）：加/减一台 */
  切换出击(键) {
    const R = this.RUN;
    if (!R) return false;
    if (R.出击.includes(键)) R.出击 = R.出击.filter(k => k !== 键);
    else {
      if (R.出击.length >= 肉鸽数值.出击上限) return false;
      if (!R.队伍.some(m => m.键 === 键)) return false;
      R.出击.push(键);
    }
    this.存档();
    return true;
  },
  补给() {
    const R = this.RUN;
    if (!R) return null;
    R.源碳 += 肉鸽数值.补给源碳;
    this.记(`补给：源碳 +${肉鸽数值.补给源碳}`);
    this.节点完成();
    return 肉鸽数值.补给源碳;
  },
  奇遇(选) {
    const R = this.RUN;
    if (!R) return null;
    if (选 === '源碳') R.源碳 += 肉鸽数值.奇遇源碳; else R.希望 += 肉鸽数值.奇遇希望;
    this.记(`奇遇：${选 === '源碳' ? `源碳 +${肉鸽数值.奇遇源碳}` : `希望 +${肉鸽数值.奇遇希望}`}`);
    this.节点完成();
    return true;
  },

  /* ---------------- 层 ---------------- */
  下一层() {
    const R = this.RUN;
    R.层++;
    R.场次 = 0;
    R.地图 = this.生成层(R);
    R.当前 = R.地图.起点;
    this.记(`—— 进入第 ${R.层} 层 ——`);
    this.存档();
    return R.层;
  },
  失败耐久(战报){ const 剩 = 战报 && 战报.敌方 ? 战报.敌方.filter(u => u.hp > 0).length : 1; return Math.max(1, 剩); },
  失败(原因) {
    this.进行中 = false;
    this.记(`本局结束：${原因}`);
    this.清存档();
    return 原因;
  },
  通关() { this.进行中 = false; this.记('通关！'); this.清存档(); },

  /* ---------------- 日志 ---------------- */
  记(文字) { if (this.RUN) this.RUN.日志.push({ 回合: this.RUN.层, 文本: 文字, 时间: Date.now() }); },

  /* ---------------- 存档（关掉页面能继续） ---------------- */
  存档() {
    if (!this.RUN) return false;
    try {
      const 存 = { RUN: this.RUN, 进行中: this.进行中 };
      if (typeof localStorage !== 'undefined' && localStorage.setItem) localStorage.setItem(存档键, JSON.stringify(存));
      return true;
    } catch (e) { return false; }
  },
  读存档() {
    try {
      if (typeof localStorage === 'undefined' || !localStorage.getItem) return null;
      const s = localStorage.getItem(存档键);
      if (!s) return null;
      const 存 = JSON.parse(s);
      if (!存 || !存.RUN || !存.RUN.地图) return null;
      this.RUN = 存.RUN;
      this.进行中 = !!存.进行中;
      return this.RUN;
    } catch (e) { return null; }
  },
  有存档() { return !!this.读存档(); },
  清存档() {
    try { if (typeof localStorage !== 'undefined' && localStorage.removeItem) localStorage.removeItem(存档键); } catch (e) {}
  },
};
