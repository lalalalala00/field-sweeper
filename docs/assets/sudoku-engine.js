// 스도쿠 규칙과 퍼즐 생성. 앱의 SudokuEngine.swift를 그대로 옮겼다. 규칙을 바꾸면 양쪽을 함께 고친다.
// 난이도: 1 초급(싱글), 2 중급(겹침 제외·페어), 3 고급(트리플·X-윙), 4 전문가(XY-윙·소드피시)
(function (root) {
  const LEVELS = [
    { id: 1, name: '초급', minClues: 36, detail: '기본적인 행·열·구역 제외법' },
    { id: 2, name: '중급', minClues: 28, detail: '숫자 후보 비교' },
    { id: 3, name: '고급', minClues: 24, detail: '여러 후보의 연쇄 추론' },
    { id: 4, name: '전문가', minClues: 22, detail: '복잡한 후보 조합과 고급 논리 기법' },
  ];

  const units = [];
  for (let r = 0; r < 9; r++) units.push([...Array(9)].map((_, k) => r * 9 + k));
  for (let c = 0; c < 9; c++) units.push([...Array(9)].map((_, k) => k * 9 + c));
  for (let b = 0; b < 9; b++) {
    const r0 = Math.floor(b / 3) * 3, c0 = (b % 3) * 3;
    units.push([...Array(9)].map((_, k) => (r0 + Math.floor(k / 3)) * 9 + c0 + (k % 3)));
  }
  const box = i => Math.floor(i / 27) * 3 + Math.floor((i % 9) / 3);
  const unitsOf = [...Array(81)].map((_, i) => [Math.floor(i / 9), 9 + (i % 9), 18 + box(i)]);
  const peers = [...Array(81)].map((_, i) => {
    const set = new Set();
    for (const u of unitsOf[i]) for (const k of units[u]) set.add(k);
    set.delete(i);
    return [...set].sort((a, b) => a - b);
  });

  const ALL = 0b1111111110;
  const bit = d => 1 << d;
  const popcount = m => { let n = 0; while (m) { m &= m - 1; n++; } return n; };
  const digitsOf = m => { const out = []; for (let d = 1; d <= 9; d++) if (m & bit(d)) out.push(d); return out; };
  const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

  function combinations(items, k) {
    if (k <= 0) return [[]];
    if (items.length < k) return [];
    const out = [];
    const walk = (start, acc) => {
      if (acc.length === k) { out.push(acc); return; }
      for (let i = start; i <= items.length - (k - acc.length); i++) walk(i + 1, acc.concat([items[i]]));
    };
    walk(0, []);
    return out;
  }

  // ── 정답 개수 세기 ──
  function countSolutions(grid, limit = 2) {
    const g = grid.slice();
    let count = 0;
    for (let i = 0; i < 81; i++) if (g[i] && peers[i].some(p => g[p] === g[i])) return 0;
    const cand = i => { let used = 0; for (const p of peers[i]) if (g[p]) used |= bit(g[p]); return ALL & ~used; };
    function search() {
      if (count >= limit) return;
      let best = -1, bestMask = 0, bestCount = 10;
      for (let i = 0; i < 81; i++) {
        if (g[i]) continue;
        const m = cand(i), n = popcount(m);
        if (n === 0) return;
        if (n < bestCount) { best = i; bestMask = m; bestCount = n; if (n === 1) break; }
      }
      if (best < 0) { count++; return; }
      for (const d of digitsOf(bestMask)) {
        g[best] = d;
        search();
        if (count >= limit) break;
      }
      g[best] = 0;
    }
    search();
    return count;
  }

  // ── 생성 ──
  function randomSolution() {
    const g = new Array(81).fill(0);
    const fill = i => {
      if (i === 81) return true;
      let used = 0;
      for (const p of peers[i]) if (g[p]) used |= bit(g[p]);
      for (const d of shuffle(digitsOf(ALL & ~used))) { g[i] = d; if (fill(i + 1)) return true; }
      g[i] = 0;
      return false;
    };
    fill(0);
    return g;
  }

  // 정답이 하나뿐이고 추측 없이 풀리는 퍼즐. 목표 난이도가 안 나오면 그보다 쉬운 것 중 가장 어려운 것.
  // 웹은 앱보다 느리므로 시간 한도(budgetMs)가 지나면 그때까지 나온 것 중에서 고른다.
  function generate(level, attempts = 400, budgetMs = 6000) {
    const spec = LEVELS[level - 1];
    const deadline = Date.now() + budgetMs;
    let fallback = null;
    for (let a = 0; a < attempts; a++) {
      if (fallback && Date.now() > deadline) break;
      const solution = randomSolution();
      const puzzle = solution.slice();
      let clues = 81;
      for (const i of shuffle([...Array(81).keys()])) {
        if (clues <= spec.minClues) break;
        const saved = puzzle[i];
        puzzle[i] = 0;
        const g = countSolutions(puzzle) === 1 ? grade(puzzle) : null;
        if (g != null && g <= level) clues--; else puzzle[i] = saved;
      }
      const g = grade(puzzle);
      if (g == null) continue;
      const cand = { givens: puzzle, solution, level: g };
      if (g === level) return cand;
      if (!fallback || g > fallback.level) fallback = cand;
    }
    return fallback || generate(1, 1, budgetMs);
  }

  // ── 논리 풀이 ──
  function grade(grid) { return new LogicSolver(grid).solve(); }

  class LogicSolver {
    constructor(grid) {
      this.values = grid.slice();
      this.cand = new Array(81).fill(0);
      for (let i = 0; i < 81; i++) {
        if (this.values[i]) continue;
        let used = 0;
        for (const p of peers[i]) if (this.values[p]) used |= bit(this.values[p]);
        this.cand[i] = ALL & ~used;
      }
    }

    solve() {
      let hardest = 1;
      for (;;) {
        if (!this.values.includes(0)) return hardest;
        for (let i = 0; i < 81; i++) if (!this.values[i] && !this.cand[i]) return null;
        if (this.nakedSingle() || this.hiddenSingle()) continue;
        if (this.lockedCandidates() || this.nakedSubset(2) || this.hiddenSubset(2)) { hardest = Math.max(hardest, 2); continue; }
        if (this.nakedSubset(3) || this.hiddenSubset(3) || this.fish(2)) { hardest = Math.max(hardest, 3); continue; }
        if (this.xyWing() || this.fish(3)) { hardest = 4; continue; }
        return null;
      }
    }

    place(i, d) {
      this.values[i] = d;
      this.cand[i] = 0;
      for (const p of peers[i]) this.cand[p] &= ~bit(d);
    }

    eliminate(mask, i) {
      if (this.values[i] || !(this.cand[i] & mask)) return false;
      this.cand[i] &= ~mask;
      return true;
    }

    nakedSingle() {
      for (let i = 0; i < 81; i++) {
        if (!this.values[i] && popcount(this.cand[i]) === 1) { this.place(i, digitsOf(this.cand[i])[0]); return true; }
      }
      return false;
    }

    hiddenSingle() {
      for (const unit of units) {
        for (let d = 1; d <= 9; d++) {
          let spot = -1, n = 0;
          for (const i of unit) if (!this.values[i] && (this.cand[i] & bit(d))) { spot = i; n++; }
          if (n === 1) { this.place(spot, d); return true; }
        }
      }
      return false;
    }

    // 구역 안의 후보가 한 줄에만 있으면 그 줄의 다른 구역에서 지운다(포인팅), 반대도 마찬가지(클레이밍).
    lockedCandidates() {
      let changed = false;
      for (let d = 1; d <= 9; d++) {
        for (let u = 0; u < units.length; u++) {
          const unit = units[u];
          const spots = unit.filter(i => !this.values[i] && (this.cand[i] & bit(d)));
          if (spots.length < 2) continue;
          const targets = [];
          if (u >= 18) {
            if (new Set(spots.map(i => Math.floor(i / 9))).size === 1) targets.push(units[Math.floor(spots[0] / 9)]);
            if (new Set(spots.map(i => i % 9)).size === 1) targets.push(units[9 + (spots[0] % 9)]);
          } else if (new Set(spots.map(box)).size === 1) {
            targets.push(units[18 + box(spots[0])]);
          }
          for (const target of targets) {
            for (const i of target) if (!unit.includes(i)) changed = this.eliminate(bit(d), i) || changed;
          }
          if (changed) return true;
        }
      }
      return false;
    }

    nakedSubset(k) {
      for (const unit of units) {
        const open = unit.filter(i => { const n = popcount(this.cand[i]); return !this.values[i] && n >= 2 && n <= k; });
        if (open.length < k) continue;
        for (const combo of combinations(open, k)) {
          const union = combo.reduce((m, i) => m | this.cand[i], 0);
          if (popcount(union) !== k) continue;
          let changed = false;
          for (const i of unit) if (!combo.includes(i)) changed = this.eliminate(union, i) || changed;
          if (changed) return true;
        }
      }
      return false;
    }

    hiddenSubset(k) {
      for (const unit of units) {
        const digits = [];
        for (let d = 1; d <= 9; d++) {
          const n = unit.filter(i => !this.values[i] && (this.cand[i] & bit(d))).length;
          if (n >= 2 && n <= k) digits.push(d);
        }
        if (digits.length < k) continue;
        for (const combo of combinations(digits, k)) {
          const mask = combo.reduce((m, d) => m | bit(d), 0);
          const spots = unit.filter(i => !this.values[i] && (this.cand[i] & mask));
          if (spots.length !== k) continue;
          let changed = false;
          for (const i of spots) changed = this.eliminate(~mask & ALL, i) || changed;
          if (changed) return true;
        }
      }
      return false;
    }

    // X-윙(n=2), 소드피시(n=3).
    fish(n) {
      for (let d = 1; d <= 9; d++) {
        for (const byRow of [true, false]) {
          const lines = [];
          for (let line = 0; line < 9; line++) {
            const spots = new Set();
            for (let k = 0; k < 9; k++) {
              const i = byRow ? line * 9 + k : k * 9 + line;
              if (!this.values[i] && (this.cand[i] & bit(d))) spots.add(k);
            }
            if (spots.size >= 2 && spots.size <= n) lines.push({ line, spots });
          }
          if (lines.length < n) continue;
          for (const combo of combinations([...lines.keys()], n)) {
            const cover = new Set();
            for (const x of combo) for (const k of lines[x].spots) cover.add(k);
            if (cover.size !== n) continue;
            const base = new Set(combo.map(x => lines[x].line));
            let changed = false;
            for (const k of cover) {
              for (let line = 0; line < 9; line++) {
                if (base.has(line)) continue;
                const i = byRow ? line * 9 + k : k * 9 + line;
                changed = this.eliminate(bit(d), i) || changed;
              }
            }
            if (changed) return true;
          }
        }
      }
      return false;
    }

    xyWing() {
      const pairs = [];
      for (let i = 0; i < 81; i++) if (!this.values[i] && popcount(this.cand[i]) === 2) pairs.push(i);
      for (const pivot of pairs) {
        const ab = this.cand[pivot];
        const wings = peers[pivot].filter(i => !this.values[i] && popcount(this.cand[i]) === 2 && popcount(this.cand[i] & ab) === 1);
        for (let x = 0; x < wings.length; x++) {
          for (let y = x + 1; y < wings.length; y++) {
            const w1 = wings[x], w2 = wings[y];
            const c1 = this.cand[w1], c2 = this.cand[w2];
            if (c1 === c2 || (c1 & ab) === (c2 & ab)) continue;
            const c = c1 & c2 & ~ab;
            if (popcount(c) !== 1) continue;
            let changed = false;
            const p2 = new Set(peers[w2]);
            for (const i of peers[w1]) if (p2.has(i) && i !== pivot) changed = this.eliminate(c, i) || changed;
            if (changed) return true;
          }
        }
      }
      return false;
    }
  }

  root.SudokuEngine = { LEVELS, units, peers, box, countSolutions, generate, grade };
})(typeof self !== 'undefined' ? self : globalThis);
