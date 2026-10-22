/* ============================================================================
 * 音乐鉴赏页（音乐对话维护，作者 2026-10-10：「方便我更新调整」）
 * ----------------------------------------------------------------------------
 * 开场菜单 →「音乐鉴赏」打开。能做的事：
 *   - 每首曲子试听、拖进度、调音量（dB 偏移，按实测响度拉平之后再加减）；
 *   - 改「哪个场景放哪首」「哪个势力 / 角色的主题曲是哪首」；
 *   - 改动存在这台浏览器里，回到游戏立刻生效；
 *   - 「复制设置」导出一段文字，发给音乐对话写进 audio/local-music.js，所有人才生效。
 * 依赖 audio/local-music.js 的 MechAudio（preview / seek / meta / tuning）。只读写自己的 DOM，不碰游戏状态。
 * 用法：MechAudio.openRoom({factions:[势力名...], units:{机体代号: 显示名}}) → Promise，关闭时 resolve。
 * ========================================================================== */
(function(){
  'use strict';
  const MA = globalThis.MechAudio;
  if (!MA || !MA.tuning || typeof document === 'undefined') return;

  const SCENES = [
    ['title', '开场菜单'], ['mapStrategy', '部署 / 肉鸽大地图'], ['allyPhase', '我方回合'], ['enemyPhase', '敌方回合'],
    ['boss', 'Boss 在场'], ['victory', '胜利'], ['defeat', '失败'],
  ];
  const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;'}[c]));
  const mmss = t => { t = Math.max(0, Math.floor(t || 0)); return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}`; };

  const CSS = `
.mr .dlg{width:min(1040px,100%)}
.mr-now{display:grid;grid-template-columns:auto minmax(0,1fr) auto;gap:10px;align-items:center;background:var(--panel2);border:1px solid var(--line);border-radius:6px;padding:8px 12px;margin:10px 0 4px}
.mr-now b{font-size:15px}
.mr-now input[type=range]{width:100%}
.mr-now .t{font-family:var(--font-m);font-size:12px;color:var(--muted);font-variant-numeric:tabular-nums;white-space:nowrap}
.mr-cols{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:14px;margin-top:10px}
.mr-sec h3{margin:0 0 6px;font-family:var(--font-d);font-weight:600;font-size:13px;letter-spacing:.14em;color:var(--muted)}
.mr-row{display:grid;grid-template-columns:8.5em minmax(0,1fr);gap:8px;align-items:center;padding:3px 0;font-size:13px}
.mr-row select{background:var(--panel2);color:var(--fg);border:1px solid var(--line);border-radius:3px;font:inherit;font-size:13px;padding:2px 4px;min-width:0;width:100%}
.mr-row.chg span{color:var(--accent)}
.mr-row.chg select{border-color:var(--accent)}
.mr-tracks{margin-top:14px}
.mr-tr{display:grid;grid-template-columns:34px minmax(0,1.3fr) 3.2em minmax(0,1.6fr) minmax(150px,1fr);gap:10px;align-items:center;padding:6px 0;border-bottom:1px dotted var(--line);font-size:13px}
.mr-tr:last-child{border-bottom:0}
.mr-tr .play{width:30px;height:28px;padding:0;border-radius:4px;background:var(--panel2);border:1px solid var(--line)}
.mr-tr.on .play{border-color:var(--accent);color:var(--accent)}
.mr-tr.on .nm b{color:var(--accent)}
.mr-tr .nm small{display:block;color:var(--muted);font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.mr-tr .dur{font-family:var(--font-m);font-size:12px;color:var(--muted);font-variant-numeric:tabular-nums}
.mr-tr .use{display:flex;flex-wrap:wrap;gap:4px}
.mr-tr .use span{font-size:11px;padding:0 6px;border-radius:3px;border:1px solid var(--line);color:var(--muted)}
.mr-tr .use em{font-style:normal;font-size:11px;color:var(--muted);opacity:.6}
.mr-tr .vol{display:grid;grid-template-columns:minmax(0,1fr) 4.2em;gap:6px;align-items:center}
.mr-tr .vol input{width:100%}
.mr-tr .vol output{font-family:var(--font-m);font-size:12px;text-align:right;font-variant-numeric:tabular-nums}
.mr-tr .vol output.chg{color:var(--accent)}
.mr-tr.bad{opacity:.5}
.mr-tr .miss{font-size:11px;color:var(--enemy)}
.mr-out{width:100%;box-sizing:border-box;min-height:110px;margin-top:8px;background:#0b1016;color:var(--fg);border:1px solid var(--line);border-radius:4px;font-family:var(--font-m);font-size:12px;padding:8px}
@media (max-width:900px){.mr-cols{grid-template-columns:minmax(0,1fr)}.mr-tr{grid-template-columns:34px minmax(0,1fr) 3.2em;}.mr-tr .use,.mr-tr .vol{grid-column:2 / -1}}
`;

  function openRoom(opts){
    opts = opts || {};
    if (!document.getElementById('mrStyle')){ const st = document.createElement('style'); st.id = 'mrStyle'; st.textContent = CSS; document.head.appendChild(st); }
    const T = MA.TRACKS, names = Object.keys(T);
    const factions = (opts.factions || []).slice();
    for (const f in MA.tuning.defaults.faction) if (!factions.includes(f)) factions.push(f);
    const units = Object.assign({}, opts.units || {});
    for (const u in MA.tuning.defaults.unit) if (!(u in units)) units[u] = u;
    const prevCue = MA.state().cue;
    const wasMuted = MA.state().muted;
    if (wasMuted) MA.mute(false);
    MA.unlock();

    const root = document.createElement('div');
    root.className = 'modal mr'; root.id = 'musicRoom';
    document.body.appendChild(root);

    let showOut = false;
    function usage(){
      const u = {}; names.forEach(n => u[n] = []);
      SCENES.forEach(([k, lb]) => { const n = MA.CUES[k]; if (n && u[n]) u[n].push(lb); });
      for (const k in MA.THEMES.unit){ const n = MA.THEMES.unit[k]; if (n && u[n]) u[n].push((units[k] || k) + ' 主题'); }
      for (const k in MA.THEMES.faction){ const n = MA.THEMES.faction[k]; if (n && u[n]) u[n].push(k + ' 主题'); }
      return u;
    }
    const opt = (sel, none) => `<option value=""${sel ? '' : ' selected'}>${none}</option>` +
      names.map(n => `<option value="${esc(n)}"${n === sel ? ' selected' : ''}>${esc(n)}${MA.meta(n).bad ? '（缺文件）' : ''}</option>`).join('');

    function render(){
      const t = MA.tuning.get(), use = usage(), st = MA.state();
      const sceneRows = SCENES.map(([k, lb]) => `<label class="mr-row${k in t.cues ? ' chg' : ''}"><span>${lb}</span><select data-kind="cues" data-key="${k}">${opt(MA.CUES[k] || null, '（静音）')}</select></label>`).join('');
      const themeRows = Object.keys(units).map(k => `<label class="mr-row${k in t.unit ? ' chg' : ''}"><span>${esc(units[k])}（个人）</span><select data-kind="unit" data-key="${esc(k)}">${opt(MA.THEMES.unit[k] || null, '（不切，用势力的）')}</select></label>`).join('')
        + factions.map(f => `<label class="mr-row${f in t.faction ? ' chg' : ''}"><span>${esc(f)}</span><select data-kind="faction" data-key="${esc(f)}">${opt(MA.THEMES.faction[f] || null, '（没有主题曲）')}</select></label>`).join('');
      const rows = names.map(n => {
        const m = MA.meta(n), db = MA.tuning.dbOf(n), on = st.track === n && st.playing;
        return `<div class="mr-tr${on ? ' on' : ''}${m.bad ? ' bad' : ''}" data-n="${esc(n)}">
          <button class="play" data-play="${esc(n)}" title="${on ? '暂停' : '试听'}" ${m.bad ? 'disabled' : ''}>${on ? '❚❚' : '▶'}</button>
          <div class="nm"><b>${esc(n)}</b><small>${esc(T[n].file)}${T[n].id ? '' : ' · 本地版权曲'}</small>${m.bad ? '<span class="miss">这里读不到这首（退到 ' + esc(T[n].alt || '无') + '）</span>' : ''}</div>
          <span class="dur">${m.dur ? mmss(m.dur) : '—'}</span>
          <div class="use">${use[n].length ? use[n].map(x => `<span>${esc(x)}</span>`).join('') : '<em>没用上</em>'}</div>
          <div class="vol"><input type="range" min="-12" max="6" step="0.5" value="${db}" data-db="${esc(n)}" aria-label="${esc(n)} 音量"><output class="${db ? 'chg' : ''}">${db > 0 ? '+' : ''}${db} dB</output></div>
        </div>`;
      }).join('');
      const nChg = MA.tuning.changed();
      root.innerHTML = `<div class="dlg">
        <div class="eyebrow" style="color:var(--accent)">音乐鉴赏</div>
        <h2>试听、调音量、换曲子</h2>
        <p class="small">改动只存在这台浏览器里，回到游戏立刻生效。满意了点「复制设置」，把那段文字发给音乐对话，写进仓库后所有人都生效。音量是在按实测响度拉平之后再加减。</p>
        <div class="mr-now"><button class="btn" data-act="toggle">${st.playing ? '❚❚ 暂停' : '▶ 播放'}</button>
          <div><b>${st.track ? esc(st.track) : '（没有在放）'}</b><input type="range" min="0" max="${Math.max(1, Math.floor(st.dur))}" step="1" value="${Math.floor(st.time)}" data-act="seek" aria-label="进度"></div>
          <span class="t" id="mrTime">${mmss(st.time)} / ${mmss(st.dur)}</span></div>
        <div class="mr-cols">
          <section class="mr-sec"><h3>场景放哪首</h3>${sceneRows}</section>
          <section class="mr-sec"><h3>主题曲（放大招时切，放到本回合结束）</h3>${themeRows}</section>
        </div>
        <section class="mr-sec mr-tracks"><h3>全部曲目（${names.length} 首）</h3>${rows}</section>
        ${showOut ? `<textarea class="mr-out" readonly>${esc(MA.tuning.exportText())}</textarea><p class="small" id="mrCopied"></p>` : ''}
        <div class="acts">
          <button class="btn primary" data-act="copy">复制设置${nChg ? `（${nChg} 处改动）` : ''}</button>
          <button class="btn" data-act="reset"${nChg ? '' : ' disabled'}>恢复默认</button>
          <button class="btn" data-act="close">关闭</button>
        </div>
        <p class="small">新曲子：放进仓库的 <code>audio/SUNO/</code>，告诉音乐对话要放在哪，它会加进曲目表。</p>
      </div>`;
    }
    render();

    /* 进度条每 0.25 秒刷新（不整页重画，拖动时不打断） */
    let dragging = false;
    const iv = setInterval(() => {
      const st = MA.state(), sk = root.querySelector('[data-act=seek]'), tm = root.querySelector('#mrTime');
      if (sk && !dragging){ sk.max = Math.max(1, Math.floor(st.dur)); sk.value = Math.floor(st.time); }
      if (tm) tm.textContent = `${mmss(st.time)} / ${mmss(st.dur)}`;
      root.querySelectorAll('.mr-tr').forEach(r => { const d = r.querySelector('.dur'), n = r.dataset.n; if (d && d.textContent === '—'){ const m = MA.meta(n); if (m.dur) d.textContent = mmss(m.dur); } });
    }, 250);

    return new Promise(resolve => {
      function close(){
        clearInterval(iv); window.removeEventListener('keydown', onKey, true); root.remove();
        if (wasMuted) MA.mute(true);
        MA.play(prevCue);
        resolve();
      }
      function onKey(e){
        if (e.key === 'Escape'){ e.preventDefault(); close(); }
        e.stopPropagation();          // 鉴赏页开着时不触发游戏快捷键（空格结束回合、M 静音等）
      }
      window.addEventListener('keydown', onKey, true);
      root.addEventListener('click', async e => {
        const b = e.target.closest('button'); if (!b) return;
        if (b.dataset.play){
          const n = b.dataset.play, st = MA.state();
          if (st.track === n && st.playing) MA.stop(); else MA.preview(n);
          return setTimeout(render, 60);
        }
        const a = b.dataset.act;
        if (a === 'close') return close();
        if (a === 'toggle'){ const st = MA.state(); if (st.playing) MA.stop(); else if (st.track) MA.preview(st.track); else MA.preview(MA.CUES.title || names[0]); return setTimeout(render, 60); }
        if (a === 'reset'){ MA.tuning.reset(); return render(); }
        if (a === 'copy'){
          showOut = true; render();
          const txt = MA.tuning.exportText(), ta = root.querySelector('.mr-out'), msg = root.querySelector('#mrCopied');
          let ok = false;
          try { await navigator.clipboard.writeText(txt); ok = true; } catch(err){ try { ta.select(); ok = document.execCommand('copy'); } catch(e2){} }
          if (msg) msg.textContent = ok ? '已复制到剪贴板，直接粘贴给音乐对话就行。' : '没能自动复制：请选中上面的文字手动复制。';
        }
      });
      root.addEventListener('change', e => {
        const s = e.target;
        if (s.dataset.kind){ MA.tuning.assign(s.dataset.kind, s.dataset.key, s.value || null); render(); }
      });
      root.addEventListener('input', e => {
        const r = e.target;
        if (r.dataset.db){ MA.tuning.setDb(r.dataset.db, +r.value); const o = r.parentNode.querySelector('output'), v = MA.tuning.dbOf(r.dataset.db); o.textContent = `${v > 0 ? '+' : ''}${v} dB`; o.className = v ? 'chg' : ''; }
        if (r.dataset.act === 'seek'){ dragging = true; MA.seek(+r.value); }
      });
      root.addEventListener('pointerup', () => { dragging = false; });
      root.addEventListener('change', e => { if (e.target.dataset.act === 'seek'){ dragging = false; } });
    });
  }
  MA.openRoom = openRoom;
})();
