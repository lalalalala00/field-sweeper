import Foundation

/// 짝네모 난이도. 초급은 빈칸이 남아도 되고, 중급부터는 벽을 뺀 모든 칸을 써야 하며 답이 하나뿐인 판만 낸다.
/// 중급부터는 사람처럼 푸는 풀이기(PairEngine.grade)로 재서 고른다(pick).
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
        case .easy: 6
        case .medium: 7
        case .hard: 8
        case .expert: 10
        }
    }

    /// 빈칸 허용 난이도에서 놓을 쌍의 수. 모든 칸 사용 난이도는 판을 나누는 대로 정해진다.
    var pairs: ClosedRange<Int> { self == .easy ? 4...5 : 0...0 }

    /// 한 길의 칸 수(양 끝 포함). 전문가는 길을 길게 해서 처음에 바로 정해지는 곳을 줄인다.
    var length: ClosedRange<Int> {
        switch self {
        case .easy: 3...8
        case .medium: 3...10
        case .hard: 4...12
        case .expert: 6...14
        }
    }

    /// 어떤 판을 낼지.
    /// gentle: 넓은 추리 1번 이하, 구역 계산·가정 없이 풀림(모든 칸 채우기를 익히는 판)
    /// tricky: 넓은 추리 3번 이상이나 구역 계산이 필요하고, 가정 없이 풀림
    /// hardest: PairEngine.searchSeconds 동안 만들어 보고 가장 어려운 판
    enum Pick { case any, gentle, tricky, hardest }
    var pick: Pick {
        switch self {
        case .easy: .any
        case .medium: .gentle
        case .hard: .tricky
        case .expert: .hardest
        }
    }

    var fullCover: Bool { self >= .medium }

    var walls: Int { self == .medium || self == .hard ? 1 : 0 }
}

/// 풀이기 결과. solved면 답이 하나뿐이다. entry는 처음에 바로 정해진 쌍 수, 나머지는 각 추리를 쓴 횟수.
struct PairGrade: Equatable {
    var solved = false
    var entry = 0, wide = 0, region = 0, look = 0
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
    /// budget: 길을 한 칸 늘리는 걸음 수의 상한. 넘으면 끝까지 세지 못한 것이므로 limit을 돌려준다(답이 여럿인 것처럼 다룬다).
    static func countSolutions(_ p: PairPuzzle, limit: Int = 2, budget: Int = .max) -> Int {
        let n = p.size, cells = n * n
        var grid = Array(repeating: -1, count: cells)   // -2 벽, -1 빈칸, 0 이상 길 번호
        for w in p.walls { grid[w] = -2 }
        var clue = Array(repeating: 0, count: cells)
        for (k, v) in p.clues { clue[k] = v }
        let ends = p.clues.keys.sorted()
        var matched = Array(repeating: false, count: cells)
        let nb = (0..<cells).map { neighbors($0, size: n) }
        func dist(_ a: Int, _ b: Int) -> Int { abs(a / n - b / n) + abs(a % n - b % n) }
        var count = 0, nextID = 0, steps = 0
        func spend() { steps += 1; if steps > budget { count = limit } }
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
                    spend()
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

    // MARK: 난이도: 사람처럼 푸는 풀이기
    // 숫자 쌍마다 가능한 길을 모두 늘어놓고(routeCap개가 넘으면 '넓음'으로 두고 나중에 다시 센다), 사람이 쓰는 추리로 지워 나간다.
    //  쉬운 추리   갈 수 있는 길이 하나뿐인 숫자는 그 길로 정한다.
    //  넓은 추리   ① 한 숫자의 모든 길이 지나는 칸은 그 숫자 몫이라 다른 길은 못 지난다.
    //              ② 어떤 빈칸을 지날 수 있는 길이 모두 한 숫자의 길이면, 그 숫자는 이 칸을 지나는 길만 남는다.
    //  구역 계산   이 길로 정하면 갇히는 빈 구역을 안의 숫자로 정확히 채울 수 없게 되는 길은 지운다.
    //  한 단계 가정 길이 적은 숫자부터 한 길로 정해 보고, 위 추리만으로 모순이 나면 그 길을 지운다.
    // 쉬운 추리부터 쓰고, 막힐 때만 다음 추리를 한 번 써서 그 횟수를 센다. 웹(pair-engine.js grade)과 같은 순서로 지운다.
    static let routeCap = 20000, regionMax = 200, lookMax = 12

    static func grade(_ p: PairPuzzle) -> PairGrade { PairGrader(p).run() }

    /// 전문가에서 가장 어려운 판을 찾는 시간. 가정 3번 이상에 처음 바로 정해지는 쌍이 1개 이하인 판을 찾으면 바로 낸다.
    static let searchSeconds = 2.5

    /// 어려운 순서: 가정 횟수 > 구역 계산 > 넓은 추리, 처음에 바로 정해지는 쌍이 적을수록.
    /// 풀이기가 끝까지 못 푼 판(답이 하나인 건 따로 확인함)은 가정을 두 단계 이상 해야 하니 가장 어렵게 친다.
    static func hardness(_ r: PairGrade) -> Int {
        (r.solved ? r.look * 100 + r.region * 20 + r.wide : 1000) - r.entry * 5
    }

    static func accept(_ pick: PairLevel.Pick, _ r: PairGrade) -> Bool {
        guard r.solved else { return false }
        switch pick {
        case .gentle: return r.look == 0 && r.region == 0 && r.wide <= 1
        case .tricky: return r.look == 0 && (r.wide >= 3 || r.region >= 1)
        case .any, .hardest: return false
        }
    }

    static func generate<R: RandomNumberGenerator>(_ level: PairLevel, using rng: inout R) -> PairPuzzle {
        let n = level.size, start = Date()
        var best: PairPuzzle?, bestScore = Int.min
        while true {
            if !level.fullCover {
                guard let paths = scatter(size: n, count: Int.random(in: level.pairs, using: &rng), length: level.length, using: &rng) else { continue }
                return build(level, paths: paths, walls: [])
            }
            let walls = Array((0..<(n * n)).shuffled(using: &rng).prefix(level.walls))
            guard let paths = partition(size: n, walls: walls, length: level.length, using: &rng) else { continue }
            let puzzle = build(level, paths: paths, walls: walls)
            // 답이 하나인지 빨리 확인되지 않는 판은 버린다(solveBudget).
            if countSolutions(puzzle, budget: solveBudget) == 1 {
                let r = grade(puzzle)
                if level.pick == .hardest {
                    let h = hardness(r)
                    if h > bestScore { best = puzzle; bestScore = h }
                    if r.solved && r.look >= 3 && r.entry <= 1 { return puzzle }
                } else if accept(level.pick, r) {
                    return puzzle
                }
            }
            if level.pick == .hardest, let best, Date().timeIntervalSince(start) > searchSeconds { return best }
        }
    }

    static let solveBudget = 20000

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

/// PairEngine.grade의 풀이기. 길 목록(routes)은 모든 상태가 함께 쓰고 덧붙이기만 한다.
/// 상태(State)는 값이라 가정해 볼 때 그대로 복사해 쓴다.
private final class PairGrader {
    struct Route { let a: Int, b: Int, cells: [Int] }
    struct Wide { let a: Int, b: Int, length: Int }
    struct State {
        var blocked: [Bool], matched: [Bool], alive: [Int], wide: [Wide]
    }
    enum Outcome { case solved, stuck, contra }

    let n: Int, cells: Int
    let clue: [Int], ends: [Int], nb: [[Int]]
    var routes: [Route] = []
    var stats = PairGrade()
    var seen: [Int], stamp = 0

    init(_ p: PairPuzzle) {
        n = p.size; cells = n * n
        var c = Array(repeating: 0, count: cells)
        for (k, v) in p.clues { c[k] = v }
        clue = c
        ends = p.clues.keys.sorted()
        let size = n
        nb = (0..<cells).map { PairEngine.neighbors($0, size: size) }
        seen = Array(repeating: 0, count: cells)
        walls = p.walls
    }
    private let walls: [Int]

    func dist(_ x: Int, _ y: Int) -> Int { abs(x / n - y / n) + abs(x % n - y % n) }

    func enumerate(_ S: State, _ a: Int, _ b: Int, _ length: Int) -> [[Int]]? {
        var out: [[Int]] = [], path: [Int] = [], used = Array(repeating: false, count: cells), over = false
        func walk(_ cur: Int, _ len: Int) {
            let left = length - len
            for j in nb[cur] {
                if over { return }
                if left == 1 {
                    if j == b { out.append(path); if out.count > PairEngine.routeCap { over = true } }
                    continue
                }
                if used[j] || S.blocked[j] || clue[j] != 0 { continue }
                let d = dist(j, b)
                if d > left - 1 || (left - 1 - d) % 2 != 0 { continue }
                used[j] = true; path.append(j)
                walk(j, len + 1)
                path.removeLast(); used[j] = false
            }
        }
        walk(a, 1)
        return over ? nil : out
    }

    /// 처음에는 모든 쌍을, 그다음부터는 '넓음'으로 둔 쌍만 다시 늘어놓는다.
    func list(_ S: inout State, _ pairs: [(Int, Int)]) {
        S.wide = []
        for (a, b) in pairs where !S.matched[a] && !S.matched[b] {
            if let rs = enumerate(S, a, b, clue[a]) {
                for c in rs { routes.append(Route(a: a, b: b, cells: c)); S.alive.append(routes.count - 1) }
            } else {
                S.wide.append(Wide(a: a, b: b, length: clue[a]))
            }
        }
    }

    func isWide(_ S: State, _ e: Int) -> Bool { S.wide.contains { $0.a == e || $0.b == e } }
    func routesOf(_ S: State, _ e: Int) -> [Int] { S.alive.filter { routes[$0].a == e || routes[$0].b == e } }

    /// 길 k로 정한다: 그 칸을 막고, 같은 숫자 칸을 쓰거나 그 칸을 지나는 다른 길을 지운다.
    func fix(_ S: inout State, _ k: Int) {
        let r = routes[k]
        for c in r.cells { S.blocked[c] = true }
        S.matched[r.a] = true; S.matched[r.b] = true
        let blocked = S.blocked, matched = S.matched
        S.alive = S.alive.filter { q in
            let o = routes[q]
            return !(matched[o.a] || matched[o.b] || o.cells.contains { blocked[$0] })
        }
        list(&S, S.wide.map { ($0.a, $0.b) })
    }

    /// 빈 구역마다 안의 같은 숫자가 짝수 개이고, 그 숫자들의 길이로 구역을 정확히 채울 수 있어야 한다.
    /// r가 있으면 그 길로 정했다고 치고 본다.
    func regionsOk(_ S: State, _ r: Route? = nil) -> Bool {
        stamp += 1
        let on = Set(r?.cells ?? [])
        func free(_ i: Int) -> Bool {
            !S.blocked[i] && !on.contains(i) && !(clue[i] != 0 && (S.matched[i] || i == r?.a || i == r?.b))
        }
        for s in 0..<cells where seen[s] != stamp && free(s) {
            var size = 0, counts: [Int: Int] = [:], stack = [s]
            seen[s] = stamp
            while let i = stack.popLast() {
                size += 1
                if clue[i] != 0 { counts[clue[i], default: 0] += 1 }
                for j in nb[i] where seen[j] != stamp && free(j) { seen[j] = stamp; stack.append(j) }
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

    /// level: 0 쉬운 추리만, 1 +넓은 추리, 2 +구역 계산, 3 +한 단계 가정. top이면 횟수를 센다.
    func propagate(_ S: inout State, level: Int, top: Bool) -> Outcome {
        var first = true
        while true {
            var fixed = false
            for e in ends where !S.matched[e] && !isWide(S, e) {
                let mine = routesOf(S, e)
                if mine.isEmpty { return .contra }
                if mine.count > 1 { continue }
                fix(&S, mine[0])
                fixed = true
                if top && first { stats.entry += 1 }
            }
            first = false
            if fixed { if !regionsOk(S) { return .contra }; continue }
            if ends.allSatisfy({ S.matched[$0] }) {
                for i in 0..<cells where !S.blocked[i] && clue[i] == 0 { return .contra }
                return .solved
            }
            if level < 1 { return .stuck }

            // 넓은 추리 ①②
            var kill = Set<Int>()
            for e in ends where !S.matched[e] && !isWide(S, e) {
                let mine = routesOf(S, e)
                var common = Set(routes[mine[0]].cells)
                for k in mine { common.formIntersection(routes[k].cells) }
                if common.isEmpty { continue }
                for k in S.alive {
                    let r = routes[k]
                    if r.a != e && r.b != e && r.cells.contains(where: { common.contains($0) }) { kill.insert(k) }
                }
            }
            var cover = Array(repeating: [Int](), count: cells)
            for k in S.alive where !kill.contains(k) { for c in routes[k].cells { cover[c].append(k) } }
            for c in 0..<cells where !S.blocked[c] && clue[c] == 0 {
                var shared: [Int]?
                for k in cover[c] {
                    let r = routes[k]
                    shared = shared.map { $0.filter { $0 == r.a || $0 == r.b } } ?? [r.a, r.b]
                }
                for w in S.wide {
                    let d = dist(w.a, c) + dist(c, w.b)
                    if d <= w.length - 1 && (w.length - 1 - d) % 2 == 0 {
                        shared = shared.map { $0.filter { $0 == w.a || $0 == w.b } } ?? [w.a, w.b]
                    }
                }
                guard let shared else { return .contra }
                for e in shared where !isWide(S, e) {
                    for k in S.alive {
                        let r = routes[k]
                        if (r.a == e || r.b == e) && !r.cells.contains(c) { kill.insert(k) }
                    }
                }
            }
            if !kill.isEmpty {
                S.alive.removeAll { kill.contains($0) }
                if top { stats.wide += 1 }
                continue
            }
            if level < 2 { return .stuck }

            // 구역 계산
            for e in ends where !S.matched[e] && !isWide(S, e) {
                let mine = routesOf(S, e)
                if mine.count > PairEngine.regionMax { continue }
                for k in mine where !regionsOk(S, routes[k]) { kill.insert(k) }
            }
            if !kill.isEmpty {
                S.alive.removeAll { kill.contains($0) }
                if top { stats.region += 1 }
                continue
            }
            if level < 3 { return .stuck }

            // 한 단계 가정: 길이 적은 숫자부터 한 길로 정해 보고, 모순이면 그 길을 지운다. 한 숫자에서 지우면 처음으로 돌아간다.
            var cand: [(e: Int, mine: [Int])] = []
            for e in ends where !S.matched[e] && !isWide(S, e) {
                let mine = routesOf(S, e)
                if mine.count <= PairEngine.lookMax { cand.append((e, mine)) }
            }
            cand.sort { a, b in a.mine.count != b.mine.count ? a.mine.count < b.mine.count : a.e < b.e }
            var found = false
            for c in cand {
                for k in c.mine where S.alive.contains(k) {
                    var T = S
                    fix(&T, k)
                    if !regionsOk(T) || propagate(&T, level: 2, top: false) == .contra {
                        S.alive.removeAll { $0 == k }
                        found = true
                    }
                }
                if found { break }
            }
            if found { if top { stats.look += 1 }; continue }
            return .stuck
        }
    }

    func run() -> PairGrade {
        var S = State(blocked: Array(repeating: false, count: cells), matched: Array(repeating: false, count: cells), alive: [], wide: [])
        for w in walls { S.blocked[w] = true }
        var pairs: [(Int, Int)] = []
        for a in ends { for b in ends where b > a && clue[a] == clue[b] { pairs.append((a, b)) } }
        list(&S, pairs)
        stats.solved = propagate(&S, level: 3, top: true) == .solved
        return stats
    }
}
