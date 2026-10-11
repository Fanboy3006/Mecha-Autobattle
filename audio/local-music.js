/* ============================================================================
 * 本地音乐播放层 MechAudio（音乐对话维护，2026-10-08 起取代 DSH 的合成器）
 * ----------------------------------------------------------------------------
 * 作者 10-09 起：主要曲子是作者用 Suno 生成的（audio/SUNO/，进仓库，试玩页也带）；
 * 还没有 Suno 版的（战略、Boss）用作者本地的版权曲（audio/*.mp3，.gitignore 排除，不进仓库），读不到时退到 alt。
 *   Claude hand off/src/index.html → ../../audio/<file>；试玩页 → music/<id>.mp3
 * 一首都读不到（测试环境）就整体不可用，声音按钮隐藏，游戏照常。
 *
 * 接口和 DSH 的 MechAudio 一样（31d 的接线不用大改）：
 *   play(cue)  切到某个场景的曲子（淡出旧的、淡入新的，每首记住播到哪里，切回来接着放）
 *   stop()     全部淡出；mute(bool)；unlock()（浏览器要用户点一下才能出声）；sfx(name)（暂时没有音效）
 *   state()    {ready, cue, track, muted, playing}
 * 新增：
 *   themeOf(mech, tpl)  这台机体出手时放的主题曲 cue（没有就 null）
 *   hasCue(cue)         这个 cue 有没有对应的曲子（胜利 / 失败现在没有）
 *   onAvailable(fn)     文件读得到 / 读不到时回调 fn(true / false)
 * 改曲目只改下面三张表。
 * ========================================================================== */
(function(){
  'use strict';
  /* 曲目：文件（相对 audio/）+ 实测响度（LUFS，ffmpeg ebur128）+ id（试玩页发布用的英文文件名）。
     音量按响度拉平到 REF，换曲子要重测。
     作者 10-09：换成作者用 Suno 生成的曲子（audio/SUNO/，进仓库，试玩页也带）。
     没有 id 的是作者本地的版权曲（不进仓库），读不到时退到 alt。 */
  const TRACKS = {
    'Suno 主角':     {file:'SUNO/Suno 主角.mp3',      lufs:-13.4, id:'hero'},
    'Suno 我方回合': {file:'SUNO/SUNO战斗音乐.mp3',   lufs:-13.9, id:'ally-phase'},
    'Suno 敌方回合': {file:'SUNO/Suno 敌方回合.mp3',  lufs:-13.3, id:'enemy-phase'},
    'Suno ATX':      {file:'SUNO/Suno ATX 小队.mp3',  lufs:-13.4, id:'atx'},
    'Suno 流星小队': {file:'SUNO/Suno 流星小队1.mp3', lufs:-13.8, id:'meteor'},
    'Suno 影世界':   {file:'SUNO/Suno 影世界1.mp3',   lufs:-14.3, id:'shadow'},
    'Suno 月王国':   {file:'SUNO/SUNO 月王国.mp3',    lufs:-12.9, id:'moon'},
    'Suno 秘银':     {file:'SUNO/SUNO 秘银小队.mp3',  lufs:-13.8, id:'mithril'},
    'Suno 卫星国防军':     {file:'SUNO/SUNO 卫星国防军.mp3',      lufs:-14.9, id:'clyne'},
    /* 还没有 Suno 版的，用作者本地的版权曲 */
    '战略音乐1':     {file:'战略音乐1.mp3',  lufs:-15.5, alt:'Suno 主角'},
    'BOSS BGM':      {file:'BOSS BGM.mp3',   lufs:-15.0, alt:'Suno 我方回合'},
  };
  /* 场景 → 曲目（作者 10-08 定，10-09 换 Suno）。null = 静音（胜利 / 失败暂时没有曲子） */
  const CUES = {
    title:'Suno 主角', mapStrategy:'战略音乐1',
    allyPhase:'Suno 我方回合', enemyPhase:'Suno 敌方回合', boss:'BOSS BGM',
    victory:null, defeat:null,
  };
  /* 主题曲（作者 10-08：像机战一样；10-09：只有放大招才切，保持到本回合结束）。先查机体代号，再查主势力；什么时候切在 31d */
  const THEMES = {
    unit:    {B1:'Suno 主角'},                          // 雷萨
    faction: {'流星小队':'Suno 流星小队', 'ATX':'Suno ATX', '影世界':'Suno 影世界',
              '月球王国':'Suno 月王国', '秘银':'Suno 秘银', '卫星国防军':'Suno 卫星国防军'},   // 天人还没有
  };

  /* 仓库里的页面（Claude hand off/src/index.html）从 ../../audio/ 读；试玩页由 build-artifact 设 MECHA_MUSIC_BASE = 'music/'、MECHA_MUSIC_FLAT = true，按 id 读 music/<id>.mp3 */
  const W = typeof window !== 'undefined' ? window : {};
  const BASE = W.MECHA_MUSIC_BASE || '../../audio/', FLAT = !!W.MECHA_MUSIC_FLAT;
  const REF = -17.5, MASTER = 0.8, FADE = 600;

  /* ---------- 作者的试听调整（音乐鉴赏页，10-10） ----------
     存在这台浏览器的 localStorage（TUNE_KEY），游戏里立刻生效；「复制设置」导出后发给音乐对话写进上面的表，所有人才生效。
     {db:{曲名: 音量偏移 dB}, cues:{场景: 曲名 | null}, unit:{机体代号: 曲名 | null}, faction:{势力: 曲名 | null}} */
  const TUNE_KEY = 'mecha-music-tune';
  const DEF = {cues: Object.assign({}, CUES), unit: Object.assign({}, THEMES.unit), faction: Object.assign({}, THEMES.faction)};
  let tune = {db:{}, cues:{}, unit:{}, faction:{}};
  try { const t = JSON.parse(localStorage.getItem(TUNE_KEY) || 'null'); if (t && typeof t === 'object') tune = Object.assign(tune, t); } catch(e){}
  function applyTune(){
    const put = (dst, def, ov) => { for (const k in dst) delete dst[k]; Object.assign(dst, def); for (const k in ov){ if (ov[k] === null || TRACKS[ov[k]]) dst[k] = ov[k]; } for (const k in dst) if (dst[k] === null && !(k in CUES_SCENES)) delete dst[k]; };
    put(CUES, DEF.cues, tune.cues); put(THEMES.unit, DEF.unit, tune.unit); put(THEMES.faction, DEF.faction, tune.faction);
  }
  const CUES_SCENES = Object.assign({}, CUES);      // 场景的键（值为 null 的 = 静音，要保留）
  function saveTune(){ try { localStorage.setItem(TUNE_KEY, JSON.stringify(tune)); } catch(e){} }
  const dbOf = n => +(tune.db[n] || 0);
  const gainOf = n => Math.min(1, Math.pow(10, (REF - TRACKS[n].lufs + dbOf(n)) / 20)) * MASTER;
  const urlOf = n => { const t = TRACKS[n]; if (FLAT && !t.id) return null; try { return new URL(BASE + (FLAT ? t.id + '.mp3' : t.file), document.baseURI).href; } catch(e){ return null; } };
  /* 读不到的曲子（试玩页上的本地版权曲）退到 alt */
  const bad = {};
  const usable = n => { for (let k = 0; n && k < 5; k++){ if (!bad[n] && (!FLAT || TRACKS[n].id)) return n; n = TRACKS[n].alt || null; } return null; };
  const nameOf = cue => usable(!cue ? null : cue.startsWith('theme:') ? cue.slice(6) : cue.startsWith('track:') ? (TRACKS[cue.slice(6)] ? cue.slice(6) : null) : (CUES[cue] || null));

  const els = {};
  let avail = null, muted = false, unlocked = false, cue = null, cur = null;
  const waiters = [];
  function setAvail(v){ if (avail !== null) return; avail = v; waiters.splice(0).forEach(f => { try { f(v); } catch(e){} }); if (v) resume(); }

  function el(n){
    if (els[n]) return els[n];
    const u = urlOf(n); if (!u || typeof Audio === 'undefined') return null;
    const a = new Audio(); a.preload = 'metadata'; a.loop = true; a.volume = 0; a.src = u;
    a._target = 0;
    a.addEventListener('error', () => { bad[n] = true; if (cur === n){ cur = null; play(cue); } });
    return (els[n] = a);
  }
  /* 淡入淡出：每 30ms 把每个元素的音量往目标挪一步，到 0 就暂停（保留播放位置） */
  let timer = null;
  function tick(){
    let busy = false;
    for (const n in els){
      const a = els[n], step = 30 / FADE;
      if (a.volume !== a._target){
        const v = a.volume < a._target ? Math.min(a._target, a.volume + step) : Math.max(a._target, a.volume - step);
        a.volume = v; busy = true;
      }
      if (a._target === 0 && a.volume === 0 && !a.paused) a.pause();
    }
    if (!busy){ clearInterval(timer); timer = null; }
  }
  function fadeTo(n, v){ const a = els[n]; if (!a) return; a._target = v; if (!timer) timer = setInterval(tick, 30); }
  function start(n){
    const a = el(n); if (!a) return;
    a.preload = 'auto';
    const p = a.play(); if (p && p.catch) p.catch(() => {});
    fadeTo(n, gainOf(n));
  }
  function resume(){ if (cur && avail && !muted && unlocked) start(cur); }

  function play(c){
    cue = c || null;
    const n = nameOf(cue);
    if (n === cur){ resume(); return; }
    if (cur) fadeTo(cur, 0);
    cur = n;
    resume();
  }
  function stop(){ cue = null; if (cur) fadeTo(cur, 0); cur = null; }
  function mute(on){ muted = !!on; if (muted){ for (const n in els) fadeTo(n, 0); } else resume(); }
  function unlock(){ if (unlocked) return; unlocked = true; resume(); }
  function themeOf(mech, tpl){
    const n = THEMES.unit[mech] || (tpl && tpl.tags && THEMES.faction[tpl.tags.势力]);   // 双势力按主势力（拉米亚 → ATX）
    return n && TRACKS[n] ? 'theme:' + n : null;
  }
  function onAvailable(fn){ if (avail !== null) fn(avail); else waiters.push(fn); }
  function state(){ const a = cur && els[cur]; return {ready: !!avail, cue, track: cur, muted, playing: !!(a && !a.paused), time: a ? a.currentTime : 0, dur: a && isFinite(a.duration) ? a.duration : 0}; }

  /* ---------- 给音乐鉴赏页用 ---------- */
  const tuning = {
    defaults: DEF,
    get(){ return JSON.parse(JSON.stringify(tune)); },
    setDb(n, db){ db = Math.round(db * 2) / 2; if (db) tune.db[n] = db; else delete tune.db[n]; saveTune(); if (cur === n && els[n] && els[n]._target > 0) fadeTo(n, gainOf(n)); },
    /* kind: 'cues' | 'unit' | 'faction'；name 为 null = 静音 / 没有主题曲；和默认一样就删掉覆盖 */
    assign(kind, key, name){
      const def = DEF[kind][key] === undefined ? (kind === 'cues' ? null : undefined) : DEF[kind][key];
      if ((name || null) === (def || null)) delete tune[kind][key]; else tune[kind][key] = name || null;
      saveTune(); applyTune();
      if (cue && !cue.startsWith('track:')) play(cue);   // 正在放的场景换了曲子就跟着换
    },
    reset(){ tune = {db:{}, cues:{}, unit:{}, faction:{}}; saveTune(); applyTune(); if (cur && els[cur] && els[cur]._target > 0) fadeTo(cur, gainOf(cur)); },
    changed(){ return Object.keys(tune.db).length + Object.keys(tune.cues).length + Object.keys(tune.unit).length + Object.keys(tune.faction).length; },
    /* 导出：发给音乐对话的一段文字 */
    exportText(){
      const L = ['【音乐鉴赏 · 调整】' + new Date().toLocaleString()];
      const nm = v => v === null ? '（静音 / 不切）' : v;
      for (const k in tune.cues) L.push(`场景 ${k}：${nm(DEF.cues[k] === undefined ? null : DEF.cues[k])} → ${nm(tune.cues[k])}`);
      for (const k in tune.unit) L.push(`机体 ${k} 主题曲：${nm(DEF.unit[k] || null)} → ${nm(tune.unit[k])}`);
      for (const k in tune.faction) L.push(`势力 ${k} 主题曲：${nm(DEF.faction[k] || null)} → ${nm(tune.faction[k])}`);
      for (const k in tune.db) L.push(`音量 ${k}：${tune.db[k] > 0 ? '+' : ''}${tune.db[k]} dB`);
      if (L.length === 1) L.push('（没有改动）');
      L.push('', JSON.stringify(tune));
      return L.join('\n');
    },
    dbOf, usable: n => usable(n) === n,
  };
  /* 试听一首：直接放这首（不管场景），seek 到 t 秒 */
  function preview(n){ if (TRACKS[n]) play('track:' + n); }
  function seek(t){ const a = cur && els[cur]; if (a && isFinite(t)) try { a.currentTime = Math.max(0, t); } catch(e){} }
  function meta(n){ const a = el(n); return a ? {dur: isFinite(a.duration) ? a.duration : 0, bad: !!bad[n] || usable(n) !== n} : {dur:0, bad:true}; }

  applyTune();

  /* 探测：先载第一首战斗曲的元数据，读得到就算可用 */
  (function probe(){
    const a = el('Suno 我方回合');
    if (!a){ setAvail(false); return; }
    a.addEventListener('loadedmetadata', () => setAvail(true), {once:true});
    a.addEventListener('error', () => setAvail(false), {once:true});
    a.load();
  })();
  /* 浏览器要用户手势才放声音：任何一次点击 / 按键都算 */
  if (typeof document !== 'undefined'){
    const u = () => { unlock(); document.removeEventListener('pointerdown', u, true); document.removeEventListener('keydown', u, true); };
    document.addEventListener('pointerdown', u, true); document.addEventListener('keydown', u, true);
  }

  globalThis.MechAudio = {local:true, play, stop, mute, unlock, sfx(){}, setVolume(){}, state, themeOf, hasCue: c => !!nameOf(c), onAvailable, TRACKS, CUES, THEMES, _bad: bad, preview, seek, meta, tuning};
})();
