// 짝네모 규칙과 문제 생성. 앱의 PairEngine.swift와 같은 규칙이다. 규칙을 바꾸면 양쪽을 함께 고친다.
// 같은 숫자 두 칸을 상하좌우로 잇는다. 숫자는 양 끝을 포함한 길의 칸 수다. 길은 서로 겹치거나 지나갈 수 없다.
// 같은 숫자가 여러 쌍이면 같은 숫자끼리 어느 것과 이어도 된다. 판정은 규칙으로 한다(저장된 답과 비교하지 않는다).
// fullCover 난이도는 벽을 뺀 모든 칸을 써야 하고, 답이 하나뿐인 판만 낸다.
(function (root) {
  const LEVELS = [
    { id: 1, name: '초급', size: 5, pairs: [3, 3], length: [3, 6], fullCover: false, walls: 0 },
    { id: 2, name: '중급', size: 6, pairs: [4, 5], length: [3, 8], fullCover: false, walls: 0 },
    { id: 3, name: '고급', size: 7, length: [3, 10], fullCover: true, walls: 2 },
    { id: 4, name: '전문가', size: 8, length: [3, 12], fullCover: true, walls: 3 },
  ];
  const rand = n => Math.floor(Math.random() * n);
  const between = ([a, b]) => a + rand(b - a + 1);
  const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = rand(i + 1); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const neighbors = (i, n) => {
    const r = Math.floor(i / n), c = i % n, out = [];
    if (r > 0) out.push(i - n);
    if (r < n - 1) out.push(i + n);
    if (c > 0) out.push(i - 1);
    if (c < n - 1) out.push(i + 1);
    return out;
  };
  const adjacent = (a, b, n) => (Math.abs(a - b) === n) || (Math.abs(a - b) === 1 && Math.floor(a / n) === Math.floor(b / n));

  // ── 판정: 그린 길들이 규칙을 지키고 모든 숫자를 이었는지 ──
  // puzzle: { size, clues: { [cell]: length }, walls: [cell], fullCover }, paths: [[cell, ...]] (양 끝이 숫자 칸)
  function check(puzzle, paths) {
    const n = puzzle.size, used = new Map(), walls = new Set(puzzle.walls);
    let complete = 0;
    for (const p of paths) {
      for (const c of p) { if (used.has(c) || walls.has(c)) return { solved: false, complete }; used.set(c, true); }
      for (let k = 1; k < p.length; k++) if (!adjacent(p[k - 1], p[k], n)) return { solved: false, complete };
      const a = puzzle.clues[p[0]], b = puzzle.clues[p[p.length - 1]];
      if (p.length >= 2 && a != null && a === b && a === p.length && p.slice(1, -1).every(c => puzzle.clues[c] == null)) complete++;
    }
    const clueCount = Object.keys(puzzle.clues).length;
    const allLinked = complete * 2 === clueCount && complete === paths.length;
    const covered = !puzzle.fullCover || used.size === n * n - puzzle.walls.length;
    return { solved: allLinked && covered, complete, covered: used.size };
  }

  // ── 풀이기: 모든 칸 사용 판의 답을 limit까지 센다 ──
  function countSolutions(puzzle, limit = 2) {
    const n = puzzle.size, N = n * n;
    // grid: -2 벽, -1 빈칸, 0 이상 길 번호
    const grid = new Int16Array(N).fill(-1);
    for (const w of puzzle.walls) grid[w] = -2;
    const clue = new Int16Array(N).fill(0);
    const ends = [];
    for (const k in puzzle.clues) { clue[+k] = puzzle.clues[k]; ends.push(+k); }
    const matched = new Uint8Array(N);
    const nb = [...Array(N)].map((_, i) => neighbors(i, n));
    const dist = (a, b) => Math.abs(Math.floor(a / n) - Math.floor(b / n)) + Math.abs((a % n) - (b % n));
    let count = 0, id = 0;

    // 빈칸 덩어리마다: 숫자 칸이 있어야 하고, 같은 숫자가 짝수 개이며, 그 숫자들로 덩어리를 정확히 채울 수 있어야 한다.
    const seen = new Int32Array(N);
    let stamp = 0;
    function feasible() {
      stamp++;
      for (let s = 0; s < N; s++) {
        if (seen[s] === stamp || grid[s] !== -1 || (clue[s] && matched[s])) continue;
        let size = 0;
        const counts = new Map();
        const stack = [s];
        seen[s] = stamp;
        while (stack.length) {
          const i = stack.pop();
          size++;
          if (clue[i]) counts.set(clue[i], (counts.get(clue[i]) || 0) + 1);
          for (const j of nb[i]) if (seen[j] !== stamp && grid[j] === -1 && !(clue[j] && matched[j])) { seen[j] = stamp; stack.push(j); }
        }
        let need = 0;
        for (const [L, c] of counts) { if (c % 2) return false; need += (c / 2) * L; }
        if (need !== size) return false;
      }
      return true;
    }

    function pick() {
      // 갈 수 있는 이웃이 가장 적은 숫자 칸부터
      let best = -1, bestScore = Infinity;
      for (const e of ends) {
        if (matched[e]) continue;
        let free = 0;
        for (const j of nb[e]) if (grid[j] === -1 && (!clue[j] || (!matched[j] && clue[j] === clue[e]))) free++;
        const score = free * 100 + clue[e];
        if (score < bestScore) { best = e; bestScore = score; }
      }
      return best;
    }

    function solve() {
      if (count >= limit) return;
      const a = pick();
      if (a < 0) { count++; return; }
      const L = clue[a];
      const targets = ends.filter(b => b !== a && !matched[b] && clue[b] === L);
      if (!targets.length) return;
      const myId = id++;
      matched[a] = 1;
      grid[a] = myId;
      const walk = (cur, len) => {
        if (count >= limit) return;
        const left = L - len;
        for (const j of nb[cur]) {
          if (left === 1) {
            if (clue[j] === L && !matched[j] && grid[j] === -1) {
              matched[j] = 1; grid[j] = myId;
              if (feasible()) solve();
              matched[j] = 0; grid[j] = -1;
            }
            continue;
          }
          if (grid[j] !== -1 || clue[j]) continue;
          // 남은 걸음으로 갈 수 있는 짝이 있어야 한다(거리와 홀짝).
          if (!targets.some(b => !matched[b] && dist(j, b) <= left - 1 && (left - 1 - dist(j, b)) % 2 === 0)) continue;
          grid[j] = myId;
          walk(j, len + 1);
          grid[j] = -1;
          if (count >= limit) return;
        }
      };
      walk(a, 1);
      matched[a] = 0;
      grid[a] = -1;
    }
    if (feasible()) solve();
    return count;
  }

  // ── 생성 ──
  // 모든 칸 사용: 빈칸을 무작위로 골라 양 끝으로 길을 늘려 판을 길들로 나누고, 짧게 남은 길은 옆 길 끝에 붙인다.
  function partition(n, walls, [minL, maxL]) {
    const N = n * n, owner = new Int16Array(N).fill(-1);
    for (const w of walls) owner[w] = -2;
    const paths = [];
    for (const s of shuffle([...Array(N).keys()])) {
      if (owner[s] !== -1) continue;
      const id = paths.length, path = [s];
      owner[s] = id;
      const target = between([minL, maxL]);
      while (path.length < target) {
        const ends = rand(2) ? [path.length - 1, 0] : [0, path.length - 1];
        let grown = false;
        for (const e of ends) {
          const opts = neighbors(path[e], n).filter(j => owner[j] === -1);
          if (!opts.length) continue;
          const j = opts[rand(opts.length)];
          owner[j] = id;
          if (e === 0) path.unshift(j); else path.push(j);
          grown = true;
          break;
        }
        if (!grown) break;
      }
      paths.push(path);
    }
    // 짧은 길은 끝이 맞닿은 다른 길과 잇는다.
    let changed = true;
    while (changed) {
      changed = false;
      for (let k = 0; k < paths.length; k++) {
        const p = paths[k];
        if (!p || p.length >= minL) continue;
        let joined = false;
        for (const [pe, pIsHead] of [[p[0], true], [p[p.length - 1], false]]) {
          for (let q = 0; q < paths.length && !joined; q++) {
            const o = paths[q];
            if (q === k || !o || o.length + p.length > maxL) continue;
            const pp = pIsHead ? p.slice().reverse() : p.slice(); // pe가 끝으로 오게
            if (adjacent(pe, o[0], n)) { paths[q] = pp.concat(o); joined = true; }
            else if (adjacent(pe, o[o.length - 1], n)) { paths[q] = o.concat(pp.slice().reverse()); joined = true; }
          }
          if (joined) break;
        }
        if (joined) { paths[k] = null; changed = true; }
      }
    }
    const out = paths.filter(Boolean);
    return out.every(p => p.length >= minL && p.length <= maxL) ? out : null;
  }

  // 빈칸 허용: 서로 겹치지 않는 길 몇 개를 무작위로 놓는다.
  function scatter(n, count, [minL, maxL]) {
    for (let attempt = 0; attempt < 200; attempt++) {
      const owner = new Int16Array(n * n).fill(-1), paths = [];
      for (let k = 0; k < count; k++) {
        let placed = null;
        for (let t = 0; t < 60 && !placed; t++) {
          const L = between([minL, maxL]), s = rand(n * n);
          if (owner[s] !== -1) continue;
          const path = [s], used = new Set([s]);
          while (path.length < L) {
            const opts = neighbors(path[path.length - 1], n).filter(j => owner[j] === -1 && !used.has(j));
            if (!opts.length) break;
            const j = opts[rand(opts.length)];
            path.push(j); used.add(j);
          }
          // 양 끝이 바로 붙어 있으면 한 걸음에 이어져 너무 쉬우니 피한다.
          if (path.length === L && !adjacent(path[0], path[L - 1], n)) placed = path;
        }
        if (!placed) break;
        placed.forEach(c => { owner[c] = k; });
        paths.push(placed);
      }
      if (paths.length === count) return paths;
    }
    return null;
  }

  function generate(levelId) {
    const L = LEVELS[levelId - 1], n = L.size;
    const deadline = Date.now() + 4000;
    for (let attempt = 0; ; attempt++) {
      if (!L.fullCover) {
        const paths = scatter(n, between(L.pairs), L.length);
        if (!paths) continue;
        return build(L, n, paths, []);
      }
      const walls = shuffle([...Array(n * n).keys()]).slice(0, L.walls);
      const paths = partition(n, walls, L.length);
      if (!paths) continue;
      const puzzle = build(L, n, paths, walls);
      if (countSolutions(puzzle, 2) === 1) return puzzle;
      if (Date.now() > deadline && attempt > 50) throw new Error('pair: could not generate');
    }
  }
  function build(L, n, paths, walls) {
    const clues = {};
    for (const p of paths) { clues[p[0]] = p.length; clues[p[p.length - 1]] = p.length; }
    return { size: n, clues, walls: walls.slice().sort((a, b) => a - b), fullCover: L.fullCover, solution: paths, level: L.id };
  }

  root.PairEngine = { LEVELS, neighbors, adjacent, check, countSolutions, generate, partition };
})(typeof self !== 'undefined' ? self : globalThis);
