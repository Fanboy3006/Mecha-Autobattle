#!/usr/bin/env bash
# 在 CI（Linux x86_64）上安装 Godot 与 Web 导出模板。本地开发不需要它。
#   用法：bash godot/tools/ci_setup_godot.sh [--with-web-templates]
# 版本只在这里改一处；改版本时同步 godot/project.godot 的 config/features。
set -euo pipefail
GODOT_VERSION="4.7.2"
CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/.cache/godot-ci}"
BIN="$CACHE_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
mkdir -p "$CACHE_DIR"
if [ ! -x "$BIN" ]; then
  curl -sSfL -o "$CACHE_DIR/godot.zip" "$BASE/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip -o -q "$CACHE_DIR/godot.zip" -d "$CACHE_DIR"
  rm "$CACHE_DIR/godot.zip"
fi
mkdir -p "$HOME/.local/bin"
ln -sf "$BIN" "$HOME/.local/bin/godot"
if [ "${1:-}" = "--with-web-templates" ]; then
  TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
  mkdir -p "$TPL_DIR"
  # 只需要单线程 Web 模板（约 10 MB）；完整模板包 1.28 GB，解压后只留这一个并缓存
  if [ ! -f "$CACHE_DIR/web_nothreads_release.zip" ]; then
    curl -sSfL -o "$CACHE_DIR/templates.tpz" "$BASE/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
    unzip -o -q -j "$CACHE_DIR/templates.tpz" templates/web_nothreads_release.zip templates/version.txt -d "$CACHE_DIR"
    rm "$CACHE_DIR/templates.tpz"
  fi
  cp "$CACHE_DIR/web_nothreads_release.zip" "$CACHE_DIR/version.txt" "$TPL_DIR/"
fi
"$HOME/.local/bin/godot" --version
