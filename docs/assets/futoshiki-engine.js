// 후토시키 규칙과 퍼즐 생성. 앱의 FutoshikiEngine.swift를 그대로 옮겼다. 규칙을 바꾸면 양쪽을 함께 고친다.
// 부등호: 0 없음, 1 왼쪽(위쪽)이 작다, 2 왼쪽(위쪽)이 크다. horizontal[r*n+c]는 (r,c)-(r,c+1), vertical[r*n+c]는 (r,c)-(r+1,c).
(function (root) {
  const LEVELS = [
    { id: 1, name: '초급', size: 4, minTier: 1, maxTier: 1 },
    { id: 2, name: '중급', size: 5, minTier: 1, maxTier: 1 },
    { id: 3, name: '고급', size: 6, minTier: 2, maxTier: 2 },
    { id: 4, name: '전문가', size: 7, minTier: 2, maxTier: 3 },
  ];
  const NONE = 0, LESS = 1, GREATER = 2;

  const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const popcount = m => { let n = 0; while (m) { m &= m - 1; n++; } return n; };
  const lowBit = m => { for (let d = 0; d < 16; d++) if (m & (1 << d)) return d; return 16; };
  const highBit = m => { for (let d = 15; d >= 0; d--) if (m & (1 << d)) return d; return -1; };

  // 부등호로 이어진 쌍 [작은 칸, 큰 칸].
  function relations(n, horizontal, vertical) {
    const out = [];
    for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) {
      const i = r * n + c;
      if (c < n - 1) { if (horizontal[i] === LESS) out.push([i, i + 1]); else if (horizontal[i] === GREATER) out.push([i + 1, i]); }
      if (r < n - 1) { if (vertical[i] === LESS) out.push([i, i + n]); else if (vertical[i] === GREATER) out.push([i + n, i]); }
    }
    return out;
  }

  const linesFor = n => {
    const lines = [];
    for (let r = 0; r < n; r++) lines.push([...Array(n)].map((_, k) => r * n + k));
    for (let c = 0; c < n; c++) lines.push([...Array(n)].map((_, k) => k * n + c));
    return lines;
  };
  const peersFor = n => [...Array(n * n)].map((_, i) => {
    const r = Math.floor(i / n), c = i % n, out = [];
    for (let k = 0; k < n; k++) { if (r * n + k !== i) out.push(r * n + k); if (k * n + c !== i) out.push(k * n + c); }
    return out;
  });

  function randomLatin(n) {
    const g = new Array(n * n).fill(0);
    const fill = i => {
      if (i === n * n) return true;
      const r = Math.floor(i / n), c = i % n, used = new Set();
      for (let k = 0; k < n; k++) { used.add(g[r * n + k]); used.add(g[k * n + c]); }
      for (const d of shuffle([...Array(n)].map((_, k) => k + 1))) {
        if (used.has(d)) continue;
        g[i] = d;
        if (fill(i + 1)) return true;
      }
      g[i] = 0;
      return false;
    };
    fill(0);
    return g;
  }

  // 해의 개수를 limit까지 센다. 한 칸을 정할 때마다 싱글·히든 싱글·부등호 범위를 끝까지 전파한다.
  function countSolutions(n, givens, rel, limit = 2) {
    const cells = n * n, full = (1 << (n + 1)) - 2, lines = linesFor(n), peers = peersFor(n);
    let count = 0;
    function propagate(d) {
      let changed = true;
      while (changed) {
        changed = false;
        for (let i = 0; i < cells; i++) {
          const m = d[i];
          if (!m) return false;
          if (popcount(m) !== 1) continue;
          for (const p of peers[i]) if (d[p] & m) { d[p] &= ~m; if (!d[p]) return false; changed = true; }
        }
        for (const line of lines) {
          for (let digit = 1; digit <= n; digit++) {
            const b = 1 << digit;
            let spot = -1, seen = 0;
            for (const i of line) if (d[i] & b) { spot = i; seen++; if (seen > 1) break; }
            if (!seen) return false;
            if (seen === 1 && d[spot] !== b) { d[spot] = b; changed = true; }
          }
        }
        for (const [s, b] of rel) {
          if (!d[s] || !d[b]) return false;
          const maxB = highBit(d[b]), minS = lowBit(d[s]);
          const keepS = d[s] & ((1 << maxB) - 1);
          const keepB = d[b] & ~((1 << (minS + 1)) - 1);
          if (keepS !== d[s]) { d[s] = keepS; changed = true; }
          if (keepB !== d[b]) { d[b] = keepB; changed = true; }
          if (!d[s] || !d[b]) return false;
        }
      }
      return true;
    }
    function search(start) {
      if (count >= limit) return;
      const d = start.slice();
      if (!propagate(d)) return;
      let best = -1, bestCount = Infinity;
      for (let i = 0; i < cells; i++) {
        const k = popcount(d[i]);
        if (k > 1 && k < bestCount) { best = i; bestCount = k; if (k === 2) break; }
      }
      if (best < 0) { count++; return; }
      for (let digit = 1; digit <= n; digit++) {
        if (!(d[best] & (1 << digit))) continue;
        const next = d.slice();
        next[best] = 1 << digit;
        search(next);
        if (count >= limit) return;
      }
    }
    search(givens.map(v => (v ? 1 << v : full)));
    return count;
  }

  class Logic {
    constructor(n, givens, rel) {
      this.n = n; this.rel = rel; this.values = givens.slice(); this.lines = linesFor(n); this.peers = peersFor(n);
      const all = (1 << (n + 1)) - 2;
      this.cand = givens.map(v => (v ? 0 : all));
      givens.forEach((v, i) => { if (v) this.clearPeers(i, v); });
    }
    clearPeers(i, d) { for (const p of this.peers[i]) this.cand[p] &= ~(1 << d); }
    place(i, d) { this.values[i] = d; this.cand[i] = 0; this.clearPeers(i, d); }
    low(i) { if (this.values[i]) return this.values[i]; for (let d = 1; d <= this.n; d++) if (this.cand[i] & (1 << d)) return d; return this.n + 1; }
    high(i) { if (this.values[i]) return this.values[i]; for (let d = this.n; d >= 1; d--) if (this.cand[i] & (1 << d)) return d; return 0; }

    solve(maxTier) {
      let hardest = 1;
      for (;;) {
        if (!this.values.includes(0)) return hardest;
        for (let i = 0; i < this.n * this.n; i++) if (!this.values[i] && !this.cand[i]) return null;
        if (this.single() || this.bounds()) continue;
        if (maxTier >= 2 && this.subset(2)) { hardest = Math.max(hardest, 2); continue; }
        if (maxTier >= 3 && this.subset(3)) { hardest = 3; continue; }
        return null;
      }
    }

    single() {
      const n = this.n;
      for (let i = 0; i < n * n; i++) {
        if (!this.values[i] && popcount(this.cand[i]) === 1) { this.place(i, lowBit(this.cand[i])); return true; }
      }
      for (const line of this.lines) {
        for (let d = 1; d <= n; d++) {
          const spots = line.filter(i => !this.values[i] && (this.cand[i] & (1 << d)));
          if (spots.length === 1 && !line.some(i => this.values[i] === d)) { this.place(spots[0], d); return true; }
        }
      }
      return false;
    }

    bounds() {
      let changed = false;
      const n = this.n;
      for (const [s, b] of this.rel) {
        if (!this.values[s]) {
          const limit = this.high(b);
          for (let d = Math.max(limit, 1); d <= n; d++) if (this.cand[s] & (1 << d)) { this.cand[s] &= ~(1 << d); changed = true; }
        }
        if (!this.values[b]) {
          const limit = this.low(s);
          for (let d = 1; d <= Math.min(limit, n); d++) if (this.cand[b] & (1 << d)) { this.cand[b] &= ~(1 << d); changed = true; }
        }
      }
      return changed;
    }

    subset(k) {
      const n = this.n;
      for (const line of this.lines) {
        const open = line.filter(i => !this.values[i]);
        if (open.length <= k) continue;
        for (const combo of combos(open.filter(i => { const c = popcount(this.cand[i]); return c >= 2 && c <= k; }), k)) {
          const union = combo.reduce((m, i) => m | this.cand[i], 0);
          if (popcount(union) !== k) continue;
          let changed = false;
          for (const i of open) if (!combo.includes(i) && (this.cand[i] & union)) { this.cand[i] &= ~union; changed = true; }
          if (changed) return true;
        }
        const digits = [];
        for (let d = 1; d <= n; d++) {
          const c = open.filter(i => this.cand[i] & (1 << d)).length;
          if (c >= 2 && c <= k) digits.push(d);
        }
        for (const combo of combos(digits, k)) {
          const mask = combo.reduce((m, d) => m | (1 << d), 0);
          const spots = open.filter(i => this.cand[i] & mask);
          if (spots.length !== k) continue;
          let changed = false;
          for (const i of spots) if (this.cand[i] & ~mask) { this.cand[i] &= mask; changed = true; }
          if (changed) return true;
        }
      }
      return false;
    }
  }

  function combos(items, k) {
    if (items.length < k) return [];
    if (k === 0) return [[]];
    const out = [];
    items.forEach((x, i) => { for (const rest of combos(items.slice(i + 1), k - 1)) out.push([x, ...rest]); });
    return out;
  }

  function grade(n, givens, rel, maxTier = 3) { return new Logic(n, givens, rel).solve(maxTier); }

  function generate(level, attempts = 40) {
    const spec = LEVELS[level - 1], n = spec.size;
    let fallback = null;
    const signOf = (a, b) => (a < b ? LESS : GREATER);
    for (let a = 0; a < attempts; a++) {
      const solution = randomLatin(n);
      const givens = solution.slice();
      const horizontal = new Array(n * n).fill(NONE), vertical = new Array(n * n).fill(NONE);
      const cellSlots = [], signSlots = [];
      for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) {
        const i = r * n + c;
        cellSlots.push(['cell', i]);
        if (c < n - 1) { horizontal[i] = signOf(solution[i], solution[i + 1]); signSlots.push(['h', i]); }
        if (r < n - 1) { vertical[i] = signOf(solution[i], solution[i + n]); signSlots.push(['v', i]); }
      }
      // 숫자 칸을 먼저 지워 부등호가 단서로 남게 한다.
      for (const [kind, i] of shuffle(cellSlots).concat(shuffle(signSlots))) {
        if (kind === 'cell') givens[i] = 0; else if (kind === 'h') horizontal[i] = NONE; else vertical[i] = NONE;
        const rel = relations(n, horizontal, vertical);
        const ok = grade(n, givens, rel, spec.maxTier) != null && countSolutions(n, givens, rel) === 1;
        if (!ok) {
          if (kind === 'cell') givens[i] = solution[i];
          else if (kind === 'h') horizontal[i] = signOf(solution[i], solution[i + 1]);
          else vertical[i] = signOf(solution[i], solution[i + n]);
        }
      }
      const tier = grade(n, givens, relations(n, horizontal, vertical));
      if (tier == null) continue;
      const puzzle = { size: n, givens, solution, horizontal, vertical, level };
      if (tier >= spec.minTier) return puzzle;
      if (!fallback || tier > fallback.tier) fallback = { puzzle, tier };
    }
    return fallback.puzzle;
  }

  root.FutoshikiEngine = { LEVELS, NONE, LESS, GREATER, relations, countSolutions, grade, generate, randomLatin };
})(typeof self !== 'undefined' ? self : globalThis);
