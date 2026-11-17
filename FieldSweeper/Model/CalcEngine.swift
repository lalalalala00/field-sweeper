import Foundation

/// 셈네모 난이도. 판 크기, 쓸 수 있는 연산, 묶음 크기, 풀이에 필요한 추리 단계로 정한다.
/// 웹 docs/assets/calc-engine.js와 같은 규칙이다. 규칙을 바꾸면 양쪽을 함께 고친다.
enum CalcLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
    case easy = 1, medium, hard, expert

    var id: Int { rawValue }
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .easy: "초급"
        case .medium: "중급"
        case .hard: "고급"
        case .expert: "전문가"
        }
    }

    var size: Int {
        switch self {
        case .easy: 4
        case .medium: 5
        case .hard: 6
        case .expert: 7
        }
    }

    var ops: [CalcOp] {
        switch self {
        case .easy: [.add, .sub]
        case .medium: [.add, .sub, .mul]
        case .hard, .expert: [.add, .sub, .mul, .div]
        }
    }

    /// 묶음 크기를 고르는 가중치(1칸, 2칸, 3칸, …).
    var sizes: [Int] {
        switch self {
        case .easy: [0, 5, 3]
        case .medium: [0, 5, 4, 1]
        case .hard: [0, 4, 4, 2]
        case .expert: [0, 3, 4, 3, 1]
        }
    }

    /// 1칸 묶음(주어진 숫자)의 최대 개수.
    var maxSingles: Int { self <= .medium ? 2 : 1 }

    /// 사람처럼 푸는 풀이기(CalcEngine.grade)로 풀 때 필요한 가장 어려운 추리 단계의 범위.
    var tier: ClosedRange<Int> {
        switch self {
        case .easy, .medium: 1...1
        case .hard: 2...2
        case .expert: 3...3
        }
    }
}

/// 묶음 연산. equal은 1칸 묶음(숫자가 그대로 주어진 칸)이다.
enum CalcOp: String, Codable {
    case add = "+", sub = "-", mul = "*", div = "/", equal = "="

    /// 화면에 쓰는 기호
    var symbol: String {
        switch self {
        case .add: "+"
        case .sub: "−"
        case .mul: "×"
        case .div: "÷"
        case .equal: ""
        }
    }
}

struct CalcCage: Codable, Equatable {
    /// 칸 번호(작은 순). 첫 칸이 이름표를 쓰는 왼쪽 위 칸이다.
    var cells: [Int]
    var op: CalcOp
    var target: Int

    /// 묶음 이름표: "12×", 1칸 묶음은 숫자만
    var label: String { "\(target)\(op.symbol)" }
}

struct CalcPuzzle: Codable, Equatable {
    var size: Int
    var cages: [CalcCage]
    /// 1칸 묶음의 숫자. 나머지는 0.
    var givens: [Int]
    var solution: [Int]
    var level: CalcLevel
}

enum CalcEngine {
    /// 묶음 값이 목표와 맞는지. values는 묶음 칸 순서대로의 숫자.
    static func fits(_ op: CalcOp, _ target: Int, _ values: [Int]) -> Bool {
        switch op {
        case .equal: return values[0] == target
        case .add: return values.reduce(0, +) == target
        case .mul: return values.reduce(1, *) == target
        case .sub, .div:
            let hi = max(values[0], values[1]), lo = min(values[0], values[1])
            return op == .sub ? hi - lo == target : hi == lo * target
        }
    }

    /// 묶음에 들어갈 수 있는 숫자 조합(칸 순서대로). 같은 줄의 두 칸은 같은 숫자일 수 없다.
    static func tuples(of cage: CalcCage, size n: Int) -> [[Int]] {
        let cells = cage.cells, k = cells.count
        let clash = (0..<k).map { a in (0..<a).filter { b in cells[a] / n == cells[b] / n || cells[a] % n == cells[b] % n } }
        var out: [[Int]] = [], cur = Array(repeating: 0, count: k)
        func walk(_ a: Int) {
            if a == k { if fits(cage.op, cage.target, cur) { out.append(cur) }; return }
            for v in 1...n where !clash[a].contains(where: { cur[$0] == v }) {
                cur[a] = v
                walk(a + 1)
            }
        }
        walk(0)
        return out
    }

    /// 판정: 모든 칸이 차 있고, 줄마다 숫자가 겹치지 않고, 모든 묶음 계산이 맞는지.
    static func check(_ p: CalcPuzzle, values: [Int]) -> Bool {
        let n = p.size
        if values.contains(0) { return false }
        for k in 0..<n {
            if Set((0..<n).map { values[k * n + $0] }).count != n || Set((0..<n).map { values[$0 * n + k] }).count != n { return false }
        }
        return p.cages.allSatisfy { c in fits(c.op, c.target, c.cells.map { values[$0] }) }
    }

    /// 다 채웠는데 계산이 틀린 묶음들의 번호
    static func wrongCages(_ p: CalcPuzzle, values: [Int]) -> [Int] {
        p.cages.indices.filter { k in
            let c = p.cages[k], vs = c.cells.map { values[$0] }
            return !vs.contains(0) && !fits(c.op, c.target, vs)
        }
    }

    /// 답을 limit까지 센다(시험용). 묶음 단위로 조합을 골라 넣는다.
    static func countSolutions(_ p: CalcPuzzle, limit: Int = 2) -> Int {
        let n = p.size, cages = p.cages, all = cages.map { tuples(of: $0, size: n) }
        var rowUsed = Array(repeating: 0, count: n), colUsed = Array(repeating: 0, count: n)
        var done = Array(repeating: false, count: cages.count), count = 0
        func ok(_ c: Int, _ t: [Int]) -> Bool {
            cages[c].cells.indices.allSatisfy { a in let i = cages[c].cells[a]; return (rowUsed[i / n] | colUsed[i % n]) & (1 << t[a]) == 0 }
        }
        func put(_ c: Int, _ t: [Int]) {
            for (a, i) in cages[c].cells.enumerated() { rowUsed[i / n] ^= 1 << t[a]; colUsed[i % n] ^= 1 << t[a] }
        }
        func solve() {
            if count >= limit { return }
            var best = -1, bestList: [[Int]] = []
            for c in cages.indices where !done[c] {
                let list = all[c].filter { ok(c, $0) }
                if list.isEmpty { return }
                if best < 0 || list.count < bestList.count { best = c; bestList = list }
            }
            if best < 0 { count += 1; return }
            done[best] = true
            for t in bestList {
                put(best, t); solve(); put(best, t)
                if count >= limit { break }
            }
            done[best] = false
        }
        solve()
        return count
    }

    // MARK: 난이도: 사람처럼 푸는 풀이기
    // 칸마다 후보(비트마스크)를 두고 아래 추리로 지워 나간다. 쉬운 단계부터 쓰고, 막힐 때만 다음 단계를 쓴다.
    //  1단계 묶음 계산: 묶음의 가능한 조합으로 칸 후보를 줄인다. 후보가 하나뿐인 칸, 줄에서 한 자리만 남은 숫자를 넣는다.
    //  2단계 줄의 짝: 한 줄에서 두 칸이 같은 두 후보만 가지면 나머지 칸에서 그 둘을 지운다.
    //        묶음이 꼭 쓰는 숫자: 묶음의 모든 조합에 들어 있는 숫자가 한 줄 안에만 놓일 수 있으면 그 줄의 다른 칸에서 지운다.
    //  3단계 줄의 셋: 세 칸에 세 후보(naked triple), 줄에서 두 숫자가 같은 두 칸에만 갈 수 있음(hidden pair).
    // 끝까지 풀리면 (쓴 가장 어려운 단계, 2단계 이상을 쓴 횟수), 막히면 nil. 끝까지 풀리면 답이 하나뿐이다.
    static func grade(_ p: CalcPuzzle, maxTier: Int = 3) -> (tier: Int, steps: Int)? {
        let n = p.size, cellCount = n * n, full = ((1 << n) - 1) << 1
        let cages = p.cages
        var tuples = cages.map { self.tuples(of: $0, size: n) }
        var cand = Array(repeating: full, count: cellCount)
        var lines: [[Int]] = []
        for k in 0..<n {
            lines.append((0..<n).map { k * n + $0 })
            lines.append((0..<n).map { $0 * n + k })
        }
        func lineOf(_ i: Int, row: Bool) -> [Int] { lines[row ? (i / n) * 2 : (i % n) * 2 + 1] }
        func pop(_ m: Int) -> Int { m.nonzeroBitCount }
        var tier = 0, steps = 0

        // 묶음 조합을 지금 후보에 맞게 거르고, 칸 후보를 조합에 나오는 숫자로 줄인다. 조합이 없으면 nil.
        func cagePass() -> Bool? {
            var changed = false
            for c in cages.indices {
                let cells = cages[c].cells
                tuples[c] = tuples[c].filter { t in t.indices.allSatisfy { cand[cells[$0]] & (1 << t[$0]) != 0 } }
                if tuples[c].isEmpty { return nil }
                for (a, i) in cells.enumerated() {
                    var m = 0
                    for t in tuples[c] { m |= 1 << t[a] }
                    if cand[i] & m != cand[i] { cand[i] &= m; changed = true }
                }
            }
            return changed
        }
        func singles() -> Bool {
            var changed = false
            for i in 0..<cellCount where pop(cand[i]) == 1 {
                for line in [lineOf(i, row: true), lineOf(i, row: false)] {
                    for j in line where j != i && cand[j] & cand[i] != 0 { cand[j] &= ~cand[i]; changed = true }
                }
            }
            for line in lines {
                for v in 1...n {
                    let at = line.filter { cand[$0] & (1 << v) != 0 }
                    if at.count == 1 && cand[at[0]] != 1 << v { cand[at[0]] = 1 << v; changed = true }
                }
            }
            return changed
        }
        func nakedSubsets(_ size: Int) -> Bool {
            var changed = false
            for line in lines {
                let open = line.filter { pop(cand[$0]) > 1 && pop(cand[$0]) <= size }
                func pick(_ from: Int, _ chosen: [Int], _ mask: Int) {
                    if chosen.count == size {
                        if pop(mask) != size { return }
                        for j in line where !chosen.contains(j) && cand[j] & mask != 0 { cand[j] &= ~mask; changed = true }
                        return
                    }
                    if from < open.count { for k in from..<open.count { pick(k + 1, chosen + [open[k]], mask | cand[open[k]]) } }
                }
                pick(0, [], 0)
            }
            return changed
        }
        func hiddenPairs() -> Bool {
            var changed = false
            for line in lines {
                var at = Array(repeating: [Int](), count: n + 1)
                for v in 1...n { at[v] = line.filter { cand[$0] & (1 << v) != 0 } }
                for a in 1...n { for b in (a + 1)..<(n + 1) {
                    guard at[a].count == 2, at[b].count == 2, at[a] == at[b] else { continue }
                    let keep = (1 << a) | (1 << b)
                    for i in at[a] where cand[i] & ~keep != 0 { cand[i] &= keep; changed = true }
                } }
            }
            return changed
        }
        func cageMusts() -> Bool {
            var changed = false
            for c in cages.indices {
                let cells = cages[c].cells
                if cells.count < 2 { continue }
                for v in 1...n where tuples[c].allSatisfy({ $0.contains(v) }) {
                    let at = cells.indices.filter { a in tuples[c].contains { $0[a] == v } }.map { cells[$0] }
                    for row in [true, false] {
                        func key(_ i: Int) -> Int { row ? i / n : i % n }
                        guard at.allSatisfy({ key($0) == key(at[0]) }) else { continue }
                        for j in lineOf(at[0], row: row) where !cells.contains(j) && cand[j] & (1 << v) != 0 {
                            cand[j] &= ~(1 << v); changed = true
                        }
                    }
                }
            }
            return changed
        }

        for _ in 0..<1000 {
            guard let cp = cagePass() else { return nil }
            if cand.contains(0) { return nil }
            if cp || singles() { tier = max(tier, 1); continue }
            if cand.allSatisfy({ pop($0) == 1 }) {
                let values = cand.map { $0.trailingZeroBitCount }
                return check(p, values: values) ? (tier, steps) : nil
            }
            if maxTier >= 2 && (nakedSubsets(2) || cageMusts()) { tier = max(tier, 2); steps += 1; continue }
            if maxTier >= 3 && (nakedSubsets(3) || hiddenPairs()) { tier = 3; steps += 1; continue }
            return nil
        }
        return nil
    }

    // MARK: 생성
    // 1. 정답 라틴 방진을 만든다. 2. 칸을 무작위 순서로 돌며 이웃으로 묶음을 키운다.
    // 3. 묶음마다 연산을 고른다. 4. 풀이기로 난이도를 재서 범위에 맞는 판만 낸다(끝까지 풀리면 답이 하나뿐이다).
    static func randomLatin<R: RandomNumberGenerator>(_ n: Int, using rng: inout R) -> [Int] {
        let rows = Array(0..<n).shuffled(using: &rng), cols = Array(0..<n).shuffled(using: &rng)
        let map = [0] + Array(1...n).shuffled(using: &rng)
        var out = Array(repeating: 0, count: n * n)
        for r in 0..<n { for c in 0..<n { out[r * n + c] = map[((rows[r] + cols[c]) % n) + 1] } }
        return out
    }

    static func neighbors(_ i: Int, size n: Int) -> [Int] {
        let r = i / n, c = i % n
        var out: [Int] = []
        if r > 0 { out.append(i - n) }
        if r < n - 1 { out.append(i + n) }
        if c > 0 { out.append(i - 1) }
        if c < n - 1 { out.append(i + 1) }
        return out
    }

    private static func partition<R: RandomNumberGenerator>(_ level: CalcLevel, using rng: inout R) -> [[Int]] {
        let n = level.size, weights = level.sizes, total = weights.reduce(0, +)
        var owner = Array(repeating: -1, count: n * n)
        var cages: [[Int]?] = []
        func pickSize() -> Int {
            var r = Int.random(in: 0..<total, using: &rng)
            for (s, w) in weights.enumerated() { if r < w { return s + 1 }; r -= w }
            return 2
        }
        for s in Array(0..<(n * n)).shuffled(using: &rng) where owner[s] == -1 {
            let id = cages.count, want = pickSize()
            var cells = [s]
            owner[s] = id
            while cells.count < want {
                var options: [Int] = []
                for c in cells { for j in neighbors(c, size: n) where owner[j] == -1 && !options.contains(j) { options.append(j) } }
                guard let j = options.randomElement(using: &rng) else { break }
                owner[j] = id
                cells.append(j)
            }
            cages.append(cells)
        }
        // 1칸 묶음이 너무 많으면 이웃 묶음(최대 크기 미만)에 붙인다.
        var singles = cages.filter { $0?.count == 1 }.count
        for k in cages.indices where singles > level.maxSingles {
            guard let c = cages[k], c.count == 1 else { continue }
            let near = neighbors(c[0], size: n).map { owner[$0] }.filter { $0 != k && (cages[$0]?.count ?? .max) < weights.count }
            guard let o = near.randomElement(using: &rng) else { continue }
            cages[o]!.append(c[0]); owner[c[0]] = o; cages[k] = nil; singles -= 1
        }
        return cages.compactMap { $0?.sorted() }
    }

    private static func chooseOp<R: RandomNumberGenerator>(_ values: [Int], _ ops: [CalcOp], using rng: inout R) -> (CalcOp, Int) {
        if values.count == 1 { return (.equal, values[0]) }
        if values.count == 2 {
            let hi = values.max()!, lo = values.min()!
            if ops.contains(.div) && hi % lo == 0 && Double.random(in: 0..<1, using: &rng) < 0.5 { return (.div, hi / lo) }
            if ops.contains(.sub) && Double.random(in: 0..<1, using: &rng) < 0.45 { return (.sub, hi - lo) }
        }
        if ops.contains(.mul) && Double.random(in: 0..<1, using: &rng) < 0.45 { return (.mul, values.reduce(1, *)) }
        return (.add, values.reduce(0, +))
    }

    static func generate<R: RandomNumberGenerator>(_ level: CalcLevel, using rng: inout R) -> CalcPuzzle {
        let n = level.size, start = Date()
        var fallback: (puzzle: CalcPuzzle, tier: Int)?
        while true {
            let solution = randomLatin(n, using: &rng)
            let cages = partition(level, using: &rng).map { cells -> CalcCage in
                let (op, target) = chooseOp(cells.map { solution[$0] }, level.ops, using: &rng)
                return CalcCage(cells: cells, op: op, target: target)
            }
            var givens = Array(repeating: 0, count: n * n)
            for c in cages where c.op == .equal { givens[c.cells[0]] = c.target }
            let puzzle = CalcPuzzle(size: n, cages: cages, givens: givens, solution: solution, level: level)
            guard let g = grade(puzzle, maxTier: level.tier.upperBound) else { continue }
            if g.tier >= level.tier.lowerBound { return puzzle }
            if fallback.map({ g.tier > $0.tier }) ?? true { fallback = (puzzle, g.tier) }
            if let fallback, Date().timeIntervalSince(start) > 3 { return fallback.puzzle }
        }
    }
}
