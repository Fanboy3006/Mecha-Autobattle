// M4 本地试玩入口：把 .tools/smoke/_site 用正确的 MIME 静态托管出来。
//   /       → JS 旧版（仓库根的自包含 index.html）
//   /godot/ → Godot M4 版（godot/build/web 导出产物）
// 用法：node serve-site.mjs [站点目录] [端口]
// 为什么需要专门写：`.wasm` 必须是 application/wasm，否则浏览器不做流式实例化（会慢/可能报错）；
// 单线程导出（variant/thread_support=false）不需要 COOP/COEP 响应头。
import { createServer } from 'http';
import { readFile, stat } from 'fs/promises';
import { extname, join, resolve } from 'path';

const SITE = resolve(process.argv[2] || 'F:\\DSH-mecha\\.tools\\smoke\\_site');
const PORT = Number(process.argv[3] || 8099);
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.woff2': 'font/woff2',
};

const server = createServer(async (req, res) => {
  try {
    let p = join(SITE, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    const st = await stat(p);
    if (st.isDirectory()) p = join(p, 'index.html');
    const body = await readFile(p);
    res.writeHead(200, {
      'Content-Type': TYPES[extname(p)] || 'application/octet-stream',
      'Content-Length': body.length,
      'Cache-Control': 'no-store',
    });
    res.end(body);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404');
  }
});
server.listen(PORT, '127.0.0.1', () => {
  console.log(`站点目录：${SITE}`);
  console.log(`JS 旧版  ：http://127.0.0.1:${PORT}/`);
  console.log(`Godot M4 ：http://127.0.0.1:${PORT}/godot/`);
  console.log('（Ctrl+C 停；这是只读静态托管，不改任何仓库文件）');
});
