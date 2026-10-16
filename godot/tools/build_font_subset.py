#!/usr/bin/env python3
"""生成 Web 版用的字体子集（Web 版没有系统字体，缺字就显示方框）。

  · assets/fonts/NotoSansSC-Subset.otf —— 主字体：ASCII + 常用标点 + GB2312 一级字（3755 个常用汉字）+ 工程里出现的所有字符
  · assets/fonts/<后备>-Subset.ttf     —— 后备字体：主字体里没有的字符，依次交给 Noto Emoji / Noto Sans Symbols 2 / Noto Sans Math
  · assets/fonts/ui_font.tres          —— 项目默认字体：主字体 + 后备字体链

一级字常驻，所以日常加文案一般不用重新生成；tests/unit/test_font_coverage.gd 会在缺字时报红。

用法（需要 fonttools：pip install fonttools）：
    python godot/tools/build_font_subset.py
源字体（全部 SIL OFL 1.1，许可证在 assets/fonts/）首次运行时下载到 godot/tools/.cache/，按 SHA-256 校验。
"""
import hashlib
import pathlib
import sys
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent          # godot/
CACHE = ROOT / "tools" / ".cache"
FONTS = ROOT / "assets" / "fonts"
GF = "https://raw.githubusercontent.com/google/fonts/main/ofl"
MAIN = ("NotoSansSC-Regular.otf",
        "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf",
        "faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9",
        "NotoSansSC-Subset.otf")
FALLBACKS = [
    ("NotoEmoji.ttf", f"{GF}/notoemoji/NotoEmoji%5Bwght%5D.ttf",
     "de6c18832938afc99caf132b39d6a30a19bac7f2e812e28db2535b4608d27551", "NotoEmoji-Subset.ttf"),
    ("NotoSansSymbols2-Regular.ttf", f"{GF}/notosanssymbols2/NotoSansSymbols2-Regular.ttf",
     "7d5fb73b7ca67a6798101741f5d280a3d016a56a197afcd4199dbb57b4b82a21", "NotoSansSymbols2-Subset.ttf"),
    ("NotoSansMath-Regular.ttf", f"{GF}/notosansmath/NotoSansMath-Regular.ttf",
     "3f495fe933c06786e4d5f6d86b8ee70b6753a68ee3b9d87528726de0f6e2c47d", "NotoSansMath-Subset.ttf"),
]
TEXT_EXT = {".gd", ".tscn", ".tres", ".json", ".cfg", ".godot"}
SKIP_DIRS = {".godot", "build", "tools", "tests"}   # tests 只在控制台输出，不上屏


def fetch(name: str, url: str, sha: str) -> pathlib.Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / name
    if not path.exists():
        print(f"下载源字体：{url}")
        urllib.request.urlretrieve(url, path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != sha:
        sys.exit(f"{name} 校验失败：{digest}（期望 {sha}）")
    return path


def make_subset(src: pathlib.Path, text: str, out: pathlib.Path) -> None:
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    opts.hinting = False
    font = subset.load_font(str(src), opts)
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(font)
    out.parent.mkdir(parents=True, exist_ok=True)
    subset.save_font(font, str(out), opts)


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

    main_src = fetch(*MAIN[:3])
    make_subset(main_src, text, FONTS / MAIN[3])
    print(f"主字体 {MAIN[3]}：{len(set(text))} 个字符，{(FONTS / MAIN[3]).stat().st_size / 1024:.0f} KB")

    in_main = TTFont(str(main_src)).getBestCmap()
    missing = sorted({c for c in text if ord(c) > 0x7F and ord(c) not in in_main and not 0xFE00 <= ord(c) <= 0xFE0F})
    used = []
    for name, url, sha, out in FALLBACKS:
        src = fetch(name, url, sha)
        cmap = TTFont(str(src)).getBestCmap()
        mine = "".join(c for c in missing if ord(c) in cmap)
        missing = [c for c in missing if ord(c) not in cmap]
        if mine:
            make_subset(src, mine, FONTS / out)
            used.append(out)
            print(f"后备 {out}：{mine}（{(FONTS / out).stat().st_size / 1024:.0f} KB）")
        elif (FONTS / out).exists():
            (FONTS / out).unlink()
    if missing:
        print(f"⚠ 所有字体都没有的字符：{''.join(missing)}（tests/unit/test_font_coverage.gd 会报红）")

    lines = [f'[gd_resource type="FontVariation" load_steps={len(used) + 2} format=3]', "",
             f'[ext_resource type="FontFile" path="res://assets/fonts/{MAIN[3]}" id="0"]']
    lines += [f'[ext_resource type="FontFile" path="res://assets/fonts/{out}" id="{i + 1}"]' for i, out in enumerate(used)]
    fb = ", ".join(f'ExtResource("{i + 1}")' for i in range(len(used)))
    lines += ["", "[resource]", 'base_font = ExtResource("0")', f"fallbacks = Array[Font]([{fb}])", ""]
    (FONTS / "ui_font.tres").write_text("\n".join(lines), encoding="utf-8")
    print(f"项目字体 ui_font.tres：主字体 + {len(used)} 个后备")


if __name__ == "__main__":
    main()
