#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · **全队方针**测试（作者 2026-10-12 拍板的第一件）
 * ----------------------------------------------------------------------------
 * 规格书 = `协作/方向调整-全队方针与反馈.md` **第 1 节**（1.1–1.8），验收 = **§1.8 的 9 条**。
 * 旧的逐台指令（进攻 / 集火 / 守护 / 防御 / 换位）与「守护」整条机制、战斗中的「换位」都已删（§1.4），
 * 所以旧的**集火 / 守护 / 换位**断言按方案书明确授权删掉，换成下面这 9 段
 * （「旧断言 → 新断言 → 为什么」的逐条对照表在 `协作/任务板.md` 的「方针」段）。
 *
 * 全部用固定种子 + 单回合驱动（`开局()` → `设方针()` / `设单位开关()` → `打一回合()`），结果是决定性的。
 * 用法：node tests/commands.js
 * ========================================================================== */
import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { loadPage } from './lib/dom-stub.mjs';
import { 读源码 } from './lib/读源码.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');

/* ★ 2026-10-13 P1（源码机械拆分）之后：本套件的正文按职责拆在下面这些**编号片段**里。
   它们是**逐行搬的家**（拼接产物与原文件逐字节相同），由 `tests/lib/跑分段.mjs`
   顺序拼起来、当作一个模块跑（同一个作用域、同一个顺序、断言一句没改）。
   **不是独立套件** —— `tools/verify-all.mjs` 的入口与套件总数一个都没变。
   机制、片段清单与逐字节证据见 `docs/实现/结构表.md`。 */
import { 跑分段 } from './lib/跑分段.mjs';

/* 片段是脚本（不是模块），head 里的这些名字要发布到 globalThis 才看得见 */
Object.assign(globalThis, { HERE, ROOT, readFileSync, dirname, join, fileURLToPath, loadPage, 读源码 });

await 跑分段(import.meta.url, [
  'commands-1-默认路径与方针.js',
  'commands-2-三层反馈与标定经济.js',
]);
