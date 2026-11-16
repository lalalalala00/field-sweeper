import Foundation

/// 풀이에 필요한 가장 어려운 기법으로 정한 난이도.
enum SudokuLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
    /// 싱글(남은 숫자가 하나뿐인 칸, 한 곳에만 들어갈 수 있는 숫자)만으로 풀린다.
    case easy = 1
    /// 후보 비교: 줄·구역 겹침 제외, 네이키드/히든 페어.
    case medium
    /// 여러 후보의 연쇄: 트리플, X-윙.
    case hard
    /// 고급 기법: XY-윙, 소드피시.
    case expert

    var id: Int { rawValue }

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// 한국어 이름. 화면에는 tr()로 바꿔서 쓴다.
    var name: String {
        switch self {
        case .easy: "초급"
        case .medium: "중급"
        case .hard: "고급"
        case .expert: "전문가"
        }
    }

    /// 지울 수 있는 최소 단서 수. 초급은 단서를 넉넉히 남긴다.
    fileprivate var minClues: Int {
        switch self {
        case .easy: 36
        case .medium: 28
        case .hard: 24
        case .expert: 22
        }
    }
}

struct SudokuPuzzle: Codable, Equatable {
    /// 81칸, 0은 빈칸.
    var givens: [Int]
    var solution: [Int]
    var level: SudokuLevel
}

/// 칸 번호(0…80)와 같은 줄·구역 정보.
enum SudokuGrid {
    static let units: [[Int]] = {
        var units: [[Int]] = []
        for r in 0..<9 { units.append((0..<9).map { r * 9 + $0 }) }
        for c in 0..<9 { units.append((0..<9).map { $0 * 9 + c }) }
        for b in 0..<9 {
            let r0 = b / 3 * 3, c0 = b % 3 * 3
            units.append((0..<9).map { (r0 + $0 / 3) * 9 + c0 + $0 % 3 })
        }
        return units
    }()

    /// 같은 줄·열·구역에 있는 다른 20칸.
    static let peers: [[Int]] = (0..<81).map { i in
        var set = Set<Int>()
        for u in unitsOf[i] { set.formUnion(units[u]) }
        set.remove(i)
        return set.sorted()
    }

    /// 칸이 속한 가로줄·세로줄·구역의 units 번호.
    static let unitsOf: [[Int]] = (0..<81).map { i in [i / 9, 9 + i % 9, 18 + i / 27 * 3 + i % 9 / 3] }

    static func box(_ i: Int) -> Int { i / 27 * 3 + i % 9 / 3 }
}

private let allDigits: UInt16 = 0b11_1111_1110

@inline(__always) private func bit(_ d: Int) -> UInt16 { 1 << UInt16(d) }

private extension UInt16 {
    var count: Int { nonzeroBitCount }
    var digits: [Int] { (1...9).filter { self & bit($0) != 0 } }
}

enum SudokuEngine {
    // MARK: 정답 개수 세기

    /// 해의 개수를 limit까지만 센다. 유일성 확인에는 limit 2면 충분하다.
    static func countSolutions(_ grid: [Int], limit: Int = 2) -> Int {
        var g = grid
        var count = 0
        func candidates(_ i: Int) -> UInt16 {
            var used: UInt16 = 0
            for p in SudokuGrid.peers[i] where g[p] != 0 { used |= bit(g[p]) }
            return allDigits & ~used
        }
        func search() {
            if count >= limit { return }
            var best = -1, bestMask: UInt16 = 0, bestCount = 10
            for i in 0..<81 where g[i] == 0 {
                let m = candidates(i)
                let n = m.count
                if n == 0 { return }
                if n < bestCount { best = i; bestMask = m; bestCount = n; if n == 1 { break } }
            }
            if best < 0 { count += 1; return }
            for d in bestMask.digits {
                g[best] = d
                search()
                if count >= limit { break }
            }
            g[best] = 0
        }
        // 주어진 숫자끼리 이미 겹치면 해가 없다.
        for i in 0..<81 where g[i] != 0 {
            if SudokuGrid.peers[i].contains(where: { g[$0] == g[i] }) { return 0 }
        }
        search()
        return count
    }

    // MARK: 생성

    static func randomSolution<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        var g = Array(repeating: 0, count: 81)
        func fill(_ i: Int) -> Bool {
            if i == 81 { return true }
            var used: UInt16 = 0
            for p in SudokuGrid.peers[i] where g[p] != 0 { used |= bit(g[p]) }
            for d in (allDigits & ~used).digits.shuffled(using: &rng) {
                g[i] = d
                if fill(i + 1) { return true }
            }
            g[i] = 0
            return false
        }
        _ = fill(0)
        return g
    }

    /// 정답이 하나뿐이고 추측 없이 풀리는 퍼즐을 만든다.
    /// 목표 난이도가 나올 때까지 여러 번 시도하고, 끝내 안 나오면 목표보다 쉬운 것 중 가장 어려운 것을 돌려준다.
    static func generate<R: RandomNumberGenerator>(_ level: SudokuLevel, attempts: Int = 400, using rng: inout R) -> SudokuPuzzle {
        var fallback: SudokuPuzzle?
        for _ in 0..<attempts {
            let solution = randomSolution(using: &rng)
            var puzzle = solution
            var clues = 81
            for i in (0..<81).shuffled(using: &rng) {
                if clues <= level.minClues { break }
                let saved = puzzle[i]
                puzzle[i] = 0
                if countSolutions(puzzle) == 1, let g = grade(puzzle), g <= level {
                    clues -= 1
                } else {
                    puzzle[i] = saved
                }
            }
            guard let g = grade(puzzle) else { continue }
            let candidate = SudokuPuzzle(givens: puzzle, solution: solution, level: g)
            if g == level { return candidate }
            if fallback.map({ g > $0.level }) ?? true { fallback = candidate }
        }
        // 초급은 지울 때마다 싱글로 풀리는지 확인하므로 한 번에 반드시 만들어진다.
        return fallback ?? generate(.easy, attempts: 1, using: &rng)
    }

    // MARK: 논리 풀이

    /// 사람이 쓰는 기법만으로 풀어 보고, 필요했던 가장 어려운 기법의 난이도를 돌려준다.
    /// 추측 없이는 풀리지 않으면 nil.
    static func grade(_ grid: [Int]) -> SudokuLevel? {
        var solver = LogicSolver(grid)
        return solver.solve()
    }

    /// 논리 풀이로 채운 결과. 풀리지 않으면 nil. (테스트와 힌트용)
    static func logicalSolution(_ grid: [Int]) -> [Int]? {
        var solver = LogicSolver(grid)
        return solver.solve() == nil ? nil : solver.values
    }
}

/// 후보를 비트로 들고 기법을 하나씩 적용하는 풀이기.
private struct LogicSolver {
    var values: [Int]
    var cand: [UInt16]

    init(_ grid: [Int]) {
        values = grid
        cand = Array(repeating: 0, count: 81)
        for i in 0..<81 where values[i] == 0 {
            var used: UInt16 = 0
            for p in SudokuGrid.peers[i] where values[p] != 0 { used |= bit(values[p]) }
            cand[i] = allDigits & ~used
        }
    }

    mutating func solve() -> SudokuLevel? {
        var hardest = SudokuLevel.easy
        while true {
            if !values.contains(0) { return hardest }
            for i in 0..<81 where values[i] == 0 && cand[i] == 0 { return nil }

            if nakedSingle() || hiddenSingle() { continue }
            if lockedCandidates() || nakedSubset(2) || hiddenSubset(2) {
                hardest = max(hardest, .medium); continue
            }
            if nakedSubset(3) || hiddenSubset(3) || fish(2) {
                hardest = max(hardest, .hard); continue
            }
            if xyWing() || fish(3) {
                hardest = .expert; continue
            }
            return nil
        }
    }

    private mutating func place(_ i: Int, _ d: Int) {
        values[i] = d
        cand[i] = 0
        for p in SudokuGrid.peers[i] { cand[p] &= ~bit(d) }
    }

    /// 지운 것이 하나라도 있으면 true.
    private mutating func eliminate(_ mask: UInt16, from i: Int) -> Bool {
        guard values[i] == 0, cand[i] & mask != 0 else { return false }
        cand[i] &= ~mask
        return true
    }

    private mutating func nakedSingle() -> Bool {
        for i in 0..<81 where values[i] == 0 && cand[i].count == 1 {
            place(i, cand[i].digits[0])
            return true
        }
        return false
    }

    private mutating func hiddenSingle() -> Bool {
        for unit in SudokuGrid.units {
            for d in 1...9 {
                var spot = -1, n = 0
                for i in unit where values[i] == 0 && cand[i] & bit(d) != 0 { spot = i; n += 1 }
                if n == 1 { place(spot, d); return true }
            }
        }
        return false
    }

    /// 구역 안의 후보가 한 줄에만 있으면 그 줄의 다른 구역에서 지운다(포인팅), 반대도 마찬가지(클레이밍).
    private mutating func lockedCandidates() -> Bool {
        var changed = false
        for d in 1...9 {
            for (u, unit) in SudokuGrid.units.enumerated() {
                let spots = unit.filter { values[$0] == 0 && cand[$0] & bit(d) != 0 }
                guard spots.count >= 2 else { continue }
                var targets: [[Int]] = []
                if u >= 18 {
                    // 구역 → 가로줄/세로줄
                    if Set(spots.map { $0 / 9 }).count == 1 { targets.append(SudokuGrid.units[spots[0] / 9]) }
                    if Set(spots.map { $0 % 9 }).count == 1 { targets.append(SudokuGrid.units[9 + spots[0] % 9]) }
                } else if Set(spots.map(SudokuGrid.box)).count == 1 {
                    // 가로줄/세로줄 → 구역
                    targets.append(SudokuGrid.units[18 + SudokuGrid.box(spots[0])])
                }
                for target in targets {
                    for i in target where !unit.contains(i) { changed = eliminate(bit(d), from: i) || changed }
                }
                if changed { return true }
            }
        }
        return false
    }

    /// 칸 k개의 후보 합집합이 정확히 k개 숫자면, 같은 줄의 다른 칸에서 그 숫자들을 지운다.
    private mutating func nakedSubset(_ k: Int) -> Bool {
        for unit in SudokuGrid.units {
            let open = unit.filter { values[$0] == 0 && (2...k).contains(cand[$0].count) }
            guard open.count >= k else { continue }
            for combo in combinations(open, k) {
                let union = combo.reduce(UInt16(0)) { $0 | cand[$1] }
                guard union.count == k else { continue }
                var changed = false
                for i in unit where !combo.contains(i) { changed = eliminate(union, from: i) || changed }
                if changed { return true }
            }
        }
        return false
    }

    /// 숫자 k개가 같은 k칸에만 들어갈 수 있으면, 그 칸들의 다른 후보를 지운다.
    private mutating func hiddenSubset(_ k: Int) -> Bool {
        for unit in SudokuGrid.units {
            let digits = (1...9).filter { d in
                let n = unit.filter { values[$0] == 0 && cand[$0] & bit(d) != 0 }.count
                return (2...k).contains(n)
            }
            guard digits.count >= k else { continue }
            for combo in combinations(digits, k) {
                let mask = combo.reduce(UInt16(0)) { $0 | bit($1) }
                let spots = unit.filter { values[$0] == 0 && cand[$0] & mask != 0 }
                guard spots.count == k else { continue }
                var changed = false
                for i in spots { changed = eliminate(~mask & allDigits, from: i) || changed }
                if changed { return true }
            }
        }
        return false
    }

    /// X-윙(n=2), 소드피시(n=3). 가로줄 기준과 세로줄 기준을 모두 본다.
    private mutating func fish(_ n: Int) -> Bool {
        for d in 1...9 {
            for byRow in [true, false] {
                var lines: [(line: Int, spots: Set<Int>)] = []
                for line in 0..<9 {
                    var spots = Set<Int>()
                    for k in 0..<9 {
                        let i = byRow ? line * 9 + k : k * 9 + line
                        if values[i] == 0 && cand[i] & bit(d) != 0 { spots.insert(k) }
                    }
                    if (2...n).contains(spots.count) { lines.append((line, spots)) }
                }
                guard lines.count >= n else { continue }
                for combo in combinations(Array(lines.indices), n) {
                    let cover = combo.reduce(Set<Int>()) { $0.union(lines[$1].spots) }
                    guard cover.count == n else { continue }
                    let base = Set(combo.map { lines[$0].line })
                    var changed = false
                    for k in cover {
                        for line in 0..<9 where !base.contains(line) {
                            let i = byRow ? line * 9 + k : k * 9 + line
                            changed = eliminate(bit(d), from: i) || changed
                        }
                    }
                    if changed { return true }
                }
            }
        }
        return false
    }

    /// 후보가 둘인 칸 {a,b}와, 그 칸이 보는 {a,c}·{b,c} 두 칸이 있으면 두 칸을 모두 보는 칸에서 c를 지운다.
    private mutating func xyWing() -> Bool {
        let pairs = (0..<81).filter { values[$0] == 0 && cand[$0].count == 2 }
        for pivot in pairs {
            let ab = cand[pivot]
            let wings = SudokuGrid.peers[pivot].filter { values[$0] == 0 && cand[$0].count == 2 && (cand[$0] & ab).count == 1 }
            for (x, w1) in wings.enumerated() {
                for w2 in wings[(x + 1)...] {
                    let c1 = cand[w1], c2 = cand[w2]
                    guard c1 != c2, (c1 & ab) != (c2 & ab) else { continue }
                    let c = c1 & c2 & ~ab
                    guard c.count == 1 else { continue }
                    var changed = false
                    let seen = Set(SudokuGrid.peers[w1]).intersection(SudokuGrid.peers[w2])
                    for i in seen where i != pivot { changed = eliminate(c, from: i) || changed }
                    if changed { return true }
                }
            }
        }
        return false
    }
}

private func combinations<T>(_ items: [T], _ k: Int) -> [[T]] {
    guard k > 0 else { return [[]] }
    guard items.count >= k else { return [] }
    var out: [[T]] = []
    func walk(_ start: Int, _ acc: [T]) {
        if acc.count == k { out.append(acc); return }
        guard start < items.count else { return }
        for i in start...(items.count - (k - acc.count)) { walk(i + 1, acc + [items[i]]) }
    }
    walk(0, [])
    return out
}
