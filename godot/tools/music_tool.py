#!/usr/bin/env python3
"""音乐工具：参考曲分析（写 Suno 提示词用）+ Suno 成品后处理（切无缝循环、可选 GBA 颗粒感）。

  python godot/tools/music_tool.py analyze <参考曲.mp3> [--json 报告.json]
  python godot/tools/music_tool.py loop <成品.mp3> <输出目录> [--name 英文id] [--gba 0~1] [--min-loop 秒]

依赖：pip install librosa soundfile scipy；ffmpeg（带 libvorbis）要在 PATH 上。不打进游戏包。
流程说明见 协作/音乐/Suno工作流.md。
"""
import argparse, json, os, re, subprocess, sys

import librosa
import numpy as np
import scipy.signal as ss
import soundfile as sf

NAMES = 'C C# D D# E F F# G G# A A# B'.split()
MAJ = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MIN = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
AR = 22050  # 分析用采样率


# ---- 通用测量 ----

def key_of(y, sr):
    prof = librosa.feature.chroma_cqt(y=y, sr=sr).mean(1)
    c, k = max(((np.corrcoef(prof, np.roll(t, i))[0, 1], NAMES[i] + q)
                for i in range(12) for t, q in ((MAJ, ' major'), (MIN, ' minor'))))
    return k, round(float(c), 2)


def tempo_of(y, sr):
    """返回 (拍点秒数, 拍点检测 BPM, 听感 BPM, 周期图最强峰)。
    拍点检测常给出半速；写提示词要用「听感 BPM」，否则 Suno 会做成慢歌。"""
    _, beats = librosa.beat.beat_track(y=y, sr=sr)
    bt = librosa.frames_to_time(beats, sr=sr)
    bpm = 60 / np.median(np.diff(bt))
    tg = librosa.feature.tempogram(onset_envelope=librosa.onset.onset_strength(y=y, sr=sr), sr=sr).mean(1)
    f = librosa.tempo_frequencies(len(tg), sr=sr)
    m = (f > 50) & (f < 260)
    peak = float(f[m][np.argmax(tg[m])])
    fold = lambda v: v * 2 if v < 80 else (v / 2 if v >= 200 else v)
    cands = [v for v in (bpm, bpm * 2, bpm / 2) if 80 <= v < 200] or [fold(bpm)]
    felt = min(cands, key=lambda v: abs(np.log(v / fold(fold(peak)))))
    return bt, round(float(bpm), 1), round(float(felt), 1), round(peak, 1)


def beat_ssm(y, sr, bt):
    hop = 512
    C = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=hop)
    M = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13, hop_length=hop)
    bf = librosa.time_to_frames(bt, sr=sr, hop_length=hop)
    F = np.vstack([librosa.util.sync(C, bf, aggregate=np.median),
                   librosa.util.sync(M, bf) / (np.abs(M).max(1, keepdims=True) + 1e-9)])
    F = F - F.mean(0, keepdims=True)
    F /= np.linalg.norm(F, axis=0, keepdims=True) + 1e-9
    return F.T @ F


def find_loop(S, bt, min_loop_s):
    """找「整段重复」：对每个滞后 k 拍，量对角线上连续相似的最长一段，取最长者。"""
    n = S.shape[0]
    beat = np.median(np.diff(bt))
    best = (0, 0, 0)
    for k in range(int(min_loop_s / beat), n - 8):
        good = np.convolve(np.diag(S, k) > 0.85, np.ones(4) / 4, 'same') >= 0.75
        run = bl = bs = st = 0
        for i, g in enumerate(good):
            if g:
                if run == 0: st = i
                run += 1
                if run > bl: bl, bs = run, st
            else:
                run = 0
        if bl > best[0]: best = (bl, k, bs)
    run, k, i0 = best
    if k == 0 or i0 + 1 + k >= len(bt):
        return None
    i0 += 1  # 从重复区里面一拍开始，避开边缘
    sim = float(np.mean(np.diag(S, k)[i0:i0 + run - 1]))
    return dict(lag_beats=int(k), start_beat=int(i0), repeat_run_beats=int(run),
                mean_similarity=round(sim, 3), t_start=float(bt[i0]), t_end=float(bt[i0 + k]))


def find_seams(S, bt, min_loop_s, back=4, fwd=8, tol=0.04, k=3):
    """Suno 成品通常没有整段重复：改找「接缝最顺」的一对拍 (i, j)——j 前后几拍和 i 前后几拍都像，
    从 j 跳回 i 听不出断。在最高分 tol 以内的候选里按循环长度排序（越长越不腻），返回前 k 个互不重叠的。
    循环长度取整小节。"""
    n = S.shape[0]
    beat = np.median(np.diff(bt))
    kmin = int(np.ceil(min_loop_s / beat / 4)) * 4
    cands = [(float(np.mean([S[i + d, j + d] for d in range(-back, fwd)])), i, j)
             for i in range(back, n - fwd) for j in range(i + kmin, n - fwd, 4)]
    if not cands:
        return []
    top = max(c[0] for c in cands)
    pool = sorted((c for c in cands if c[0] >= top - tol), key=lambda c: (c[2] - c[1], c[0]), reverse=True)
    out = []
    for score, i, j in pool:
        if any(abs(i - o['start_beat']) < 8 and abs(j - o['start_beat'] - o['lag_beats']) < 8 for o in out):
            continue
        out.append(dict(seam_score=round(score, 3), start_beat=int(i), lag_beats=int(j - i),
                        t_start=round(float(bt[i]), 2), t_end=round(float(bt[j]), 2),
                        length_s=round(float(bt[j] - bt[i]), 1)))
        if len(out) == k: break
    return out


def _env(y, sr, hop=16, win=64):
    return np.sqrt(np.convolve(y ** 2, np.ones(win) / win, 'same'))[::hop], sr / hop


def _best_lag(a, env, start, search):
    a = a - a.mean()
    best = (-2.0, 0)
    for d in range(-search, search + 1):
        b = env[start + d: start + d + len(a)]
        if len(b) < len(a): break
        b = b - b.mean()
        c = float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))
        if c > best[0]: best = (c, d)
    return best


def refine_loop(y, sr, t0, t1, span=None):
    """先用能量包络在 ±150 ms 内定循环长度，再用波形在 ±4 ms 内精对。返回 (起点样本, 终点样本)。
    span = 拿起点之后多少秒来比（整段重复用大半个循环，接缝模式只比几秒）。"""
    env, esr = _env(y, sr, hop=32, win=128)
    n = int(min(span or (t1 - t0) * 0.8, len(y) / sr - t1 - 0.2) * esr)
    _, d = _best_lag(env[int(t0 * esr): int(t0 * esr) + n], env, int(t1 * esr), int(0.15 * esr))
    L = (int(t1 * esr) + d) / esr - t0
    s0 = int(t0 * sr)
    w = y[s0: s0 + 2 * sr]
    best = (-2.0, int((t0 + L) * sr))
    for dd in range(-int(0.004 * sr), int(0.004 * sr) + 1):
        s = int((t0 + L) * sr) + dd
        b = y[s: s + len(w)]
        if len(b) < len(w): break
        c = float(np.dot(w, b) / (np.linalg.norm(w) * np.linalg.norm(b) + 1e-9))
        if c > best[0]: best = (c, s)
    return s0, best[1]


def loop_stability(y, sr, t0, L, win=3.0, step=6.0):
    """沿循环逐段比对第一遍和第二遍，返回偏差在 ±3 ms 内的段落比例。
    不要求波形逐点相同：GBA 混音、MP3 编码每遍都略有差别。"""
    env, esr = _env(y, sr)
    hits = tot = 0
    t = t0
    while t + win < t0 + L and (t + L + win + 0.3) * sr < len(y):
        a = env[int(t * esr): int((t + win) * esr)]
        _, d = _best_lag(a, env, int((t + L) * esr), int(0.05 * esr))
        tot += 1
        hits += abs(d / esr) <= 0.003
        t += step
    return round(hits / tot, 2) if tot else 0.0


def lufs(path):
    out = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', path, '-af', 'ebur128', '-f', 'null', '-'],
                         capture_output=True, text=True, encoding='utf-8', errors='replace').stderr
    m = re.search(r'I:\s+(-?[\d.]+) LUFS', out.split('Summary:')[-1])
    return float(m.group(1)) if m else None


def load(path, sr):
    y, _ = librosa.load(path, sr=sr, mono=False)
    return np.vstack([y, y]) if y.ndim == 1 else y


# ---- analyze：参考曲 → 写提示词用的数据 ----

def bar_labels(S, nb):
    """按小节（4 拍）聚类，相似度 > 0.9 的小节用同一个字母（0.8 会把不同段落并成一类）。"""
    B = np.array([[S[i * 4:(i + 1) * 4, j * 4:(j + 1) * 4].diagonal().mean() for j in range(nb)] for i in range(nb)])
    lab = [-1] * nb
    nxt = 0
    for i in range(nb):
        if lab[i] >= 0: continue
        lab[i] = nxt
        for j in range(i + 1, nb):
            if lab[j] < 0 and B[i, j] > 0.9: lab[j] = nxt
        nxt += 1
    return lab


def stereo_events(st, sr, bt, nb):
    """每小节的声场宽度（side/mid）和高频声像；再按八分音符找左右交替（乒乓）的小节。"""
    L, R = st
    n, hop = 2048, 512
    SL = np.abs(librosa.stft(L, n_fft=n, hop_length=hop)) ** 2
    SR_ = np.abs(librosa.stft(R, n_fft=n, hop_length=hop)) ** 2
    f = librosa.fft_frequencies(sr=sr, n_fft=n)
    t = librosa.times_like(SL, sr=sr, hop_length=hop)
    hb = f > 1000
    pan = (SR_[hb].sum(0) - SL[hb].sum(0)) / (SR_[hb].sum(0) + SL[hb].sum(0) + 1e-9)
    width, pingpong = [], []
    for b in range(nb):
        s, e = bt[b * 4], bt[b * 4 + 4]
        i0, i1 = int(s * sr), int(e * sr)
        width.append(round(float(np.std(L[i0:i1] - R[i0:i1]) / (np.std(L[i0:i1] + R[i0:i1]) + 1e-9)), 2))
        cells = []
        for k in range(8):
            a = s + (e - s) * k / 8
            m = (t >= a) & (t < a + (e - s) / 8)
            cells.append(float(np.median(pan[m])) if m.any() else 0.0)
        strong = [c for c in cells if abs(c) > 0.15]
        flips = sum(1 for x, y in zip(strong, strong[1:]) if np.sign(x) != np.sign(y))
        if len(strong) >= 3 and flips >= 2:
            pingpong.append(b + 1)
    return width, pingpong


def cmd_analyze(a):
    st = load(a.src, AR)
    y = st.mean(0)
    bt, bpm_b, bpm_f, peak = tempo_of(y, AR)
    key, kc = key_of(y, AR)
    S = beat_ssm(y, AR, bt)
    nb = (len(bt) - 1) // 4
    lab = bar_labels(S, nb)
    width, pp = stereo_events(st, AR, bt, nb)
    loop = find_loop(S, bt, 20.0)
    yf, srf = librosa.load(a.src, sr=44100)
    X = np.abs(librosa.stft(yf, n_fft=4096)) ** 2
    ff = librosa.fft_frequencies(sr=44100, n_fft=4096)
    hi, mid = X[(ff > 8000) & (ff < 15000)].sum(0), X[(ff > 200) & (ff < 2000)].sum(0)
    letters = ''.join(chr(65 + l) if l < 26 else '?' for l in lab)
    rep = dict(source=os.path.basename(a.src), duration_s=round(len(y) / AR, 1),
               bpm_beat_tracker=bpm_b, bpm_felt=bpm_f, tempogram_peak=peak,
               key=key, key_confidence=kc, bar_seconds=round(float(np.median(np.diff(bt)) * 4), 3),
               bar_labels=letters, bar_start_s=[round(float(bt[i * 4]), 1) for i in range(nb)],
               loop=loop, stereo_width_per_bar=width, pingpong_bars=pp,
               grit_high_vs_mid_db=round(float(10 * np.log10(hi.mean() / mid.mean())), 1),
               grit_tracks_notes_corr=round(float(np.corrcoef(hi, mid)[0, 1]), 2))
    print(f"时长 {rep['duration_s']}s · 听感 {bpm_f} BPM（拍点检测 {bpm_b}）· {key}（{kc}）· 一小节 {rep['bar_seconds']}s")
    print("小节标签（同字母 = 同一段素材）：")
    for i in range(0, nb, 8):
        print(f"  {i + 1:3d}-{min(i + 8, nb):3d}  {rep['bar_start_s'][i]:6.1f}s  {letters[i:i + 8]}")
    if loop:
        print(f"循环：{loop['t_start']:.2f}s → {loop['t_end']:.2f}s（{loop['lag_beats'] // 4} 小节，相似度 {loop['mean_similarity']}）")
    print(f"乒乓声像小节：{pp or '无'}")
    print(f"高频颗粒：比中频 {rep['grit_high_vs_mid_db']} dB，跟音符相关 {rep['grit_tracks_notes_corr']}"
          "（没有绝对标准：Suno 成品也跑一次 analyze，两个数都明显低于参考曲就是「沙哑」不够）")
    if a.json:
        with open(a.json, 'w', encoding='utf-8') as fh:
            json.dump(rep, fh, ensure_ascii=False, indent=2)


# ---- loop：Suno 成品 → 游戏用 OGG + 循环数据 ----

def gba_grit(x, mix, sr, hold=3, bits=8):
    """每 hold 个采样保持一次（44.1k/3 ≈ 14.7 kHz，接近 GBA 13.4 kHz，不做抗混叠）+ 量化到 bits 位，
    只取 6 kHz 以上的混叠/量化成分叠加回原声；中低频不动，音量不变。"""
    idx = (np.arange(x.shape[1]) // hold) * hold
    q = 2 ** (bits - 1)
    crushed = np.round(x[:, idx] * q) / q
    sos = ss.butter(6, 6000 / (sr / 2), 'high', output='sos')
    out = x + mix * 2.0 * ss.sosfiltfilt(sos, crushed - x, axis=1)
    peak = np.abs(out).max()
    return out / peak * 0.98 if peak > 0.98 else out


def cmd_loop(a):
    sr = 44100
    os.makedirs(a.outdir, exist_ok=True)
    name = a.name or re.sub(r'[^A-Za-z0-9_-]+', '_', os.path.splitext(os.path.basename(a.src))[0]).strip('_') or 'track'
    st = load(a.src, sr)
    mono = st.mean(0)
    ya = librosa.resample(mono, orig_sr=sr, target_sr=AR)
    bt, bpm_b, bpm_f, peak = tempo_of(ya, AR)
    key, kc = key_of(ya, AR)
    S = beat_ssm(ya, AR, bt)
    rep = dict(source=os.path.basename(a.src), duration_s=round(len(mono) / sr, 2),
               bpm_felt=bpm_f, bpm_beat_tracker=bpm_b, key=key, loop_ok=False)
    s0, s1, fade = 0, st.shape[1], 256
    loop = find_loop(S, bt, a.min_loop)
    if loop and loop['repeat_run_beats'] >= 16 and loop['mean_similarity'] >= 0.9:
        s0, s1 = refine_loop(mono, sr, loop['t_start'], loop['t_end'])
        stab = loop_stability(mono, sr, s0 / sr, (s1 - s0) / sr)
        rep.update(loop_mode='repeat', loop_ok=stab >= 0.7, loop_stability=stab, loop_similarity=loop['mean_similarity'])
    if not rep['loop_ok']:
        seams = [s for s in find_seams(S, bt, a.min_loop) if s['seam_score'] >= 0.85]
        rep['seam_candidates'] = seams
        if seams:
            seam = seams[min(a.pick, len(seams)) - 1]
            s0, s1 = refine_loop(mono, sr, seam['t_start'], seam['t_end'], span=4.0)
            fade = 2048  # 两边音频不完全相同，用 ~46 ms 交叉淡化盖住差异
            rep.update(loop_mode='seam', loop_ok=True, seam_pick=seams.index(seam) + 1, seam_score=seam['seam_score'],
                       note='没有整段重复，按「接缝最顺」选的点；循环终点之后（通常是尾声）被切掉。'
                            '务必听 seam.wav；不满意用 --pick 2 / 3 换 seam_candidates 里的其他候选。')
    if rep['loop_ok']:
        rep.update(loop_start_s=round(s0 / sr, 4), loop_end_s=round(s1 / sr, 4), loop_length_s=round((s1 - s0) / sr, 3))
    else:
        rep['note'] = '找不到能无缝循环的点（接缝分 < 0.85）。整首照原样导出；换一版生成，或人工挑点。'
        s0, s1 = 0, st.shape[1]
    body = st[:, :s1].copy()
    if rep['loop_ok']:
        fade = min(fade, s0)  # 终点前一小段淡化成「起点之前那段」，跳回起点时波形连续
        w = np.sin(np.linspace(0, np.pi / 2, fade)) ** 2
        body[:, -fade:] = body[:, -fade:] * (1 - w) + st[:, s0 - fade:s0] * w
        seam = np.hstack([body[:, max(0, s1 - 6 * sr):], body[:, s0:s0 + 6 * sr]])
        sf.write(os.path.join(a.outdir, f'{name}.seam.wav'), seam.T, sr)
    if a.gba > 0:
        body = gba_grit(body, a.gba, sr)
    tmp = os.path.join(a.outdir, f'.{name}.tmp.wav')
    sf.write(tmp, body.T, sr, subtype='FLOAT')
    ogg = os.path.join(a.outdir, f'{name}.ogg')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', tmp,
                    '-c:a', 'libvorbis', '-q:a', '6', ogg], check=True)
    os.remove(tmp)
    rep.update(output=os.path.basename(ogg), gba_mix=a.gba, lufs=lufs(ogg),
               godot=dict(loop=rep['loop_ok'], loop_offset=rep.get('loop_start_s', 0.0)))
    with open(os.path.join(a.outdir, f'{name}.loop.json'), 'w', encoding='utf-8') as fh:
        json.dump(rep, fh, ensure_ascii=False, indent=2)
    print(json.dumps(rep, ensure_ascii=False, indent=2))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('analyze', help='分析参考曲：速度、调性、小节结构、循环、声像、颗粒感')
    p.add_argument('src'); p.add_argument('--json')
    p = sub.add_parser('loop', help='Suno 成品 → 切好循环的 OGG + <id>.loop.json + 接缝试听')
    p.add_argument('src'); p.add_argument('outdir'); p.add_argument('--name')
    p.add_argument('--gba', type=float, default=0.0, help='GBA 颗粒感 0~1，0 = 不加')
    p.add_argument('--min-loop', type=float, default=45.0, help='循环最短秒数（太短玩家很快听腻）')
    p.add_argument('--pick', type=int, default=1, help='接缝模式下用第几个候选（1~3，见报告 seam_candidates）')
    a = ap.parse_args()
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    {'analyze': cmd_analyze, 'loop': cmd_loop}[a.cmd](a)


if __name__ == '__main__':
    main()
