/* ============================================================================
 * 「跑分段」——测试套件按段拆分后的**执行器**（★ 2026-10-13 P1 测试拆分新增）。
 * ----------------------------------------------------------------------------
 * **为什么有它**：`tools/verify-all.mjs` 是按 `tests/<名>.js` **一个套件一个文件** spawn 的，
 * 套件总数与入口是硬要求（不许变）。所以大套件拆出来的编号片段**不是独立套件**，
 * 而是由**同名入口**（`tests/map.js`）按序读出来、拼成一份、**当作一个模块跑**。
 *
 * **做法**：把片段文本按序拼接后交给 `vm.runInThisContext`，外面包一个
 * `(async function () { 'use strict'; … })()`：
 *   · 拼出来的文本 == 拆分前那个文件的**逐字节副本**（片段就是逐行搬的家）→ 语义不变；
 *   · 所有片段在**同一个函数作用域**里跑 → 顶层 `const/let/函数/全局计数` 照旧互相看得见；
 *   · 顶层 `await`（`map.js` 有）在 async 函数里合法；
 *   · `'use strict'` = 原文件是 ESM（模块恒定严格模式），这样 `this` / 静默赋值这些行为一致；
 *   · `process.exit()` 照旧直接退出（退出码就是套件自己的退出码）。
 * **入口那一侧**要做的：只保留「import + HERE / ROOT」这几行（`import.meta` 在脚本里不合法），
 * 把它们 `Object.assign(globalThis, …)` 发布出去，再 `await 跑分段(...)`。见各入口文件头的说明。
 * ========================================================================== */
import { readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import vm from 'vm';

/** 按序跑一个套件的所有片段（`段文件们` 的顺序就是拼接顺序，也是执行顺序）。 */
export async function 跑分段(入口url, 段文件们) {
  const 目录 = dirname(fileURLToPath(入口url));
  const 文 = 段文件们.map(f => readFileSync(join(目录, f), 'utf8')).join('');
  await vm.runInThisContext(
    `(async function () {\n'use strict';\n${文}\n})()`,
    { filename: `[P1 分段] ${段文件们.join(' + ')}` });
}
