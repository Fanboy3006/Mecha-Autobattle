# Web 导出 + 站点组装 + 浏览器冒烟（本机可复现环境）
#
# 用法：pwsh -File F:\DSH-mecha\.tools\web-export-and-site.ps1 [-SkipSmoke]
#
# 背景（2026-10-16 实测结论，详见交付报告）：
#   · Godot 4.7.2 在 Windows 上**只认** %APPDATA%\Godot\export_templates\<ver>.<status>\
#     —— res://export_templates/ 与 XDG_DATA_HOME/HOME/GODOT_EDITOR_SETTINGS 都**不管用**。
#     本沙箱写不了 C:\Users\...，所以用 $env:APPDATA 重定向到 workspace（路线 A，已验证可行）。
#   · 模板 = `Godot_v4.7.2-stable_export_templates.tpz` 里的 **单个成员**
#     `templates/web_nothreads_release.zip`。用 .tools\zipmember.mjs 以 HTTP Range 只取
#     该成员（**9.81 MiB**），不必下载 1222 MiB 整包；再补一个 `version.txt`（内容 `4.7.2.stable`）。
#   · 浏览器冒烟在本沙箱**跑不了**：Chromium/Edge 的 Mojo IPC 用命名管道，被沙箱拒绝
#     （`mojo\public\cpp\platform\platform_channel.cc  Check failed: 拒绝访问 (0x5)`）。
#     必须在**沙箱外**跑冒烟（见文末）。
param([switch]$SkipSmoke)
$ErrorActionPreference = 'Stop'

$Godot   = 'F:\DSH-mecha\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$Repo    = 'F:\DSH-mecha\mecha-autobattle'
$Proj    = "$Repo\godot"
$Tools   = 'F:\DSH-mecha\.tools'
$TplSrc  = "$Tools\godot-templates"
$AppData = "$Tools\godot-appdata"          # 假装成 %APPDATA%
$Local   = "$Tools\godot-localappdata"     # 假装成 %LOCALAPPDATA%
$Site    = "$Tools\smoke\_site"

# ── 1. 模板就位（缺了才用 Range 取，只取单成员） ──────────────────────────
$TplDir = "$AppData\Godot\export_templates\4.7.2.stable"
New-Item -ItemType Directory -Force -Path $TplSrc, $TplDir, $Local | Out-Null
if (-not (Test-Path "$TplSrc\web_nothreads_release.zip")) {
  $url = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
  Write-Host '取模板成员 templates/web_nothreads_release.zip（约 9.8 MiB）…'
  node "$PSScriptRoot\zipmember.mjs" $url 'templates/web_nothreads_release.zip' "$TplSrc\web_nothreads_release.zip"
  # 注意：tpz 里原版 version.txt 是 13 字节（**带尾部换行**），别用 -NoNewline
  Set-Content "$TplSrc\version.txt" '4.7.2.stable' -Encoding ascii
}
Copy-Item "$TplSrc\web_nothreads_release.zip","$TplSrc\version.txt" $TplDir -Force

# ── 2. 导出 ───────────────────────────────────────────────────────────────
$env:APPDATA      = $AppData
$env:LOCALAPPDATA = $Local
New-Item -ItemType Directory -Force -Path "$Proj\build\web" | Out-Null
& $Godot --headless --path $Proj --export-release 'Web' "$Proj\build\web\index.html"
if ($LASTEXITCODE -ne 0) { throw "导出失败，exit=$LASTEXITCODE" }
if (-not (Test-Path "$Proj\build\web\index.wasm")) { throw '导出后没有 index.wasm' }
Get-ChildItem "$Proj\build\web" | Sort-Object Name |
  ForEach-Object { '{0,-42} {1,12} bytes' -f $_.Name, $_.Length }

# ── 3. 组装站点（照 .github/workflows/pages.yml） ─────────────────────────
Remove-Item $Site -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Site | Out-Null
robocopy $Repo $Site /E /XD .git .github godot _site node_modules 私密 /NFL /NDL /NJH /NJS /NP | Out-Null
New-Item -ItemType Directory -Force -Path "$Site\godot" | Out-Null
Copy-Item "$Proj\build\web\*" "$Site\godot\" -Recurse -Force
New-Item -ItemType File -Force -Path "$Site\.nojekyll" | Out-Null
Write-Host "站点已组装: $Site"
# 剧-10：公开包不许带 协作/私密/（剧本、设定、敌方设计）
node "$Proj\tools\check_public_bundle.mjs" $Site
if ($LASTEXITCODE -ne 0) { throw "站点里带了私密内容，停止" }

# ── 4. 冒烟（本沙箱必失败，见文末） ───────────────────────────────────────
if ($SkipSmoke) { return }
$smoke = "$Tools\smoke"
$env:NODE_PATH = "$smoke\node_modules"
$env:CHROME_PATH = 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
New-Item -ItemType Directory -Force -Path "$smoke\shots" | Out-Null
try {
  node "$PSScriptRoot\web_smoke.mjs" $Site "$smoke\shots"
} catch {
  Write-Warning @'
冒烟失败。本沙箱里 Chromium 起不来（Mojo 命名管道被拒），必须在沙箱外跑：
  $env:CHROME_PATH = 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
  node <repo>\godot\tools\web_smoke.mjs <站点目录> <截图目录>
并在 .tools\smoke 下准备 playwright-core（npm install playwright-core --prefix .tools\smoke，
npm 缓存也要用 workspace 内路径：npm_config_cache=F:\DSH-mecha\.tools\npm-cache）。
'@
}
