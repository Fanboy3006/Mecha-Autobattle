/* ============================================================================
 * 作战记录（保存 / 复制 / 下载）—— 作者 2026-10-12 的要求
 * 作者原话：「**现在这个作战记录你看看能不能安排保存一下**」
 * ----------------------------------------------------------------------------
 * 为什么有它：作者试玩时怀疑「攻击已经死掉的敌方」（另一条线在查那个 bug），
 * 需要一个**能把某一场战斗的完整记录发出来**的途径。`RUN.日志`（大地图 / 事件层的日志）
 * 早就进存档、也有记录屏了；可是**战斗内那一份逐条记录（`ctx.log`）战斗结束就没了** ——
 * 没法回看、没法导出。这个文件就是给它一个落点。
 *
 * 文件位置：`84-反馈.js` 之后、`80-界面.js` 之前（纯数据层，界面只是画它）。
 *
 * 三条硬规矩（写在文件头，改这个文件前先读）：
 *   1. **独立键**：`localStorage` 键 = `mecha-autobattle-战斗记录` —— 和肉鸽存档（`存档键`，
 *      当前是 `mecha-autobattle-run-v4`）**完全无关**：`RUN` 结构不改、存档版本号不动、
 *      没有 `RUN` 的路径（练习模式 / `simulate()` / 平衡工具）也照常能存。
 *   2. **别让存档无限膨胀**：只留**最近 `战斗记录场数上限 = 5` 场**（FIFO，超了从最老丢），
 *      再加一道**总容量上限 `战斗记录容量上限 = 500 × 1024 = 512000`**（口径见下面那条注释），
 *      超了继续从最老丢；**单场就超上限 → 这一场不存**（返回 `ok:false` + 人话原因，屏上照样能复制 / 下载）。
 *   3. **坏数据 / 空数据 / 垃圾一律不崩**：读不出来、JSON 坏了、形状不对、单条坏 →
 *      一律退化成「没有记录」（空数组），一个异常都不抛（`localStorage` 不给用也一样）。
 *
 * 一场存什么（够复现这一场，作者要的是这个）：
 *   `{ 时间, 时间戳, 来源, 种子, 层, 节点类型, 编成ID, 编成, 结果, 原因, 回合数,
 *      我方, 敌方, 方针表, 单位开关, 波次, 调参, 记录 }`
 *   · **种子 + 编成 + 方针 + 单位开关 + 完整记录数组** 是硬要求（最少这一套）；
 *   · `我方 / 敌方` 存的是**规格**（`{键, 位, 等级, 名}`，敌方多一个 `强化`、我方多一个 `开战HP比`）
 *     —— 不是打完之后那些大对象，所以一份记录只有几十 KB 而不是几百 KB；
 *   · `记录` 是 `ctx.log` **原样引用**：导出的文本要**逐字照抄**，一个字都不许改写
 *     （作者要拿它复现 bug）。
 *
 * ★ 2026-10-12 追加（作者：「需要一个对话在**理解规则**的情况下**检视我的游戏记录**」）：
 *   同一个文件里还住着**本局日志（`RUN.日志`）的导出**（第 ④ 节 `本局文本()` / `本局文件名()`）——
 *   战斗记录只看得见「一场里发生了什么」，**大地图那一路**（路线 / 花销 / 晋升 / 事件 / 推进剂）
 *   只在 `RUN.日志` 里，所以要把它也导出。两个导出**共用**同一套「复制 / 下载 / 失败兜底」（第 ⑤ 节），
 *   `RUN` 由调用方传进来（这一节不依赖 `90-肉鸽.js`；界面在 `92-肉鸽界面.js`）。
 * ★ 2026-10-13 追加（作者：「日志需要能够**记录下我当时的选项和我的实际选择**…**节省空间**」）：
 *   同一个导出文本**末尾多一节**「———— 决策记录（紧凑，程序可读，共 N 条）————」+ **每行一条 JSON**
 *   （第 ④b 节 `本局决策们()` / `决策节文本()`）。数据来自**录像**里这一局的 `决策` 字段
 *   （`89-录像.js` / `8b-决策日志.js`）；**上面已有的文本格式一个字节都没动**，只是追加。
 *
 * 容量口径（写清楚，免得以后有人按字节重算）：`容量上限` 比的是
 * `JSON.stringify(整个数组).length`，也就是 **UTF-16 字符数**（不是 UTF-8 字节数）——
 * localStorage 的配额本身也是按字符算的，所以这个口径和浏览器一致。
 * ========================================================================== */

/** localStorage 键（独立键，和肉鸽存档 `存档键` 无关）。 */
const 战斗记录键 = 'mecha-autobattle-战斗记录';
/** 最多保留最近几场（FIFO，超了从最老的丢）。 */
const 战斗记录场数上限 = 5;
/** 总容量上限：500 KB —— `JSON.stringify(数组).length` 的**字符数**上限。 */
const 战斗记录容量上限 = 500 * 1024;
/** 屏上一次最多画多少条逐条记录（只影响画面，不影响存档里的内容）。 */
const 战斗记录屏条数上限 = 300;

/** 安全的数字（`null` / `''` / `NaN` / 认不出来的东西 → 兜底值）。 */
const 记录数 = (v, 兜底) => {
  if (v == null || v === '') return 兜底;
  const n = Number(v);
  return Number.isFinite(n) ? n : 兜底;
};
const 记录文字 = v => (v == null ? '' : String(v));

const 战斗记录 = {
  键: 战斗记录键,
  场数上限: 战斗记录场数上限,
  容量上限: 战斗记录容量上限,
  屏条数上限: 战斗记录屏条数上限,

  /* ---------------- ① localStorage：读（坏数据一律不崩） ---------------- */
  /** 拿到 localStorage（没有 / 被禁 → null；**绝不抛**）。 */
  存根() {
    try {
      if (typeof localStorage === 'undefined' || !localStorage) return null;
      return localStorage;
    } catch (e) { return null; }
  },
  /** 原始字符串（读不到 → 空串）。 */
  原文() {
    const L = this.存根();
    if (!L) return '';
    try { return 记录文字(L.getItem(this.键)); } catch (e) { return ''; }
  },
  /** 读回记录表：**空 / 坏 JSON / 形状不对 / 单条坏 → 一律当「没有记录」，一个异常都不抛**。
   *  形状过滤比「有没有 JSON」严一档：每条至少要有 `记录` 数组（否则玩家点进去会崩在画屏那一步）。 */
  读() {
    const 文 = this.原文();
    if (!文) return [];
    let 解 = null;
    try { 解 = JSON.parse(文); } catch (e) { return []; }
    if (!Array.isArray(解)) return [];
    const 好 = 解.filter(x => x && typeof x === 'object' && !Array.isArray(x) && Array.isArray(x.记录));
    return 好.length > this.场数上限 ? 好.slice(-this.场数上限) : 好;
  },
  /** 一份 / 一堆记录的体积（**字符数**；序列化不了 → `Infinity`，让上层把它丢掉）。 */
  体积(场) { try { return JSON.stringify(场 == null ? null : 场).length; } catch (e) { return Infinity; } },
  总量(场们) { try { return JSON.stringify(Array.isArray(场们) ? 场们 : []).length; } catch (e) { return Infinity; } },

  /** 写回整个数组：先按**容量**从最老丢，再按**场数**截；单场就超上限 → 一场都不留。
   *  返回 `{ok, 场数, 总量, 丢了}`（写不进去时 `ok:false`，不抛）。 */
  写(场们) {
    const 表 = (Array.isArray(场们) ? 场们 : []).filter(x => x && typeof x === 'object' && !Array.isArray(x));
    let 丢 = 0;
    while (表.length > this.场数上限) { 表.shift(); 丢++; }
    while (表.length > 1 && this.总量(表) > this.容量上限) { 表.shift(); 丢++; }
    if (表.length === 1 && this.总量(表) > this.容量上限) { 表.length = 0; 丢++; }
    const L = this.存根();
    let ok = false;
    if (L) { try { L.setItem(this.键, JSON.stringify(表)); ok = true; } catch (e) { ok = false; } }
    return { ok, 场数: 表.length, 总量: this.总量(表), 丢了: 丢, 表 };
  },

  /** 存一场（战斗结束时调一次）：返回 `{ok, 第几场, 场数, 体积, 总量, 丢了, why, 提示}`。
   *  · `第几场` = 这一场在「最近 N 场」里排第几（最新的一场 = 第 N 场）——界面直接拿它写反馈；
   *  · 单场超过容量上限 → **不存**（`ok:false` + `why`），免得把整个键撑爆；屏上仍可复制 / 下载。 */
  存(场) {
    const 现 = this.读();
    if (!场 || typeof 场 !== 'object' || !Array.isArray(场.记录)) {
      return { ok: false, 第几场: 0, 场数: 现.length, 体积: 0, 总量: this.总量(现), 丢了: 0,
        why: '这一场没有可存的记录（记录数组是空的）', 提示: '' };
    }
    const 大小 = this.体积(场);
    if (!(大小 <= this.容量上限)) {
      return { ok: false, 第几场: 0, 场数: 现.length, 体积: 大小, 总量: this.总量(现), 丢了: 0,
        why: `这一场记录太大（${大小} 字符 > 上限 ${this.容量上限}），没有存进 localStorage`,
        提示: `本场记录太大，没存下（${大小} 字符 > 上限 ${this.容量上限}）—— 屏上还能复制 / 下载` };
    }
    现.push(场);
    const 回 = this.写(现);
    const 第几场 = 回.场数;
    const 失败原因 = '写不进 localStorage（无痕模式 / 配额满了？）';
    const 提 = 回.ok
      ? `本场记录已保存（最近 ${this.场数上限} 场：第 ${第几场} 场` +
        `${回.丢了 ? `；顺手丢掉了最老的 ${回.丢了} 场` : ''}）`
      : `本场记录没存下：${失败原因} —— 屏上还能复制 / 下载`;
    return { ok: 回.ok, 第几场, 场数: 回.场数, 体积: 大小, 总量: 回.总量, 丢了: 回.丢了,
      why: 回.ok ? null : 失败原因, 提示: 提 };
  },
  /** 清掉这个键（玩家 / 测试用；清完读回来就是空数组）。 */
  清() {
    const L = this.存根();
    if (L) { try { L.removeItem(this.键); } catch (e) { /* 不崩 */ } }
    return true;
  },

  /* ---------------- ② 组一场记录（战斗结束时由界面调） ---------------- */
  /** `时间`：给「现在」（Date / 时间戳），不给就现取 —— 测试能钉死它。 */
  时间文字(现在) {
    const d = (现在 && typeof 现在.getTime === 'function') ? 现在
      : (现在 != null && Number.isFinite(Number(现在)) ? new Date(Number(现在)) : new Date());
    const t = d && typeof d.getTime === 'function' ? d.getTime() : NaN;
    if (!Number.isFinite(t)) return '—';
    const p = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ` +
      `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
  },
  /** 文件名里那一段时间（不含冒号，Windows 上能用）：`20261012-150405`。 */
  文件名时间(现在) {
    const 文 = this.时间文字(现在);
    const m = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/.exec(文);
    return m ? `${m[1]}${m[2]}${m[3]}-${m[4]}${m[5]}${m[6]}` : '00000000-000000';
  },
  /** 单位「规格」：`{键, 位, 等级, 名}`（+ 敌方的 `强化` / 我方的 `开战HP比`）。
   *  认的是两种写法：编成规格（`键`）与引擎单位（`key` / `slot` / `lv`）。 */
  规格们(甲, 乙, 方) {
    const 源 = Array.isArray(甲) ? 甲 : (Array.isArray(乙) ? 乙 : []);
    return 源.map(x => {
      if (!x || typeof x !== 'object') return null;
      const 键 = x.键 != null ? x.键 : x.key;
      if (键 == null) return null;
      const 位 = 记录数(x.位 != null ? x.位 : x.slot, null);
      const 等级 = 记录数(x.等级 != null ? x.等级 : x.lv, null);
      let 名 = x.名 != null ? x.名 : x.name;
      if (名 == null && typeof 界面 !== 'undefined' && 界面 && typeof 界面.单位名 === 'function') {
        try { 名 = 界面.单位名(键, 方); } catch (e) { 名 = 键; }
      }
      const 出 = { 键: 记录文字(键), 位, 等级, 名: 记录文字(名 == null ? 键 : 名) };
      if (方 === 'enemy') { const 强 = 记录数(x.强化, null); if (强 != null && 强 !== 1) 出.强化 = 强; }
      else { const h = x.hp; if (typeof h === 'number' && h > 0 && h < 1) 出.开战HP比 = h; }
      return 出;
    }).filter(Boolean).sort((a, b) => (a.位 == null ? 99 : a.位) - (b.位 == null ? 99 : b.位));
  },
  /** 方针表：`{ 1: {类型:'全军突击', 目标位:null}, 2: … }`（界面按回合记，`开打()` 里写）。
   *  传字符串 / 只写类型也认；认不出来的回合丢掉（不崩）。 */
  方针表(历史) {
    const 出 = {};
    if (!历史 || typeof 历史 !== 'object') return 出;
    for (const k of Object.keys(历史)) {
      if (!/^\d+$/.test(k)) continue;
      const v = 历史[k];
      const 型 = typeof v === 'string' ? v : (v && v.类型);
      if (!型) continue;
      出[k] = { 类型: 记录文字(型), 目标位: (v && typeof v === 'object' && v.目标位 != null) ? 记录数(v.目标位, null) : null };
    }
    return 出;
  },
  /** 单位开关表：只留**非默认**的那几项（默认 = 自动 / 不保留），省得每场都存一堆空对象。 */
  开关们(表) {
    const 出 = {};
    if (!表 || typeof 表 !== 'object') return 出;
    for (const k of Object.keys(表)) {
      const v = 表[k] || {};
      const 项 = {};
      if (v.保留大招) 项.保留大招 = true;
      if (v.TRANSAM === '手动') 项.TRANSAM = '手动';
      if (v.本回合开TRANSAM) 项.本回合开TRANSAM = true;
      if (Object.keys(项).length) 出[k] = 项;
    }
    return 出;
  },
  /** 波次（敌方增援表）：原样收着（`{回合, 来:[{键,等级,强化}]}`）。 */
  波次们(波次) {
    if (!Array.isArray(波次)) return [];
    return 波次.map(w => ({
      回合: 记录数(w && w.回合, null),
      来: ((w && w.来) || []).map(e => {
        const 出 = { 键: 记录文字(e && e.键), 等级: 记录数(e && e.等级, null) };
        if (e && e.强化 != null && e.强化 !== 1) 出.强化 = 记录数(e.强化, 1);
        return 出;
      }),
    }));
  },
  /** 编成信息（层 / 类型 / 前后阵容 / 考点 / 在表里的序号）——`编成ID` 由它拼。 */
  编成信息(条目) {
    if (!条目 || typeof 条目 !== 'object') return null;
    let 序号 = 0;
    try { 序号 = 编成表.indexOf(条目) + 1; } catch (e) { 序号 = 0; }
    const 层 = 记录数(条目.层, null), 类型 = 记录文字(条目.类型);
    return {
      层, 类型, 序号,
      前: (条目.前 || []).map(记录文字), 后: (条目.后 || []).map(记录文字),
      考点: 记录文字(条目.考点),
      ID: `第${层 == null ? '?' : 层}层-${类型 || '?'}${序号 ? `#${序号}` : ''}`,
    };
  },
  /** **组一场记录**（界面在战斗结束时调；全部字段都可缺，缺了退化成空值，绝不抛）。 */
  做一场(参) {
    const o = (参 && typeof 参 === 'object') ? 参 : {};
    const 战报 = (o.战报 && typeof o.战报 === 'object') ? o.战报 : {};
    const 记录 = Array.isArray(战报.记录) ? 战报.记录 : (Array.isArray(o.记录) ? o.记录 : []);
    const 编成 = this.编成信息(o.条目 || null);
    const 现在 = o.现在;
    const 种子 = 记录数(战报.种子 != null ? 战报.种子 : o.种子, null);
    return {
      版本: 1,
      时间: this.时间文字(现在),
      时间戳: (现在 && typeof 现在.getTime === 'function') ? 现在.getTime()
        : (现在 != null && Number.isFinite(Number(现在)) ? Number(现在) : Date.now()),
      来源: 记录文字(o.来源 || '练习'),
      种子,
      层: 记录数(o.层, 编成 ? 编成.层 : null),
      节点类型: o.节点类型 != null ? 记录文字(o.节点类型) : (编成 ? 编成.类型 : null),
      编成ID: 编成 ? 编成.ID : (o.编成ID != null ? 记录文字(o.编成ID) : null),
      编成,
      结果: 记录文字(战报.结果 || o.结果 || '—'),
      原因: 记录文字(战报.原因 || o.原因 || '—'),
      回合数: 记录数(战报.回合数 != null ? 战报.回合数 : o.回合数, null),
      我方: this.规格们(o.我方, 战报.我方, 'ally'),
      敌方: this.规格们(o.敌方, 战报.敌方, 'enemy'),
      方针表: this.方针表(o.方针表),
      单位开关: this.开关们(o.单位开关),
      波次: this.波次们(o.波次),
      调参: (o.调参 && typeof o.调参 === 'object') ? JSON.parse(JSON.stringify(o.调参)) : null,
      记录,
    };
  },

  /* ---------------- ③ 显示与导出 ---------------- */
  /** 一行摘要（结算屏 / 记录列表都用它）：时间 · 种子 · 编成 · 结果 · 回合数 · 记录条数。 */
  摘要行(场) {
    if (!场 || typeof 场 !== 'object') return '（没有这一场记录）';
    const 条 = Array.isArray(场.记录) ? 场.记录.length : 0;
    return `${记录文字(场.时间) || '—'} · 种子 ${场.种子 == null ? '—' : 场.种子} · ` +
      `${记录文字(场.编成ID) || '（没记编成）'} · ${记录文字(场.结果) || '—'} · ` +
      `${场.回合数 == null ? '—' : 场.回合数} 回合 · ${条} 条记录`;
  },
  /** 阵容一行（导出文本用）：`前1 雷萨 B1 Lv10；前2 蕾卡 B2 Lv10 …`。 */
  阵容行(单位们) {
    const 们 = Array.isArray(单位们) ? 单位们 : [];
    if (!们.length) return '—';
    return 们.map(u => {
      const 位 = u.位 == null ? '？' : (typeof 位名 === 'function' ? 位名(u.位) : `位 ${u.位}`);
      const 级 = u.等级 == null ? '' : ` Lv${u.等级}`;
      const 强 = u.强化 != null && u.强化 !== 1 ? `（强化 ×${u.强化}）` : '';
      const 血 = u.开战HP比 != null ? `（开战 HP ${Math.round(u.开战HP比 * 100)}%）` : '';
      return `${位} ${u.名 || u.键} ${u.键}${级}${强}${血}`;
    }).join('；');
  },
  /** 方针表一行：`第 1 回合 全军突击；第 2 回合 集中攻击（目标位 4）`。 */
  方针行(表) {
    const 键 = Object.keys(表 || {}).filter(k => /^\d+$/.test(k)).sort((a, b) => Number(a) - Number(b));
    if (!键.length) return '—';
    return 键.map(k => {
      const v = 表[k] || {};
      return `第 ${k} 回合 ${v.类型 || '—'}${v.目标位 != null ? `（目标位 ${v.目标位}）` : ''}`;
    }).join('；');
  },
  /** 单位开关一行：`前1 保留大招；前2 TRANS-AM 手动`。 */
  开关行(表) {
    const 键 = Object.keys(表 || {});
    if (!键.length) return '（全默认：大招自动）';
    return 键.map(k => {
      const v = 表[k] || {};
      const 项 = [];
      if (v.保留大招) 项.push('保留大招');
      if (v.TRANSAM === '手动') 项.push(v.本回合开TRANSAM ? 'TRANS-AM 手动（本回合点开）' : 'TRANS-AM 手动');
      const 位 = /^\d+$/.test(k) && typeof 位名 === 'function' ? 位名(Number(k)) : `位 ${k}`;
      return `${位} ${项.join(' / ')}`;
    }).join('；');
  },
  波次行(波次) {
    const 们 = Array.isArray(波次) ? 波次 : [];
    if (!们.length) return '—';
    const 名 = (键, 方) => {
      if (typeof 界面 === 'undefined' || !界面 || typeof 界面.单位名 !== 'function') return 键;
      try { return 界面.单位名(键, 方); } catch (e) { return 键; }
    };
    return 们.map(w => `第 ${w.回合 == null ? '?' : w.回合} 回合 ` +
      `${(w.来 || []).map(e => `${名(e.键, 'enemy')} ${e.键}${e.等级 == null ? '' : ` Lv${e.等级}`}`).join('、')}`).join('；');
  },
  /** **导出文本**：开头一段摘要（种子 / 层 / 节点类型 / 编成 / 我方阵容与等级 / 敌方阵容 /
   *  方针表 / 结果 / 回合数），然后是**逐条记录一行一条**。
   *  ★ 记录那一部分**原文照抄**：只加一个行号 + `[第 N 回合]` 前缀，`文本` 一个字都不改
   *  （作者要拿它复现「攻击已经死掉的敌方」那个 bug）。 */
  场文本(场) {
    if (!场 || typeof 场 !== 'object') return '（没有这一场记录）';
    const 记录 = Array.isArray(场.记录) ? 场.记录 : [];
    const 头 = [
      `机甲指挥 · 作战记录（${记录文字(场.结果) || '—'} · ${场.回合数 == null ? '—' : 场.回合数} 回合 · ${记录.length} 条）`,
      `时间：${记录文字(场.时间) || '—'}　　来源：${记录文字(场.来源) || '—'}`,
      `种子：${场.种子 == null ? '—' : 场.种子}　　层：${场.层 == null ? '—' : `第 ${场.层} 层`}　　节点类型：${记录文字(场.节点类型) || '—'}`,
      `编成：${记录文字(场.编成ID) || '—'}` +
        (场.编成 ? `（前 ${(场.编成.前 || []).join('+') || '—'} / 后 ${(场.编成.后 || []).join('+') || '—'}）` : ''),
      `结果：${记录文字(场.结果) || '—'}（${记录文字(场.原因) || '—'}）　　回合数：${场.回合数 == null ? '—' : 场.回合数}`,
      `我方：${this.阵容行(场.我方)}`,
      `敌方：${this.阵容行(场.敌方)}`,
      `方针：${this.方针行(场.方针表)}`,
      `单位开关：${this.开关行(场.单位开关)}`,
    ];
    if (场.波次 && 场.波次.length) 头.push(`敌方增援：${this.波次行(场.波次)}`);
    if (场.调参) 头.push(`调参室倍率：${JSON.stringify(场.调参)}`);
    if (场.编成 && 场.编成.考点) 头.push(`考点：${场.编成.考点}`);
    const 身 = 记录.map((x, i) => {
      const 回 = x && x.回合 != null ? x.回合 : '?';
      const 文 = x && x.文本 != null ? String(x.文本) : '（这条记录没有文本）';
      return `${i + 1}. [第 ${回} 回合] ${文}`;
    });
    return 头.join('\n') + '\n' +
      `———— 逐条记录（原文照抄，共 ${记录.length} 条）————\n` +
      (身.length ? 身.join('\n') : '（这一场没有逐条记录）') + '\n';
  },
  /** 下载用的文件名（**带种子与时间**）：`作战记录-第1层-普通-种子20261010-20261012-150405.txt`。 */
  文件名(场) {
    const 层 = 场 && 场.层 != null ? `第${场.层}层-` : '';
    const 型 = 场 && 场.节点类型 ? `${场.节点类型}-` : '';
    const 种 = `种子${场 && 场.种子 != null ? 场.种子 : '—'}`;
    const 时 = this.文件名时间(场 && 场.时间戳);
    return `作战记录-${层}${型}${种}-${时}.txt`
      .replace(/[\\/:*?"<>|\s]/g, '');      // Windows / macOS 都不认的字符一律去掉
  },

  /* ---------------- ④ 本局日志（`RUN.日志`）的导出（作者 2026-10-12「记录导出」这一件） ----------------
   * 作者原话：「需要一个对话在**理解规则**的情况下**检视我的游戏记录**，然后**尝试理解我的游戏思路**」。
   * 为什么有它：这一版只导出了**战斗内**那一份逐条记录（一场一场地看），而**大地图那一路**
   * ——走哪条路、在哪买东西、何时晋升、遇到什么事件、每层怎么花推进剂——只在 `RUN.日志` 里；
   * 只看战斗记录看不出路线与花费的思路，所以这里给**本局日志**一个**同款**的导出（不另造一套）。
   *
   * 口径（和上面 `场文本()` 一套样式，一个字都不许改写）：
   *   · 文本 = **一段摘要**（种子 / 分队 / 当前层 / 希望 / 源碳结晶 / 招募券 / 作战耐久 /
   *     队伍（键 + 等级）/ 藏品 / 零件 / 当前推进剂）+ **`RUN.日志` 逐条原文照抄**：
   *     一条一行、带序号、**按时间顺序**（最老的第 1 条 —— 记录屏是「最新在前」，导出要的是时间线）；
   *   · `RUN` 由调用方传进来 —— 这一节**不依赖 `90-肉鸽.js` / `93-藏品.js` / `94-零件.js`**
   *     （本文件在它们前面加载）：读不到 `券名` / `券汇总文字` / `藏品表` / `零件表` / `推进剂上限`
   *     时**就地兜底**（退回键名 / 不写那一格），缺字段 / 坏数据一律退化成「—」，**一个异常都不抛**；
   *   · 全部内容**只由 `RUN` 决定**，唯一随时间变的是摘要里那一行 `时间：…`（导出这一刻）——
   *     所以「同种子两遍导出」除那一行之外逐字相同；
   *   · 没有 `RUN` / 日志为空 → `本局有记录()` = false、文本里写「还没有记录」，
   *     界面据此给「还没有记录」那句可见反馈（不崩、也不摊一个空文本框）。
   * 界面（复制 / 下载两个按钮 + 三层反馈）在 `92-肉鸽界面.js`；复制 / 下载本体是下面 ⑤ 那两个通用口子。 */
  /** 归一后的本局日志：`[{序号, 层, 文本}]`；没有 RUN / 日志不是数组 / 空 → `[]`（不抛）。
   *  ★ 只做「取出来」这一件事：`文本` **一个字都不改**（每条自带的 `时间` 字段不进导出文本）。 */
  本局日志们(RUN) {
    const R = (RUN && typeof RUN === 'object') ? RUN : null;
    const 本 = (R && Array.isArray(R.日志)) ? R.日志 : [];
    return 本.map((x, i) => ({
      序号: i + 1,
      层: (x && typeof x === 'object') ? 记录数(x.层, null) : null,
      文本: (x && typeof x === 'object') ? (x.文本 == null ? '' : String(x.文本))
        : (typeof x === 'string' ? x : ''),
    }));
  },
  /** 这一局有没有可导出的东西（界面据此给「还没有记录」，不画空文本框）。 */
  本局有记录(RUN) { return this.本局日志们(RUN).length > 0; },
  /** 藏品 id → 显示名（`93-藏品.js` 的 `藏品表`；读不到 / 认不出来就退回 id —— 不崩）。 */
  藏品名(id) {
    try {
      if (typeof 藏品表 !== 'undefined' && 藏品表 && 藏品表[id] && 藏品表[id].名) return String(藏品表[id].名);
    } catch (e) { /* 认不出来就用 id */ }
    return 记录文字(id);
  },
  /** 零件键 → 显示名（`94-零件.js` 的 `零件表`；读不到就退回键名）。 */
  零件名(k) {
    try {
      if (typeof 零件表 !== 'undefined' && 零件表 && 零件表[k] && 零件表[k].名) return String(零件表[k].名);
    } catch (e) { /* 认不出来就用键名 */ }
    return 记录文字(k);
  },
  /** 一张券的名字（`90-肉鸽.js` 的 `券名()`；读不到就写它自己的 `名`）。 */
  券名文字(券) {
    try { if (typeof 券名 === 'function') return 券名(券); } catch (e) { /* 兜底 */ }
    return (券 && 券.名) ? String(券.名) : '招募券';
  },
  /** 招募券那一格：`2 张（近卫招募券 ×2、天人势力招募券 ×1）`；一张都没有 → `0 张`。 */
  券行(RUN) {
    const R = (RUN && typeof RUN === 'object') ? RUN : null;
    const 们 = (R && Array.isArray(R.券)) ? R.券 : [];
    if (!们.length) return '0 张';
    let 汇总 = '';
    try { if (typeof 券汇总文字 === 'function') 汇总 = 券汇总文字(R); } catch (e) { 汇总 = ''; }
    if (!汇总) 汇总 = 们.map(c => this.券名文字(c)).filter(Boolean).join('、');
    return `${们.length} 张${汇总 ? `（${汇总}）` : ''}`;
  },
  /** 队伍那一格（**键 + 等级**）：`B1 Lv20、B2 Lv10、…`；名册空的（开局那一下）→ 写清。 */
  队伍行(RUN) {
    const R = (RUN && typeof RUN === 'object') ? RUN : null;
    const 们 = (R && Array.isArray(R.队伍)) ? R.队伍 : [];
    if (!们.length) return '—（名册是空的）';
    return 们.map(m => `${记录文字(m && m.键)} Lv${m && m.等级 != null ? m.等级 : '?'}`).join('、');
  },
  /** 藏品那一格：`装甲强化、…`（`RUN.藏品` 存的是 id 数组）；一件都没有 → `—`。 */
  藏品行(RUN) {
    const R = (RUN && typeof RUN === 'object') ? RUN : null;
    const 们 = (R && Array.isArray(R.藏品)) ? R.藏品 : [];
    if (!们.length) return '—';
    return 们.map(id => this.藏品名(id)).join('、');
  },
  /** 零件那一格：`报废轮子（剩 1 次）、河谷祭祈`（`RUN.零件` 存的是 `{k, uses, value}`）。 */
  零件行(RUN) {
    const R = (RUN && typeof RUN === 'object') ? RUN : null;
    const 们 = (R && Array.isArray(R.零件)) ? R.零件 : [];
    if (!们.length) return '—';
    return 们.map(p => {
      const k = (p && typeof p === 'object') ? p.k : p;
      const 数 = (p && typeof p === 'object')
        ? (p.uses != null ? `（剩 ${p.uses} 次）` : (p.value != null ? `（估价 ${p.value}）` : '')) : '';
      return `${this.零件名(k)}${数}`;
    }).join('、');
  },
  /** 一行摘要（记录屏 / 大地图上画玩家看的是一行，导出文本用的是分行的那一段）：**全是纯读**。 */
  本局摘要行(RUN) {
    const R = (RUN && typeof RUN === 'object') ? RUN : null;
    if (!R) return '（没有进行中的局）';
    return `第 ${R.层 == null ? '?' : R.层} 层 · 分队 ${记录文字(R.分队) || '—'} · 种子 ${R.种子 == null ? '—' : R.种子} · ` +
      `希望 ${R.希望 == null ? '—' : R.希望} · 源碳 ${R.源碳 == null ? '—' : R.源碳} · 券 ${(R.券 || []).length} · ` +
      `耐久 ${R.耐久 == null ? '—' : R.耐久} · 推进剂 ${R.推进剂 == null ? '—' : R.推进剂} · ` +
      `队伍 ${(R.队伍 || []).length} 台 · 日志 ${this.本局日志们(R).length} 条`;
  },
  /** **本局日志导出文本**（界面「复制为文本」/「下载 .txt」用的就是它）：
   *  头一段 = 摘要（一行一格），然后是 `RUN.日志` **原文照抄**（`序号. [第 N 层] 原文`，一行一条），
   *  **末尾再追加一节「决策记录」**（★ 2026-10-13，见下面的 `本局决策们()`）。 */
  本局文本(RUN, 现在) {
    const R = (RUN && typeof RUN === 'object') ? RUN : null;
    const 日志 = this.本局日志们(R);
    const 时间 = this.时间文字(现在);
    const 尾 = `———— 本局日志（原文照抄，共 ${日志.length} 条）————`;
    const 决策节 = this.决策节文本(R);
    if (!R) {
      return `机甲指挥 · 本局日志（还没有进行中的局）\n` +
        `时间：${时间}（导出这一刻 —— 全文只有这一行随时间变）\n` +
        `${尾}\n（还没有记录：先在肉鸽里开一局，本局日志才有内容）\n` +
        决策节;
    }
    let 上限 = null;
    try { if (typeof 推进剂上限 === 'function') 上限 = 推进剂上限(R); } catch (e) { 上限 = null; }
    const 头 = [
      `机甲指挥 · 本局日志（种子 ${R.种子 == null ? '—' : R.种子} · 分队 ${记录文字(R.分队) || '—'} · ` +
        `第 ${R.层 == null ? '?' : R.层} 层 · ${日志.length} 条）`,
      `时间：${时间}（导出这一刻 —— 全文只有这一行随时间变）`,
      `种子：${R.种子 == null ? '—' : R.种子}　　分队：${记录文字(R.分队) || '—'}　　当前层：第 ${R.层 == null ? '?' : R.层} 层`,
      `希望：${记录数(R.希望, '—')}　　源碳结晶：${记录数(R.源碳, '—')}　　招募券：${this.券行(R)}　　` +
        `作战耐久：${记录数(R.耐久, '—')}`,
      `当前推进剂：${记录数(R.推进剂, '—')}${上限 == null ? '' : ` / ${上限}`}`,
      `队伍（${(R.队伍 || []).length} 台）：${this.队伍行(R)}`,
      `藏品（${(R.藏品 || []).length} 件）：${this.藏品行(R)}`,
      `零件（${(R.零件 || []).length} 件）：${this.零件行(R)}`,
    ];
    if (!日志.length) 头.push('（这一局还没有记录：走一格 / 做一件事之后，这里就开始有一行一行的时间线）');
    const 身 = 日志.map(x => `${x.序号}. [第 ${x.层 == null ? '?' : x.层} 层] ${x.文本 || '（这条记录没有文本）'}`);
    return 头.join('\n') + '\n' + 尾 + '\n' + (身.length ? 身.join('\n') : '（还没有记录）') + '\n' + 决策节;
  },
  /* ---------------- ④b ★ 2026-10-13 决策记录（**追加在本局日志末尾**的那一节） ----------------
   * 作者原话（2026-10-13）：「日志需要能够**记录下我当时的选项和我的实际选择**，可以是**人看不懂但是
   * 程序能看懂的简要版本**，**节省空间**。」
   * 口径（**不动上面已有的任何一行文本**，只在末尾追加一节）：
   *   · 数据 = **录像**（`89-录像.js`）里这一局的 **`决策: […]`**（`8b-决策日志.js` 记的）；
   *     为什么不在 `RUN` 上：`RUN` 是**存档**（会进 `localStorage` 的肉鸽存档键），决策日志是**录像**的一部分，
   *     两套东西的键、版本、生命周期都不同（照 `89-录像.js` 文件头第 1 条）；
   *   · 一节长这样（`N 条` + **每行一条 JSON**，`JSON.stringify` 原样，不再包一层人话）：
   *         ———— 决策记录（紧凑，程序可读，共 3 条）————
   *         {"序":1,"步":1,"屏":"分队","选":"选分队:无","选项":["选分队:无","选分队:近卫",…]}
   *   · **纯读**（导出不该写进被导出的东西里）；没有录像 / 还没有决策 / 坏数据 → `共 0 条` + 一句人话，不崩。 */
  /** 这一局的决策记录（从录像里读；读不到 → 空数组）。**纯读**、绝不抛。 */
  本局决策们(RUN) {
    try {
      if (typeof 录像 !== 'undefined' && 录像 && typeof 录像.当前决策 === 'function') {
        const 们 = 录像.当前决策(RUN);
        return Array.isArray(们) ? 们 : [];
      }
    } catch (e) { /* 读不到就当没有 */ }
    return [];
  },
  /** 这一局超过上限被丢掉的决策条数（0 = 一条没丢）。 */
  本局决策丢(RUN) {
    try {
      if (typeof 录像 !== 'undefined' && 录像 && typeof 录像.当前决策丢 === 'function') return 记录数(录像.当前决策丢(RUN), 0);
    } catch (e) { /* 同上 */ }
    return 0;
  },
  /** 末尾那一节（含标题行；`决策节文本(null)` 也给一节「共 0 条」，形状与有局时一致）。 */
  决策节文本(RUN) {
    const 条们 = this.本局决策们(RUN);
    const 丢 = this.本局决策丢(RUN);
    const 头 = `———— 决策记录（紧凑，程序可读，共 ${条们.length} 条${丢 ? `；另有 ${丢} 条超过上限被丢` : ''}）————`;
    const 行 = 条们.map(x => {
      try { return JSON.stringify(x); } catch (e) { return '（这一条序列化不了）'; }
    });
    return 头 + '\n' + (行.length ? 行.join('\n') : '（这一局还没有决策记录）') + '\n';
  },
  /** 下载用的文件名（**带种子与时间**）：`本局日志-第3层-种子20261010-20261012-150405.txt`。 */
  本局文件名(RUN, 现在) {
    const R = (RUN && typeof RUN === 'object') ? RUN : null;
    const 层 = (R && R.层 != null) ? `第${R.层}层-` : '';
    const 种 = `种子${R && R.种子 != null ? R.种子 : '—'}`;
    const 时 = this.文件名时间(现在);
    return `本局日志-${层}${种}-${时}.txt`
      .replace(/[\\/:*?"<>|\s]/g, '');      // Windows / macOS 都不认的字符一律去掉
  },

  /* ---------------- ⑤ 复制 / 下载（都有失败兜底，都返回可见反馈） ---------------- */
  /** 复制为文本。优先 `navigator.clipboard`，其次临时 `textarea` + `execCommand('copy')`；
   *  两条路都不行 → `{ok:false, 方式:'全选文本'}`，界面把整段文本摊在屏上让玩家手动全选。 */
  复制(文) {
    const 字 = 记录文字(文);
    if (!字) return { ok: false, 方式: null, 提示: '这一场没有可复制的文本。' };
    try {
      if (typeof navigator !== 'undefined' && navigator && navigator.clipboard
        && typeof navigator.clipboard.writeText === 'function') {
        const p = navigator.clipboard.writeText(字);
        if (p && typeof p.catch === 'function') p.catch(() => {});   // 异步失败也不炸（同步这条路已经给了反馈）
        return { ok: true, 方式: '剪贴板', 字数: 字.length, 提示: `已复制到剪贴板（${字.length} 字）` };
      }
    } catch (e) { /* 落到下面的退路 */ }
    try {
      if (typeof document !== 'undefined' && document && document.createElement && document.body
        && typeof document.execCommand === 'function') {
        const ta = document.createElement('textarea');
        ta.value = 字;
        if (ta.setAttribute) ta.setAttribute('readonly', 'readonly');
        if (ta.style) { ta.style.position = 'fixed'; ta.style.left = '-9999px'; }
        document.body.appendChild(ta);
        if (typeof ta.select === 'function') ta.select();
        const ok = document.execCommand('copy');
        if (document.body.removeChild) document.body.removeChild(ta);
        if (ok) return { ok: true, 方式: 'execCommand', 字数: 字.length, 提示: `已复制到剪贴板（${字.length} 字）` };
      }
    } catch (e) { /* 落到下面的退路 */ }
    return { ok: false, 方式: '全选文本', 字数: 字.length,
      提示: '这个环境不让写剪贴板：退化成「全选文本」—— 整段文本已经摊在屏幕上，手动全选复制就行。' };
  },
  /** 下载 .txt：`Blob` + `a[download]`。没有 `Blob` / `URL`（或建不出来）→ `{ok:false}`，界面给可见提示。 */
  下载(文, 名) {
    const 字 = 记录文字(文);
    const 文件名 = 记录文字(名) || this.文件名(null);
    if (!字) return { ok: false, 文件名, 提示: '这一场没有可下载的文本。' };
    try {
      if (typeof Blob !== 'undefined' && typeof URL !== 'undefined' && URL
        && typeof URL.createObjectURL === 'function'
        && typeof document !== 'undefined' && document && document.createElement && document.body) {
        const 块 = new Blob([字], { type: 'text/plain;charset=utf-8' });
        const 址 = URL.createObjectURL(块);
        const a = document.createElement('a');
        a.href = 址;
        a.download = 文件名;
        if (a.style) a.style.display = 'none';
        document.body.appendChild(a);
        if (typeof a.click === 'function') a.click();
        if (document.body.removeChild) document.body.removeChild(a);
        if (typeof URL.revokeObjectURL === 'function') URL.revokeObjectURL(址);
        return { ok: true, 文件名, 字数: 字.length, 地址: 址, 提示: `已下载 ${文件名}（${字.length} 字）` };
      }
    } catch (e) { /* 落到下面的兜底 */ }
    return { ok: false, 文件名, 字数: 字.length,
      提示: '这个环境不支持下载（没有 Blob / URL）：用「复制为文本」，或者把文本摊出来手动存。' };
  },
};
