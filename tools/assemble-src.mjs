/* ============================================================================
 * 把 shell.html + css + js 拼回一份完整 HTML 文本。
 * ----------------------------------------------------------------------------
 * 规则（照搬战棋 tools/assemble-src.mjs，需求单 #1 起的那套）：
 *   - `<!-- @include 相对路径 -->` 整行（连同换行）替换成那个文件的内容；
 *   - 文件内容是**原样**拼接的，所以 js/ 里所有片段共享同一个作用域；
 *   - 生成物（src/artifact-fragment.html、index.html）不要手改，改源文件再跑
 *     `node tools/build-src.mjs`。
 * ========================================================================== */
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

export function hasShell(srcDir) { return existsSync(join(srcDir, 'shell.html')); }

export function assemble(srcDir) {
  const shell = readFileSync(join(srcDir, 'shell.html'), 'utf8');
  return shell.replace(/^<!-- @include (\S+) -->\r?\n/gm, (_, rel) => {
    const p = join(srcDir, rel);
    if (!existsSync(p)) throw new Error(`shell.html 引用的 ${rel} 不存在`);
    return readFileSync(p, 'utf8');
  });
}
