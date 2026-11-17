import Foundation

/// 스위치네모 난이도. 판은 짝수 크기만 쓴다. 짝수 판은 모든 판이 풀리고 누를 칸 조합이 하나뿐이라,
/// 운이 아니라 추론으로 답을 찾을 수 있다(홀수 판은 같은 결과를 내는 조합이 16~256가지).
enum SwitchLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
    case easy = 1, medium, hard, expert
    /// 전문가와 같은 크기지만, 최소 횟수 안에 풀어야 하고 되돌리기를 쓸 수 없다.
    case hell

    var id: Int { rawValue }
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .easy: "초급"
        case .medium: "중급"
        case .hard: "고급"
        case .expert: "전문가"
        case .hell: "지옥"
        }
    }

    var size: Int {
        switch self {
        case .easy, .medium: 4
        case .hard: 6
        case .expert, .hell: 8
        }
    }

    /// 최소 조작 수의 범위. 초급을 1회부터 시작하면 문제가 696개뿐이라 2회부터 시작한다.
    var moves: ClosedRange<Int> {
        switch self {
        case .easy: 2...4
        case .medium: 4...7
        case .hard: 8...14
        case .expert: 15...25
        case .hell: 18...28
        }
    }

    /// 고급부터는 최소 조작 수를 먼저 보여주고 그 안에 풀기를 도전한다.
    var showsMinimum: Bool { self >= .hard }

    /// 지옥: 최소 조작 수를 다 쓰고도 못 풀면 실패.
    /// 되돌리기는 모든 난이도에서 횟수 제한 없이 쓰되 조작 1회로 센다(같은 칸 다시 누르기와 같으므로). UndoLimit을 따르지 않는다.
    var limitsMoves: Bool { self == .hell }
}

struct SwitchPuzzle: Codable, Equatable {
    var size: Int
    /// 처음 상태. true가 켜진 불.
    var start: [Bool]
    /// 최소로 눌러야 하는 칸(오름차순). 짝수 판에서는 유일한 답이다.
    var solution: [Int]
    var level: SwitchLevel
}

enum SwitchEngine {
    /// (r, c)를 누르면 같은 가로줄과 세로줄의 모든 칸이 바뀐다. 누른 칸은 한 번만 바뀐다.
    static func press(_ state: inout [Bool], at i: Int, size n: Int) {
        let r = i / n, c = i % n
        for k in 0..<n {
            state[r * n + k].toggle()
            if k != r { state[k * n + c].toggle() }
        }
    }

    /// 모든 불을 켜는 가장 적은 누름(오름차순). 풀 수 없으면 nil.
    /// GF(2) 연립방정식을 풀고, 같은 결과를 내는 조합(영공간)을 모두 비교해 가장 짧은 것을 고른다.
    static func solve(_ state: [Bool], size n: Int) -> [Int]? {
        let cells = n * n
        // rows[a] = [칸 a에 영향을 주는 누름들 | 칸 a가 꺼져 있으면 1]
        var rows: [[UInt8]] = (0..<cells).map { a in
            var row = [UInt8](repeating: 0, count: cells + 1)
            for p in 0..<cells where p / n == a / n || p % n == a % n { row[p] = 1 }
            row[cells] = state[a] ? 0 : 1
            return row
        }
        var pivotCols: [Int] = []
        var r = 0
        for col in 0..<cells {
            guard let pivot = (r..<cells).first(where: { rows[$0][col] == 1 }) else { continue }
            rows.swapAt(r, pivot)
            for k in 0..<cells where k != r && rows[k][col] == 1 {
                for j in col...cells { rows[k][j] ^= rows[r][j] }
            }
            pivotCols.append(col)
            r += 1
        }
        // 0 = 1 꼴의 모순이 있으면 풀 수 없다.
        if (r..<cells).contains(where: { rows[$0][cells] == 1 }) { return nil }

        let free = (0..<cells).filter { !pivotCols.contains($0) }
        func assignment(_ freeValues: [UInt8]) -> [UInt8] {
            var x = [UInt8](repeating: 0, count: cells)
            for (k, f) in free.enumerated() { x[f] = freeValues[k] }
            for (k, col) in pivotCols.enumerated() {
                var v = rows[k][cells]
                for f in free where rows[k][f] == 1 { v ^= x[f] }
                x[col] = v
            }
            return x
        }
        var best: [UInt8]?
        for mask in 0..<(1 << free.count) {
            let x = assignment(free.indices.map { UInt8((mask >> $0) & 1) })
            if best.map({ x.reduce(0, { $0 + Int($1) }) < $0.reduce(0, { $0 + Int($1) }) }) ?? true { best = x }
        }
        return best.map { x in (0..<cells).filter { x[$0] == 1 } }
    }

    /// 회전·뒤집기로 같아지는 판을 하나로 묶는 키. 최근에 낸 판을 피할 때 쓴다.
    static func canonicalKey(_ state: [Bool], size n: Int) -> String {
        var keys: [String] = []
        for t in 0..<8 {
            var s = ""
            for r in 0..<n {
                for c in 0..<n {
                    let (rr, cc) = transform(r, c, n, t)
                    s.append(state[rr * n + cc] ? "1" : "0")
                }
            }
            keys.append(s)
        }
        return keys.min()!
    }

    private static func transform(_ r: Int, _ c: Int, _ n: Int, _ t: Int) -> (Int, Int) {
        let m = n - 1
        switch t {
        case 0: return (r, c)
        case 1: return (c, m - r)
        case 2: return (m - r, m - c)
        case 3: return (m - c, r)
        case 4: return (r, m - c)
        case 5: return (m - r, c)
        case 6: return (c, r)
        default: return (m - c, m - r)
        }
    }

    /// 모든 불이 켜진 상태에서 무작위 칸들을 눌러 문제를 만든다. 그래서 항상 풀린다.
    /// 짝수 판에서는 누른 칸이 곧 유일한 최소 답이다. recent에 있는 판(회전·뒤집기 포함)은 다시 내지 않는다.
    static func generate<R: RandomNumberGenerator>(_ level: SwitchLevel, avoiding recent: Set<String> = [],
                                                   using rng: inout R) -> SwitchPuzzle {
        let n = level.size
        var fallback: SwitchPuzzle?
        for _ in 0..<200 {
            let k = Int.random(in: level.moves, using: &rng)
            let presses = Array((0..<(n * n)).shuffled(using: &rng).prefix(k)).sorted()
            var state = Array(repeating: true, count: n * n)
            for p in presses { press(&state, at: p, size: n) }
            let puzzle = SwitchPuzzle(size: n, start: state, solution: presses, level: level)
            if !recent.contains(canonicalKey(state, size: n)) { return puzzle }
            fallback = fallback ?? puzzle
        }
        return fallback!
    }
}
