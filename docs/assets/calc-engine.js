// 셈네모 규칙과 문제 생성. 앱의 CalcEngine.swift와 같은 규칙이다. 규칙을 바꾸면 양쪽을 함께 고친다.
// n×n 판의 가로줄과 세로줄에 1~n을 한 번씩 채운다. 판은 칸 묶음(cage)으로 나뉘고, 묶음마다 목표 숫자와 연산이 있다.
// 묶음 안 숫자를 그 연산으로 계산하면 목표가 나와야 한다. −와 ÷는 2칸 묶음에만 쓰고 순서는 상관없다(큰 수에서 작은 수).
// 1칸 묶음(op '=')은 숫자가 그대로 주어진 칸이다. 줄만 다르면 한 묶음 안에 같은 숫자가 여러 번 들어갈 수 있다.
(function (root) {
  // sizes: 묶음 크기를 고르는 가중치(1칸, 2칸, 3칸, 4칸, 5칸). maxSingles: 1칸 묶음(주어진 숫자)의 최대 개수.
  // ops: 쓸 수 있는 연산. tier: 사람처럼 푸는 풀이기(grade)로 풀 때 필요한 가장 어려운 추리 단계의 범위.
  const LEVELS = [
    { id: 1, name: '초급', size: 4, ops: '+-', sizes: [0, 5, 3], maxSingles: 2, tier: [1, 1] },
    { id: 2, name: '중급', size: 5, ops: '+-*', sizes: [0, 5, 4, 1], maxSingles: 2, tier: [1, 1] },
    { id: 3, name: '고급', size: 6, ops: '+-*/', sizes: [0, 4, 4, 2], maxSingles: 1, tier: [2, 2] },
    { id: 4, name: '전문가', size: 7, ops: '+-*/', sizes: [0, 3, 4, 3, 1], maxSingles: 1, tier: [3, 3] },
    // 지옥: 처음 숫자 0개(1칸 묶음 없음), 숫자 조합이 한 가지뿐인 묶음은 maxPlain개까지, 묶음 계산만으로 바로 정해지는 칸 0개,
    // 가정 없이 3단계까지로 풀림. search 동안 만들어 보고 2·3단계 추리를 가장 많이 써야 하는 판을 낸다(enough번 이상이면 바로).
    // 조합이 한 가지뿐인 묶음(주로 ×·÷)을 모두 빼면 실마리가 너무 약해 답이 하나인 판이 거의 나오지 않아서 2개까지 둔다.
    { id: 5, name: '지옥', size: 8, ops: '+-*/', sizes: [0, 4, 5, 2], maxSingles: 0, tier: [3, 3], hell: true, maxPlain: 2, search: 4000, enough: 8 },
  ];
  const SYMBOL = { '+': '+', '-': '−', '*': '×', '/': '÷', '=': '' };

  const rand = n => Math.floor(Math.random() * n);
  const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = rand(i + 1); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const popcount = m => { let k = 0; while (m) { m &= m - 1; k++; } return k; };
  const bitOf = m => { for (let d = 1; d < 16; d++) if (m === 1 << d) return d; return 0; };

  // 정답: 무작위 라틴 방진. 첫 줄을 섞고, 줄 순서·열 순서·숫자를 섞는다.
  function randomLatin(n) {
    const base = [...Array(n)].map((_, r) => [...Array(n)].map((_, c) => ((r + c) % n) + 1));
    const rows = shuffle([...Array(n).keys()]), cols = shuffle([...Array(n).keys()]);
    const map = [0, ...shuffle([...Array(n)].map((_, k) => k + 1))];
    const out = new Array(n * n);
    for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) out[r * n + c] = map[base[rows[r]][cols[c]]];
    return out;
  }

  const neighbors = (i, n) => {
    const r = Math.floor(i / n), c = i % n, out = [];
    if (r > 0) out.push(i - n);
    if (r < n - 1) out.push(i + n);
    if (c > 0) out.push(i - 1);
    if (c < n - 1) out.push(i + 1);
    return out;
  };

  // 묶음 값이 목표와 맞는지. values는 묶음 칸 순서대로의 숫자.
  function fits(op, target, values) {
    if (op === '=') return values[0] === target;
    if (op === '+') return values.reduce((a, b) => a + b, 0) === target;
    if (op === '*') return values.reduce((a, b) => a * b, 1) === target;
    const [a, b] = values, hi = Math.max(a, b), lo = Math.min(a, b);
    if (op === '-') return hi - lo === target;
    return hi === lo * target;
  }

  // 묶음에 들어갈 수 있는 숫자 조합(칸 순서대로). 같은 줄의 두 칸은 같은 숫자일 수 없다.
  function tuplesOf(cage, n) {
    const cells = cage.cells, k = cells.length, out = [], cur = [];
    const clash = [...Array(k)].map((_, a) => [...Array(a)].map((_, b) => b)
      .filter(b => Math.floor(cells[a] / n) === Math.floor(cells[b] / n) || cells[a] % n === cells[b] % n));
    const walk = a => {
      if (a === k) { if (fits(cage.op, cage.target, cur)) out.push(cur.slice()); return; }
      for (let v = 1; v <= n; v++) {
        if (clash[a].some(b => cur[b] === v)) continue;
        cur[a] = v; walk(a + 1);
      }
    };
    walk(0);
    return out;
  }

  // 판정: 모든 칸이 차 있고, 줄마다 숫자가 겹치지 않고, 모든 묶음 계산이 맞는지.
  function check(puzzle, values) {
    const n = puzzle.size;
    if (values.some(v => !v)) return false;
    for (let k = 0; k < n; k++) {
      const row = new Set(), col = new Set();
      for (let j = 0; j < n; j++) { row.add(values[k * n + j]); col.add(values[j * n + k]); }
      if (row.size !== n || col.size !== n) return false;
    }
    return puzzle.cages.every(c => fits(c.op, c.target, c.cells.map(i => values[i])));
  }
  // 다 채웠는데 계산이 틀린 묶음들의 번호
  const wrongCages = (puzzle, values) => puzzle.cages.map((c, k) => (c.cells.every(i => values[i]) && !fits(c.op, c.target, c.cells.map(i => values[i])) ? k : -1)).filter(k => k >= 0);

  // ── 풀이기: 답을 limit까지 센다(시험용). 묶음 단위로 조합을 골라 넣는다. ──
  function countSolutions(puzzle, limit = 2) {
    const n = puzzle.size, cages = puzzle.cages, tuples = cages.map(c => tuplesOf(c, n));
    const rowUsed = new Array(n).fill(0), colUsed = new Array(n).fill(0), done = new Array(cages.length).fill(false);
    let count = 0;
    const okTuple = (c, t) => cages[c].cells.every((i, a) => !((rowUsed[Math.floor(i / n)] | colUsed[i % n]) & (1 << t[a])));
    const put = (c, t, on) => cages[c].cells.forEach((i, a) => { rowUsed[Math.floor(i / n)] ^= 1 << t[a]; colUsed[i % n] ^= 1 << t[a]; });
    const solve = () => {
      if (count >= limit) return;
      let best = -1, bestList = null;
      for (let c = 0; c < cages.length; c++) {
        if (done[c]) continue;
        const list = tuples[c].filter(t => okTuple(c, t));
        if (!list.length) return;
        if (!bestList || list.length < bestList.length) { best = c; bestList = list; }
      }
      if (best < 0) { count++; return; }
      done[best] = true;
      for (const t of bestList) { put(best, t, true); solve(); put(best, t, false); if (count >= limit) break; }
      done[best] = false;
    };
    solve();
    return count;
  }

  // ── 난이도: 사람처럼 푸는 풀이기 ──
  // 칸마다 후보(비트마스크)를 두고 아래 추리로 지워 나간다. 쉬운 단계부터 쓰고, 막힐 때만 다음 단계를 쓴다.
  //  1단계 묶음 계산: 묶음의 가능한 조합으로 칸 후보를 줄인다. 후보가 하나뿐인 칸, 줄에서 한 자리만 남은 숫자를 넣는다.
  //  2단계 줄의 짝: 한 줄에서 두 칸이 같은 두 후보만 가지면 나머지 칸에서 그 둘을 지운다.
  //        묶음이 꼭 쓰는 숫자: 묶음의 모든 조합에 들어 있는 숫자가 한 줄 안에만 놓일 수 있으면 그 줄의 다른 칸에서 지운다.
  //  3단계 줄의 셋: 세 칸에 세 후보(naked triple), 줄에서 두 숫자가 같은 두 칸에만 갈 수 있음(hidden pair).
  // 돌려주는 값: 끝까지 풀리면 { tier: 쓴 가장 어려운 단계, steps: 2단계 이상을 쓴 횟수 }, 막히면 null.
  // 추리는 모두 불가능한 후보만 지우므로 끝까지 풀리면 답이 하나뿐이다.
  function grade(puzzle, maxTier = 3) {
    const n = puzzle.size, N = n * n, full = ((1 << n) - 1) << 1;
    const cages = puzzle.cages, tuples = cages.map(c => tuplesOf(c, n));
    const cand = new Array(N).fill(full);
    const lines = [];
    for (let k = 0; k < n; k++) {
      lines.push([...Array(n)].map((_, j) => k * n + j));
      lines.push([...Array(n)].map((_, j) => j * n + k));
    }
    const lineOf = (i, isRow) => lines[isRow ? Math.floor(i / n) * 2 : (i % n) * 2 + 1];
    let tier = 0, steps = 0, opening = -1;

    // 묶음 조합을 지금 후보에 맞게 거르고, 칸 후보를 조합에 나오는 숫자로 줄인다.
    function cagePass() {
      let changed = false;
      for (let c = 0; c < cages.length; c++) {
        const cells = cages[c].cells;
        tuples[c] = tuples[c].filter(t => t.every((v, a) => cand[cells[a]] & (1 << v)));
        if (!tuples[c].length) return null;
        cells.forEach((i, a) => {
          let m = 0;
          for (const t of tuples[c]) m |= 1 << t[a];
          if ((cand[i] & m) !== cand[i]) { cand[i] &= m; changed = true; }
        });
      }
      return changed;
    }
    // 후보가 하나뿐인 칸은 줄의 다른 칸에서 그 숫자를 지우고, 줄에서 한 자리만 남은 숫자는 그 칸에 넣는다.
    function singles() {
      let changed = false;
      for (let i = 0; i < N; i++) {
        if (popcount(cand[i]) !== 1) continue;
        for (const line of [lineOf(i, true), lineOf(i, false)]) for (const j of line) {
          if (j !== i && cand[j] & cand[i]) { cand[j] &= ~cand[i]; changed = true; }
        }
      }
      for (const line of lines) for (let v = 1; v <= n; v++) {
        const at = line.filter(i => cand[i] & (1 << v));
        if (at.length === 1 && cand[at[0]] !== 1 << v) { cand[at[0]] = 1 << v; changed = true; }
      }
      return changed;
    }
    // 줄에서 size칸이 합쳐 size개 후보만 가지면(naked subset) 나머지 칸에서 지운다.
    function nakedSubsets(size) {
      let changed = false;
      for (const line of lines) {
        const open = line.filter(i => popcount(cand[i]) > 1 && popcount(cand[i]) <= size);
        const pick = (from, chosen, mask) => {
          if (chosen.length === size) {
            if (popcount(mask) !== size) return;
            for (const j of line) if (!chosen.includes(j) && cand[j] & mask) { cand[j] &= ~mask; changed = true; }
            return;
          }
          for (let k = from; k < open.length; k++) pick(k + 1, chosen.concat(open[k]), mask | cand[open[k]]);
        };
        pick(0, [], 0);
      }
      return changed;
    }
    // 줄에서 두 숫자가 같은 두 칸에만 갈 수 있으면(hidden pair) 그 두 칸의 다른 후보를 지운다.
    function hiddenPairs() {
      let changed = false;
      for (const line of lines) {
        const where = [];
        for (let v = 1; v <= n; v++) where[v] = line.filter(i => cand[i] & (1 << v));
        for (let a = 1; a <= n; a++) for (let b = a + 1; b <= n; b++) {
          if (where[a].length !== 2 || where[b].length !== 2 || where[a][0] !== where[b][0] || where[a][1] !== where[b][1]) continue;
          const keep = (1 << a) | (1 << b);
          for (const i of where[a]) if (cand[i] & ~keep) { cand[i] &= keep; changed = true; }
        }
      }
      return changed;
    }
    // 묶음의 모든 조합에 들어 있는 숫자가 묶음 안에서 한 줄에만 놓일 수 있으면, 그 줄의 다른 칸에서 지운다.
    function cageMusts() {
      let changed = false;
      for (let c = 0; c < cages.length; c++) {
        const cells = cages[c].cells;
        if (cells.length < 2) continue;
        for (let v = 1; v <= n; v++) {
          if (!tuples[c].every(t => t.includes(v))) continue;
          const at = cells.filter((i, a) => tuples[c].some(t => t[a] === v));
          for (const isRow of [true, false]) {
            const key = i => (isRow ? Math.floor(i / n) : i % n);
            if (!at.every(i => key(i) === key(at[0]))) continue;
            // 모든 조합에서 v가 이 줄에 정확히 한 번 들어가야 다른 칸에서 지울 수 있다(같은 줄에는 한 번뿐이라 늘 참).
            for (const j of lineOf(at[0], isRow)) if (!cells.includes(j) && cand[j] & (1 << v)) { cand[j] &= ~(1 << v); changed = true; }
          }
        }
      }
      return changed;
    }

    for (let guard = 0; guard < 1000; guard++) {
      const cp = cagePass();
      if (cp === null) return null;
      if (cand.some(m => !m)) return null;
      // 묶음 계산만 한 번 하고 바로 정해지는 칸 수(지옥은 0이어야 한다)
      if (opening < 0) opening = cand.filter(m => popcount(m) === 1).length;
      if (cp || singles()) { tier = Math.max(tier, 1); continue; }
      if (cand.every(m => popcount(m) === 1)) {
        const values = cand.map(bitOf);
        return check(puzzle, values) ? { tier, steps, opening, values } : null;
      }
      if (maxTier >= 2 && (nakedSubsets(2) || cageMusts())) { tier = Math.max(tier, 2); steps++; continue; }
      if (maxTier >= 3 && (nakedSubsets(3) || hiddenPairs())) { tier = 3; steps++; continue; }
      return null;
    }
    return null;
  }

  // ── 생성 ──
  // 1. 정답 라틴 방진을 만든다. 2. 칸을 무작위 순서로 돌며 이웃으로 묶음을 키운다.
  // 3. 묶음마다 연산을 고른다. 4. 풀이기로 난이도를 재서 범위에 맞는 판만 낸다.
  function partition(n, L) {
    const owner = new Array(n * n).fill(-1), cages = [];
    const total = L.sizes.reduce((a, b) => a + b, 0);
    const pickSize = () => { let r = rand(total); for (let s = 0; s < L.sizes.length; s++) { if (r < L.sizes[s]) return s + 1; r -= L.sizes[s]; } return 2; };
    for (const s of shuffle([...Array(n * n).keys()])) {
      if (owner[s] !== -1) continue;
      const id = cages.length, cells = [s], want = pickSize();
      owner[s] = id;
      while (cells.length < want) {
        const opts = [];
        for (const c of cells) for (const j of neighbors(c, n)) if (owner[j] === -1 && !opts.includes(j)) opts.push(j);
        if (!opts.length) break;
        const j = opts[rand(opts.length)];
        owner[j] = id; cells.push(j);
      }
      cages.push(cells);
    }
    // 1칸 묶음이 너무 많으면 이웃 묶음(5칸 미만)에 붙인다.
    let singles = cages.filter(c => c && c.length === 1).length;
    for (let k = 0; k < cages.length && singles > L.maxSingles; k++) {
      const c = cages[k];
      if (!c || c.length !== 1) continue;
      const near = neighbors(c[0], n).map(j => owner[j]).filter(o => o !== k && cages[o].length < L.sizes.length);
      if (!near.length) continue;
      const o = near[rand(near.length)];
      cages[o].push(c[0]); owner[c[0]] = o; cages[k] = null; singles--;
    }
    return cages.filter(Boolean).map(c => c.sort((a, b) => a - b));
  }
  function chooseOp(values, ops) {
    if (values.length === 1) return { op: '=', target: values[0] };
    if (values.length === 2) {
      const hi = Math.max(...values), lo = Math.min(...values);
      if (ops.includes('/') && hi % lo === 0 && Math.random() < 0.5) return { op: '/', target: hi / lo };
      if (ops.includes('-') && Math.random() < 0.45) return { op: '-', target: hi - lo };
    }
    if (ops.includes('*') && Math.random() < 0.45) return { op: '*', target: values.reduce((a, b) => a * b, 1) };
    return { op: '+', target: values.reduce((a, b) => a + b, 0) };
  }
  // 묶음에 들어갈 수 있는 숫자 묶음(순서 무시)이 2가지 이상인지. 한 가지뿐이면 그 묶음만 보고 숫자를 알 수 있다.
  const ambiguous = (cage, n) => new Set(tuplesOf(cage, n).map(t => t.slice().sort((a, b) => a - b).join(','))).size >= 2;
  // 지옥 묶음: 1칸 묶음이 없어야 하고, 묶음마다 조합이 여러 가지인 연산을 고른다(없으면 아무 연산, 그런 묶음은 maxPlain개까지).
  function hellCages(n, L, solution) {
    const parts = partition(n, L);
    if (parts.some(c => c.length === 1)) return null;
    let plain = 0;
    const cages = parts.map(cells => {
      const v = cells.map(i => solution[i]), hi = Math.max(...v), lo = Math.min(...v);
      const options = [{ op: '+', target: v.reduce((a, b) => a + b, 0) }, { op: '*', target: v.reduce((a, b) => a * b, 1) }];
      if (v.length === 2) { options.push({ op: '-', target: hi - lo }); if (hi % lo === 0) options.push({ op: '/', target: hi / lo }); }
      const all = shuffle(options).map(o => ({ cells, ...o }));
      const pick = all.find(c => ambiguous(c, n));
      if (pick) return pick;
      plain++;
      return all[0];
    });
    return plain <= L.maxPlain ? cages : null;
  }
  function generate(levelId) {
    const L = LEVELS[levelId - 1], n = L.size;
    const start = Date.now();
    let fallback = null, best = null;
    for (let attempt = 0; ; attempt++) {
      const solution = randomLatin(n);
      if (L.hell) {
        const cages = hellCages(n, L, solution);
        if (cages) {
          const puzzle = { size: n, cages, givens: new Array(n * n).fill(0), solution, level: levelId };
          const g = grade(puzzle, L.tier[1]);
          if (g && g.tier >= L.tier[0] && g.opening === 0) {
            if (g.steps >= L.enough) return puzzle;
            if (!best || g.steps > best.steps) best = { puzzle, steps: g.steps };
          }
        }
        if (best && Date.now() > start + L.search) return best.puzzle;
        if (Date.now() > start + 30000) throw new Error('calc: could not generate');
        continue;
      }
      const cages = partition(n, L).map(cells => ({ cells, ...chooseOp(cells.map(i => solution[i]), L.ops) }));
      const givens = new Array(n * n).fill(0);
      for (const c of cages) if (c.op === '=') givens[c.cells[0]] = c.target;
      const puzzle = { size: n, cages, givens, solution, level: levelId };
      const g = grade(puzzle, L.tier[1]);
      // 풀이기가 끝까지 풀면 답이 하나뿐이다.
      if (!g) continue;
      if (g.tier >= L.tier[0]) return puzzle;
      if (!fallback || g.tier > fallback.tier) fallback = { puzzle, tier: g.tier };
      if (fallback && Date.now() > start + 3000) return fallback.puzzle;
      if (Date.now() > start + 10000 && attempt > 50) throw new Error('calc: could not generate');
    }
  }

  // 묶음 이름표: "12×", 1칸 묶음은 숫자만
  const label = cage => `${cage.target}${SYMBOL[cage.op]}`;

  root.CalcEngine = { LEVELS, SYMBOL, randomLatin, fits, tuplesOf, check, wrongCages, countSolutions, grade, generate, label, partition, ambiguous };
})(typeof self !== 'undefined' ? self : globalThis);
