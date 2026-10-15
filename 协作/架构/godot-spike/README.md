# godot-spike（CC · 2026-10-15）

《Godot Migration Architecture v1》的实测证据，也是 M0 新仓库 `core/util` 的种子代码。**不是正式工程**，M0 建好 Godot 仓库后整体迁过去，这个目录随即删除。

| 文件 | 作用 |
|---|---|
| `core/rng.gd` | `Mulberry32`：与 JS `00-head.js` 的 `mulberry32()` 逐位一致 |
| `core/js_compat.gd` | `js_round`（JS `Math.round` 语义）、`stable_sort`（与 V8 稳定排序一致） |
| `tests/run_tests.gd` | 无界面测试入口，退出码 0 / 1 |
| `tests/golden/rng_vectors.json` | 从 JS 构建导出的对拍向量（随机数存 uint32、浮点存 IEEE-754 位串） |
| `gen_vectors.mjs` | 导出上面那份向量（只读加载 JS 的 `index.html`） |
| `main.tscn` / `main.gd` | Web 冒烟场景：浏览器里算同一个校验和 |
| `export_presets.cfg` | Web 预设：单线程（GitHub Pages 不需要特殊响应头） |
| `web_export_chromium.png` | Chromium 里的实际运行截图（中文方框 = 还没打包 CJK 字体） |

```
node gen_vectors.mjs <JS 仓库路径> tests/golden/rng_vectors.json
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd            # 期望：通过 11 · 失败 0
godot --headless --path . --export-release "Web" build/web/index.html  # 需要 4.7.2 的 Web 导出模板
```

实测结果（Godot 4.7.2，Linux）：测试 11/11 通过；Web 导出 `index.wasm` 39.5 MB（gzip 10.1 MB）；Chromium 中校验和 `182751003` 与 headless 相同。
