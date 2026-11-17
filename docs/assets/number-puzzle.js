// 칸을 골라 숫자를 넣는 퍼즐(스도쿠, 후토시키)의 공통 진행. 앱의 SudokuGame/FutoshikiGame과 각 View를 옮겼다.
// 게임마다 다른 것(판 그리기, 이웃 칸, 생성, 메뉴 항목)은 cfg로 받는다.
window.NumberPuzzle = function (cfg) {
  const { t, store, stats, clock } = Nemo;
  const K = Nemo.kind(cfg.kind);
  const app = document.getElementById('app');
  const wrap = document.getElementById('wrap');
  const canvas = document.getElementById('board');
  const keysEl = document.getElementById('keys');
  const guideEl = document.getElementById('guide');

  const bar = Nemo.topBar(cfg.kind);
  app.prepend(bar);
  const q = sel => bar.querySelector(sel);

  let showTimer = store.get('showTimer', true);
  const opts = {};
  for (const o of cfg.options) opts[o.key] = store.get(`${cfg.kind}.${o.key}`, o.default);

  const G = { puzzle: null, values: [], notes: [], status: 'empty', selected: null, noteMode: false,
    history: [], counted: false, undosUsed: 0, timer: new Nemo.Timer(), isNewBest: false };
  const undosLeft = () => (G.puzzle ? Math.max(0, Nemo.undoLimit(levelOf(G.puzzle).name) - G.undosUsed) : Infinity);
  const n = () => (G.puzzle ? cfg.size(G.puzzle) : cfg.emptySize);
  const isGiven = i => !!(G.puzzle && G.puzzle.givens[i]);
  const levelOf = p => cfg.levels.find(l => l.id === p.level) || cfg.levels[0];
  const subtitle = () => (G.puzzle ? cfg.subtitle(G.puzzle) : '');
  const saveKey = cfg.kind + '.save';

  // ── 시작·저장 ──
  function start(puzzle, saved) {
    G.puzzle = puzzle;
    const cells = cfg.size(puzzle) ** 2;
    G.values = saved ? saved.values.slice() : puzzle.givens.slice();
    G.notes = saved ? saved.notes.slice() : new Array(cells).fill(0);
    G.history = [];
    G.selected = null;
    G.noteMode = false;
    G.counted = saved ? !!saved.counted : false;
    G.undosUsed = saved ? saved.undosUsed || 0 : 0;
    G.isNewBest = false;
    G.timer = new Nemo.Timer(saved ? saved.elapsed : 0);
    G.timer.start();
    G.status = 'playing';
    render();
  }
  function restore(s) {
    if (!s || !s.puzzle || !Array.isArray(s.values)) return false;
    const cells = cfg.size(s.puzzle) ** 2;
    if (!cells || s.values.length !== cells || s.notes?.length !== cells || s.puzzle.givens?.length !== cells
      || s.puzzle.solution?.length !== cells || !s.puzzle.givens.every((g, i) => !g || g === s.values[i])) return false;
    if (cfg.validate && !cfg.validate(s.puzzle)) return false;
    start(s.puzzle, s);
    return true;
  }
  function save() {
    if (G.status !== 'playing') return;
    store.set(saveKey, { puzzle: G.puzzle, values: G.values, notes: G.notes, elapsed: G.timer.seconds, counted: G.counted, undosUsed: G.undosUsed, savedAt: Date.now() });
  }

  // ── 입력 ──
  function record(changes) {
    G.history.push(changes);
    if (G.history.length > 500) G.history.splice(0, G.history.length - 500);
  }
  function enter(d) {
    const i = G.selected;
    if (G.status !== 'playing' || i == null || isGiven(i) || d < 1 || d > n()) return;
    const b = 1 << d;
    if (G.noteMode) {
      if (G.values[i]) return;
      record([{ i, v: G.values[i], m: G.notes[i] }]);
      G.notes[i] ^= b;
    } else {
      // 같은 숫자를 다시 누르면 지운다. 숫자를 넣으면 이웃 칸 메모에서 그 숫자를 지운다.
      const next = G.values[i] === d ? 0 : d;
      const changes = [{ i, v: G.values[i], m: G.notes[i] }];
      if (next) for (const p of cfg.peers(n())[i]) if (G.notes[p] & b) { changes.push({ i: p, v: G.values[p], m: G.notes[p] }); G.notes[p] &= ~b; }
      record(changes);
      G.values[i] = next;
      G.notes[i] = 0;
    }
    if (!G.counted) { G.counted = true; stats.recordStart(cfg.kind); }
    checkWin();
    render(); save();
  }
  function erase() {
    const i = G.selected;
    if (G.status !== 'playing' || i == null || isGiven(i) || (!G.values[i] && !G.notes[i])) return;
    record([{ i, v: G.values[i], m: G.notes[i] }]);
    G.values[i] = 0; G.notes[i] = 0;
    render(); save();
  }
  function undo() {
    if (G.status !== 'playing' || !G.history.length || !undosLeft()) return;
    const last = G.history.pop();
    G.undosUsed++;
    for (const c of last.slice().reverse()) { G.values[c.i] = c.v; G.notes[c.i] = c.m; }
    G.selected = last[0].i;
    render(); save();
  }
  function toggleNote() { if (G.status === 'playing') { G.noteMode = !G.noteMode; render(); } }

  function checkWin() {
    if (!G.values.every((v, i) => v === G.puzzle.solution[i])) return;
    G.timer.pause();
    G.status = 'won';
    G.selected = null;
    store.set(saveKey, null);
    const seconds = Math.round(G.timer.seconds);
    G.isNewBest = stats.recordWin(cfg.kind, levelOf(G.puzzle).name, seconds);
    setTimeout(() => { if (G.status === 'won') showResult(); }, 400);
  }

  // ── 화면 ──
  function render() {
    q('[data-sub]').textContent = subtitle();
    q('[data-pause]').disabled = G.status !== 'playing';
    wrap.classList.toggle('empty', G.status === 'empty');
    if (guideEl) guideEl.hidden = !(cfg.showGuide?.(opts) && G.status !== 'empty');
    tick();
    renderControls();
    draw();
  }
  function tick() {
    const show = showTimer && G.status === 'playing';
    q('[data-timer]').hidden = !show;
    if (show) q('[data-time]').textContent = clock(Math.floor(G.timer.seconds));
  }
  setInterval(tick, 250);

  const tools = {
    undo: document.getElementById('undo'), erase: document.getElementById('erase'), note: document.getElementById('note'),
  };
  tools.undo.onclick = undo;
  tools.erase.onclick = erase;
  tools.note.onclick = toggleNote;
  let keyCount = 0;
  function renderControls() {
    const playing = G.status === 'playing', size = n();
    tools.undo.disabled = !playing || !G.history.length || !undosLeft();
    tools.undo.querySelector('span').textContent = Nemo.undoLabel(undosLeft());
    tools.erase.disabled = !playing;
    tools.note.disabled = !playing;
    tools.note.setAttribute('aria-pressed', G.noteMode);
    tools.note.querySelector('span').textContent = t(G.noteMode ? '메모 켜짐' : '메모');
    if (keyCount !== size) {
      keyCount = size;
      keysEl.replaceChildren(...[...Array(size)].map((_, k) => {
        const b = document.createElement('button');
        b.innerHTML = `<b>${k + 1}</b><small></small>`;
        b.onclick = () => enter(k + 1);
        return b;
      }));
    }
    keysEl.classList.toggle('note', G.noteMode);
    [...keysEl.children].forEach((b, k) => {
      const d = k + 1, left = size - G.values.filter(v => v === d).length;
      b.disabled = !playing;
      b.classList.toggle('done', left <= 0 && !G.noteMode);
      b.querySelector('small').textContent = left > 0 ? left : '';
      b.setAttribute('aria-label', `${d}, ${t('남은 {0}개', Math.max(left, 0))}`);
    });
  }

  let side = 0;
  function draw() {
    const w = Math.min(wrap.clientWidth, wrap.clientHeight, cfg.maxWidth);
    if (w <= 0) return;
    side = Math.floor(w);
    const ctx = Nemo.fitCanvas(canvas, side, side);
    ctx.clearRect(0, 0, side, side);
    if (!G.puzzle && !cfg.drawEmpty) return;
    cfg.draw(ctx, side, G, opts, n());
    const pct = G.puzzle ? Math.round(cfg.progress(G) * 100) : 0;
    canvas.setAttribute('aria-label', `${K.title} · ${t('{0}% 채움', pct)}`);
  }
  new ResizeObserver(draw).observe(wrap);
  Nemo.onTheme(draw);

  // ── 판 입력: 탭으로 칸을 고르고, 키보드로 숫자를 넣는다 ──
  canvas.addEventListener('pointerdown', e => {
    if (G.status !== 'playing') return;
    const r = canvas.getBoundingClientRect();
    const i = cfg.hit(e.clientX - r.left, e.clientY - r.top, side, n());
    if (i == null) return;
    G.selected = G.selected === i ? null : i;
    render();
  });
  document.addEventListener('keydown', e => {
    if (G.status !== 'playing' || Nemo.isOpen() || e.target.closest?.('input, select')) return;
    const size = n();
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z') { e.preventDefault(); undo(); return; }
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    const move = { ArrowLeft: [0, -1], ArrowRight: [0, 1], ArrowUp: [-1, 0], ArrowDown: [1, 0] }[e.key];
    if (move) {
      e.preventDefault();
      const cur = G.selected ?? 0;
      const r = Math.min(size - 1, Math.max(0, Math.floor(cur / size) + move[0]));
      const c = Math.min(size - 1, Math.max(0, (cur % size) + move[1]));
      G.selected = G.selected == null ? 0 : r * size + c;
      render();
    } else if (/^[1-9]$/.test(e.key)) enter(+e.key);
    else if (e.key === 'Backspace' || e.key === 'Delete' || e.key === '0') { e.preventDefault(); erase(); }
    else if (e.key === 'n' || e.key === 'N') toggleNote();
    else if (e.key === 'Escape') { G.selected = null; render(); }
  });

  // ── 겹쳐 보이는 창 ──
  const time = () => (showTimer ? clock(Math.round(G.timer.seconds)) : null);
  function showLevels() {
    G.timer.pause();
    const lastLevel = store.get(cfg.kind + '.lastLevel', 2);
    const best = stats.load(cfg.kind).bestByDifficulty;
    Nemo.levelPicker({
      items: cfg.levels.map(l => ({ id: l.id, name: t(l.name), detail: cfg.detail(l), best: best[l.name] })),
      current: lastLevel, canCancel: G.status !== 'empty',
      onPick: id => newPuzzle(id),
      onCancel: () => { if (G.status === 'empty') location.href = './'; else G.timer.start(); },
    });
  }
  function newPuzzle(id) {
    store.set(cfg.kind + '.lastLevel', id);
    G.timer.pause();
    const level = cfg.levels.find(l => l.id === id);
    Nemo.working(t('{0} 퍼즐을 만들고 있어요', t(level.name)));
    // 창이 먼저 그려지도록 한 프레임 뒤에 만든다.
    setTimeout(() => {
      const puzzle = cfg.generate(id);
      store.set(saveKey, null);
      Nemo.close();
      start(puzzle);
      save();
    }, 40);
  }
  function pause() {
    if (G.status !== 'playing' || Nemo.isOpen()) return;
    G.timer.pause();
    save();
    Nemo.pauseCover({ subtitle: subtitle(), time: time(), onResume: () => G.timer.start() });
  }
  function showResult() {
    Nemo.result({
      title: t('{0} 완성', K.title), subtitle: subtitle(), time: time(), isNewBest: G.isNewBest,
      onClose: () => {}, onOther: showLevels, onAgain: () => newPuzzle(levelOf(G.puzzle).id),
    });
  }
  function askRestart() {
    G.timer.pause();
    Nemo.confirmBox({
      title: t('처음부터 다시 풀까요?'), message: t('같은 문제를 처음 상태로 되돌려요.'), ok: t('다시 풀기'),
      onOk: () => { start(G.puzzle); save(); }, onCancel: () => G.timer.start(),
    });
  }

  q('[data-pause]').onclick = pause;
  q('[data-back]').addEventListener('click', save);
  Nemo.menu(q('[data-more]'), q('[data-menu]'), () => [
    { section: t('새 퍼즐') },
    ...cfg.levels.map(l => ({ label: cfg.menuLabel(l), onClick: () => newPuzzle(l.id) })),
    { sep: true },
    { label: t('처음부터 다시'), icon: 'restart', disabled: G.status !== 'playing', onClick: askRestart },
    { section: t('표시') },
    ...cfg.options.map(o => ({ label: t(o.label), checked: opts[o.key], onChange: v => { opts[o.key] = v; store.set(`${cfg.kind}.${o.key}`, v); render(); } })),
  ]);

  // 다른 탭이나 앱으로 가면 저장하고 일시정지 화면을 띄운다.
  document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });
  window.addEventListener('pagehide', save);

  document.title = `${K.title} · ${t('네모 안에 네모')}`;
  tools.erase.querySelector('span').textContent = t('지우기');
  tools.undo.setAttribute('aria-label', t('되돌리기'));
  tools.erase.setAttribute('aria-label', t('지우기'));
  if (guideEl && cfg.guideText) guideEl.innerHTML = cfg.guideText();

  if (!restore(store.get(saveKey, null))) { render(); showLevels(); }
};

// 빈칸 중 채운 비율. 메인 화면 카드에서도 쓴다.
window.NumberPuzzle.progress = s => {
  const empty = s.puzzle.givens.filter(v => !v).length;
  return empty ? s.values.filter((v, i) => !s.puzzle.givens[i] && v).length / empty : 0;
};
