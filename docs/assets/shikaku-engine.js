// 시카쿠 규칙과 퍼즐 생성. 앱의 ShikakuEngine.swift를 그대로 옮겼다. 규칙을 바꾸면 양쪽을 함께 고친다.
// 직사각형은 { row, col, height, width }, 단서는 { index, area }.
(function (root) {
  const LEVELS = [
    { id: 1, name: '초급', size: 5, maxArea: 6, picks: 4 },
    { id: 2, name: '중급', size: 7, maxArea: 9, picks: 10 },
    { id: 3, name: '고급', size: 10, maxArea: 12, picks: 16 },
    { id: 4, name: '전문가', size: 12, maxArea: 16, picks: 16 },
    { id: 5, name: '커스텀', size: 12, maxArea: 16, picks: 16 },
  ];
  const CUSTOM_SIZES = [5, 15];
  const REGION_SIZES = [
    { id: 0, name: '작게', maxArea: n => Math.max(4, Math.round(n * 0.8)) },
    { id: 1, name: '보통', maxArea: n => Math.max(6, Math.round(n * 1.3)) },
    { id: 2, name: '크게', maxArea: n => Math.max(8, Math.round(n * 1.6)) },
  ];

  const R = {
    area: r => r.height * r.width,
    contains: (r, row, col) => row >= r.row && row < r.row + r.height && col >= r.col && col < r.col + r.width,
    containsIndex: (r, i, n) => R.contains(r, Math.floor(i / n), i % n),
    cells(r, n) {
      const out = [];
      for (let y = r.row; y < r.row + r.height; y++) for (let x = r.col; x < r.col + r.width; x++) out.push(y * n + x);
      return out;
    },
    intersects: (a, o) => a.row < o.row + o.height && o.row < a.row + a.height && a.col < o.col + o.width && o.col < a.col + a.width,
    touches(a, o) {
      const rowsOverlap = a.row < o.row + o.height && o.row < a.row + a.height;
      const colsOverlap = a.col < o.col + o.width && o.col < a.col + a.width;
      return (rowsOverlap && (a.col + a.width === o.col || o.col + o.width === a.col))
        || (colsOverlap && (a.row + a.height === o.row || o.row + o.height === a.row));
    },
    equal: (a, b) => a.row === b.row && a.col === b.col && a.height === b.height && a.width === b.width,
    spanning(a, b, n) {
      const r0 = Math.min(Math.floor(a / n), Math.floor(b / n)), r1 = Math.max(Math.floor(a / n), Math.floor(b / n));
      const c0 = Math.min(a % n, b % n), c1 = Math.max(a % n, b % n);
      return { row: r0, col: c0, height: r1 - r0 + 1, width: c1 - c0 + 1 };
    },
  };
  const pick = a => a[Math.floor(Math.random() * a.length)];

  // 숫자마다 놓을 수 있는 직사각형: 그 숫자를 포함하고, 넓이가 같고, 다른 숫자는 포함하지 않는다.
  function candidates(n, clues) {
    const clueAt = new Array(n * n).fill(-1);
    clues.forEach((c, k) => { clueAt[c.index] = k; });
    return clues.map((clue, k) => {
      const r = Math.floor(clue.index / n), c = clue.index % n, out = [];
      for (let h = 1; h <= clue.area; h++) {
        if (clue.area % h) continue;
        const w = clue.area / h;
        if (h > n || w > n) continue;
        for (let top = Math.max(0, r - h + 1); top <= Math.min(r, n - h); top++) {
          for (let left = Math.max(0, c - w + 1); left <= Math.min(c, n - w); left++) {
            const rect = { row: top, col: left, height: h, width: w };
            if (R.cells(rect, n).every(i => clueAt[i] === -1 || clueAt[i] === k)) out.push(rect);
          }
        }
      }
      return out;
    });
  }

  function countSolutions(n, clues, limit = 2) {
    if (clues.reduce((a, c) => a + c.area, 0) !== n * n) return 0;
    const cands = candidates(n, clues);
    const covered = new Array(n * n).fill(false), done = new Array(clues.length).fill(false);
    let count = 0;
    const fits = rect => R.cells(rect, n).every(i => !covered[i]);
    function search(left) {
      if (count >= limit) return;
      if (left === 0) { count++; return; }
      let best = -1, bestList = [];
      for (let k = 0; k < clues.length; k++) {
        if (done[k]) continue;
        const list = cands[k].filter(fits);
        if (!list.length) return;
        if (best < 0 || list.length < bestList.length) { best = k; bestList = list; if (list.length === 1) break; }
      }
      done[best] = true;
      for (const rect of bestList) {
        const cells = R.cells(rect, n);
        cells.forEach(i => { covered[i] = true; });
        search(left - 1);
        cells.forEach(i => { covered[i] = false; });
        if (count >= limit) break;
      }
      done[best] = false;
    }
    search(clues.length);
    return count;
  }

  // 추측 없이 규칙만으로 풀어 본다. effort가 클수록 한 번에 보이지 않는 추론이 많이 필요하다.
  function solve(n, clues) {
    let effort = 0;
    let cands = candidates(n, clues);
    const forcedAtStart = cands.filter(c => c.length === 1).length;
    const owner = new Array(n * n).fill(-1);
    const placed = new Array(clues.length).fill(null);
    const stuck = () => clues.map((_, k) => k).filter(k => !placed[k]);
    const fail = () => ({ rects: null, effort, forcedAtStart, stuck: stuck() });
    const place = (k, rect) => { placed[k] = rect; cands[k] = [rect]; R.cells(rect, n).forEach(i => { owner[i] = k; }); };

    while (placed.some(p => !p)) {
      let progress = false;

      // 1. 이미 덮인 칸과 겹치는 후보를 지우고, 하나 남으면 확정.
      for (let k = 0; k < clues.length; k++) {
        if (placed[k]) continue;
        cands[k] = cands[k].filter(rect => !R.cells(rect, n).some(i => owner[i] !== -1));
        if (!cands[k].length) return fail();
        if (cands[k].length === 1) { place(k, cands[k][0]); progress = true; }
      }
      if (progress) continue;
      effort += 1;

      // 2. 어떤 칸을 덮을 수 있는 숫자가 하나뿐이면, 그 숫자의 후보는 그 칸을 덮는 것만 남긴다.
      for (let i = 0; i < n * n; i++) {
        if (owner[i] !== -1) continue;
        const who = [];
        for (let k = 0; k < clues.length; k++) {
          if (!placed[k] && cands[k].some(r => R.containsIndex(r, i, n))) who.push(k);
        }
        if (!who.length) return fail();
        if (who.length === 1) {
          const k = who[0], before = cands[k].length;
          cands[k] = cands[k].filter(r => R.containsIndex(r, i, n));
          if (cands[k].length < before) progress = true;
        }
      }
      if (progress) continue;
      effort += 2;

      // 3. 한 숫자의 모든 후보가 함께 덮는 칸은 그 숫자 몫이다. 다른 숫자의 후보에서 그 칸을 뺀다.
      for (let k = 0; k < clues.length; k++) {
        if (placed[k]) continue;
        let common = new Set(R.cells(cands[k][0], n));
        for (const rect of cands[k].slice(1)) { const cs = new Set(R.cells(rect, n)); common = new Set([...common].filter(i => cs.has(i))); }
        for (let j = 0; j < clues.length; j++) {
          if (j === k || placed[j]) continue;
          const before = cands[j].length;
          cands[j] = cands[j].filter(rect => !R.cells(rect, n).some(i => common.has(i)));
          if (!cands[j].length) return fail();
          if (cands[j].length < before) progress = true;
        }
      }
      if (!progress) return fail();
    }
    return { rects: placed, effort, forcedAtStart, stuck: [] };
  }

  // 판을 직사각형들로 나눈다. 1칸짜리는 다른 방법이 없을 때만 쓴다.
  function partition(n, maxArea) {
    const owner = new Array(n * n).fill(false), rects = [];
    for (let start = 0; start < n * n; start++) {
      if (owner[start]) continue;
      const r = Math.floor(start / n), c = start % n, options = [];
      let maxW = n - c;
      for (let h = 1; h <= n - r; h++) {
        let w = 0;
        while (w < maxW && !owner[(r + h - 1) * n + c + w]) w++;
        maxW = w;
        if (maxW === 0) break;
        for (let width = 1; width <= maxW; width++) if (h * width <= maxArea) options.push({ row: r, col: c, height: h, width });
      }
      const bigger = options.filter(o => R.area(o) >= 2);
      const pool = bigger.length ? bigger : options;
      // 너무 길쭉한 영역은 덜 나오게 한다.
      const weights = pool.map(o => Math.min(o.height, o.width) / Math.max(o.height, o.width));
      let x = Math.random() * weights.reduce((a, b) => a + b, 0);
      let chosen = pool[pool.length - 1];
      for (let k = 0; k < pool.length; k++) { if (x < weights[k]) { chosen = pool[k]; break; } x -= weights[k]; }
      R.cells(chosen, n).forEach(i => { owner[i] = true; });
      rects.push(chosen);
    }
    return rects;
  }

  function generateOne(level, n, maxArea) {
    for (;;) {
      const rects = partition(n, maxArea);
      const clues = rects.map(rect => ({ index: pick(R.cells(rect, n)), area: R.area(rect) }));
      // 논리 풀이가 막히면, 아직 못 정한 영역 하나의 숫자 위치만 옮겨 다시 풀어 본다.
      for (let t = 0; t < rects.length * 4; t++) {
        const result = solve(n, clues);
        if (result.rects) return { size: n, clues, solution: rects, level };
        if (!result.stuck.length) break;
        const k = pick(result.stuck);
        clues[k].index = pick(R.cells(rects[k], n));
      }
    }
  }

  // 정답이 하나뿐이고 추측 없이 풀리는 퍼즐을 여러 개 만들어, 더 생각해야 하는 것을 고른다.
  function generate(level, size, maxArea) {
    const spec = LEVELS[level - 1];
    const n = size || spec.size, area = maxArea || spec.maxArea;
    let best = null;
    const deadline = Date.now() + 1500;
    for (let k = 0; k < spec.picks; k++) {
      if (best && Date.now() > deadline) break;
      const puzzle = generateOne(level, n, area);
      const result = solve(n, puzzle.clues);
      const score = result.effort * 10 - result.forcedAtStart;
      if (!best || score > best.score) best = { puzzle, score };
    }
    return best.puzzle;
  }

  root.ShikakuEngine = { LEVELS, CUSTOM_SIZES, REGION_SIZES, Rect: R, candidates, countSolutions, solve, partition, generate };
})(typeof self !== 'undefined' ? self : globalThis);
