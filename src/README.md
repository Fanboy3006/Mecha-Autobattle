# src（游戏源文件）

**只改这些：**

| 文件 | 内容 |
|---|---|
| `shell.html` | HTML 骨架。`<style>` / `<script>` 标签之间是占位行 `<!-- @include … -->` |
| `css/main.css` | 游戏样式 |
| `js/NN-名字.js` | 游戏脚本，按文件名顺序拼接（**同一个作用域**，和拼成一个大文件等价） |

**生成物，不要手改：** `artifact-fragment.html`（片段版，以后发 claude.ai Artifact 用）、仓库根的 `index.html`（完整页面，双击可玩）。改完源文件跑：

```bash
node tools/build-src.mjs          # 生成两份 HTML
node tools/build-src.mjs --check  # 只检查
node tests/smoke.js               # 冒烟测试
```

- 拼接规则在 `tools/assemble-src.mjs`：占位行整行（连同换行）替换成文件内容，内容原样拼接。
- 加新 js 文件：放进 `js/`，在 `shell.html` 的 `<script>` 里对应位置加一行 `<!-- @include js/文件名.js -->`。
- `js/00-head.js` 开始一个贯穿全部片段的 IIFE，`js/99-boot.js` 收尾并挂 `window.__game`；**中间的片段不要再自己包一层 IIFE**，直接写顶层代码。
- 片段之间共享作用域，所以一个文件里的 `const` / `function` 其他文件直接能用。
- `@include` 的文件内容里如果要写 `</script`，会提前结束脚本块（战棋的 `art/mech-icons.js` 就踩过这个坑，注入前要检查）。
