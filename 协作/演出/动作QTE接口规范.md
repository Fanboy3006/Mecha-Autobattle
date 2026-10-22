# 动作 QTE 标准接口规范（ActionQTE Protocol v1 · 跨项目可移植说明）

> **定位**：本规范定义「机战像素风 · 多段滑动斩击动作 QTE（ActionQTE）」的输入请求、输出载荷、敌机闪避轨迹方程与状态机时序。
> **解耦保证**：核心实现见 [`协作/演出/demo-动作QTE-刹那七连斩.html`](demo-动作QTE-刹那七连斩.html) 的 Layer 1–3，**零外部框架依赖、零全局变量耦合**，其他 AI 或任何回合制 / 战棋项目可直接复制或通过 `window.__actionQTE` 挂载使用。

---

## 1. 输入与输出 JSON Schema

### 1.1 输入请求 `QTERequest`
```json
{
  "模式": "melee_slash",
  "种子": 20261013,
  "攻击者": { "键": "CB1", "名": "刹那·F·清英", "机体": "能天使·七剑", "transAm": true, "基础暴击率": 20 },
  "武器": { "名": "七剑·TRANS-AM 乱舞", "威力": 2800, "基础命中": 95, "段数": 7, "步进": 10, "单段基准伤": 380 },
  "目标": { "键": "fighter", "名": "高机动战机", "闪避": 30, "最大HP": 2600, "当前HP": 2600 },
  "配置": { "完美暴击加成": 25, "基础窗口毫秒": 650, "最小判定半径": 16, "最大判定半径": 38, "完美核心比例": 0.42 }
}
```

### 1.2 输出载荷 `QTEResult`（可直接传入引擎 `resolveAttack(..., { qte结果 })`）
```json
{
  "模式": "melee_slash",
  "种子": 20261013,
  "总段数": 7,
  "命中段数": 6,
  "完美段数": 4,
  "暴击段数": 4,
  "总伤害": 2660,
  "理论期望伤害": 1820,
  "击破": true,
  "各段": [
    { "段号": 1, "理论命中率": 95, "命中": true, "评价": "PERFECT", "暴击": true, "精度": 0.89, "距离": 3.9, "伤害": 513 }
  ]
}
```

---

## 2. 难度映射与敌机闪避数学模型（纯函数 · 0 `rng`）

### 2.1 数值 → 动作难度映射 `取晃动参数(eva, q, stageIdx)`
设目标闪避为 $\text{eva}$，当前段理论命中率为 $q \in [0, 100]$，画布原生分辨率为 $240 \times 160$：
- **晃动频率（Hz）**：$f = \text{round}_2(0.8 + 0.035 \cdot \text{eva} + 0.015 \cdot (100 - q))$
- **水平晃动幅度（px）**：$A_x = \text{round}(\min(68,\; 12 + 0.75 \cdot \text{eva} + 0.35 \cdot (100 - q)))$
- **垂直晃动幅度（px）**：$A_y = \text{round}(\min(28,\; 4 + 0.28 \cdot \text{eva} + 0.12 \cdot (100 - q)))$
- **机身有效圈半径（px）**：$R_{\text{eff}} = \text{round}(16 + (38 - 16) \cdot \text{clamp}(q, 0, 100) / 100)$
- **核心完美圈半径（px）**：$R_{\text{perf}} = \text{round}(R_{\text{eff}} \times 0.42)$
- **单段反应窗口（ms）**：$T_{\text{win}} = \text{round}(\max(380,\; 650 - 2.5 \cdot \text{eva}))$

### 2.2 敌机实时轨迹方程 `getTargetPos(tMs, stageParams, seed)`
以画布中心 $(c_x, c_y) = (120, 82)$ 为基准，时间 $t = t_{\text{ms}} / 1000$，由确定性种子与段号生成相位 $\phi_1, \phi_2$：
$$x(t) = c_x + A_x \cdot \sin(2\pi f t + \phi_1) \cdot \cos(\pi f \cdot 0.5 t)$$
$$y(t) = c_y + A_y \cdot \sin(2\pi f \cdot 1.3 t + \phi_2)$$

### 2.3 滑动斩击线段判定 `judgeSlashSegment(p1, p2, targetPos, R_eff, R_perf)`
1. 若挥砍线段长度 $\lVert p_2 - p_1 \rVert < 18\text{px}$（防误触点击）或窗口超时未划，直接判 `MISS`。
2. 计算点 $C = \text{targetPos}$ 到线段 $p_1 p_2$ 的最短欧氏距离 $d$（投影参数 $\tau = \text{clamp}(\frac{(C - p_1)\cdot(p_2 - p_1)}{\lVert p_2 - p_1\rVert^2}, 0, 1)$）。
3. 判定分级：
   - $d \le R_{\text{perf}} \Rightarrow \text{PERFECT}$（必中 + 奖励暴击修正，触发 120ms 顿帧与金色斩弧）；
   - $R_{\text{perf}} < d \le R_{\text{eff}} \Rightarrow \text{HIT}$（命中，按基础暴击率结算，触发 60ms 顿帧与青白光束斩弧）；
   - $d > R_{\text{eff}} \Rightarrow \text{MISS}$（未中，敌机拉出侧闪残影）。
4. **多段动态步进闭环（`step = 10`）**：本刀 `HIT/PERFECT` 后下一刀 $q \leftarrow \max(5, q - 10)$（敌机受惊机动加剧、判定圈收窄）；本刀 `MISS` 后下一刀 $q \leftarrow \min(100, q + 10)$（敌机旧力已竭、判定圈放大）。

---

## 3. 四幕导演状态机时序（State Machine Director）

| 幕次 | 状态枚举 | 默认时长 | 核心表现与转移条件 |
|---|---|---|---|
| **第 1 幕** | `DRAW_CUTIN` | `900 ms` | 我方特写：TRANS-AM 红霞粒子爆发 + 刹那拔出 GN 实体剑切入台词 |
| **第 2 幕** | `SLASH_QTE` ($\times 7$) | 每段 `T_win` + 顿帧 | 敌机正前晃动 + 玩家滑动挥砍（`PERFECT` 顿帧 120ms / `HIT` 60ms / `MISS` 90ms） |
| **第 3 幕** | `FINALE` | `1100 ms` | 刹那转身收刀定格，敌机身上已命中斩痕同时引爆，总伤害跳字 + 击破连爆 |
| **第 4 幕** | `RESULT` | 常驻 | 结算面板：手操实际 vs 纯随机期望对账表 + 标准 `QTEResult` JSON 导出 |

---

## 4. 20 行代码接入任意回合制 / 战棋项目示例

```js
// 1. 从战斗上下文构造 QTE 请求并运行（支持交互式 Promise 或无头模拟）
const req = {
  种子: ctx.seed,
  攻击者: { 键: att.key, 名: att.name, 基础暴击率: critRate(w, att) },
  武器: { 名: w.name, 基础命中: hitRate(att, w, def, { ctx }).hit, 段数: w.hits || 7, 步进: w.step || 10 },
  目标: { 键: def.key, 名: def.name, 闪避: def.eva, 最大HP: def.maxHp, 当前HP: def.hp },
};
// 2. 获取玩家手操（或 AI 预设）产生的 QTEResult
const qteResult = await window.__actionQTE.运行或模拟(req);
// 3. 将 QTEResult 注入原战斗结算函数 resolveAttack，逐段覆写命中与暴击
const outcome = resolveAttack(att, def, w, ctx, {
  强制QTE: true,
  qte结果: qteResult,
});
// outcome.字段.动作QTE 即包含 { 模式, 总段数, 命中段数, 完美段数, 详情 }
```
