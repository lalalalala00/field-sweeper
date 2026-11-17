// 별네모 규칙과 문제 생성. 앱의 StarEngine.swift와 같은 규칙이다. 규칙을 바꾸면 양쪽을 함께 고친다.
// n×n 판이 n개 구역으로 나뉜다. 가로줄·세로줄·구역마다 별을 k개씩 놓는다. 별끼리는 대각선을 포함해 서로 닿을 수 없다.
// 판정은 규칙으로 한다(저장된 답과 비교하지 않는다).
(function (root) {
  // k: 줄·구역마다 놓을 별 수. tier: 사람처럼 푸는 풀이기(grade)로 쓴 가장 어려운 단계의 범위(4는 한 단계 가정).
  // search: 이 시간(ms) 동안 만들어 보고 가장 어려운 판을 낸다(범위에 맞는 판을 찾으면 바로 낸다).
  const LEVELS = [
    { id: 1, name: '초급', size: 5, k: 1, tier: [1, 1] },
    { id: 2, name: '중급', size: 6, k: 1, tier: [2, 2] },
    { id: 3, name: '고급', size: 8, k: 1, tier: [3, 4] },
    { id: 4, name: '전문가', size: 10, k: 2, tier: [3, 4], search: 3000 },
  ];
  const rand = n => Math.floor(Math.random() * n);
  const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = rand(i + 1); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const nb4 = (i, n) => {
    const r = Math.floor(i / n), c = i % n, out = [];
    if (r > 0) out.push(i - n);
    if (r < n - 1) out.push(i + n);
    if (c > 0) out.push(i - 1);
    if (c < n - 1) out.push(i + 1);
    return out;
  };
  // 대각선까지 맞닿은 칸
  const nb8 = (i, n) => {
    const r = Math.floor(i / n), c = i % n, out = [];
    for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++) {
      if (!dr && !dc) continue;
      const rr = r + dr, cc = c + dc;
      if (rr >= 0 && cc >= 0 && rr < n && cc < n) out.push(rr * n + cc);
    }
    return out;
  };
  const touching = (a, b, n) => a !== b && Math.abs(Math.floor(a / n) - Math.floor(b / n)) <= 1 && Math.abs((a % n) - (b % n)) <= 1;

  // 줄 하나에 놓을 수 있는 열 조합(서로 붙지 않는 k개)
  function rowCombos(n, k) {
    const out = [];
    const walk = (from, cur) => {
      if (cur.length === k) { out.push(cur.slice()); return; }
      for (let c = from; c < n; c++) {
        if (cur.length && c - cur[cur.length - 1] < 2) continue;
        cur.push(c); walk(c + 1, cur); cur.pop();
      }
    };
    walk(0, []);
    return out;
  }

  // 가로줄·세로줄·구역 목록
  function unitsOf(puzzle) {
    const n = puzzle.size, units = [];
    for (let r = 0; r < n; r++) units.push([...Array(n)].map((_, c) => r * n + c));
    for (let c = 0; c < n; c++) units.push([...Array(n)].map((_, r) => r * n + c));
    for (let g = 0; g < n; g++) units.push([]);
    puzzle.regions.forEach((g, i) => units[2 * n + g].push(i));
    return units;
  }

  // ── 판정 ──
  // stars: 별을 놓은 칸들. 반환: 맞닿은 별, 별이 너무 많은 줄·구역의 칸, 다 풀렸는지.
  function check(puzzle, stars) {
    const n = puzzle.size, k = puzzle.k, set = new Set(stars), bad = new Set();
    for (const a of stars) for (const b of nb8(a, n)) if (set.has(b)) { bad.add(a); bad.add(b); }
    let full = true;
    for (const unit of unitsOf(puzzle)) {
      const on = unit.filter(i => set.has(i));
      if (on.length > k) on.forEach(i => bad.add(i));
      if (on.length !== k) full = false;
    }
    return { bad: [...bad], solved: full && !bad.size };
  }

  // ── 답 세기: 줄마다 열 조합을 골라 넣는다 ──
  function countSolutions(puzzle, limit = 2) {
    const n = puzzle.size, k = puzzle.k, owner = puzzle.regions, combos = rowCombos(n, k);
    const colCnt = new Array(n).fill(0), regCnt = new Array(n).fill(0), regLeft = new Array(n).fill(0), prev = [];
    owner.forEach(g => { regLeft[g]++; });
    let found = 0;
    const go = r => {
      if (found >= limit) return;
      if (r === n) { found++; return; }
      for (const cb of combos) {
        if (cb.some(c => colCnt[c] >= k)) continue;
        if (r && cb.some(c => prev[r - 1].some(p => Math.abs(p - c) <= 1))) continue;
        const regs = cb.map(c => owner[r * n + c]);
        if (regs.some(g => regCnt[g] + regs.filter(x => x === g).length > k)) continue;
        cb.forEach((c, a) => { colCnt[c]++; regCnt[regs[a]]++; });
        for (let c = 0; c < n; c++) regLeft[owner[r * n + c]]--;
        // 이 줄을 지나 더 칸이 없는데 별이 모자란 구역이 있으면 버린다
        let ok = true;
        for (let g = 0; g < n && ok; g++) if (regLeft[g] === 0 && regCnt[g] < k) ok = false;
        if (ok) { prev[r] = cb; go(r + 1); }
        for (let c = 0; c < n; c++) regLeft[owner[r * n + c]]++;
        cb.forEach((c, a) => { colCnt[c]--; regCnt[regs[a]]--; });
        if (found >= limit) return;
      }
    };
    go(0);
    return found;
  }

  // ── 난이도: 사람처럼 푸는 풀이기 ──
  // 칸 상태: 0 모름, 1 별, 2 빈칸. 쉬운 단계부터 쓰고, 막힐 때만 다음 단계를 쓴다.
  //  1단계 별 둘레 8칸 지우기, 별이 다 찬 줄·구역의 남은 칸 지우기, 남은 칸 수가 필요한 별 수와 같으면 모두 별
  //  2단계 구역의 남은 칸이 한 줄에만 있으면(또는 줄의 남은 칸이 한 구역에만 있으면) 그 줄(구역)의 다른 칸 지우기,
  //        여기에 별을 두면 어떤 줄·구역에 별을 다 놓을 수 없게 되는 칸 지우기
  //  3단계 구역 m개의 남은 칸이 줄 m개 안에만 있으면 그 줄들의 다른 칸 지우기(반대로 줄 m개가 구역 m개 안에만 있을 때도)
  //  4단계 한 단계 가정: 여기에 별을 두고 1~3단계로 풀어 보면 모순이 나는 칸 지우기
  // 끝까지 풀리면 { tier, steps(3단계 이상을 쓴 횟수), look(가정 횟수) }, 막히면 null. 끝까지 풀리면 답이 하나뿐이다.
  function grade(puzzle, maxTier = 4) {
    const n = puzzle.size, k = puzzle.k, N = n * n;
    const units = unitsOf(puzzle);
    const unitsAt = [...Array(N)].map(() => []);
    units.forEach((u, x) => u.forEach(i => unitsAt[i].push(x)));
    const near = [...Array(N)].map((_, i) => nb8(i, n));

    // 서로 닿지 않게 고를 수 있는 가장 많은 칸 수(limit에서 멈춘다)
    function capacity(cells, limit) {
      let best = 0;
      const walk = (from, picked) => {
        if (picked.length > best) best = picked.length;
        if (best >= limit) return;
        if (picked.length + (cells.length - from) <= best) return;
        for (let a = from; a < cells.length; a++) {
          if (picked.some(p => touching(p, cells[a], n))) continue;
          picked.push(cells[a]); walk(a + 1, picked); picked.pop();
          if (best >= limit) return;
        }
      };
      walk(0, []);
      return best;
    }
    // 줄·구역마다 별 수가 맞을 수 있는지(모순이면 false)
    function consistent(s) {
      for (const u of units) {
        let stars = 0;
        const open = [];
        for (const i of u) { if (s[i] === 1) stars++; else if (s[i] === 0) open.push(i); }
        if (stars > k) return false;
        if (stars + open.length < k) return false;
        if (stars < k && capacity(open, k - stars) < k - stars) return false;
      }
      for (let i = 0; i < N; i++) if (s[i] === 1) for (const j of near[i]) if (s[j] === 1) return false;
      return true;
    }
    function place(s, i) {
      s[i] = 1;
      for (const j of near[i]) if (s[j] === 0) s[j] = 2;
    }
    // 1단계. 바뀌었으면 true, 모순이면 null
    function basic(s) {
      let changed = false;
      for (const u of units) {
        let stars = 0;
        const open = [];
        for (const i of u) { if (s[i] === 1) stars++; else if (s[i] === 0) open.push(i); }
        if (stars > k || stars + open.length < k) return null;
        if (stars === k && open.length) { open.forEach(i => { s[i] = 2; }); changed = true; }
        else if (open.length && stars + open.length === k) {
          for (const i of open) { if (near[i].some(j => s[j] === 1)) return null; place(s, i); }
          changed = true;
        }
      }
      for (let i = 0; i < N; i++) if (s[i] === 1) for (const j of near[i]) {
        if (s[j] === 1) return null;
        if (s[j] === 0) { s[j] = 2; changed = true; }
      }
      return changed;
    }
    // 남은 칸들이 들어 있는 줄 번호들(가로 줄이면 row, 세로 줄이면 col)
    const linesOf = (cells, row) => [...new Set(cells.map(i => (row ? Math.floor(i / n) : i % n)))];
    const openOf = (s, u) => u.filter(i => s[i] === 0);
    const need = (s, u) => k - u.filter(i => s[i] === 1).length;
    // 2단계
    function pointing(s) {
      let changed = false;
      // 구역의 남은 별이 모두 한 줄 안에 들어가야 할 때(남은 칸이 한 줄에만 있음)
      for (let g = 0; g < n; g++) {
        const u = units[2 * n + g], open = openOf(s, u), want = need(s, u);
        if (!open.length || !want) continue;
        for (const row of [true, false]) {
          const ls = linesOf(open, row);
          if (ls.length !== 1) continue;
          const line = units[row ? ls[0] : n + ls[0]];
          // 그 줄이 이 구역에 줄 수 있는 별이 줄의 남은 별과 같을 때만 줄의 다른 칸을 지울 수 있다
          if (need(s, line) !== want) continue;
          for (const i of openOf(s, line)) if (s[i] === 0 && !u.includes(i)) { s[i] = 2; changed = true; }
        }
      }
      // 줄의 남은 칸이 모두 한 구역에 있을 때
      for (let x = 0; x < 2 * n; x++) {
        const line = units[x], open = openOf(s, line), want = need(s, line);
        if (!open.length || !want) continue;
        const gs = [...new Set(open.map(i => puzzle.regions[i]))];
        if (gs.length !== 1) continue;
        const region = units[2 * n + gs[0]];
        if (need(s, region) !== want) continue;
        for (const i of openOf(s, region)) if (!line.includes(i)) { s[i] = 2; changed = true; }
      }
      return changed;
    }
    function killers(s) {
      let changed = false;
      for (let i = 0; i < N; i++) {
        if (s[i] !== 0) continue;
        const t = s.slice();
        place(t, i);
        // 별이 다 찬 줄·구역의 남은 칸을 지운 뒤 막히는 줄·구역이 있는지 본다
        for (const x of unitsAt[i]) if (units[x].filter(j => t[j] === 1).length === k) units[x].forEach(j => { if (t[j] === 0) t[j] = 2; });
        if (!consistent(t)) { s[i] = 2; changed = true; }
      }
      return changed;
    }
    // 3단계: 구역 m개 ↔ 줄 m개(m = 2, 3)
    function pigeon(s) {
      let changed = false;
      const live = g => openOf(s, units[2 * n + g]).length > 0 && need(s, units[2 * n + g]) > 0;
      const regs = [...Array(n).keys()].filter(live);
      for (const row of [true, false]) {
        const lineUnit = l => units[row ? l : n + l];
        // 구역 m개가 줄 m개 안에 갇히면 그 줄들의 다른 칸을 지운다
        const pickRegs = (from, chosen, m) => {
          if (chosen.length === m) {
            const cells = chosen.flatMap(g => openOf(s, units[2 * n + g]));
            const ls = linesOf(cells, row);
            if (ls.length !== m) return;
            const wantRegs = chosen.reduce((a, g) => a + need(s, units[2 * n + g]), 0);
            const wantLines = ls.reduce((a, l) => a + need(s, lineUnit(l)), 0);
            if (wantRegs !== wantLines) return;
            for (const l of ls) for (const i of openOf(s, lineUnit(l))) if (!chosen.includes(puzzle.regions[i])) { s[i] = 2; changed = true; }
            return;
          }
          for (let a = from; a < regs.length; a++) pickRegs(a + 1, chosen.concat(regs[a]), m);
        };
        // 줄 m개가 구역 m개 안에 갇히면 그 구역들의 다른 칸을 지운다
        const liveLines = [...Array(n).keys()].filter(l => openOf(s, lineUnit(l)).length && need(s, lineUnit(l)) > 0);
        const pickLines = (from, chosen, m) => {
          if (chosen.length === m) {
            const cells = chosen.flatMap(l => openOf(s, lineUnit(l)));
            const gs = [...new Set(cells.map(i => puzzle.regions[i]))];
            if (gs.length !== m) return;
            const wantLines = chosen.reduce((a, l) => a + need(s, lineUnit(l)), 0);
            const wantRegs = gs.reduce((a, g) => a + need(s, units[2 * n + g]), 0);
            if (wantRegs !== wantLines) return;
            for (const g of gs) for (const i of openOf(s, units[2 * n + g])) {
              const l = row ? Math.floor(i / n) : i % n;
              if (!chosen.includes(l)) { s[i] = 2; changed = true; }
            }
            return;
          }
          for (let a = from; a < liveLines.length; a++) pickLines(a + 1, chosen.concat(liveLines[a]), m);
        };
        for (const m of [2, 3]) { pickRegs(0, [], m); pickLines(0, [], m); }
      }
      return changed;
    }
    // 1~3단계로 끝까지. 결과 'solved' | 'stuck' | 'contra'
    function propagate(s, top, upto) {
      for (;;) {
        const b = basic(s);
        if (b === null || !consistent(s)) return 'contra';
        if (b) { if (top) top.tier = Math.max(top.tier, 1); continue; }
        if (s.every(v => v !== 0)) return units.every(u => u.filter(i => s[i] === 1).length === k) ? 'solved' : 'contra';
        if (upto >= 2 && (pointing(s) || killers(s))) { if (top) top.tier = Math.max(top.tier, 2); continue; }
        if (upto >= 3 && pigeon(s)) { if (top) { top.tier = Math.max(top.tier, 3); top.steps++; } continue; }
        return 'stuck';
      }
    }
    const s = new Array(N).fill(0), info = { tier: 0, steps: 0, look: 0 };
    for (;;) {
      const r = propagate(s, info, Math.min(3, maxTier));
      if (r === 'solved') return info;
      if (r === 'contra' || maxTier < 4) return null;
      // 4단계: 한 단계 가정
      let found = false;
      for (let i = 0; i < N && !found; i++) {
        if (s[i] !== 0) continue;
        const t = s.slice();
        place(t, i);
        if (propagate(t, null, 3) === 'contra') { s[i] = 2; found = true; }
      }
      if (!found) return null;
      info.tier = 4; info.look++;
    }
  }

  // ── 생성 ──
  // 1. 별 정답을 먼저 놓는다. 2. 별을 씨앗으로 구역을 키운다(k=2면 가까운 별 둘을 한 구역으로).
  // 3. 답이 여럿이면 구역 경계의 칸 하나를 이웃 구역으로 넘기며 답이 하나가 될 때까지 고친다(정답은 그대로 맞다).
  function placeStars(n, k) {
    const combos = rowCombos(n, k), colCnt = new Array(n).fill(0), rows = [];
    let budget = 20000;
    const go = r => {
      if (r === n) return true;
      if (--budget < 0) return false;
      for (const cb of shuffle(combos.slice())) {
        if (cb.some(c => colCnt[c] >= k)) continue;
        if (r && cb.some(c => rows[r - 1].some(p => Math.abs(p - c) <= 1))) continue;
        cb.forEach(c => colCnt[c]++);
        rows[r] = cb;
        if (go(r + 1)) return true;
        cb.forEach(c => colCnt[c]--);
      }
      return false;
    };
    if (!go(0)) return null;
    const stars = [];
    rows.forEach((cb, r) => cb.forEach(c => stars.push(r * n + c)));
    return stars;
  }
  function growRegions(n, k, stars) {
    const owner = new Array(n * n).fill(-1);
    let groups;
    if (k === 1) groups = stars.map(s => [s]);
    else {
      const left = shuffle(stars.slice()), d = (a, b) => Math.abs(Math.floor(a / n) - Math.floor(b / n)) + Math.abs((a % n) - (b % n));
      groups = [];
      while (left.length) {
        const a = left.pop();
        let bi = 0;
        left.forEach((b, x) => { if (d(a, b) < d(a, left[bi])) bi = x; });
        groups.push([a, left.splice(bi, 1)[0]]);
      }
    }
    groups.forEach((g, id) => {
      g.forEach(s => { owner[s] = id; });
      if (g.length === 2) {
        // 짝 별 사이를 잇는 길을 먼저 칠한다(다른 구역 칸은 건너뛴다)
        const [a, b] = g;
        let r = Math.floor(a / n), c = a % n;
        const br = Math.floor(b / n), bc = b % n;
        while (r !== br || c !== bc) {
          if (r !== br && (c === bc || Math.random() < 0.5)) r += Math.sign(br - r); else c += Math.sign(bc - c);
          const i = r * n + c;
          if (owner[i] === -1) owner[i] = id;
        }
      }
    });
    for (;;) {
      const opts = [];
      for (let i = 0; i < n * n; i++) if (owner[i] >= 0) for (const j of nb4(i, n)) if (owner[j] === -1) opts.push([j, owner[i]]);
      if (!opts.length) break;
      const [j, o] = opts[rand(opts.length)];
      owner[j] = o;
    }
    if (owner.some(o => o < 0)) return null;
    // 구역이 끊겼으면(짝 별을 잇는 길이 다른 구역에 막힌 경우) 버린다
    for (let g = 0; g < n; g++) if (!connected(owner, g, n)) return null;
    return owner;
  }
  function connected(owner, g, n) {
    const cells = [];
    for (let i = 0; i < n * n; i++) if (owner[i] === g) cells.push(i);
    if (!cells.length) return false;
    const seen = new Set([cells[0]]), stack = [cells[0]];
    while (stack.length) { const x = stack.pop(); for (const y of nb4(x, n)) if (owner[y] === g && !seen.has(y)) { seen.add(y); stack.push(y); } }
    return seen.size === cells.length;
  }
  function makeUnique(n, k, level) {
    const stars = placeStars(n, k);
    if (!stars) return null;
    const regions = growRegions(n, k, stars);
    if (!regions) return null;
    const starSet = new Set(stars), puzzle = { size: n, k, regions, solution: stars.slice().sort((a, b) => a - b), level };
    for (let t = 0; t < 400; t++) {
      if (countSolutions(puzzle) === 1) return puzzle;
      const cand = [];
      for (let i = 0; i < n * n; i++) if (!starSet.has(i)) for (const j of nb4(i, n)) if (regions[j] !== regions[i]) cand.push([i, regions[j]]);
      const [i, o] = cand[rand(cand.length)], old = regions[i];
      regions[i] = o;
      if (!connected(regions, old, n)) regions[i] = old;
    }
    return null;
  }
  // 범위에 맞는 판이 나오면 바로 낸다. search가 있으면 그 시간 동안 만들어 보고 가장 어려운 판을 낸다.
  // 시간 안에 범위에 맞는 판을 못 찾으면 그동안 가장 가까웠던 판을 낸다.
  function generate(levelId) {
    const L = LEVELS[levelId - 1], n = L.size, start = Date.now(), wait = L.search || 3000;
    let best = null, bestScore = -1;
    for (;;) {
      const p = makeUnique(n, L.k, levelId);
      const g = p && grade(p, L.tier[1]);
      if (g) {
        const inRange = g.tier >= L.tier[0];
        if (inRange && !L.search) return p;
        const sc = (inRange ? 1e6 : 0) + g.tier * 1000 + g.look * 10 + g.steps;
        if (sc > bestScore) { best = p; bestScore = sc; }
      }
      if (best && Date.now() > start + wait) return best;
      if (Date.now() > start + 20000) throw new Error('star: could not generate');
    }
  }

  root.StarEngine = { LEVELS, nb8, unitsOf, check, countSolutions, grade, generate, makeUnique };
})(typeof self !== 'undefined' ? self : globalThis);
