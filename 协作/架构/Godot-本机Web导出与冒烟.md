# Godot · 本机 Web 导出与浏览器冒烟（怎么在**没有 CI** 的情况下自己验「Web 版可玩」）

> **什么时候读**：要验「Web 版能不能跑」、要出一个给作者试玩的包、或要复现 M4/M5 的 Web 验收时。
> **配套权威记录**：[`协作/Godot迁移-ARGON验收对照表.md`](../Godot迁移-ARGON验收对照表.md) 的 **§8.3 / §8.3b / §9.4 / §9.4b**
> （那几节记的是**当时实测的真实输出**；本文只写**怎么复现**）。
> **为什么需要本文**：M4 的 Web 验收一开始**全部依赖仓库外的东西**（模板的重定向、一键脚本、`playwright-core`、本地试玩服务）——
> 工作区一丢就复现不了。本文把那套做法落进仓库。

---

## 0. 本机环境事实（2026-10-16 实测，写死在这，改机器要重测）

| 项 | 值 |
|---|---|
| Godot | `F:\DSH-mecha\.tools\godot\Godot_v4.7.2-stable_win64_console.exe`（★ 用 `_console` 变体才有完整控制台输出） |
| 工程 | `F:\DSH-mecha\mecha-autobattle\godot` |
| 导出模板版本目录名 | **`4.7.2.stable`**（不是 `4.7.2`） |
| 需要的模板成员 | `templates/web_nothreads_release.zip`（约 **10 245 903 B**）+ `templates/version.txt`（13 B，内容 `4.7.2.stable`，**带尾部换行**） |
| node / npm | `C:\Program Files\nodejs`（实测 v24.14.1 / 11.11.0） |
| 浏览器 | Chrome `C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`；Edge 同目录 `msedge.exe` |
| 冒烟脚本 | `godot/tools/web_smoke.mjs`（仓库里，**CI 与本机共用**） |
| Web 冒烟期望值 | 校验和 **`182751003`** · 数据 `ALLY_T=34 / 编成表=47 / 战术卡牌表=32` · 无 `PAGEERROR\|USER ERROR\|SCRIPT ERROR` |

---

## 1. ★ 模板放哪：Godot 在 Windows **只认** `%APPDATA%\Godot\export_templates\<版本>.<状态>\`

**5 条路线实测结论**（详见验收对照表 §8.3）：

| 路线 | 结论 |
|---|---|
| **把 `$env:APPDATA` 指向 workspace 内一个目录** | ✅ **唯一可行**（Godot 会自己在 `<APPDATA>\Godot\export_templates\` 下建目录） |
| `LOCALAPPDATA` 一起指过去 | 可选（不指只多报一条 `Cannot create editor cache`，不影响导出） |
| `XDG_DATA_HOME` / `HOME` / `USERPROFILE` / `GODOT_EDITOR_SETTINGS` | ❌ 只认 `APPDATA` |
| 在 `%APPDATA%\Godot` 建 junction | ❌ 沙箱下 `UnauthorizedAccessException` |
| 命令行 `--export-templates <dir>` | ❌ **该选项不存在**（`--help` 实查：只有 `--export-release/-debug/-pack/-patch`） |
| 项目内 `res://export_templates/` | ❌ **不认**（测两次） |

### 拿模板：**不用下那 1.28 GB**，用 HTTP Range 只取单个成员

`Godot_v4.7.2-stable_export_templates.tpz` 整包约 1222 MiB，但我们要的只是里面一个成员。
读远程 zip 的尾部 EOCD + 中央目录、用 Range 取目标成员再 inflate → **网络只走约 9.81 MiB**。

```powershell
# 模板与「假 APPDATA」都放在**仓库外**（绝不进 git）
$Repo   = 'F:\DSH-mecha\mecha-autobattle'`n$Tools  = 'F:\DSH-mecha\.tools'
$TplSrc = "$Tools\godot-templates"
$AppData= "$Tools\godot-appdata"
New-Item -ItemType Directory -Force -Path $TplSrc, "$AppData\Godot\export_templates\4.7.2.stable" | Out-Null
if (-not (Test-Path "$TplSrc\web_nothreads_release.zip")) {
  $url = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
  # ★ 必须用 Node 取：本沙箱下 curl.exe 的所有 HTTPS 都失败
  #   （schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS 0x8009030E；明文 HTTP 与 TCP 都正常）
  node "$Repo\godot\tools\zipmember.mjs" $url 'templates/web_nothreads_release.zip' "$TplSrc\web_nothreads_release.zip"
  Set-Content "$TplSrc\version.txt" '4.7.2.stable' -Encoding ascii   # 别用 -NoNewline
}
Copy-Item "$TplSrc\web_nothreads_release.zip","$TplSrc\version.txt" "$AppData\Godot\export_templates\4.7.2.stable" -Force
```

> `godot/export_templates/` 这个目录**保持空**（实测不被识别）；**不要**往仓库里放模板。
> `.tools/**` 在仓库外，`git status` 永远看不到它。

---

## 2. 导出

```powershell
$Godot = 'F:\DSH-mecha\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$Proj  = 'F:\DSH-mecha\mecha-autobattle\godot'
$env:APPDATA      = 'F:\DSH-mecha\.tools\godot-appdata'
$env:LOCALAPPDATA = 'F:\DSH-mecha\.tools\godot-localappdata'
New-Item -ItemType Directory -Force -Path "$Proj\build\web" | Out-Null
& $Godot --headless --path $Proj --export-release 'Web' "$Proj\build\web\index.html"
if ($LASTEXITCODE -ne 0) { throw "导出失败 exit=$LASTEXITCODE" }
Test-Path "$Proj\build\web\index.wasm"   # 必须 True
```

`godot/build/` 已在 `godot/.gitignore` 里（**产物不进 git**）。
实测规模（M4 最终包）：`index.wasm` 39 514 754 · **`index.pck` 1 523 468** · `index.js` 279 815 · `index.html` 5 443。
`GODOT_THREADS_ENABLED = false`（对应预设 `variant/thread_support=false`）→ **不需要 COOP/COEP 响应头**。

---

## 3. 组装 `_site`（照 `.github/workflows/pages.yml` 的布局）

```
_site/
├─ index.html          ← 仓库根那个【自包含】生成物（ART / AUDIO 已内联）→ 就是 JS 旧版，路径 /
└─ godot/              ← 导出产物（index.html/.js/.wasm/.pck + 图标）    → 就是 Godot 版，路径 /godot/
```

```powershell
$S = 'F:\DSH-mecha\.tools\smoke\_site'
Remove-Item $S -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$S\godot" | Out-Null
Copy-Item 'F:\DSH-mecha\mecha-autobattle\index.html' "$S\index.html" -Force
Copy-Item "$Proj\build\web\*" "$S\godot\" -Recurse -Force
New-Item -ItemType File -Force -Path "$S\.nojekyll" | Out-Null
```

---

## 4. 浏览器冒烟（跑仓库里那个脚本，别自己另写）

```powershell
# 一次性准备（仓库外）
$Smoke = 'F:\DSH-mecha\.tools\smoke'
npm install --no-save --prefix $Smoke playwright-core@1.48.2   # npm 缓存也要指到 workspace 内，否则 EPERM
Copy-Item 'F:\DSH-mecha\mecha-autobattle\godot\tools\web_smoke.mjs' $Smoke -Force   # 也可以直接用仓库里那份

$env:NODE_PATH  = "$Smoke\node_modules"
$env:CHROME_PATH= 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
node "$Smoke\web_smoke.mjs" $S "$Smoke\shots"
```

**期望输出（7/7，退出码 0）**：
```
✓ /godot/ 启动（约 1.3 s）
✓ 浏览器内确定性校验和 = 182751003（期望 182751003）
✓ Web 包里带上了数据（机师 34 · 编成 47 · 战术牌 32）
✓ 无脚本错误
✓ 根路径 JS 版 HTTP 200 ／ 标题「机甲指挥」／ 无页面错误
```

### ★ 沙箱的坑（本机特有，不是工程问题）

- **`chromium.launch: spawn EPERM`**：Chromium 的 Mojo IPC **必须开命名管道**，受限沙箱一律拒绝
  （裸启动会死在 `mojo\public\cpp\platform\platform_channel.cc  Check failed: 拒绝访问 (0x5)` + crashpad `OpenProcess: 拒绝访问`）。
  → **先按常规跑一次拿到拒绝**，再对**同一条命令**申请**一次性 `danger-full-access` 重试**（DSH 会向作者弹批准）。
  **不要**改脚本去绕（改 CDP-over-TCP 也无效）。**沙箱外**则直接跑，无需提权。
- **`curl.exe` 在本沙箱所有 HTTPS 都失败** → 一切下载/探测**走 Node**。
- `godot --headless --import` / 游戏启动时会打几条
  `Could not create directory: user:/…` / `Failed to read the root certificate store`
  —— **那是沙箱环境的噪声，与代码无关**，退出码仍是 0。**看 `SCRIPT ERROR` 与 `PAGEERROR` 才是有意义的。**

---

## 5. 本地试玩入口（给作者点开即玩，不用等 Pages）

```powershell
node 'F:\DSH-mecha\mecha-autobattle\godot\tools\serve_site.mjs' 'F:\DSH-mecha\.tools\smoke\_site' 8099
#   JS 旧版  ：http://127.0.0.1:8099/
#   Godot 版 ：http://127.0.0.1:8099/godot/
```
★ 静态服务**必须**给 `.wasm` 发 `Content-Type: application/wasm`（否则不做流式实例化）；
单线程导出**不需要** COOP/COEP。服务脚本见 `godot/tools/serve_site.mjs`（`Cache-Control: no-store`，换包即生效）。

### Web 存档落在哪（试玩时要提醒作者的）

Godot 的 `user://` 在浏览器里落 **IDBFS → IndexedDB**。实测（`godot/tools/idbfs_check.mjs`）：
启动后 `indexedDB.databases()` 里有 **`/userfs`**，且**没有** `user://` 建目录失败。
→ 存储层是通的。**但无痕模式不保存、清站点数据会丢**，试玩清单里要写。

---

## 6. 与 CI 的分工

| | 本机 | CI |
|---|---|---|
| 模板 | 仓库外 + `APPDATA` 重定向 + Range 取单成员（**9.81 MiB**） | `godot/tools/ci_setup_godot.sh --with-web-templates`（下整包 tpz 1.28 GB，只抽 web 那一个） |
| 导出 | 上面第 2 节 | `godot --headless --export-release "Web" build/web/index.html` |
| 冒烟 | 第 4 节（**要一次性提权**） | `pages.yml`：ubuntu 自带 Chrome，直接跑 |
| 发布 | —— | `pages.yml`（**push 到 `main`** 时）：`/` = JS 版、`/godot/` = Godot 版 |

> ★ 按 `docs/实现/README.md` 的提交纪律：**本机提交不 push**，推送由统筹做。

---

## 7. 复现清单（出问题时照这个顺序定位）

1. 导出报「找不到导出模板」→ 回第 1 节：**`APPDATA` 指对了吗？版本目录名是 `4.7.2.stable` 吗？`version.txt` 有吗（带换行）？**
2. 导出成功但页面白屏 → 看浏览器控制台有没有 `PAGEERROR`；确认 `_site/godot/` 下 `.wasm` 与 `.pck` 都在、且 `.wasm` 的 MIME 是 `application/wasm`。
3. `MECHA_SMOKE` 那行迟迟不出现 → `presentation/boot/boot.gd` 的 `_ready()` 里那行 `print("MECHA_SMOKE …")` 是不是被改掉/挪走了（`tests/unit/test_presentation_smoke.gd` 段 1 与 `tests/unit/test_rng.gd` 都在守它）。
4. 包里的数据不对（`ALLY_T` 之类不到 34）→ `export_presets.cfg` 的 `include_filter="data/*"` 与 `godot/data/js/manifest.json`。

---

## 8. 这一套的脚本在哪（**都在仓库里了**，别再只用工作区外那份）

| 脚本（`godot/tools/`） | 干什么 |
|---|---|
| [`zipmember.mjs`](../../godot/tools/zipmember.mjs) | 读远程 `.tpz` 的尾部 EOCD + 中央目录，用 HTTP Range **只取一个成员**并 inflate（省掉 1.22 GB 下载） |
| [`web_export_and_site.ps1`](../../godot/tools/web_export_and_site.ps1) | 一键：模板就位 → 导出 → 组装 `_site`（`-SkipSmoke` 只导出；冒烟那一步在沙箱里必然失败，见第 4 节） |
| [`serve_site.mjs`](../../godot/tools/serve_site.mjs) | 本地静态托管 `_site`（`.wasm` 用 `application/wasm`，`no-store`）→ 给作者点开即玩 |
| [`idbfs_check.mjs`](../../godot/tools/idbfs_check.mjs) | 验 Web 存档的**存储层**：`indexedDB.databases()` 里有没有 `/userfs`、有没有 `user://` 建目录失败 |
| [`web_click_shots.mjs`](../../godot/tools/web_click_shots.mjs) | 按 **canvas 坐标**点进游戏逐屏截图（★ 坐标是 M4 的，改了布局要重新量）—— 这是**唯一**覆盖「真实点击穿过 boot 路由」的检查 |
| [`web_smoke.mjs`](../../godot/tools/web_smoke.mjs) | 正式冒烟（CI 与本机共用），校验和 + 数据 + 无脚本错误 |

> **仍然在仓库外的**（`F:\DSH-mecha\.tools\`，**不进 git**）：导出模板与「假 APPDATA」（约 10 MB 二进制）、
> `playwright-core` 的 `node_modules`、`_site` 与截图产物。