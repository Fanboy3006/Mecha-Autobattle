---
name: suno-music
description: 分析参考曲写 Suno 提示词，或把 Suno 成品切成游戏用的无缝循环 OGG。作者提到 Suno、BGM、参考曲、循环点、给音乐写提示词时使用。
---

# Suno 音乐工作流

完整流程、规矩和提示词要点在 `协作/音乐/Suno工作流.md`，先读它。工具是 `godot/tools/music_tool.py`。

## 分析参考曲 → 写提示词
1. 参考曲是版权曲，只在 `audio/本地音乐/`；报告写到 `audio/out/`。两处都不进仓库。
2. 运行 `python godot/tools/music_tool.py analyze <参考曲> --json audio/out/<名>.analyze.json`。
3. 按工作流第三节写 Style / Exclude / Lyrics。
   - 速度用 `bpm_felt`。
   - 结构照 `bar_labels` 写。
   - 只写风格要素，不写歌名、歌手、歌词，不抄旋律。

## Suno 成品 → 游戏用循环
1. 先跑 `analyze`，和参考曲的报告对比 BPM、调性、`grit_*`。差得多就建议改提示词。
2. 运行 `python godot/tools/music_tool.py loop audio/SUNO/<成品>.mp3 audio/out/ --name <英文id>`。
   - 需要 GBA 颗粒感时加 `--gba 0.3~0.6`。
3. 把 `<id>.loop.json` 里的这几项告诉作者：`loop_mode`、`loop_start_s`、`loop_length_s`、`seam_score`、`lufs`。
4. 请作者听 `audio/out/<id>.seam.wav`。
   - 不顺就加 `--pick 2` 或 `--pick 3` 重跑。
   - `loop_ok` 为 false，就建议换一版生成。
5. 不要声称"好听"或"接缝没问题"：你听不见，只能报数字，由作者判断。

## 依赖
- Python 包：`pip install librosa soundfile scipy`
- `ffmpeg` 在 PATH 上，需带 libvorbis。
