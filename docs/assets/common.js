// 모든 웹 페이지가 함께 쓰는 부품: 저장소, 번역, 게임 목록과 상징, 기록, 타이머, 겹쳐 보이는 창, 더보기 메뉴.
// 앱의 GameKind.swift, GameSymbol.swift, StatsStore.swift, PuzzleChrome.swift를 옮겼다.
(function () {
  const store = {
    get(k, d) { try { const v = localStorage.getItem('fs:' + k); return v == null ? d : JSON.parse(v); } catch { return d; } },
    set(k, v) { try { if (v == null) localStorage.removeItem('fs:' + k); else localStorage.setItem('fs:' + k, JSON.stringify(v)); } catch {} },
  };

  // ── 번역: 한국어 문구가 키, [영어, 일본어, 중국어 간체] ──
  const EXTRA = {
    '네모 안에 네모': ['Nemo in Nemo', 'ネモ・イン・ネモ', '方中方'],
    '웹': ['Web', 'Web', '网页版'],
    '{0}행 {1}열': ['Row {0}, column {1}', '{0}行 {1}列', '第{0}行 第{1}列'],
    '켜진 불 {0}/{1}': ['Lights on {0}/{1}', '点灯 {0}/{1}', '亮灯 {0}/{1}'],
    '조작 {0}회': ['{0} moves', '{0}手', '{0} 步'],
    '최소 {0}회': ['Fewest {0}', '最少 {0}手', '最少 {0} 步'],
    '최소 조작으로 풀었어요': ['Solved in the fewest moves', '最少手数でクリア', '以最少步数完成'],
    '조작 {0}회 · 최소 {1}회': ['{0} moves · fewest {1}', '{0}手 · 最少 {1}手', '{0} 步 · 最少 {1} 步'],
    '{0}×{1} · 최소 {2}~{3}회': ['{0}×{1} · {2}–{3} moves', '{0}×{1} · 最少 {2}〜{3}手', '{0}×{1} · 最少 {2}–{3} 步'],
    '별 {0}/{1}': ['Stars {0}/{1}', '星 {0}/{1}', '星星 {0}/{1}'],
    '도착': ['Arrived', '到着', '已到达'],
    '도착 전': ['Not there yet', '未到着', '未到达'],
    '고정된 거울이에요': ['This mirror is fixed', 'この鏡は固定されています', '这面镜子是固定的'],
    '{0}×{1} · 거울 {2}~{3}개': ['{0}×{1} · {2}–{3} mirrors', '{0}×{1} · 鏡 {2}〜{3}枚', '{0}×{1} · 镜子 {2}–{3} 面'],
    '빛이 모든 별을 지나 목적지로 나가게 해 주세요. 거울을 누르면 방향이 바뀌어요.': ['Send the light through every star and out at the goal. Tap a mirror to turn it.', '光がすべての星を通って出口から出るようにしてください。鏡を押すと向きが変わります。', '让光穿过所有星星并从终点射出。点击镜子可改变方向。'],
    '연결 {0}/{1}': ['Linked {0}/{1}', '接続 {0}/{1}', '已连接 {0}/{1}'],
    '빈칸 {0}': ['{0} empty', '空き {0}', '空格 {0}'],
    '{0}×{1} · 빈칸 허용': ['{0}×{1} · empty cells OK', '{0}×{1} · 空きマスOK', '{0}×{1} · 可留空格'],
    '{0}×{1} · 모든 칸 채우기': ['{0}×{1} · fill every cell', '{0}×{1} · 全マスを使う', '{0}×{1} · 填满所有格'],
    '길을 모두 지울까요?': ['Clear all paths?', 'すべての道を消しますか？', '要清除所有路径吗？'],
    '같은 숫자끼리 숫자만큼의 칸으로 이어 주세요. 길은 겹칠 수 없어요.': ['Link each pair of equal numbers with a path of exactly that many cells. Paths can’t cross.', '同じ数字どうしを、その数字と同じマス数の道でつないでください。道は重なれません。', '用与数字相同格数的路径连接相同的数字。路径不能交叉。'],
    '같은 숫자끼리 숫자만큼의 칸으로 이어 주세요. 모든 칸을 채워야 해요.': ['Link each pair of equal numbers with a path of exactly that many cells. Every cell must be used.', '同じ数字どうしを、その数字と同じマス数の道でつないでください。すべてのマスを使います。', '用与数字相同格数的路径连接相同的数字。必须用满所有格子。'],
    '남은 {0}회': ['{0} moves left', '残り {0}手', '剩余 {0} 步'],
    '횟수 제한': ['Move limit', '手数制限', '步数限制'],
    '최소 {0}회 안에 풀지 못했어요': ['Not solved within {0} moves', '{0}手以内に解けませんでした', '未能在 {0} 步内完成'],
    '지옥에서는 최소 횟수 안에 모든 불을 켜야 해요.': ['In Hell, every light must be on within the fewest moves.', '地獄では最少手数以内にすべての明かりをつける必要があります。', '地狱难度必须在最少步数内点亮所有灯。'],
    '최소 횟수 안에 풀어야 해요. 되돌리기도 1회로 세요.': ['Solve it within the fewest moves. Undo counts as a move too.', '最少手数以内に解いてください。元に戻すも1手に数えます。', '必须在最少步数内完成，撤销也算一步。'],
    '누른 칸의 가로줄과 세로줄이 모두 바뀌어요. 불을 모두 켜 주세요.': ['Tapping a square flips its whole row and column. Turn every light on.', 'マスを押すと、その横の列と縦の列がすべて切り替わります。すべての明かりをつけてください。', '点击方格会切换整行和整列。把所有灯都点亮。'],
  };
  const TABLE = Object.assign({}, window.NEMO_I18N || {}, EXTRA);
  const LANGS = ['ko', 'ja', 'zh', 'en'];
  const detectLang = () => {
    for (const l of navigator.languages || [navigator.language]) {
      const base = (l || '').toLowerCase().split('-')[0];
      if (LANGS.includes(base)) return base;
    }
    return 'en';
  };
  let langPref = store.get('lang', 'auto');
  let lang = langPref === 'auto' ? detectLang() : langPref;
  function t(key, ...args) {
    const row = TABLE[key];
    const text = lang === 'ko' || !row ? key : row[{ en: 0, ja: 1, zh: 2 }[lang]];
    return text.replace(/\{(\d)\}/g, (_, i) => args[i]);
  }
  function setLang(pref) {
    langPref = pref;
    store.set('lang', pref);
    lang = pref === 'auto' ? detectLang() : pref;
    document.documentElement.lang = lang === 'zh' ? 'zh-Hans' : lang;
  }
  document.documentElement.lang = lang === 'zh' ? 'zh-Hans' : lang;

  // ── 게임 목록. 순서가 메인 화면의 번호(01, 02…)다. 이름은 모든 언어에서 영어 그대로. ──
  const KINDS = [
    { id: 'minesweeper', title: 'Field Sweeper', href: 'minesweeper.html' },
    { id: 'sudoku', title: 'Sudoku', href: 'sudoku.html' },
    { id: 'shikaku', title: 'Shikaku', href: 'shikaku.html' },
    { id: 'futoshiki', title: 'Futoshiki', href: 'futoshiki.html' },
    // 아직 만들지 않은 게임은 메인 화면에 '준비 중'으로 보인다.
    { id: 'mirror', title: 'Mirror Squares', href: 'mirror.html' },
    { id: 'pair', title: 'Pair Paths', href: 'pair.html' },
    { id: 'switch', title: 'Switch Squares', href: 'switch.html' },
  ].map((k, i) => ({ ...k, number: String(i + 1).padStart(2, '0') }));
  const kind = id => KINDS.find(k => k.id === id);

  // ── 게임 이름 앞의 작은 상징. 모두 네모 안에 그 게임을 담은 모양이다. ──
  let maskSeq = 0;
  function symbol(id, cls = 'sym') {
    const s = 24, line = Math.max(1.3, s * 0.085), inset = line / 2, thin = line * 0.6;
    const p = (x, y) => `${(x * s).toFixed(2)} ${(y * s).toFixed(2)}`;
    const frame = `<rect x="${inset}" y="${inset}" width="${s - line}" height="${s - line}" rx="${s * 0.16}" fill="none" stroke="currentColor" stroke-width="${line}"/>`;
    let body = '', defs = '';
    if (id === 'minesweeper') {
      const cx = 0.5 * s, cy = 0.52 * s, r = s * 0.19, shine = s * 0.055;
      let spikes = '';
      for (let k = 0; k < 8; k++) {
        const a = k * Math.PI / 4, len = k % 2 === 0 ? s * 0.29 : s * 0.25;
        spikes += `M${cx} ${cy}L${(cx + Math.cos(a) * len).toFixed(2)} ${(cy + Math.sin(a) * len).toFixed(2)}`;
      }
      const m = 'nm' + (++maskSeq);
      defs = `<mask id="${m}"><rect width="24" height="24" fill="#fff"/><circle cx="${cx - r * 0.45}" cy="${cy - r * 0.45}" r="${shine}" fill="#000"/></mask>`;
      body = `<g mask="url(#${m})"><path d="${spikes}" stroke="currentColor" stroke-width="${thin}" stroke-linecap="round"/><circle cx="${cx}" cy="${cy}" r="${r}" fill="currentColor"/></g>`;
    } else if (id === 'sudoku') {
      const e = line / s;
      let d = '';
      for (const v of [1 / 3 + e / 3, 2 / 3 - e / 3]) d += `M${p(v, e)}L${p(v, 1 - e)}M${p(e, v)}L${p(1 - e, v)}`;
      body = `<path d="${d}" stroke="currentColor" stroke-width="${thin}"/>`;
    } else if (id === 'shikaku') {
      body = `<path d="M${p(0.56, 0.12)}L${p(0.56, 0.88)}M${p(0.12, 0.42)}L${p(0.56, 0.42)}M${p(0.56, 0.66)}L${p(0.88, 0.66)}" stroke="currentColor" stroke-width="${thin}" stroke-linecap="round"/>`;
    } else if (id === 'mirror') {
      // 거울 한 장과 꺾이는 빛
      body = `<path d="M7 17 17 7" stroke="currentColor" stroke-width="${line}" stroke-linecap="round"/><path d="M4.5 12H11V5.5" fill="none" stroke="currentColor" stroke-width="${thin}" stroke-linecap="round" stroke-dasharray="1.6 1.8"/>`;
    } else if (id === 'pair') {
      // 두 점을 잇는 길
      body = `<path d="M7 7v10h10" fill="none" stroke="currentColor" stroke-width="${thin * 1.15}" stroke-linejoin="round"/><circle cx="7" cy="7" r="2.1" fill="currentColor"/><circle cx="17" cy="17" r="2.1" fill="currentColor"/>`;
    } else if (id === 'switch') {
      // 누른 칸과 함께 바뀌는 가로줄·세로줄
      body = `<path d="M12 ${line}V${s - line}M${line} 12H${s - line}" stroke="currentColor" stroke-width="${thin}"/><circle cx="12" cy="12" r="3.2" fill="currentColor"/>`;
    } else {
      body = `<path d="M${p(0.64, 0.25)}L${p(0.36, 0.43)}L${p(0.64, 0.61)}M${p(0.36, 0.74)}L${p(0.64, 0.74)}" fill="none" stroke="currentColor" stroke-width="${line}" stroke-linecap="round" stroke-linejoin="round"/>`;
    }
    return `<svg class="${cls}" viewBox="0 0 24 24" aria-hidden="true">${defs}${frame}${body}</svg>`;
  }

  // SF Symbols를 대신하는 선 아이콘
  const ICON = {
    back: '<path d="M15 5l-7 7 7 7"/>',
    pause: '<circle cx="12" cy="12" r="9"/><path d="M10 9v6M14 9v6"/>',
    more: '<circle cx="5" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="19" cy="12" r="1.6" fill="currentColor" stroke="none"/>',
    undo: '<path d="M9 14L4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
    eraser: '<path d="M8.5 20H20"/><path d="M5.6 15.6l8.5-8.5a2 2 0 0 1 2.8 0l2 2a2 2 0 0 1 0 2.8L12 18.8a4 4 0 0 1-2.8 1.2H8.6a2 2 0 0 1-1.4-.6l-1.6-1.6a2 2 0 0 1 0-2.2z"/><path d="M10 11.2l4.8 4.8"/>',
    pencil: '<path d="M4 20l1-4.5L15.5 5a2.1 2.1 0 0 1 3 3L8 18.5z"/><path d="M13.5 7l3 3"/>',
    trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V4h6v3"/>',
    restart: '<path d="M4 12a8 8 0 1 0 2.4-5.7"/><path d="M4 4v4.5h4.5"/>',
    stopwatch: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4M9 2h6"/>',
    external: '<path d="M7 17L17 7M9 7h8v8"/>',
  };
  const icon = name => `<svg class="i" viewBox="0 0 24 24" aria-hidden="true">${ICON[name]}</svg>`;
  const pauseFill = '<svg class="pause-ico" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="11" fill="currentColor"/><rect x="8.2" y="7" width="2.6" height="10" rx=".8" fill="var(--ink)"/><rect x="13.2" y="7" width="2.6" height="10" rx=".8" fill="var(--ink)"/></svg>';

  // ── 기록: 게임마다 판 수, 완료, 난이도별 최고 기록. 난이도는 한국어 이름으로 구분한다. ──
  const blankStats = () => ({ plays: 0, completions: 0, totalSeconds: 0, completionsByDifficulty: {}, bestByDifficulty: {} });
  const stats = {
    load: id => Object.assign(blankStats(), store.get('stats.' + id, null) || {}),
    recordStart(id) { const s = stats.load(id); s.plays++; store.set('stats.' + id, s); },
    // 최고 기록을 갱신했으면 true
    recordWin(id, difficulty, seconds) {
      const s = stats.load(id);
      s.completions++;
      s.totalSeconds += seconds;
      s.completionsByDifficulty[difficulty] = (s.completionsByDifficulty[difficulty] || 0) + 1;
      const best = s.bestByDifficulty[difficulty];
      const isNew = best == null || seconds < best;
      if (isNew) s.bestByDifficulty[difficulty] = seconds;
      store.set('stats.' + id, s);
      return isNew;
    },
    totalPlays: () => KINDS.reduce((a, k) => a + stats.load(k.id).plays, 0),
  };

  // 난이도별 되돌리기 횟수: 초급·커스텀 무제한, 오를수록 줄고 지옥은 없다(앱 UndoLimit.swift와 같은 표).
  // 숫자 지우기·영역 지우기·다시 누르기 같은 직접 고치기는 횟수와 상관없다.
  const UNDO = { '중급': 10, '고급': 5, '전문가': 3, '지옥': 0 };
  const undoLimit = levelName => (levelName in UNDO ? UNDO[levelName] : Infinity);
  const undoLabel = left => (left === Infinity ? t('되돌리기') : t('되돌리기 {0}', left));

  const clock = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // ── 멈출 수 있는 시계 ──
  class Timer {
    constructor(seconds = 0) { this.acc = seconds * 1000; this.since = null; }
    start() { if (this.since == null) this.since = Date.now(); }
    pause() { if (this.since != null) { this.acc += Date.now() - this.since; this.since = null; } }
    get running() { return this.since != null; }
    get seconds() { return (this.acc + (this.since != null ? Date.now() - this.since : 0)) / 1000; }
  }

  // ── 겹쳐 보이는 창. 한 번에 하나만 띄운다. ──
  let current = null;
  function overlay(html, { cover = false, onBackdrop = null } = {}) {
    close();
    const el = document.createElement('div');
    el.className = 'scrim' + (cover ? ' cover' : '');
    el.innerHTML = html;
    if (onBackdrop) el.addEventListener('click', e => { if (e.target === el) onBackdrop(); });
    document.body.appendChild(el);
    current = el;
    el.querySelector('[data-focus]')?.focus();
    return el;
  }
  function close() { if (current) { current.remove(); current = null; } }
  const isOpen = () => current != null;

  function working(text) {
    overlay(`<div class="card center" role="status"><div class="spinner"></div><p style="color:var(--ink)">${esc(text)}</p></div>`);
  }

  // items: [{ id, name, detail, best }]
  function levelPicker({ items, current: cur, canCancel, onPick, onCancel }) {
    const el = overlay(`<div class="card wide" role="dialog" aria-modal="true" aria-labelledby="lpTitle">
      <h3 id="lpTitle">${t('난이도를 골라 주세요')}</h3>
      <div class="levels">${items.map(it => `<button class="level" data-id="${it.id}" aria-current="${it.id === cur}">
        <span><b>${esc(it.name)}</b><small>${esc(it.detail)}</small></span>${it.best != null ? `<em>${clock(it.best)}</em>` : ''}</button>`).join('')}</div>
      <button class="btn plain" data-cancel>${t(canCancel ? '취소' : '돌아가기')}</button></div>`);
    el.querySelectorAll('.level').forEach(b => { b.onclick = () => { close(); onPick(+b.dataset.id); }; });
    el.querySelector('[data-cancel]').onclick = () => { close(); onCancel(); };
    el.querySelector(`.level[aria-current="true"]`)?.focus();
  }

  function pauseCover({ subtitle, time, onResume }) {
    const el = overlay(`<div class="card center" role="dialog" aria-modal="true" aria-labelledby="psTitle" style="background:none;max-width:320px">
      ${pauseFill}<h2 id="psTitle">${t('일시정지')}</h2><p>${esc(subtitle)}</p>
      ${time != null ? `<div class="big small">${time}</div>` : ''}
      <div class="actions" style="padding-top:8px"><button class="btn primary" data-focus>${t('계속하기')}</button></div></div>`, { cover: true });
    el.querySelector('.btn').onclick = () => { close(); onResume(); };
  }

  function result({ title, subtitle, note, time, isNewBest, onClose, onOther, onAgain }) {
    const el = overlay(`<div class="card center" role="dialog" aria-modal="true" aria-labelledby="rsTitle">
      <h2 id="rsTitle">${esc(title)}</h2><p>${esc(subtitle)}</p>${note ? `<p>${esc(note)}</p>` : ''}
      ${time != null ? `<div class="big">${time}</div>${isNewBest ? `<span class="badge">${t('최고 기록')}</span>` : ''}` : ''}
      <div class="actions"><button class="btn" data-other>${t('다른 난이도')}</button><button class="btn primary" data-again data-focus>${t('새 퍼즐')}</button></div></div>`,
    { onBackdrop: () => { close(); onClose(); } });
    el.querySelector('[data-other]').onclick = () => { close(); onOther(); };
    el.querySelector('[data-again]').onclick = () => { close(); onAgain(); };
  }

  function confirmBox({ title, message, ok, onOk, onCancel = () => {} }) {
    const el = overlay(`<div class="card center" role="alertdialog" aria-modal="true" aria-labelledby="cfTitle">
      <h3 id="cfTitle">${esc(title)}</h3><p>${esc(message)}</p>
      <div class="actions"><button class="btn" data-no data-focus>${t('취소')}</button><button class="btn danger" data-yes>${esc(ok)}</button></div></div>`,
    { onBackdrop: () => { close(); onCancel(); } });
    el.querySelector('[data-no]').onclick = () => { close(); onCancel(); };
    el.querySelector('[data-yes]').onclick = () => { close(); onOk(); };
  }

  // ── 더보기 메뉴. build()가 돌려주는 항목으로 매번 새로 그린다. ──
  // { section }, { sep: true }, { label, icon, disabled, onClick }, { label, checked, onChange }
  function menu(button, panel, build) {
    const render = () => {
      panel.replaceChildren(...build().map(item => {
        if (item.section) { const d = document.createElement('div'); d.className = 'sec'; d.textContent = item.section; return d; }
        if (item.sep) return document.createElement('hr');
        const b = document.createElement('button');
        b.setAttribute('role', item.onChange ? 'menuitemcheckbox' : 'menuitem');
        b.innerHTML = (item.icon ? icon(item.icon) : '') + `<span>${esc(item.label)}</span>`;
        b.disabled = !!item.disabled;
        if (item.onChange) {
          b.className = 'check';
          b.setAttribute('aria-checked', !!item.checked);
          b.onclick = () => { item.onChange(!item.checked); toggle(false); };
        } else b.onclick = () => { toggle(false); item.onClick(); };
        return b;
      }));
    };
    const toggle = open => {
      if (open) render();
      panel.hidden = !open;
      button.setAttribute('aria-expanded', open);
    };
    button.onclick = e => { e.stopPropagation(); toggle(panel.hidden); };
    document.addEventListener('pointerdown', e => { if (!panel.hidden && !e.target.closest('.more')) toggle(false); });
    document.addEventListener('keydown', e => { if (e.key === 'Escape') toggle(false); });
    return { close: () => toggle(false) };
  }

  // ── 게임 화면 위쪽 막대: 뒤로, 상징과 이름·부제, 시간, 일시정지, 더보기 ──
  function topBar(id) {
    const k = kind(id);
    const el = document.createElement('header');
    el.className = 'topbar';
    el.innerHTML = `<a class="ib" href="./" aria-label="${t('뒤로')}" data-back>${icon('back')}</a>
      ${symbol(id)}
      <div class="title"><b>${k.title}</b><span data-sub></span></div>
      <div class="spacer"></div>
      <div class="timer" data-timer hidden>${icon('stopwatch')}<span data-time>0:00</span></div>
      <button class="ib" data-pause aria-label="${t('일시정지')}" disabled>${icon('pause')}</button>
      <div class="more"><button class="ib" data-more aria-label="${t('더보기')}" aria-haspopup="menu" aria-expanded="false">${icon('more')}</button>
      <div class="menu" role="menu" hidden data-menu></div></div>`;
    return el;
  }

  // ── 캔버스: 화면 배율에 맞춰 선명하게 그리고, CSS 색 변수를 읽는다. ──
  function fitCanvas(canvas, w, h) {
    const dpr = window.devicePixelRatio || 1;
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return ctx;
  }
  const cssColor = name => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  function onTheme(fn) {
    matchMedia('(prefers-color-scheme: dark)').addEventListener?.('change', fn);
    new MutationObserver(fn).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  }
  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    if (ctx.roundRect) ctx.roundRect(x, y, w, h, r);
    else ctx.rect(x, y, w, h);
  }

  window.Nemo = {
    store, t, setLang, get lang() { return lang; }, get langPref() { return langPref; },
    KINDS, kind, symbol, icon, stats, clock, esc, Timer, undoLimit, undoLabel,
    overlay, close, isOpen, working, levelPicker, pauseCover, result, confirmBox, menu, topBar,
    fitCanvas, cssColor, onTheme, roundRect,
  };
})();
