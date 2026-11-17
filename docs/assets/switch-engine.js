// 스위치네모 규칙과 문제 생성. 앱의 SwitchEngine.swift를 그대로 옮겼다. 규칙을 바꾸면 양쪽을 함께 고친다.
// 판은 짝수 크기만 쓴다: 모든 판이 풀리고 누를 칸 조합이 하나뿐이라 추론으로 답을 찾을 수 있다.
(function (root) {
  const LEVELS = [
    { id: 1, name: '초급', size: 4, moves: [2, 4], showsMinimum: false },
    { id: 2, name: '중급', size: 4, moves: [4, 7], showsMinimum: false },
    { id: 3, name: '고급', size: 6, moves: [8, 14], showsMinimum: true },
    { id: 4, name: '전문가', size: 8, moves: [15, 25], showsMinimum: true },
    // 지옥: 최소 조작 수를 다 쓰고도 못 풀면 실패. 눌러 보고 되돌리는 시행착오를 막으려고 되돌리기도 없다.
    { id: 5, name: '지옥', size: 8, moves: [18, 28], showsMinimum: true, limitsMoves: true, noUndo: true },
  ];

  // (r, c)를 누르면 같은 가로줄과 세로줄의 모든 칸이 바뀐다. 누른 칸은 한 번만 바뀐다. state[i]가 true면 켜진 불.
  function press(state, i, n) {
    const r = Math.floor(i / n), c = i % n;
    for (let k = 0; k < n; k++) {
      state[r * n + k] = !state[r * n + k];
      if (k !== r) state[k * n + c] = !state[k * n + c];
    }
  }

  // 모든 불을 켜는 가장 적은 누름(오름차순). 풀 수 없으면 null.
  function solve(state, n) {
    const cells = n * n;
    const rows = [];
    for (let a = 0; a < cells; a++) {
      const row = new Uint8Array(cells + 1);
      for (let p = 0; p < cells; p++) if (Math.floor(p / n) === Math.floor(a / n) || p % n === a % n) row[p] = 1;
      row[cells] = state[a] ? 0 : 1;
      rows.push(row);
    }
    const pivotCols = [];
    let r = 0;
    for (let col = 0; col < cells; col++) {
      let pivot = -1;
      for (let k = r; k < cells; k++) if (rows[k][col]) { pivot = k; break; }
      if (pivot < 0) continue;
      [rows[r], rows[pivot]] = [rows[pivot], rows[r]];
      for (let k = 0; k < cells; k++) {
        if (k !== r && rows[k][col]) for (let j = col; j <= cells; j++) rows[k][j] ^= rows[r][j];
      }
      pivotCols.push(col);
      r++;
    }
    for (let k = r; k < cells; k++) if (rows[k][cells]) return null;
    const free = [];
    for (let col = 0; col < cells; col++) if (!pivotCols.includes(col)) free.push(col);
    let best = null, bestCount = Infinity;
    for (let mask = 0; mask < (1 << free.length); mask++) {
      const x = new Uint8Array(cells);
      free.forEach((f, k) => { x[f] = (mask >> k) & 1; });
      pivotCols.forEach((col, k) => {
        let v = rows[k][cells];
        for (const f of free) if (rows[k][f]) v ^= x[f];
        x[col] = v;
      });
      const count = x.reduce((a, b) => a + b, 0);
      if (count < bestCount) { best = x; bestCount = count; }
    }
    return [...best.keys()].filter(i => best[i]);
  }

  // 회전·뒤집기로 같아지는 판을 하나로 묶는 키
  function canonicalKey(state, n) {
    const m = n - 1;
    const maps = [(r, c) => [r, c], (r, c) => [c, m - r], (r, c) => [m - r, m - c], (r, c) => [m - c, r],
      (r, c) => [r, m - c], (r, c) => [m - r, c], (r, c) => [c, r], (r, c) => [m - c, m - r]];
    let best = null;
    for (const f of maps) {
      let s = '';
      for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) { const [rr, cc] = f(r, c); s += state[rr * n + cc] ? '1' : '0'; }
      if (best == null || s < best) best = s;
    }
    return best;
  }

  // 모든 불이 켜진 상태에서 무작위 칸들을 눌러 만든다. 짝수 판에서는 누른 칸이 곧 유일한 최소 답이다.
  // recent(키 배열)에 있는 판은 회전·뒤집기까지 포함해 다시 내지 않는다.
  function generate(levelId, recent = []) {
    const spec = LEVELS[levelId - 1], n = spec.size, avoid = new Set(recent);
    let fallback = null;
    for (let t = 0; t < 200; t++) {
      const k = spec.moves[0] + Math.floor(Math.random() * (spec.moves[1] - spec.moves[0] + 1));
      const cells = [...Array(n * n).keys()];
      for (let i = cells.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [cells[i], cells[j]] = [cells[j], cells[i]]; }
      const presses = cells.slice(0, k).sort((a, b) => a - b);
      const state = new Array(n * n).fill(true);
      for (const p of presses) press(state, p, n);
      const puzzle = { size: n, start: state, solution: presses, level: levelId };
      if (!avoid.has(canonicalKey(state, n))) return puzzle;
      fallback = fallback || puzzle;
    }
    return fallback;
  }

  root.SwitchEngine = { LEVELS, press, solve, canonicalKey, generate };
})(typeof self !== 'undefined' ? self : globalThis);
