#!/usr/bin/env node
/* ============================================================================
 * 机甲指挥 · 界面测试（方案第 9 节 M2 / M3 的验收）
 * ----------------------------------------------------------------------------
 * M2：作者能从菜单进一场固定的测试战斗并打完；播放 / 暂停 / 二倍速 / 跳过动画只影响播放。
 * M3：指令阶段能下指令（进攻 / 集火 / 守护 / 防御 / 换位 + 大招开关）、能看到敌人意图、
 *     能一回合一个回合地打（指令留着，不想改就直接开打）。
 *
 * 不依赖 Playwright：用 tests/lib/dom-stub.mjs 把 index.html 的内联脚本跑起来。
 * 页面里的动画（setTimeout）在替身里不会自己跑，所以用 `界面.手动播放 = true` + `播放.tick()`
 * 一步步推进——这正是「播放只是播放」的证据：推进方式不影响结果。
 *
 * ★ 2026-10-13 录像线（作者：「（导出日志复制粘贴 / 发布成 CSV）太复杂了，你再想想还有什么方法可以保存录像」）：
 *   [14] 一键「保存本局录像 / 保存全部录像」—— 战斗结算屏 / 大地图屏 / 本局结算屏上的那两颗按钮
 *        **真派发点击**（照 [12]/[13] 段的写法）；替身里**桩掉真实下载**（Blob / URL / a[download]，
 *        并给 showSaveFilePicker / window.open 装「真下载计数器」断言恒 0）；文件名字段 / 内容字段齐 /
 *        同种子两遍字节逐字相同 / 空局给一句可见反馈 / 「保存全部」N 条与 20 局上限。
 *
 * 用法：node tests/battle_ui.js
 * ========================================================================== */
import { dirname, join } from 'path';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { loadPage } from './lib/dom-stub.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');

/* ★ 2026-10-13 P1（源码机械拆分）之后：本套件的正文按职责拆在下面这些**编号片段**里。
   它们是**逐行搬的家**（拼接产物与原文件逐字节相同），由 `tests/lib/跑分段.mjs`
   顺序拼起来、当作一个模块跑（同一个作用域、同一个顺序、断言一句没改）。
   **不是独立套件** —— `tools/verify-all.mjs` 的入口与套件总数一个都没变。
   机制、片段清单与逐字节证据见 `docs/实现/结构表.md`。 */
import { 跑分段 } from './lib/跑分段.mjs';

/* 片段是脚本（不是模块），head 里的这些名字要发布到 globalThis 才看得见 */
Object.assign(globalThis, { HERE, ROOT, dirname, join, readFileSync, fileURLToPath, loadPage });

await 跑分段(import.meta.url, [
  'battle_ui-1-编队与战斗屏.js',
  'battle_ui-2-三层反馈与敌人卡.js',
  'battle_ui-3-作战记录与声音开关.js',
  'battle_ui-4-可选项居中与保存录像.js',
  'battle_ui-5-标定经济与播放层.js',
]);
