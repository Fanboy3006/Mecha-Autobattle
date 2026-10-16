#!/usr/bin/env python3
"""生成 Web 版用的中文字体子集：assets/fonts/NotoSansSC-Subset.otf

字符集 = ASCII + 常用标点 + GB2312 一级字（3755 个常用汉字）+ 工程里实际出现的所有字符。
一级字常驻，所以日常加文案一般不用重新生成；tests/unit/test_font_coverage.gd 会在缺字时报红。

用法（需要 fonttools：pip install fonttools）：
    python godot/tools/build_font_subset.py
源字体（Noto Sans SC，SIL OFL 1.1）首次运行时下载到 godot/tools/.cache/，按 SHA-256 校验。
"""
import hashlib
import pathlib
import sys
import urllib.request

from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent          # godot/
CACHE = ROOT / "tools" / ".cache"
SRC_URL = "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf"
SRC_SHA256 = "faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9"
OUT = ROOT / "assets" / "fonts" / "NotoSansSC-Subset.otf"
TEXT_EXT = {".gd", ".tscn", ".tres", ".json", ".cfg", ".godot"}
SKIP_DIRS = {".godot", "build", "tools"}


def source_font() -> pathlib.Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / "NotoSansSC-Regular.otf"
    if not path.exists():
        print(f"下载源字体：{SRC_URL}")
        urllib.request.urlretrieve(SRC_URL, path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != SRC_SHA256:
        sys.exit(f"源字体校验失败：{digest}（期望 {SRC_SHA256}）")
    return path


def gb2312_level1() -> str:
    chars = []
    for hi in range(0xB0, 0xD8):
        for lo in range(0xA1, 0xFF):
            try:
                chars.append(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return "".join(chars)


def project_chars() -> str:
    seen = set()
    for p in ROOT.rglob("*"):
        if p.is_file() and p.suffix in TEXT_EXT and not (set(p.relative_to(ROOT).parts) & SKIP_DIRS):
            seen.update(p.read_text(encoding="utf-8", errors="ignore"))
    return "".join(sorted(c for c in seen if c.isprintable()))


def main() -> None:
    base = "".join(chr(c) for c in range(0x20, 0x7F))
    punct = "，。、；：？！…—·「」『』（）《》〈〉【】〔〕“”‘’％＋－×÷＝～￥№℃→←↑↓★☆●○◆◇■□▲△"
    text = base + punct + gb2312_level1() + project_chars()
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    opts.hinting = False
    font = subset.load_font(str(source_font()), opts)
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    subset.save_font(font, str(OUT), opts)
    print(f"已生成 {OUT.relative_to(ROOT)}：{len(set(text))} 个字符，{OUT.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
