import Foundation

/// 후토시키 난이도. 판 크기와, 풀이에 필요한 기법으로 정한다.
enum FutoshikiLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
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

    /// 처음에 남겨 둘 숫자의 최소 개수. 숫자가 하나도 없으면 부등호 사슬부터 읽어야 해서
    /// 처음 하는 사람에게 막막하므로, 쉬운 난이도에는 시작할 숫자를 남긴다.
    fileprivate var minGivens: Int {
        switch self {
        case .easy: 4
        case .medium: 2
        case .hard: 1
        case .expert: 0
        }
    }

    /// 적어도 이 단계의 기법이 필요한 문제를 고른다.
    fileprivate var minTier: Int {
        switch self {
        case .easy, .medium: 1
        case .hard: 2
        case .expert: 3
        }
    }

    /// 허용하는 가장 어려운 기법 단계. 1: 싱글과 부등호 범위, 2: 페어, 3: 트리플.
    fileprivate var maxTier: Int {
        switch self {
        case .easy, .medium: 1
        case .hard: 2
        case .expert: 3
        }
    }
}

/// 이웃한 두 칸 사이의 부등호. 가로는 왼쪽 기준, 세로는 위쪽 기준이다.
enum FutoshikiSign: Int, Codable {
    case none = 0
    /// 왼쪽(위쪽)이 더 작다.
    case less
    /// 왼쪽(위쪽)이 더 크다.
    case greater
}

struct FutoshikiPuzzle: Codable, Equatable {
    var size: Int
    /// n×n, 0은 빈칸.
    var givens: [Int]
    var solution: [Int]
    /// (r, c)와 (r, c+1) 사이. 인덱스 r * n + c, c는 0…n-2.
    var horizontal: [FutoshikiSign]
    /// (r, c)와 (r+1, c) 사이. 인덱스 r * n + c, r은 0…n-2.
    var vertical: [FutoshikiSign]
    var level: FutoshikiLevel

    /// 부등호로 이어진 쌍 (작은 칸, 큰 칸).
    var relations: [(small: Int, big: Int)] { FutoshikiEngine.relations(size: size, horizontal: horizontal, vertical: vertical) }
}

enum FutoshikiEngine {
    static func relations(size n: Int, horizontal: [FutoshikiSign], vertical: [FutoshikiSign]) -> [(small: Int, big: Int)] {
        var out: [(Int, Int)] = []
        for r in 0..<n {
            for c in 0..<n {
                let i = r * n + c
                if c < n - 1 {
                    switch horizontal[i] {
                    case .less: out.append((i, i + 1))
                    case .greater: out.append((i + 1, i))
                    case .none: break
                    }
                }
                if r < n - 1 {
                    switch vertical[i] {
                    case .less: out.append((i, i + n))
                    case .greater: out.append((i + n, i))
                    case .none: break
                    }
                }
            }
        }
        return out
    }

    // MARK: 정답판

    /// 가로·세로에 1…n이 한 번씩 들어간 무작위 판.
    static func randomLatin<R: RandomNumberGenerator>(size n: Int, using rng: inout R) -> [Int] {
        var g = Array(repeating: 0, count: n * n)
        func fill(_ i: Int) -> Bool {
            if i == n * n { return true }
            let r = i / n, c = i % n
            var used = Set<Int>()
            for k in 0..<n { used.insert(g[r * n + k]); used.insert(g[k * n + c]) }
            for d in (1...n).shuffled(using: &rng) where !used.contains(d) {
                g[i] = d
                if fill(i + 1) { return true }
            }
            g[i] = 0
            return false
        }
        _ = fill(0)
        return g
    }

    // MARK: 해 개수

    /// 해의 개수를 limit까지 센다. 칸마다 후보를 비트로 들고, 한 칸을 정할 때마다
    /// 싱글·히든 싱글·부등호 범위를 끝까지 전파해서 탐색을 줄인다.
    static func countSolutions(size n: Int, givens: [Int], relations: [(small: Int, big: Int)], limit: Int = 2) -> Int {
        let cells = n * n
        let full = UInt16((1 << (n + 1)) - 2)
        var lines: [[Int]] = []
        for r in 0..<n { lines.append((0..<n).map { r * n + $0 }) }
        for c in 0..<n { lines.append((0..<n).map { $0 * n + c }) }
        let peers: [[Int]] = (0..<cells).map { i in
            let r = i / n, c = i % n
            return (0..<n).flatMap { [r * n + $0, $0 * n + c] }.filter { $0 != i }
        }
        var count = 0

        func propagate(_ d: inout [UInt16]) -> Bool {
            var changed = true
            while changed {
                changed = false
                for i in 0..<cells {
                    let m = d[i]
                    if m == 0 { return false }
                    guard m.nonzeroBitCount == 1 else { continue }
                    for p in peers[i] where d[p] & m != 0 {
                        d[p] &= ~m
                        if d[p] == 0 { return false }
                        changed = true
                    }
                }
                for line in lines {
                    for digit in 1...n {
                        let bit = UInt16(1) << UInt16(digit)
                        var spot = -1, seen = 0
                        for i in line where d[i] & bit != 0 { spot = i; seen += 1; if seen > 1 { break } }
                        if seen == 0 { return false }
                        if seen == 1 && d[spot] != bit { d[spot] = bit; changed = true }
                    }
                }
                for (s, b) in relations {
                    // 작은 칸은 큰 칸의 최댓값보다 작고, 큰 칸은 작은 칸의 최솟값보다 크다.
                    let maxB = 15 - d[b].leadingZeroBitCount
                    let minS = d[s].trailingZeroBitCount
                    let keepS = d[s] & UInt16((1 << maxB) - 1)
                    let keepB = d[b] & ~UInt16((1 << (minS + 1)) - 1)
                    if keepS != d[s] { d[s] = keepS; changed = true }
                    if keepB != d[b] { d[b] = keepB; changed = true }
                    if d[s] == 0 || d[b] == 0 { return false }
                }
            }
            return true
        }

        func search(_ start: [UInt16]) {
            if count >= limit { return }
            var d = start
            guard propagate(&d) else { return }
            var best = -1, bestCount = Int.max
            for i in 0..<cells {
                let k = d[i].nonzeroBitCount
                if k > 1 && k < bestCount { best = i; bestCount = k; if k == 2 { break } }
            }
            if best < 0 { count += 1; return }
            for digit in 1...n where d[best] & (1 << UInt16(digit)) != 0 {
                var next = d
                next[best] = 1 << UInt16(digit)
                search(next)
                if count >= limit { return }
            }
        }

        search(givens.map { $0 == 0 ? full : UInt16(1) << UInt16($0) })
        return count
    }

    // MARK: 논리 풀이

    /// 사람이 쓰는 기법으로 풀어 보고 필요했던 가장 어려운 단계(1…3)를 돌려준다. 막히면 nil.
    static func grade(size n: Int, givens: [Int], relations: [(small: Int, big: Int)], maxTier: Int = 3) -> Int? {
        var solver = FutoshikiLogic(size: n, givens: givens, relations: relations)
        return solver.solve(maxTier: maxTier)
    }

    static func logicalSolution(size n: Int, givens: [Int], relations: [(small: Int, big: Int)]) -> [Int]? {
        var solver = FutoshikiLogic(size: n, givens: givens, relations: relations)
        return solver.solve(maxTier: 3) == nil ? nil : solver.values
    }

    // MARK: 생성

    static func generate<R: RandomNumberGenerator>(_ level: FutoshikiLevel, attempts: Int = 40, using rng: inout R) -> FutoshikiPuzzle {
        let n = level.size
        var fallback: (puzzle: FutoshikiPuzzle, tier: Int)?
        for _ in 0..<attempts {
            let solution = randomLatin(size: n, using: &rng)
            var givens = solution
            var horizontal = Array(repeating: FutoshikiSign.none, count: n * n)
            var vertical = Array(repeating: FutoshikiSign.none, count: n * n)
            for r in 0..<n {
                for c in 0..<n {
                    let i = r * n + c
                    if c < n - 1 { horizontal[i] = solution[i] < solution[i + 1] ? .less : .greater }
                    if r < n - 1 { vertical[i] = solution[i] < solution[i + n] ? .less : .greater }
                }
            }

            // 지울 수 있는 단서: 숫자 칸과 부등호 자리.
            var clues: [FutoshikiClueSlot] = (0..<(n * n)).map { .cell($0) }
            for r in 0..<n { for c in 0..<n {
                if c < n - 1 { clues.append(.h(r * n + c)) }
                if r < n - 1 { clues.append(.v(r * n + c)) }
            } }

            // 숫자 칸을 먼저 지워 부등호가 단서로 남게 한다.
            let cellSlots = clues.filter { if case .cell = $0 { true } else { false } }
            let signSlots = clues.filter { if case .cell = $0 { false } else { true } }
            var left = n * n
            for clue in cellSlots.shuffled(using: &rng) + signSlots.shuffled(using: &rng) {
                if case .cell = clue, left <= level.minGivens { continue }
                switch clue {
                case .cell(let i): givens[i] = 0
                case .h(let i): horizontal[i] = .none
                case .v(let i): vertical[i] = .none
                }
                let rel = relations(size: n, horizontal: horizontal, vertical: vertical)
                let ok = grade(size: n, givens: givens, relations: rel, maxTier: level.maxTier) != nil
                    && countSolutions(size: n, givens: givens, relations: rel) == 1
                if ok, case .cell = clue { left -= 1 }
                if !ok {
                    switch clue {
                    case .cell(let i): givens[i] = solution[i]
                    case .h(let i): horizontal[i] = solution[i] < solution[i + 1] ? .less : .greater
                    case .v(let i): vertical[i] = solution[i] < solution[i + n] ? .less : .greater
                    }
                }
            }

            let rel = relations(size: n, horizontal: horizontal, vertical: vertical)
            guard let tier = grade(size: n, givens: givens, relations: rel) else { continue }
            let puzzle = FutoshikiPuzzle(size: n, givens: givens, solution: solution,
                                         horizontal: horizontal, vertical: vertical, level: level)
            if tier >= level.minTier { return puzzle }
            if fallback.map({ tier > $0.tier }) ?? true { fallback = (puzzle, tier) }
        }
        return fallback!.puzzle
    }
}

private enum FutoshikiClueSlot { case cell(Int), h(Int), v(Int) }

/// 후보를 비트로 들고 기법을 하나씩 적용하는 풀이기.
private struct FutoshikiLogic {
    let n: Int
    var values: [Int]
    var cand: [UInt16]
    let relations: [(small: Int, big: Int)]
    let lines: [[Int]]

    init(size n: Int, givens: [Int], relations: [(small: Int, big: Int)]) {
        self.n = n
        self.relations = relations
        values = givens
        var lines: [[Int]] = []
        for r in 0..<n { lines.append((0..<n).map { r * n + $0 }) }
        for c in 0..<n { lines.append((0..<n).map { $0 * n + c }) }
        self.lines = lines
        let all = UInt16((1 << (n + 1)) - 2)
        cand = givens.map { $0 == 0 ? all : 0 }
        for i in 0..<(n * n) where givens[i] != 0 { clearPeers(i, givens[i]) }
    }

    private func peers(_ i: Int) -> [Int] {
        let r = i / n, c = i % n
        return (0..<n).flatMap { [r * n + $0, $0 * n + c] }.filter { $0 != i }
    }

    private mutating func clearPeers(_ i: Int, _ d: Int) {
        for p in peers(i) { cand[p] &= ~(1 << UInt16(d)) }
    }

    private mutating func place(_ i: Int, _ d: Int) {
        values[i] = d
        cand[i] = 0
        clearPeers(i, d)
    }

    /// 칸이 가질 수 있는 가장 작은 값과 큰 값(정해졌으면 그 값).
    private func low(_ i: Int) -> Int { values[i] != 0 ? values[i] : (1...n).first { cand[i] & (1 << UInt16($0)) != 0 } ?? n + 1 }
    private func high(_ i: Int) -> Int { values[i] != 0 ? values[i] : (1...n).last { cand[i] & (1 << UInt16($0)) != 0 } ?? 0 }

    mutating func solve(maxTier: Int) -> Int? {
        var hardest = 1
        while true {
            if !values.contains(0) { return hardest }
            for i in 0..<(n * n) where values[i] == 0 && cand[i] == 0 { return nil }
            if single() || bounds() { continue }
            if maxTier >= 2, subset(2) { hardest = max(hardest, 2); continue }
            if maxTier >= 3, subset(3) { hardest = 3; continue }
            return nil
        }
    }

    private mutating func single() -> Bool {
        for i in 0..<(n * n) where values[i] == 0 && cand[i].nonzeroBitCount == 1 {
            place(i, cand[i].trailingZeroBitCount)
            return true
        }
        for line in lines {
            for d in 1...n {
                let spots = line.filter { values[$0] == 0 && cand[$0] & (1 << UInt16(d)) != 0 }
                if spots.count == 1 && !line.contains(where: { values[$0] == d }) {
                    place(spots[0], d)
                    return true
                }
            }
        }
        return false
    }

    /// 작은 칸 < 큰 칸: 작은 칸은 큰 칸의 최댓값보다 작고, 큰 칸은 작은 칸의 최솟값보다 크다.
    private mutating func bounds() -> Bool {
        var changed = false
        for (s, b) in relations {
            if values[s] == 0 {
                let limit = high(b)
                for d in max(limit, 1)...n where cand[s] & (1 << UInt16(d)) != 0 { cand[s] &= ~(1 << UInt16(d)); changed = true }
            }
            if values[b] == 0 {
                let limit = low(s)
                for d in 1...min(limit, n) where cand[b] & (1 << UInt16(d)) != 0 { cand[b] &= ~(1 << UInt16(d)); changed = true }
            }
        }
        return changed
    }

    /// 네이키드·히든 서브셋(k=2 페어, 3 트리플).
    private mutating func subset(_ k: Int) -> Bool {
        for line in lines {
            let open = line.filter { values[$0] == 0 }
            guard open.count > k else { continue }
            // 네이키드
            for combo in combos(open.filter { (2...k).contains(cand[$0].nonzeroBitCount) }, k) {
                let union = combo.reduce(UInt16(0)) { $0 | cand[$1] }
                guard union.nonzeroBitCount == k else { continue }
                var changed = false
                for i in open where !combo.contains(i) && cand[i] & union != 0 { cand[i] &= ~union; changed = true }
                if changed { return true }
            }
            // 히든
            let digits = (1...n).filter { d in
                let c = open.filter { cand[$0] & (1 << UInt16(d)) != 0 }.count
                return (2...k).contains(c)
            }
            for combo in combos(digits, k) {
                let mask = combo.reduce(UInt16(0)) { $0 | (1 << UInt16($1)) }
                let spots = open.filter { cand[$0] & mask != 0 }
                guard spots.count == k else { continue }
                var changed = false
                for i in spots where cand[i] & ~mask != 0 { cand[i] &= mask; changed = true }
                if changed { return true }
            }
        }
        return false
    }

    private func combos<T>(_ items: [T], _ k: Int) -> [[T]] {
        guard items.count >= k else { return [] }
        if k == 0 { return [[]] }
        var out: [[T]] = []
        for (i, x) in items.enumerated() {
            for rest in combos(Array(items[(i + 1)...]), k - 1) { out.append([x] + rest) }
        }
        return out
    }
}
