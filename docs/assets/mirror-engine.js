// 거울네모 규칙과 문제 생성. 앱의 MirrorEngine.swift와 같은 규칙이다. 규칙을 바꾸면 양쪽을 함께 고친다.
// 판은 n×n. 빛은 테두리의 시작점에서 판 안으로 들어가 곧게 나아가고, 거울(0 '/', 1 '\')에서 90도 꺾인다.
// 모든 별을 지나 테두리의 목적지로 빠져나가면 성공. 다른 곳으로 나가거나 벽에 막히면 미완료.
// 테두리 자리(port)는 { side, k }: side 0 위, 1 오른쪽, 2 아래, 3 왼쪽, k는 그 변의 몇 번째 칸인지.
(function (root) {
  const LEVELS = [
    // effort: 이 범위의 판이 나올 때까지 후보를 만든다(아래 effort 참고). 그대로 두면 거의 모든 판이
    // 빛만 따라가도 풀려서, 중급은 조금 생각해야 하는 판, 고급은 꽤 헤매는 판을 고른다.
    // hardest: HARDEST_MS 동안 만들어 보고 가장 많이 헤매는 판을 낸다(HARDEST_ENOUGH 이상이면 바로 낸다).
    { id: 1, name: '초급', size: 5, mirrors: [2, 3], fixedOnPath: 0, decoyFixed: 0, walls: 0, stars: [1, 2] },
    { id: 2, name: '중급', size: 6, mirrors: [4, 5], fixedOnPath: 1, decoyFixed: 1, walls: 0, stars: [2, 3], effort: [3, 7] },
    { id: 3, name: '고급', size: 7, mirrors: [8, 9], fixedOnPath: 1, decoyFixed: 2, walls: 2, stars: [3, 4], effort: [6, Infinity] },
    { id: 4, name: '전문가', size: 8, mirrors: [11, 13], fixedOnPath: 2, decoyFixed: 2, walls: 3, stars: [3, 5], hardest: true },
  ];
  // 오른쪽, 아래, 왼쪽, 위
  const DIRS = [[0, 1], [1, 0], [0, -1], [-1, 0]];
  const reflect = (d, m) => {
    const [dr, dc] = DIRS[d];
    const [nr, nc] = m === 0 ? [-dc, -dr] : [dc, dr];
    return DIRS.findIndex(([a, b]) => a === nr && b === nc);
  };
  const rand = n => Math.floor(Math.random() * n);
  const between = ([a, b]) => a + rand(b - a + 1);
  const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = rand(i + 1); [a[i], a[j]] = [a[j], a[i]]; } return a; };

  // 테두리 자리 → 처음 들어가는 칸과 방향
  function entry(port, n) {
    const { side, k } = port;
    if (side === 0) return { r: 0, c: k, d: 1 };
    if (side === 1) return { r: k, c: n - 1, d: 2 };
    if (side === 2) return { r: n - 1, c: k, d: 3 };
    return { r: k, c: 0, d: 0 };
  }
  // 판 밖으로 나간 위치 → 테두리 자리
  function exitPort(r, c, n) {
    if (r < 0) return { side: 0, k: c };
    if (c >= n) return { side: 1, k: r };
    if (r >= n) return { side: 2, k: c };
    return { side: 3, k: r };
  }
  const samePort = (a, b) => a && b && a.side === b.side && a.k === b.k;

  // cells[i]: null 빈칸, { wall: true }, { mirror: 0|1, fixed: bool }. orient[i]는 회전 거울의 지금 방향.
  // 결과: 지나간 칸 순서(path), 나간 자리(exit) 또는 막힌 칸(blocked), 지난 별 수, 성공 여부.
  function trace(puzzle, orient) {
    const n = puzzle.size, cells = puzzle.cells;
    let { r, c, d } = entry(puzzle.start, n);
    const path = [], seen = new Set(), visited = new Set();
    for (;;) {
      if (r < 0 || c < 0 || r >= n || c >= n) {
        const exit = exitPort(r, c, n);
        const lit = puzzle.stars.filter(s => visited.has(s)).length;
        return { path, exit, blocked: null, lit, solved: samePort(exit, puzzle.goal) && lit === puzzle.stars.length };
      }
      const i = r * n + c, cell = cells[i];
      if (cell && cell.wall) return { path, exit: null, blocked: i, lit: puzzle.stars.filter(s => visited.has(s)).length, solved: false };
      const key = i * 4 + d;
      if (seen.has(key)) return { path, exit: null, blocked: null, loop: true, lit: 0, solved: false };
      seen.add(key);
      visited.add(i);
      path.push(i);
      if (cell && cell.mirror != null) d = reflect(d, cell.fixed ? cell.mirror : orient[i]);
      r += DIRS[d][0]; c += DIRS[d][1];
    }
  }

  // 회전 거울 방향을 모든 경우로 시뮬레이션해서 성공하는 경우를 limit까지 모은다.
  function solutions(puzzle, limit = 2) {
    const rot = puzzle.cells.map((c, i) => (c && c.mirror != null && !c.fixed ? i : -1)).filter(i => i >= 0);
    const out = [];
    const orient = {};
    for (let mask = 0; mask < (1 << rot.length); mask++) {
      rot.forEach((i, k) => { orient[i] = (mask >> k) & 1; });
      const t = trace(puzzle, orient);
      if (t.solved) { out.push({ orient: { ...orient }, path: t.path }); if (out.length >= limit) break; }
    }
    return out;
  }

  // ── 문제 고르기: '빛만 따라가는 사람'이 얼마나 헤매는지 ──
  // 빛을 따라가다 아직 정하지 않은 회전 거울을 만나면 두 방향 중 그럴듯한 쪽(별을 더 지나고, 더 멀리 가고,
  // 바로 판 밖으로 나가지 않는 쪽)을 먼저 골라 본다. 틀려서 되돌아간 횟수가 effort다. 0이면 빛만 따라가도 풀린다.
  function step(puzzle, decided) {
    const n = puzzle.size, cells = puzzle.cells;
    let { r, c, d } = entry(puzzle.start, n);
    const visited = new Set(), seen = new Set();
    let length = 0;
    for (;;) {
      if (r < 0 || c < 0 || r >= n || c >= n) {
        const exit = exitPort(r, c, n), lit = puzzle.stars.filter(s => visited.has(s)).length;
        return { done: true, solved: samePort(exit, puzzle.goal) && lit === puzzle.stars.length, lit, length };
      }
      const i = r * n + c, cell = cells[i];
      if (cell && cell.wall) return { done: true, solved: false, lit: 0, length };
      if (seen.has(i * 4 + d)) return { done: true, solved: false, lit: 0, length };
      seen.add(i * 4 + d);
      visited.add(i);
      length++;
      if (cell && cell.mirror != null) {
        if (!cell.fixed && decided[i] == null) return { done: false, pending: i, lit: puzzle.stars.filter(s => visited.has(s)).length, length };
        d = reflect(d, cell.fixed ? cell.mirror : decided[i]);
      }
      r += DIRS[d][0]; c += DIRS[d][1];
    }
  }
  function effort(puzzle) {
    let wrong = 0;
    const look = (decided, i, o) => {
      const t = step(puzzle, { ...decided, [i]: o });
      // 바로 끝나면서 못 푼 쪽은 누가 봐도 틀린 쪽이라 맨 뒤로
      const dead = t.done && !t.solved;
      return [t.solved ? 0 : dead ? 2 : 1, -t.lit, -t.length];
    };
    const order = (a, b) => { for (let k = 0; k < 3; k++) if (a[k] !== b[k]) return a[k] - b[k]; return 0; };
    function dfs(decided) {
      const t = step(puzzle, decided);
      if (t.done) return t.solved;
      const i = t.pending;
      const options = [0, 1].sort((a, b) => order(look(decided, i, a), look(decided, i, b)));
      for (let k = 0; k < 2; k++) {
        if (dfs({ ...decided, [i]: options[k] })) return true;
        wrong++;
      }
      return false;
    }
    dfs({});
    return wrong;
  }

  const HARDEST_MS = 1500, HARDEST_ENOUGH = 70;
  function generate(levelId) {
    const L = LEVELS[levelId - 1];
    if (L.hardest) {
      const until = Date.now() + HARDEST_MS;
      let best = null;
      while (!best || Date.now() < until) {
        const p = generateOne(levelId), e = effort(p);
        if (!best || e > best.e) best = { p, e };
        if (e >= HARDEST_ENOUGH) break;
      }
      return best.p;
    }
    if (!L.effort) return generateOne(levelId);
    // 범위 안의 판이 나오면 바로 쓰고, 시간 안에 못 찾으면 범위에 가장 가까운 판을 쓴다.
    const [lo, hi] = L.effort, deadline = Date.now() + 1500;
    let best = null;
    for (let k = 0; k < 3000; k++) {
      if (best && Date.now() > deadline) break;
      const p = generateOne(levelId), e = effort(p);
      if (e >= lo && e <= hi) return p;
      const gap = e < lo ? lo - e : e - hi;
      if (!best || gap < best.gap) best = { p, gap };
    }
    return best.p;
  }

  // 1. 시작점에서 빛을 쏘며 지나는 새 칸에 무작위로 거울을 놓아 정답 경로를 만든다.
  // 2. 그중 일부를 고정 거울로 바꾸고, 경로 밖에 헷갈리게 하는 고정 거울과 벽을 둔다.
  // 3. 경로 위 빈칸에 별을 두고, 다른 방향 조합도 성공하면 그 조합이 지나지 않는 칸에 별을 더한다.
  // 회전 거울 방향 조합 중 딱 하나만 성공하는 판만 낸다.
  function generateOne(levelId) {
    const L = LEVELS[levelId - 1], n = L.size;
    for (let attempt = 0; attempt < 5000; attempt++) {
      const want = between(L.mirrors) + L.fixedOnPath;
      const start = { side: rand(4), k: rand(n) };
      let { r, c, d } = entry(start, n);
      const cells = new Array(n * n).fill(null), visited = new Set(), order = [];
      const p = Math.min(0.6, want / (n * 1.6));
      let steps = 0, mirrors = 0, exit = null;
      while (steps++ < 4 * n * n) {
        if (r < 0 || c < 0 || r >= n || c >= n) { exit = exitPort(r, c, n); break; }
        const i = r * n + c;
        if (cells[i]) d = reflect(d, cells[i].mirror);
        else if (!visited.has(i) && mirrors < want && Math.random() < p) {
          cells[i] = { mirror: rand(2), fixed: false };
          mirrors++;
          d = reflect(d, cells[i].mirror);
        }
        if (!visited.has(i)) order.push(i);
        visited.add(i);
        r += DIRS[d][0]; c += DIRS[d][1];
      }
      if (!exit || mirrors !== want || samePort(exit, start) || order.length < n + 2) continue;

      const mirrorCells = order.filter(i => cells[i]);
      const solution = {};
      mirrorCells.forEach(i => { solution[i] = cells[i].mirror; });
      shuffle(mirrorCells.slice()).slice(0, L.fixedOnPath).forEach(i => { cells[i].fixed = true; });
      const empty = shuffle([...Array(n * n).keys()].filter(i => !visited.has(i)));
      for (let k = 0; k < L.decoyFixed && empty.length; k++) cells[empty.pop()] = { mirror: rand(2), fixed: true };
      for (let k = 0; k < L.walls && empty.length; k++) cells[empty.pop()] = { wall: true };

      const starSpots = shuffle(order.filter(i => !cells[i]));
      const stars = starSpots.splice(0, between(L.stars));
      const puzzle = { size: n, cells, start, goal: exit, stars, solution, level: levelId };
      let sols = solutions(puzzle);
      while (sols.length > 1 && stars.length < L.stars[1]) {
        const other = sols.find(s => Object.keys(solution).some(i => !cells[i].fixed && s.orient[i] !== solution[i]));
        const miss = starSpots.findIndex(i => !other.path.includes(i));
        if (miss < 0) break;
        stars.push(starSpots.splice(miss, 1)[0]);
        sols = solutions(puzzle);
      }
      if (sols.length !== 1) continue;
      stars.sort((a, b) => a - b);
      return puzzle;
    }
    throw new Error('mirror: could not generate');
  }

  // 처음 보여줄 방향: 회전 거울의 절반 이상은 정답과 다르게 섞는다(최소 조작 수가 너무 적지 않게).
  // 처음부터 풀린 상태는 피한다.
  function scramble(puzzle) {
    const rot = Object.keys(puzzle.solution).map(Number).filter(i => !puzzle.cells[i].fixed);
    const need = Math.ceil(rot.length / 2);
    for (let t = 0; t < 200; t++) {
      const orient = {};
      rot.forEach(i => { orient[i] = rand(2); });
      if (rot.filter(i => orient[i] !== puzzle.solution[i]).length < need) continue;
      if (!trace(puzzle, orient).solved) return orient;
    }
    const orient = {};
    rot.forEach(i => { orient[i] = 1 - puzzle.solution[i]; });
    return orient;
  }

  // 최소 조작 수: 처음 방향에서 정답과 다른 회전 거울의 수
  const minimumMoves = (puzzle, initial) => Object.keys(puzzle.solution).filter(i => !puzzle.cells[i].fixed && initial[i] !== puzzle.solution[i]).length;

  root.MirrorEngine = { LEVELS, DIRS, reflect, entry, exitPort, trace, solutions, generate, scramble, effort, minimumMoves };
})(typeof self !== 'undefined' ? self : globalThis);
