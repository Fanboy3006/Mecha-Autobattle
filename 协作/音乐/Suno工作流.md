# Suno 工作流（参考曲 → 提示词 → 生成 → 游戏用循环）

> 2026-10-22 Claude 整理。工具：[`godot/tools/music_tool.py`](../../godot/tools/music_tool.py)。
> 本机 Claude Code 里有同名 skill（`.claude/skills/suno-music/`），说「按 Suno 工作流处理 xxx.mp3」即可。

## 一、规矩

- **商用**：Suno Pro / Premier **下载下来的**曲子有商用权，可以放进游戏（Suno 2026-09-03 条款）。免费档下载只能个人用。
- **下载额度**：Pro 每月 20 次（含以前生成的曲子），Premier 60 次。**在 Suno 里听完挑定了再下载**，不要每版都下。
- **生成只能手动**：Suno 没有官方 API，非官方接口违反条款、可能连累商用权，不接。
- **参考曲（版权曲）只在本机**：放 `audio/本地音乐/`（已被 `.gitignore` 忽略），分析报告也写到 `audio/out/`，都不进仓库。
- **不抄旋律**：提示词只写风格要素（流派、速度、调性、配器、结构、音色），不写歌名、歌手、歌词。

## 二、步骤

| 步 | 谁 | 做什么 |
|---|---|---|
| 1 | 作者 | 把参考曲放进 `audio/本地音乐/` |
| 2 | Claude | `python godot/tools/music_tool.py analyze audio/本地音乐/<参考>.mp3 --json audio/out/<参考>.analyze.json`，按第三节写提示词 |
| 3 | 作者 | 在 Suno 生成，听完挑定一版再下载，放进 `audio/SUNO/` |
| 4 | Claude | 先 `analyze` 成品，和参考曲对比（BPM、调性、颗粒感两个数）；差得多就改提示词回到第 3 步 |
| 5 | Claude | `python godot/tools/music_tool.py loop audio/SUNO/<成品>.mp3 audio/out/ --name <英文id> [--gba 0.3~0.6]` |
| 6 | 作者 | 听 `audio/out/<id>.seam.wav`（循环终点前 6 秒 + 跳回起点后 6 秒）；不顺就 `--pick 2` / `--pick 3` 重跑，或换一版生成 |
| 7 | — | 通过后，`<id>.ogg` 和 `<id>.loop.json` 交给 Godot（见第四节） |

**依赖**：`pip install librosa soundfile scipy`；`ffmpeg` 要在 PATH 上（需带 libvorbis）。远程会话可以在云端容器里跑，作者把 mp3 发过来即可。

## 三、写提示词的要点（10-22 实测教训）

- **速度写「听感 BPM」**（报告里的 `bpm_felt`），不要写拍点检测给出的半速。写成 92 BPM 时 Suno 做成了慢歌，实际听感是 184。
- **段落之间的「节奏变化」多半不是变速**：先看报告每段的拍长；常见的是某段换成切分 / 附点节奏型、变稀、变轻，要在结构标签里写出来（如 `[Breakdown: syncopated dotted-eighth groove, sparser and softer]`）。
- **GBA 那种「沙哑」**是低采样率回放的混叠，不是失真效果器。Style 里把 `bitcrushed`、`aliased low-sample-rate PCM` 放在最前面；只写 `chiptune` / `8-bit` 会被做成干净方波。还不够就在第 5 步加 `--gba`。
- **结构照参考曲的小节标签写**（报告里同字母 = 同一段素材），纯器乐在 Lyrics 框只放 `[Instrumental]` 和段落标签；循环曲在末尾写 `[Fade Out]` 或干脆不写尾声。
- **左右声道乒乓**（报告 `pingpong_bars`）Suno 不一定做得出，写进对应段落的标签里碰运气；要精确就后期处理。

Style 模板（按报告替换方括号）：
```
[年代/平台] [游戏类型] soundtrack, [bpm_felt] BPM, [key], [节奏特征], gritty bitcrushed [主旋律音色], aliased low-sample-rate PCM instruments, [低频], [鼓], [声像特征], loopable instrumental
```
Exclude：`vocals, clean hi-fi, orchestral reverb, modern EDM, supersaw`（按需增减）。

## 四、交给 Godot

- `<id>.ogg` 的结尾就是循环终点；`<id>.loop.json` 里 `godot.loop_offset` 是循环起点（秒）。
- 导入面板：勾 **Loop**，**Loop Offset** 填 `loop_offset`；或运行时 `stream.loop = true; stream.loop_offset = …`（`AudioStreamOggVorbis`）。
- 音量：`lufs` 是整首实测响度，Godot 播放器按它拉平（照 JS 版 `TRACKS.lufs` 的做法）。
- Godot 版目前**还没有音乐播放器**；放哪个目录（建议 `godot/assets/music/`）、曲目表怎么写，等做播放器时再定，见路线图。

## 五、报告字段速查

| 字段 | 含义 |
|---|---|
| `bpm_felt` / `bpm_beat_tracker` | 听感速度 / 拍点检测速度（常是一半） |
| `bar_labels` | 每小节一个字母，同字母 = 同一段素材（相似度 > 0.9） |
| `loop`（analyze） | 整段重复的起止秒数；游戏原声一般能找到，Suno 成品一般找不到 |
| `loop_mode`（loop） | `repeat` = 整段重复；`seam` = 没有整段重复，按接缝最顺选点（尾声会被切掉） |
| `seam_score` / `seam_candidates` | 接缝前后几拍的相似度（≥ 0.85 才用；参考曲这类原声约 0.99）/ 前 3 个候选 |
| `pingpong_bars` | 高频声部按八分音符左右交替的小节 |
| `grit_*` | 高频颗粒：比中频多少 dB、跟音符的相关度。没有绝对标准，和参考曲对比 |
