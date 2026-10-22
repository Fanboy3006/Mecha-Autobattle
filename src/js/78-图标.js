/* ============================================================================
 * 机体图标层（M5，方案 8.2）
 * ----------------------------------------------------------------------------
 * 素材是**原创矢量图形** `art/mech-icons.js`（战棋带过来的，不进旧仓库改动），
 * 由 `tools/build-src.mjs` 原样内联进 HTML 的 ART 块，对外是全局 `MechIcons`（下面简称 MI）。
 *
 * 用法（照方案 8.2 的写法）：
 *   MI.build(id, {pal, plate, size, lod, role}) → 绘制指令数组
 *   MI.draw(ctx, prims, size, x, y)             → 画到 canvas 的 (x, y) 起、边长 size 的方框里
 * 这里把「机体键 → 图标 id → 调色板 → 小 canvas → dataURL」缓存一遍，界面用字符串拼 HTML 时直接塞 <img>。
 *
 * 图标怎么选（照战棋 `20-绘制.js:424-451` 的 iconIdOf / palKeyOf / STOCK_BY_ROLE）：
 *   - `MI.ICON_BY_MECH[机体名]` 有专属图标就用它；
 *   - 我方没有专属图标的，按 `tags.战斗分类` 借用**原型剪影**（势力配色仍按自己的势力）；
 *   - 敌人没有专属图标的，按体型 / 飞行退到 `flagship` / `fortress` / `fighter` / `grunt`；
 *   - 再挑不出来（或者没有 canvas、没有 MI、id 不在 `MI.ids` 里）→ **退回势力色方块 + 短名**，不报错。
 * 配色：我方查 `MI.FACTION_PAL[势力]`，敌方一律 `enemy`（和战棋一样）。
 * ========================================================================== */

const 图标 = {
  MI: null,                        // ART 块注入的 MechIcons；没注入就是 null（退方块）
  尺寸: { 卡: 34, 列表: 28, 格: 32 },   // 三种卡片上的图标边长（逻辑像素）
  倍: 2,                           // 画布按 2 倍渲染，高分屏上不糊
  缓存: {},                        // "图标id|调色板|尺寸" → dataURL（画一次就够了）
  原型: { 近卫: 'B1', 尖兵: 'B2', 指挥: 'M1', 重装: 'M2', 狙击: 'CB2', 特种: 'CB3' },

  /** 取素材接口：ART 块在游戏脚本之前执行，所以这里一定拿得到（除非素材没注入）。 */
  取MI() {
    if (!this.MI && typeof MechIcons !== 'undefined') this.MI = MechIcons;
    return this.MI || null;
  },
  就绪() { return !!this.取MI(); },

  /** 单位模板：我方查 ALLY_T，敌方查 ENEMY_T（和 80-界面.js 的 界面.单位模板 同一个口径）。 */
  单位模板(键, 方) { return 方 === 'ally' ? tplOf(键) : ENEMY_T[键]; },
  /** 机体名（数据里的 `mech` 字段）——图标按它查 ICON_BY_MECH。 */
  机体名(键, 方) { const t = this.单位模板(键, 方); return (t && t.mech) || 键; },
  短名(键, 方) { const t = this.单位模板(键, 方); return (t && (t.short || t.mech)) || 键; },
  转义(s) { return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); },

  /** 机体键 + 阵营 → 图标 id（挑不出来就 null = 退方块）。 */
  图标号(键, 方) {
    const MI = this.取MI();
    if (!MI || !MI.ICON_BY_MECH) return null;
    const 名 = this.机体名(键, 方);
    if (MI.ICON_BY_MECH[名]) return MI.ICON_BY_MECH[名];
    const t = this.单位模板(键, 方);
    if (方 === 'ally') return this.原型[(t && t.tags && t.tags.战斗分类) || ''] || null;
    if (!t) return null;                       // 连模板都没有（数据里没有这个敌人）→ 退方块 + 短名
    /* 敌人：3×3 以上当旗舰、2×2 当要塞、飞行当战斗机，其余当杂兵（战棋 20-绘制.js:437-443） */
    const w = Math.max((t && t.w) || 1, (t && t.h) || 1);
    return w >= 3 ? 'flagship' : w === 2 ? 'fortress' : (t && t.flying ? 'fighter' : 'grunt');
  },

  /** 势力 → 调色板键（敌方一律 enemy）。 */
  调色板(键, 方) {
    const MI = this.取MI();
    if (!MI || !MI.FACTION_PAL || 方 !== 'ally') return 'enemy';
    const t = this.单位模板(键, 'ally');
    return MI.FACTION_PAL[(t && t.tags && t.tags.势力) || ''] || 'cb';
  },

  /** 画一张小图 → dataURL（画不出来返回 null）。同一个 id + 调色板 + 尺寸只画一次。 */
  画布(键, 方) {
    const MI = this.取MI();
    const id = this.图标号(键, 方);
    const pal = this.调色板(键, 方);
    const 逻辑 = this.尺寸.卡;
    const 长 = Math.round(逻辑 * this.倍);
    const 缓键 = id + '|' + pal + '|' + 长;
    if (缓键 in this.缓存) return this.缓存[缓键];
    let url = null;
    try {
      if (MI && id && document && document.createElement && MI.ids && MI.ids.indexOf(id) >= 0) {
        const cv = document.createElement('canvas');
        cv.width = 长; cv.height = 长;
        const ctx = cv.getContext ? cv.getContext('2d') : null;
        if (ctx) {
          const t = this.单位模板(键, 方);
          const role = (t && t.tags && t.tags.战斗分类) || undefined;
          MI.draw(ctx, MI.build(id, { pal, plate: 'none', role, size: 长 }), 长, 0, 0);
          url = cv.toDataURL ? cv.toDataURL() : null;
        }
      }
    } catch (e) { url = null; }        // 没有 canvas / 画失败：静默退到方块 + 短名，不往上抛
    this.缓存[缓键] = url;
    return url;
  },

  /** 卡片上的一格图标：矢量图标（`<img>` 内联 dataURL）或势力色方块 + 短名。 */
  卡(键, 方, 尺寸 = 图标.尺寸.卡) {
    const 名 = this.转义(this.短名(键, 方));
    const 标 = this.转义(this.机体名(键, 方));
    const url = this.画布(键, 方);
    const 外 = `width:${尺寸}px;height:${尺寸}px`;
    if (url) return `<span class="mic" title="${标}" style="${外}"><img class="mi" src="${url}" alt="${标}" width="${尺寸}" height="${尺寸}"></span>`;
    const 色 = 方 === 'ally' ? 势力色(键) : 敌方色;
    return `<span class="mic fb" title="${标}" style="--fc:${色};${外}">${名}</span>`;
  },
};
