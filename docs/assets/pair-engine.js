// 짝네모 규칙과 문제 생성. 앱의 PairEngine.swift와 같은 규칙이다. 규칙을 바꾸면 양쪽을 함께 고친다.
// 같은 숫자 두 칸을 상하좌우로 잇는다. 숫자는 양 끝을 포함한 길의 칸 수다. 길은 서로 겹치거나 지나갈 수 없다.
// 같은 숫자가 여러 쌍이면 같은 숫자끼리 어느 것과 이어도 된다. 판정은 규칙으로 한다(저장된 답과 비교하지 않는다).
// fullCover 난이도는 벽을 뺀 모든 칸을 써야 하고, 답이 하나뿐인 판만 낸다.
(function (root) {
  const LEVELS = [
    { id: 1, name: '초급', size: 6, pairs: [4, 5], length: [3, 8], fullCover: false, walls: 0 },
    // pick: 사람처럼 푸는 풀이기(grade)로 재서 어떤 판을 낼지.
    //  gentle  넓은 추리 1번 이하, 구역 계산·가정 없이 풀림(모든 칸 채우기를 익히는 판)
    //  tricky  넓은 추리 3번 이상이나 구역 계산이 필요하고, 가정 없이 풀림
    //  hardest SEARCH_MS 동안 만들어 보고 가장 어려운 판(가정이 많고, 처음에 바로 정해지는 쌍이 적은 판)
    { id: 2, name: '중급', size: 7, length: [3, 10], fullCover: true, walls: 1, pick: 'gentle' },
    { id: 3, name: '고급', size: 8, length: [4, 12], fullCover: true, walls: 1, pick: 'tricky' },
    { id: 4, name: '전문가', size: 10, length: [6, 14], fullCover: true, walls: 0, pick: 'hardest' },
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
  // budget: 길을 한 칸 늘리는 걸음 수의 상한. 넘으면 끝까지 세지 못한 것이므로 limit을 돌려준다(답이 여럿인 것처럼 다룬다).
  function countSolutions(puzzle, limit = 2, budget = Infinity) {
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
    let count = 0, id = 0, steps = 0;
    const spend = () => { if (++steps > budget) count = limit; };

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
          spend();
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

  // ── 난이도: 사람처럼 푸는 풀이기 ──
  // 숫자 쌍마다 가능한 길을 모두 늘어놓고(ROUTE_CAP개가 넘으면 '넓음'으로 두고 나중에 다시 센다), 사람이 쓰는 추리로 지워 나간다.
  //  쉬운 추리   갈 수 있는 길이 하나뿐인 숫자는 그 길로 정한다.
  //  넓은 추리   ① 한 숫자의 모든 길이 지나는 칸은 그 숫자 몫이라 다른 길은 못 지난다.
  //              ② 어떤 빈칸을 지날 수 있는 길이 모두 한 숫자의 길이면, 그 숫자는 이 칸을 지나는 길만 남는다.
  //  구역 계산   이 길로 정하면 갇히는 빈 구역을 안의 숫자로 정확히 채울 수 없게 되는 길은 지운다.
  //  한 단계 가정 길이 적은 숫자부터 한 길로 정해 보고, 위 추리만으로 모순이 나면 그 길을 지운다.
  // 쉬운 추리부터 쓰고, 막힐 때만 다음 추리를 한 번 써서 그 횟수를 센다.
  // 돌려주는 값: res('solved' | 'stuck'), entry(처음에 바로 정해진 쌍 수), wide, region, look(각 추리를 쓴 횟수).
  // 추리는 모두 불가능한 길만 지우므로 'solved'면 답이 하나뿐이다.
  const ROUTE_CAP = 20000, REGION_MAX = 200, LOOK_MAX = 12;
  function grade(puzzle) {
    const n = puzzle.size, N = n * n;
    const clue = new Int16Array(N);
    for (const k in puzzle.clues) clue[+k] = puzzle.clues[k];
    const ends = Object.keys(puzzle.clues).map(Number);
    const nb = [...Array(N)].map((_, i) => neighbors(i, n));
    const dist = (x, y) => Math.abs(Math.floor(x / n) - Math.floor(y / n)) + Math.abs((x % n) - (y % n));
    // routes: 모든 상태가 함께 쓰는 길 목록(덧붙이기만 한다). 상태 S는 살아 있는 길 번호(alive)와 막힌 칸, 이은 숫자를 가진다.
    const routes = [];
    const stats = { entry: 0, wide: 0, region: 0, look: 0 };

    function enumerate(S, a, b, L) {
      const out = [], path = [], used = new Uint8Array(N);
      let over = false;
      const walk = (cur, len) => {
        const left = L - len;
        for (const j of nb[cur]) {
          if (over) return;
          if (left === 1) { if (j === b && out.push(path.slice()) > ROUTE_CAP) over = true; continue; }
          if (used[j] || S.blocked[j] || clue[j]) continue;
          const d = dist(j, b);
          if (d > left - 1 || (left - 1 - d) % 2) continue;
          used[j] = 1; path.push(j);
          walk(j, len + 1);
          path.pop(); used[j] = 0;
        }
      };
      walk(a, 1);
      return over ? null : out;
    }
    // 처음에는 모든 쌍을, 그다음부터는 '넓음'으로 둔 쌍만 다시 늘어놓는다.
    function list(S, pairs) {
      S.wide = [];
      for (const [a, b] of pairs) {
        if (S.matched[a] || S.matched[b]) continue;
        const rs = enumerate(S, a, b, clue[a]);
        if (rs) for (const cells of rs) { routes.push({ a, b, cells }); S.alive.push(routes.length - 1); }
        else S.wide.push({ a, b, L: clue[a] });
      }
    }
    const isWide = (S, e) => S.wide.some(w => w.a === e || w.b === e);
    const routesOf = (S, e) => S.alive.filter(k => routes[k].a === e || routes[k].b === e);
    // 길 k로 정한다: 그 칸을 막고, 같은 숫자 칸을 쓰거나 그 칸을 지나는 다른 길을 지운다.
    function fix(S, k) {
      const r = routes[k];
      for (const c of r.cells) S.blocked[c] = 1;
      S.matched[r.a] = 1; S.matched[r.b] = 1;
      S.alive = S.alive.filter(q => { const o = routes[q]; return !(S.matched[o.a] || S.matched[o.b] || o.cells.some(c => S.blocked[c])); });
      list(S, S.wide.map(w => [w.a, w.b]));
    }
    const clone = S => ({ blocked: S.blocked.slice(), matched: S.matched.slice(), alive: S.alive.slice(), wide: S.wide.slice() });

    // 빈 구역마다 안의 같은 숫자가 짝수 개이고, 그 숫자들의 길이로 구역을 정확히 채울 수 있어야 한다.
    // r가 있으면 그 길로 정했다고 치고 본다.
    const seen = new Int32Array(N);
    let stamp = 0;
    function regionsOk(S, r) {
      stamp++;
      const on = r ? new Set(r.cells) : null;
      const free = i => !S.blocked[i] && !(on && on.has(i)) && !(clue[i] && (S.matched[i] || (r && (i === r.a || i === r.b))));
      for (let s = 0; s < N; s++) {
        if (seen[s] === stamp || !free(s)) continue;
        let size = 0;
        const counts = new Map(), stack = [s];
        seen[s] = stamp;
        while (stack.length) {
          const i = stack.pop();
          size++;
          if (clue[i]) counts.set(clue[i], (counts.get(clue[i]) || 0) + 1);
          for (const j of nb[i]) if (seen[j] !== stamp && free(j)) { seen[j] = stamp; stack.push(j); }
        }
        let need = 0;
        for (const [L, c] of counts) { if (c % 2) return false; need += (c / 2) * L; }
        if (need !== size) return false;
      }
      return true;
    }

    // level: 0 쉬운 추리만, 1 +넓은 추리, 2 +구역 계산, 3 +한 단계 가정. top이면 횟수를 센다.
    function propagate(S, level, top) {
      let first = true;
      for (;;) {
        let fixed = false;
        for (const e of ends) {
          if (S.matched[e] || isWide(S, e)) continue;
          const mine = routesOf(S, e);
          if (!mine.length) return 'contra';
          if (mine.length > 1) continue;
          fix(S, mine[0]);
          fixed = true;
          if (top && first) stats.entry++;
        }
        first = false;
        if (fixed) { if (!regionsOk(S)) return 'contra'; continue; }
        if (ends.every(e => S.matched[e])) {
          for (let i = 0; i < N; i++) if (!S.blocked[i] && !clue[i]) return 'contra';
          return 'solved';
        }
        if (level < 1) return 'stuck';

        // 넓은 추리 ①②
        const kill = new Set();
        for (const e of ends) {
          if (S.matched[e] || isWide(S, e)) continue;
          const mine = routesOf(S, e);
          let common = new Set(routes[mine[0]].cells);
          for (const k of mine) { const cs = new Set(routes[k].cells); common = new Set([...common].filter(c => cs.has(c))); }
          if (!common.size) continue;
          for (const k of S.alive) {
            const r = routes[k];
            if (r.a !== e && r.b !== e && r.cells.some(c => common.has(c))) kill.add(k);
          }
        }
        const cover = [...Array(N)].map(() => []);
        for (const k of S.alive) if (!kill.has(k)) for (const c of routes[k].cells) cover[c].push(k);
        for (let c = 0; c < N; c++) {
          if (S.blocked[c] || clue[c]) continue;
          let shared = null;
          for (const k of cover[c]) { const r = routes[k]; shared = shared ? shared.filter(x => x === r.a || x === r.b) : [r.a, r.b]; }
          for (const w of S.wide) {
            const d = dist(w.a, c) + dist(c, w.b);
            if (d <= w.L - 1 && (w.L - 1 - d) % 2 === 0) shared = shared ? shared.filter(x => x === w.a || x === w.b) : [w.a, w.b];
          }
          if (!shared) return 'contra';
          for (const e of shared) {
            if (isWide(S, e)) continue;
            for (const k of S.alive) { const r = routes[k]; if ((r.a === e || r.b === e) && !r.cells.includes(c)) kill.add(k); }
          }
        }
        if (kill.size) { S.alive = S.alive.filter(k => !kill.has(k)); if (top) stats.wide++; continue; }
        if (level < 2) return 'stuck';

        // 구역 계산
        for (const e of ends) {
          if (S.matched[e] || isWide(S, e)) continue;
          const mine = routesOf(S, e);
          if (mine.length > REGION_MAX) continue;
          for (const k of mine) if (!regionsOk(S, routes[k])) kill.add(k);
        }
        if (kill.size) { S.alive = S.alive.filter(k => !kill.has(k)); if (top) stats.region++; continue; }
        if (level < 3) return 'stuck';

        // 한 단계 가정: 길이 적은 숫자부터 한 길로 정해 보고, 모순이면 그 길을 지운다. 한 숫자에서 지우면 처음으로 돌아간다.
        const cand = ends.filter(e => !S.matched[e] && !isWide(S, e)).map(e => ({ e, mine: routesOf(S, e) }))
          .filter(x => x.mine.length <= LOOK_MAX).sort((x, y) => x.mine.length - y.mine.length || x.e - y.e);
        let found = false;
        for (const { mine } of cand) {
          for (const k of mine) {
            if (!S.alive.includes(k)) continue;
            const T = clone(S);
            fix(T, k);
            if (!regionsOk(T) || propagate(T, 2, false) === 'contra') { S.alive = S.alive.filter(q => q !== k); found = true; }
          }
          if (found) break;
        }
        if (found) { if (top) stats.look++; continue; }
        return 'stuck';
      }
    }

    const S = { blocked: new Uint8Array(N), matched: new Uint8Array(N), alive: [], wide: [] };
    for (const w of puzzle.walls) S.blocked[w] = 1;
    const pairs = [];
    for (const a of ends) for (const b of ends) if (b > a && clue[a] === clue[b]) pairs.push([a, b]);
    list(S, pairs);
    const res = propagate(S, 3, true) === 'solved' ? 'solved' : 'stuck';
    return { res, ...stats };
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

  // 전문가에서 가장 어려운 판을 찾는 시간. 가정 3번 이상에 처음 바로 정해지는 쌍이 1개 이하인 판을 찾으면 바로 낸다.
  const SEARCH_MS = 2500;
  // 어려운 순서: 가정 횟수 > 구역 계산 > 넓은 추리, 처음에 바로 정해지는 쌍이 적을수록.
  // 풀이기가 끝까지 못 푼 판(답이 하나인 건 따로 확인함)은 가정을 두 단계 이상 해야 하니 가장 어렵게 친다.
  const hardness = r => (r.res === 'solved' ? r.look * 100 + r.region * 20 + r.wide : 1000) - r.entry * 5;
  function accept(pick, r) {
    if (r.res !== 'solved') return false;
    if (pick === 'gentle') return r.look === 0 && r.region === 0 && r.wide <= 1;
    if (pick === 'tricky') return r.look === 0 && (r.wide >= 3 || r.region >= 1);
    return false;
  }
  function generate(levelId) {
    const L = LEVELS[levelId - 1], n = L.size;
    const start = Date.now();
    let best = null, bestScore = -Infinity;
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
      // 답이 하나인지 빨리 확인되지 않는 판은 버린다(SOLVE_BUDGET).
      if (countSolutions(puzzle, 2, SOLVE_BUDGET) === 1) {
        const r = grade(puzzle);
        if (L.pick === 'hardest') {
          const h = hardness(r);
          if (h > bestScore) { best = puzzle; bestScore = h; }
          if (r.res === 'solved' && r.look >= 3 && r.entry <= 1) return puzzle;
        } else if (accept(L.pick, r)) return puzzle;
      }
      if (L.pick === 'hardest' && best && Date.now() > start + SEARCH_MS) return best;
      if (Date.now() > start + 15000 && attempt > 50) throw new Error('pair: could not generate');
    }
  }
  const SOLVE_BUDGET = 20000;
  function build(L, n, paths, walls) {
    const clues = {};
    for (const p of paths) { clues[p[0]] = p.length; clues[p[p.length - 1]] = p.length; }
    return { size: n, clues, walls: walls.slice().sort((a, b) => a - b), fullCover: L.fullCover, solution: paths, level: L.id };
  }

  root.PairEngine = { LEVELS, neighbors, adjacent, check, countSolutions, grade, generate, partition };
})(typeof self !== 'undefined' ? self : globalThis);
