/**
 * 职责：给 `tests/golden/native/inputs.json` 追加 / 刷新**殖民卫星军分区**（新文件 `colonial.json`）。
 *
 * 为什么单独一个工具：`tools/extract_native_inputs.gd` 是从已退役的 `tests/golden/battle/*.json` 抽的，
 * 那个脚本注明「别重跑」；本工具只做**增补**——其它样例一个字不动。
 *
 * 分区怎么搭（`colonial`）：我方固定 = 殖民卫星军五人 Lv30 全卡池（与 `GameSession.殖民卫星军快速编成` 一致）；
 * 敌方规格 / 编成 直接借 `faction_殖民卫星军.json` 里**回合数最长**的那几场（久战才跑得出觉醒入场 → SEED、
 * 感应牌库抽 / 放入、METEOR 锁定链；速推图一场打完什么都看不到）。每套敌方规格配 2 个种子。
 *
 * 用法（仓库根目录）：node godot/tools/add_colonial_native_inputs.mjs
 * 幂等：已有的 `colonial/*` 样例先删再按下面这份表重建；键名升序（与现有文件同一套写法）。
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const 根 = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const 输入 = path.join(根, 'tests/golden/native/inputs.json');
const 敌来源 = path.join(根, 'tests/golden/native/faction_殖民卫星军.json');
/** 殖民卫星军五人 Lv30（前排 迪奥 / 特洛瓦 / 拉克丝，后排 卡嘉莉 / 希罗）。 */
const 五人 = [
  { 键: 'W2', 位: 0, 等级: 30, hp比: 1 },
  { 键: 'W3', 位: 1, 等级: 30, hp比: 1 },
  { 键: 'S1', 位: 2, 等级: 30, hp比: 1 },
  { 键: 'S2', 位: 4, 等级: 30, hp比: 1 },
  { 键: 'W1', 位: 5, 等级: 30, hp比: 1 },
];
const 种子偏移 = [0, 101];

const 数据 = JSON.parse(fs.readFileSync(输入, 'utf8'));
// 上一版工具加过的 quick_colonial 分区一并清掉（殖民卫星军改走久战的 `colonial` 分区）。
数据.样例 = 数据.样例.filter((s) => {
  const id = String((s && s.id) || '');
  return !id.startsWith('colonial/') && !id.startsWith('quick_colonial/');
});
/** inputs.json 里按 id 查**输入**（黄金样例文件只有期望、没有输入）。 */
const 输入表 = new Map(数据.样例.map((s) => [String(s.id || ''), s]));

const 敌组 = JSON.parse(fs.readFileSync(敌来源, 'utf8')).样例;
const 按回合 = [...敌组].sort((a, b) => (b.期望.回合摘要 || []).length - (a.期望.回合摘要 || []).length);
const 用过 = new Set();
const 模板们 = [];
for (const 样 of 按回合) {
  const 源 = 输入表.get(String(样.id || ''));
  if (!源) continue;
  const 指纹 = JSON.stringify(源.敌方规格 || []);
  if (用过.has(指纹)) continue;
  用过.add(指纹);
  模板们.push(源);
  if (模板们.length >= 2) break;
}
if (模板们.length === 0) {
  console.error('✗ inputs.json 里找不到 faction_殖民卫星军 的久战输入模板');
  process.exit(1);
}

let 加 = 0;
for (let k = 0; k < 模板们.length; k++) {
  const 源 = 模板们[k];
  const 敌方规格 = 源.敌方规格 || [];
  const 编成 = 源.编成 || {};
  const 种子 = Number(源.种子 || 20261013);
  for (const 偏 of 种子偏移) {
    const 条 = {
      分文件: 'colonial',
      我方: JSON.parse(JSON.stringify(五人)),
      敌方规格: JSON.parse(JSON.stringify(敌方规格)),
      种子: 种子 + 偏,
      编成: JSON.parse(JSON.stringify(编成)),
      藏品: [],
      组: 'colonial',
      id: `colonial/殖民卫星军-${k + 1}-${种子 + 偏}`,
    };
    const 排序 = {};
    for (const key of Object.keys(条).sort()) 排序[key] = 条[key];
    数据.样例.push(排序);
    加 += 1;
  }
}
fs.writeFileSync(输入, JSON.stringify(数据, null, 1) + '\n');
console.log(`✓ 已写入 ${加} 条 colonial 样例（久战模板 ${模板们.length} 套 × ${种子偏移.length} 种子）→ ${path.relative(根, 输入)}`);
