import Foundation

/// 거울네모 난이도. 판 크기, 회전 거울 수, 고정 거울·벽 수, 별 수로 정한다.
enum MirrorLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
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
        case .easy: 5
        case .medium: 6
        case .hard: 7
        case .expert: 8
        }
    }

    /// 사용자가 돌릴 수 있는 거울 수.
    var mirrors: ClosedRange<Int> {
        switch self {
        case .easy: 2...3
        case .medium: 4...5
        case .hard: 6...7
        case .expert: 8...10
        }
    }

    /// 정답 경로 위에 있지만 돌릴 수 없는 거울 수.
    var fixedOnPath: Int {
        switch self {
        case .easy: 0
        case .medium, .hard: 1
        case .expert: 2
        }
    }

    /// 정답 경로 밖에서 다른 길로 새게 만드는 고정 거울 수.
    var decoyFixed: Int {
        switch self {
        case .easy: 0
        case .medium: 1
        case .hard, .expert: 2
        }
    }

    var walls: Int {
        switch self {
        case .easy, .medium: 0
        case .hard: 2
        case .expert: 3
        }
    }

    var stars: ClosedRange<Int> {
        switch self {
        case .easy: 1...2
        case .medium: 2...3
        case .hard: 3...4
        case .expert: 3...5
        }
    }

    /// 이 범위의 effort가 나올 때까지 후보를 만든다. 중급은 그대로 두면 거의 모든 판이 빛만 따라가도 풀려서
    /// 조금 생각해야 하는 판을 고른다. 고급부터는 크기만으로 충분히 어려워 고르지 않는다.
    var effort: ClosedRange<Int>? { self == .medium ? 3...7 : nil }
}

/// 테두리의 자리. side 0 위, 1 오른쪽, 2 아래, 3 왼쪽. k는 그 변의 몇 번째 칸인지.
struct MirrorPort: Codable, Hashable {
    var side: Int
    var k: Int
}

enum MirrorCell: Codable, Equatable {
    case empty
    case wall
    /// orientation 0은 '/', 1은 '\'. 고정 거울은 돌릴 수 없다.
    case mirror(orientation: Int, fixed: Bool)

    var isRotatable: Bool { if case .mirror(_, false) = self { true } else { false } }
}

struct MirrorPuzzle: Codable, Equatable {
    var size: Int
    var cells: [MirrorCell]
    var start: MirrorPort
    var goal: MirrorPort
    /// 별이 있는 칸.
    var stars: [Int]
    /// 정답 경로 위 모든 거울의 방향(고정 거울 포함). 회전 거울의 답은 여기서 읽는다.
    var solution: [Int: Int]
    var level: MirrorLevel

    var rotatable: [Int] { cells.indices.filter { cells[$0].isRotatable } }
}

struct MirrorTrace {
    /// 빛이 지나간 칸, 지나간 순서대로.
    var path: [Int]
    /// 판 밖으로 나간 자리. 벽에 막히면 nil.
    var exit: MirrorPort?
    var blocked: Int?
    var lit: Int
    var solved: Bool
}

enum MirrorEngine {
    /// 오른쪽, 아래, 왼쪽, 위
    static let dirs: [(Int, Int)] = [(0, 1), (1, 0), (0, -1), (-1, 0)]

    static func reflect(_ d: Int, _ m: Int) -> Int {
        let (dr, dc) = dirs[d]
        let next = m == 0 ? (-dc, -dr) : (dc, dr)
        return dirs.firstIndex { $0 == next }!
    }

    static func entry(_ port: MirrorPort, size n: Int) -> (r: Int, c: Int, d: Int) {
        switch port.side {
        case 0: (0, port.k, 1)
        case 1: (port.k, n - 1, 2)
        case 2: (n - 1, port.k, 3)
        default: (port.k, 0, 0)
        }
    }

    static func exitPort(_ r: Int, _ c: Int, size n: Int) -> MirrorPort {
        if r < 0 { return MirrorPort(side: 0, k: c) }
        if c >= n { return MirrorPort(side: 1, k: r) }
        if r >= n { return MirrorPort(side: 2, k: c) }
        return MirrorPort(side: 3, k: r)
    }

    /// 지금 거울 방향으로 빛을 쏴 본다. orient는 회전 거울의 방향.
    static func trace(_ p: MirrorPuzzle, orient: [Int: Int]) -> MirrorTrace {
        let n = p.size
        var (r, c, d) = entry(p.start, size: n)
        var path: [Int] = []
        var seen = Set<Int>(), visited = Set<Int>()
        func lit() -> Int { p.stars.filter(visited.contains).count }
        while true {
            if r < 0 || c < 0 || r >= n || c >= n {
                let exit = exitPort(r, c, size: n)
                let count = lit()
                return MirrorTrace(path: path, exit: exit, blocked: nil, lit: count,
                                   solved: exit == p.goal && count == p.stars.count)
            }
            let i = r * n + c
            if p.cells[i] == .wall { return MirrorTrace(path: path, exit: nil, blocked: i, lit: lit(), solved: false) }
            // 두 면 거울만 있어 테두리에서 들어온 빛은 돌지 않지만, 혹시 몰라 같은 칸·방향을 다시 오면 멈춘다.
            guard seen.insert(i * 4 + d).inserted else { return MirrorTrace(path: path, exit: nil, blocked: nil, lit: 0, solved: false) }
            visited.insert(i)
            path.append(i)
            if case .mirror(let m, let fixed) = p.cells[i] { d = reflect(d, fixed ? m : orient[i] ?? m) }
            r += dirs[d].0
            c += dirs[d].1
        }
    }

    /// 회전 거울 방향을 모든 경우로 시뮬레이션해 성공하는 경우를 limit까지 모은다.
    static func solutions(_ p: MirrorPuzzle, limit: Int = 2) -> [(orient: [Int: Int], path: [Int])] {
        let rot = p.rotatable
        var out: [(orient: [Int: Int], path: [Int])] = []
        for mask in 0..<(1 << rot.count) {
            var orient: [Int: Int] = [:]
            for (k, i) in rot.enumerated() { orient[i] = (mask >> k) & 1 }
            let t = trace(p, orient: orient)
            if t.solved {
                out.append((orient, t.path))
                if out.count >= limit { break }
            }
        }
        return out
    }

    // MARK: 문제 고르기

    private enum Step {
        case done(solved: Bool, lit: Int, length: Int)
        case pending(cell: Int, lit: Int, length: Int)
    }

    /// 정한 거울까지만 빛을 쏜다. 아직 정하지 않은 회전 거울을 만나면 거기서 멈춘다.
    private static func step(_ p: MirrorPuzzle, decided: [Int: Int]) -> Step {
        let n = p.size
        var (r, c, d) = entry(p.start, size: n)
        var visited = Set<Int>(), seen = Set<Int>()
        var length = 0
        func lit() -> Int { p.stars.filter(visited.contains).count }
        while true {
            if r < 0 || c < 0 || r >= n || c >= n {
                let count = lit()
                return .done(solved: exitPort(r, c, size: n) == p.goal && count == p.stars.count, lit: count, length: length)
            }
            let i = r * n + c
            if p.cells[i] == .wall || !seen.insert(i * 4 + d).inserted { return .done(solved: false, lit: 0, length: length) }
            visited.insert(i)
            length += 1
            if case .mirror(let m, let fixed) = p.cells[i] {
                if !fixed && decided[i] == nil { return .pending(cell: i, lit: lit(), length: length) }
                d = reflect(d, fixed ? m : decided[i]!)
            }
            r += dirs[d].0
            c += dirs[d].1
        }
    }

    /// '빛만 따라가는 사람'이 헤매는 정도. 빛을 따라가다 아직 정하지 않은 회전 거울을 만나면
    /// 그럴듯한 쪽(별을 더 지나고, 더 멀리 가고, 바로 끝나지 않는 쪽)을 먼저 골라 보고, 틀려서 되돌아간 횟수를 센다.
    static func effort(_ p: MirrorPuzzle) -> Int {
        var wrong = 0
        func rank(_ decided: [Int: Int], _ i: Int, _ o: Int) -> [Int] {
            var next = decided
            next[i] = o
            switch step(p, decided: next) {
            case .done(let solved, let lit, let length): return [solved ? 0 : 2, -lit, -length]
            case .pending(_, let lit, let length): return [1, -lit, -length]
            }
        }
        func dfs(_ decided: [Int: Int]) -> Bool {
            switch step(p, decided: decided) {
            case .done(let solved, _, _): return solved
            case .pending(let i, _, _):
                let options = [0, 1].sorted { rank(decided, i, $0).lexicographicallyPrecedes(rank(decided, i, $1)) }
                for o in options {
                    var next = decided
                    next[i] = o
                    if dfs(next) { return true }
                    wrong += 1
                }
                return false
            }
        }
        _ = dfs([:])
        return wrong
    }

    /// 최소 조작 수: 처음 방향에서 정답과 다른 회전 거울의 수.
    static func minimumMoves(_ p: MirrorPuzzle, initial: [Int: Int]) -> Int {
        p.rotatable.filter { initial[$0] != p.solution[$0] }.count
    }

    /// 난이도에 effort 범위가 있으면 그 범위의 판이 나올 때까지 만들고, 시간 안에 못 찾으면 가장 가까운 판을 쓴다.
    static func generate<R: RandomNumberGenerator>(_ level: MirrorLevel, using rng: inout R) -> MirrorPuzzle {
        guard let band = level.effort else { return generateOne(level, using: &rng) }
        let deadline = Date.now.addingTimeInterval(1.5)
        var best: (puzzle: MirrorPuzzle, gap: Int)?
        for _ in 0..<3000 {
            if best != nil && Date.now > deadline { break }
            let p = generateOne(level, using: &rng)
            let e = effort(p)
            if band.contains(e) { return p }
            let gap = e < band.lowerBound ? band.lowerBound - e : e - band.upperBound
            if best.map({ gap < $0.gap }) ?? true { best = (p, gap) }
        }
        return best!.puzzle
    }

    /// 1. 시작점에서 빛을 쏘며 지나는 새 칸에 무작위로 거울을 놓아 정답 경로를 만든다.
    /// 2. 그중 일부를 고정 거울로 바꾸고, 경로 밖에 헷갈리게 하는 고정 거울과 벽을 둔다.
    /// 3. 경로 위 빈칸에 별을 두고, 다른 방향 조합도 성공하면 그 조합이 지나지 않는 칸에 별을 더한다.
    /// 회전 거울 방향 조합 중 딱 하나만 성공하는 판만 낸다.
    private static func generateOne<R: RandomNumberGenerator>(_ level: MirrorLevel, using rng: inout R) -> MirrorPuzzle {
        let n = level.size
        for _ in 0..<5000 {
            let want = Int.random(in: level.mirrors, using: &rng) + level.fixedOnPath
            let start = MirrorPort(side: Int.random(in: 0..<4, using: &rng), k: Int.random(in: 0..<n, using: &rng))
            var (r, c, d) = entry(start, size: n)
            var cells = Array(repeating: MirrorCell.empty, count: n * n)
            var visited = Set<Int>(), order: [Int] = []
            let chance = min(0.6, Double(want) / (Double(n) * 1.6))
            var steps = 0, placed = 0
            var exit: MirrorPort?
            while steps < 4 * n * n {
                steps += 1
                if r < 0 || c < 0 || r >= n || c >= n { exit = exitPort(r, c, size: n); break }
                let i = r * n + c
                if case .mirror(let m, _) = cells[i] {
                    d = reflect(d, m)
                } else if !visited.contains(i) && placed < want && Double.random(in: 0..<1, using: &rng) < chance {
                    let m = Int.random(in: 0...1, using: &rng)
                    cells[i] = .mirror(orientation: m, fixed: false)
                    placed += 1
                    d = reflect(d, m)
                }
                if visited.insert(i).inserted { order.append(i) }
                r += dirs[d].0
                c += dirs[d].1
            }
            guard let goal = exit, placed == want, goal != start, order.count >= n + 2 else { continue }

            var solution: [Int: Int] = [:]
            let mirrorCells = order.filter { cells[$0] != .empty }
            for i in mirrorCells { if case .mirror(let m, _) = cells[i] { solution[i] = m } }
            for i in mirrorCells.shuffled(using: &rng).prefix(level.fixedOnPath) {
                cells[i] = .mirror(orientation: solution[i]!, fixed: true)
            }
            var empty = (0..<(n * n)).filter { !visited.contains($0) }.shuffled(using: &rng)
            for _ in 0..<level.decoyFixed { if let i = empty.popLast() { cells[i] = .mirror(orientation: Int.random(in: 0...1, using: &rng), fixed: true) } }
            for _ in 0..<level.walls { if let i = empty.popLast() { cells[i] = .wall } }

            var starSpots = order.filter { cells[$0] == .empty }.shuffled(using: &rng)
            let first = min(Int.random(in: level.stars, using: &rng), starSpots.count)
            var puzzle = MirrorPuzzle(size: n, cells: cells, start: start, goal: goal,
                                      stars: Array(starSpots.prefix(first)), solution: solution, level: level)
            starSpots.removeFirst(first)
            var sols = solutions(puzzle)
            while sols.count > 1 && puzzle.stars.count < level.stars.upperBound {
                guard let other = sols.first(where: { s in puzzle.rotatable.contains { s.orient[$0] != solution[$0] } }),
                      let miss = starSpots.firstIndex(where: { !other.path.contains($0) }) else { break }
                puzzle.stars.append(starSpots.remove(at: miss))
                sols = solutions(puzzle)
            }
            guard sols.count == 1 else { continue }
            puzzle.stars.sort()
            return puzzle
        }
        fatalError("거울네모 문제를 만들지 못했다")
    }

    /// 처음 보여줄 방향: 회전 거울의 절반 이상은 정답과 다르게 섞는다(최소 조작 수가 너무 적지 않게).
    /// 처음부터 풀린 상태는 피한다.
    static func scramble<R: RandomNumberGenerator>(_ p: MirrorPuzzle, using rng: inout R) -> [Int: Int] {
        let rot = p.rotatable
        let need = (rot.count + 1) / 2
        for _ in 0..<200 {
            var orient: [Int: Int] = [:]
            for i in rot { orient[i] = Int.random(in: 0...1, using: &rng) }
            if rot.filter({ orient[$0] != p.solution[$0] }).count < need { continue }
            if !trace(p, orient: orient).solved { return orient }
        }
        return Dictionary(uniqueKeysWithValues: rot.map { ($0, 1 - p.solution[$0]!) })
    }
}
