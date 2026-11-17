import Foundation

/// 짝네모 난이도. 초급·중급은 빈칸이 남아도 되고, 고급부터는 벽을 뺀 모든 칸을 써야 하며 답이 하나뿐인 판만 낸다.
enum PairLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
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

    /// 빈칸 허용 난이도에서 놓을 쌍의 수. 모든 칸 사용 난이도는 판을 나누는 대로 정해진다.
    var pairs: ClosedRange<Int> {
        switch self {
        case .easy: 3...3
        case .medium: 4...5
        case .hard, .expert: 0...0
        }
    }

    /// 한 길의 칸 수(양 끝 포함).
    var length: ClosedRange<Int> {
        switch self {
        case .easy: 3...6
        case .medium: 3...8
        case .hard: 3...10
        case .expert: 3...12
        }
    }

    var fullCover: Bool { self >= .hard }

    var walls: Int {
        switch self {
        case .easy, .medium: 0
        case .hard: 2
        case .expert: 3
        }
    }
}

struct PairPuzzle: Codable, Equatable {
    var size: Int
    /// 숫자 칸 → 길의 칸 수. 같은 숫자가 여러 쌍이면 같은 숫자끼리 어느 것과 이어도 된다.
    var clues: [Int: Int]
    var walls: [Int]
    var fullCover: Bool
    /// 만들 때 쓴 길들. 판정은 규칙으로 하므로 이 답과 비교하지 않는다.
    var solution: [[Int]]
    var level: PairLevel
}

enum PairEngine {
    static func neighbors(_ i: Int, size n: Int) -> [Int] {
        let r = i / n, c = i % n
        var out: [Int] = []
        if r > 0 { out.append(i - n) }
        if r < n - 1 { out.append(i + n) }
        if c > 0 { out.append(i - 1) }
        if c < n - 1 { out.append(i + 1) }
        return out
    }

    static func adjacent(_ a: Int, _ b: Int, size n: Int) -> Bool {
        abs(a - b) == n || (abs(a - b) == 1 && a / n == b / n)
    }

    /// 그린 길들이 규칙을 지키고 모든 숫자를 이었는지. complete는 제대로 이어진 길 수, covered는 길이 덮은 칸 수.
    static func check(_ p: PairPuzzle, paths: [[Int]]) -> (solved: Bool, complete: Int, covered: Int) {
        let n = p.size, walls = Set(p.walls)
        var used = Set<Int>()
        var complete = 0
        for path in paths {
            for c in path {
                if walls.contains(c) || !used.insert(c).inserted { return (false, complete, used.count) }
            }
            for k in path.indices.dropFirst() where !adjacent(path[k - 1], path[k], size: n) { return (false, complete, used.count) }
            if path.count >= 2, let a = p.clues[path[0]], a == p.clues[path[path.count - 1]], a == path.count,
               path.dropFirst().dropLast().allSatisfy({ p.clues[$0] == nil }) {
                complete += 1
            }
        }
        let allLinked = complete * 2 == p.clues.count && complete == paths.count
        let covered = !p.fullCover || used.count == n * n - p.walls.count
        return (allLinked && covered, complete, used.count)
    }

    /// 모든 칸 사용 판의 답을 limit까지 센다.
    static func countSolutions(_ p: PairPuzzle, limit: Int = 2) -> Int {
        let n = p.size, cells = n * n
        var grid = Array(repeating: -1, count: cells)   // -2 벽, -1 빈칸, 0 이상 길 번호
        for w in p.walls { grid[w] = -2 }
        var clue = Array(repeating: 0, count: cells)
        for (k, v) in p.clues { clue[k] = v }
        let ends = p.clues.keys.sorted()
        var matched = Array(repeating: false, count: cells)
        let nb = (0..<cells).map { neighbors($0, size: n) }
        func dist(_ a: Int, _ b: Int) -> Int { abs(a / n - b / n) + abs(a % n - b % n) }
        var count = 0, nextID = 0
        var seen = Array(repeating: 0, count: cells), stamp = 0

        // 빈칸 덩어리마다: 같은 숫자가 짝수 개이고, 그 숫자들로 덩어리를 정확히 채울 수 있어야 한다.
        func feasible() -> Bool {
            stamp += 1
            for s in 0..<cells where seen[s] != stamp && grid[s] == -1 && !(clue[s] != 0 && matched[s]) {
                var size = 0
                var counts: [Int: Int] = [:]
                var stack = [s]
                seen[s] = stamp
                while let i = stack.popLast() {
                    size += 1
                    if clue[i] != 0 { counts[clue[i], default: 0] += 1 }
                    for j in nb[i] where seen[j] != stamp && grid[j] == -1 && !(clue[j] != 0 && matched[j]) {
                        seen[j] = stamp
                        stack.append(j)
                    }
                }
                var need = 0
                for (length, c) in counts {
                    if c % 2 != 0 { return false }
                    need += c / 2 * length
                }
                if need != size { return false }
            }
            return true
        }

        // 갈 수 있는 이웃이 가장 적은 숫자 칸부터
        func pick() -> Int? {
            var best: Int?, bestScore = Int.max
            for e in ends where !matched[e] {
                let free = nb[e].filter { j in grid[j] == -1 && (clue[j] == 0 || (!matched[j] && clue[j] == clue[e])) }.count
                let score = free * 100 + clue[e]
                if score < bestScore { best = e; bestScore = score }
            }
            return best
        }

        func solve() {
            if count >= limit { return }
            guard let a = pick() else { count += 1; return }
            let length = clue[a]
            let targets = ends.filter { $0 != a && !matched[$0] && clue[$0] == length }
            if targets.isEmpty { return }
            let id = nextID
            nextID += 1
            matched[a] = true
            grid[a] = id
            func walk(_ cur: Int, _ len: Int) {
                if count >= limit { return }
                let left = length - len
                for j in nb[cur] {
                    if left == 1 {
                        if clue[j] == length && !matched[j] && grid[j] == -1 {
                            matched[j] = true; grid[j] = id
                            if feasible() { solve() }
                            matched[j] = false; grid[j] = -1
                        }
                        continue
                    }
                    if grid[j] != -1 || clue[j] != 0 { continue }
                    // 남은 걸음으로 갈 수 있는 짝이 있어야 한다(거리와 홀짝).
                    guard targets.contains(where: { b in !matched[b] && dist(j, b) <= left - 1 && (left - 1 - dist(j, b)) % 2 == 0 }) else { continue }
                    grid[j] = id
                    walk(j, len + 1)
                    grid[j] = -1
                    if count >= limit { return }
                }
            }
            walk(a, 1)
            matched[a] = false
            grid[a] = -1
        }
        if feasible() { solve() }
        return count
    }

    /// 모든 칸 사용: 빈칸을 무작위로 골라 양 끝으로 길을 늘려 판을 길들로 나누고, 짧게 남은 길은 옆 길 끝에 붙인다.
    static func partition<R: RandomNumberGenerator>(size n: Int, walls: [Int], length: ClosedRange<Int>,
                                                    using rng: inout R) -> [[Int]]? {
        var owner = Array(repeating: -1, count: n * n)
        for w in walls { owner[w] = -2 }
        var paths: [[Int]?] = []
        for s in (0..<(n * n)).shuffled(using: &rng) where owner[s] == -1 {
            let id = paths.count
            var path = [s]
            owner[s] = id
            let target = Int.random(in: length, using: &rng)
            while path.count < target {
                let order = Bool.random(using: &rng) ? [path.count - 1, 0] : [0, path.count - 1]
                var grown = false
                for e in order {
                    let options = neighbors(path[e], size: n).filter { owner[$0] == -1 }
                    guard let j = options.randomElement(using: &rng) else { continue }
                    owner[j] = id
                    if e == 0 { path.insert(j, at: 0) } else { path.append(j) }
                    grown = true
                    break
                }
                if !grown { break }
            }
            paths.append(path)
        }
        var changed = true
        while changed {
            changed = false
            for k in paths.indices {
                guard let p = paths[k], p.count < length.lowerBound else { continue }
                var joined = false
                for (end, isHead) in [(p[0], true), (p[p.count - 1], false)] where !joined {
                    let tail = isHead ? Array(p.reversed()) : p   // end가 끝으로 오게
                    for q in paths.indices where q != k && !joined {
                        guard let o = paths[q], o.count + p.count <= length.upperBound else { continue }
                        if adjacent(end, o[0], size: n) { paths[q] = tail + o; joined = true }
                        else if adjacent(end, o[o.count - 1], size: n) { paths[q] = o + tail.reversed(); joined = true }
                    }
                }
                if joined { paths[k] = nil; changed = true }
            }
        }
        let out = paths.compactMap { $0 }
        return out.allSatisfy({ length.contains($0.count) }) ? out : nil
    }

    /// 빈칸 허용: 서로 겹치지 않는 길 몇 개를 무작위로 놓는다. 양 끝이 바로 붙은 길은 너무 쉬워 피한다.
    static func scatter<R: RandomNumberGenerator>(size n: Int, count: Int, length: ClosedRange<Int>,
                                                  using rng: inout R) -> [[Int]]? {
        for _ in 0..<200 {
            var owner = Array(repeating: -1, count: n * n)
            var paths: [[Int]] = []
            for k in 0..<count {
                var placed: [Int]?
                for _ in 0..<60 where placed == nil {
                    let target = Int.random(in: length, using: &rng), s = Int.random(in: 0..<(n * n), using: &rng)
                    guard owner[s] == -1 else { continue }
                    var path = [s], used: Set<Int> = [s]
                    while path.count < target {
                        let options = neighbors(path[path.count - 1], size: n).filter { owner[$0] == -1 && !used.contains($0) }
                        guard let j = options.randomElement(using: &rng) else { break }
                        path.append(j)
                        used.insert(j)
                    }
                    if path.count == target && !adjacent(path[0], path[target - 1], size: n) { placed = path }
                }
                guard let path = placed else { break }
                for c in path { owner[c] = k }
                paths.append(path)
            }
            if paths.count == count { return paths }
        }
        return nil
    }

    static func generate<R: RandomNumberGenerator>(_ level: PairLevel, using rng: inout R) -> PairPuzzle {
        let n = level.size
        while true {
            if !level.fullCover {
                guard let paths = scatter(size: n, count: Int.random(in: level.pairs, using: &rng), length: level.length, using: &rng) else { continue }
                return build(level, paths: paths, walls: [])
            }
            let walls = Array((0..<(n * n)).shuffled(using: &rng).prefix(level.walls))
            guard let paths = partition(size: n, walls: walls, length: level.length, using: &rng) else { continue }
            let puzzle = build(level, paths: paths, walls: walls)
            if countSolutions(puzzle) == 1 { return puzzle }
        }
    }

    private static func build(_ level: PairLevel, paths: [[Int]], walls: [Int]) -> PairPuzzle {
        var clues: [Int: Int] = [:]
        for p in paths {
            clues[p[0]] = p.count
            clues[p[p.count - 1]] = p.count
        }
        return PairPuzzle(size: level.size, clues: clues, walls: walls.sorted(), fullCover: level.fullCover,
                          solution: paths, level: level)
    }
}
