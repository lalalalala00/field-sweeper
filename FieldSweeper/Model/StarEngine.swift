import Foundation

/// 별네모 난이도. 판 크기, 줄·구역마다 놓을 별 수, 풀이에 필요한 추리 단계로 정한다.
/// 웹 docs/assets/star-engine.js와 같은 규칙이다. 규칙을 바꾸면 양쪽을 함께 고친다.
enum StarLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
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
        case .hard: 8
        case .expert: 10
        }
    }

    /// 가로줄·세로줄·구역마다 놓을 별 수
    var stars: Int { self == .expert ? 2 : 1 }

    /// 사람처럼 푸는 풀이기(StarEngine.grade)로 쓴 가장 어려운 단계의 범위(4는 한 단계 가정).
    var tier: ClosedRange<Int> {
        switch self {
        case .easy: 1...1
        case .medium: 2...2
        case .hard, .expert: 3...4
        }
    }

    /// 이 시간 동안 만들어 보고 가장 어려운 판을 낸다. nil이면 범위에 맞는 판이 나오는 대로 낸다.
    var searchSeconds: Double? { self == .expert ? 3 : nil }
}

struct StarPuzzle: Codable, Equatable {
    var size: Int
    /// 가로줄·세로줄·구역마다 놓을 별 수
    var k: Int
    /// 칸 → 구역 번호(0..<size)
    var regions: [Int]
    /// 만들 때 쓴 별 칸들. 판정은 규칙으로 하므로 이 답과 비교하지 않는다.
    var solution: [Int]
    var level: StarLevel
}

/// 풀이기 결과. tier는 쓴 가장 어려운 단계, steps는 3단계 이상을 쓴 횟수, look은 가정 횟수.
struct StarGrade: Equatable {
    var tier = 0, steps = 0, look = 0
}

enum StarEngine {
    static func neighbors4(_ i: Int, size n: Int) -> [Int] {
        let r = i / n, c = i % n
        var out: [Int] = []
        if r > 0 { out.append(i - n) }
        if r < n - 1 { out.append(i + n) }
        if c > 0 { out.append(i - 1) }
        if c < n - 1 { out.append(i + 1) }
        return out
    }

    /// 대각선까지 맞닿은 칸
    static func neighbors8(_ i: Int, size n: Int) -> [Int] {
        let r = i / n, c = i % n
        var out: [Int] = []
        for dr in -1...1 { for dc in -1...1 where dr != 0 || dc != 0 {
            let rr = r + dr, cc = c + dc
            if rr >= 0 && cc >= 0 && rr < n && cc < n { out.append(rr * n + cc) }
        } }
        return out
    }

    static func touching(_ a: Int, _ b: Int, size n: Int) -> Bool {
        a != b && abs(a / n - b / n) <= 1 && abs(a % n - b % n) <= 1
    }

    /// 줄 하나에 놓을 수 있는 열 조합(서로 붙지 않는 k개)
    static func rowCombos(_ n: Int, _ k: Int) -> [[Int]] {
        var out: [[Int]] = [], cur: [Int] = []
        func walk(_ from: Int) {
            if cur.count == k { out.append(cur); return }
            guard from < n else { return }
            for c in from..<n {
                if let last = cur.last, c - last < 2 { continue }
                cur.append(c); walk(c + 1); cur.removeLast()
            }
        }
        walk(0)
        return out
    }

    /// 가로줄(0..<n), 세로줄(n..<2n), 구역(2n..<3n) 목록
    static func units(_ p: StarPuzzle) -> [[Int]] {
        let n = p.size
        var out = (0..<n).map { r in (0..<n).map { r * n + $0 } } + (0..<n).map { c in (0..<n).map { $0 * n + c } }
        out += Array(repeating: [Int](), count: n)
        for (i, g) in p.regions.enumerated() { out[2 * n + g].append(i) }
        return out
    }

    /// 판정: 맞닿은 별과 별이 너무 많은 줄·구역의 별(bad), 다 풀렸는지.
    static func check(_ p: StarPuzzle, stars: [Int]) -> (bad: Set<Int>, solved: Bool) {
        let n = p.size, set = Set(stars)
        var bad = Set<Int>(), full = true
        for a in stars { for b in neighbors8(a, size: n) where set.contains(b) { bad.insert(a); bad.insert(b) } }
        for u in units(p) {
            let on = u.filter { set.contains($0) }
            if on.count > p.k { bad.formUnion(on) }
            if on.count != p.k { full = false }
        }
        return (bad, full && bad.isEmpty)
    }

    /// 답을 limit까지 센다. 줄마다 열 조합을 골라 넣는다.
    static func countSolutions(_ p: StarPuzzle, limit: Int = 2) -> Int {
        let n = p.size, k = p.k, owner = p.regions, combos = rowCombos(n, k)
        var colCnt = Array(repeating: 0, count: n), regCnt = Array(repeating: 0, count: n), regLeft = Array(repeating: 0, count: n)
        var prev = Array(repeating: [Int](), count: n), found = 0
        for g in owner { regLeft[g] += 1 }
        func go(_ r: Int) {
            if found >= limit { return }
            if r == n { found += 1; return }
            for cb in combos {
                if cb.contains(where: { colCnt[$0] >= k }) { continue }
                if r > 0 && cb.contains(where: { c in prev[r - 1].contains { abs($0 - c) <= 1 } }) { continue }
                let regs = cb.map { owner[r * n + $0] }
                if regs.contains(where: { g in regCnt[g] + regs.filter { $0 == g }.count > k }) { continue }
                for (a, c) in cb.enumerated() { colCnt[c] += 1; regCnt[regs[a]] += 1 }
                for c in 0..<n { regLeft[owner[r * n + c]] -= 1 }
                // 이 줄을 지나 더 칸이 없는데 별이 모자란 구역이 있으면 버린다
                if !(0..<n).contains(where: { regLeft[$0] == 0 && regCnt[$0] < k }) { prev[r] = cb; go(r + 1) }
                for c in 0..<n { regLeft[owner[r * n + c]] += 1 }
                for (a, c) in cb.enumerated() { colCnt[c] -= 1; regCnt[regs[a]] -= 1 }
                if found >= limit { return }
            }
        }
        go(0)
        return found
    }

    // MARK: 난이도: 사람처럼 푸는 풀이기
    // 칸 상태: 0 모름, 1 별, 2 빈칸. 쉬운 단계부터 쓰고, 막힐 때만 다음 단계를 쓴다. 웹(star-engine.js grade)과 같은 순서다.
    //  1단계 별 둘레 8칸 지우기, 별이 다 찬 줄·구역의 남은 칸 지우기, 남은 칸 수가 필요한 별 수와 같으면 모두 별
    //  2단계 구역의 남은 칸이 한 줄에만 있으면(또는 줄의 남은 칸이 한 구역에만 있으면) 그 줄(구역)의 다른 칸 지우기,
    //        여기에 별을 두면 어떤 줄·구역에 별을 다 놓을 수 없게 되는 칸 지우기
    //  3단계 구역 m개의 남은 칸이 줄 m개 안에만 있으면 그 줄들의 다른 칸 지우기(반대도), m = 2, 3
    //  4단계 한 단계 가정: 여기에 별을 두고 1~3단계로 풀어 보면 모순이 나는 칸 지우기
    // 끝까지 풀리면 결과, 막히면 nil. 끝까지 풀리면 답이 하나뿐이다.
    static func grade(_ p: StarPuzzle, maxTier: Int = 4) -> StarGrade? {
        let n = p.size, k = p.k, cellCount = n * n
        let units = self.units(p)
        var unitsAt = Array(repeating: [Int](), count: cellCount)
        for (x, u) in units.enumerated() { for i in u { unitsAt[i].append(x) } }
        let near = (0..<cellCount).map { neighbors8($0, size: n) }

        // 서로 닿지 않게 고를 수 있는 가장 많은 칸 수(limit에서 멈춘다)
        func capacity(_ cells: [Int], _ limit: Int) -> Int {
            var best = 0, picked: [Int] = []
            func walk(_ from: Int) {
                if picked.count > best { best = picked.count }
                if best >= limit { return }
                if picked.count + (cells.count - from) <= best { return }
                for a in from..<cells.count {
                    if picked.contains(where: { touching($0, cells[a], size: n) }) { continue }
                    picked.append(cells[a]); walk(a + 1); picked.removeLast()
                    if best >= limit { return }
                }
            }
            walk(0)
            return best
        }
        func consistent(_ s: [Int]) -> Bool {
            for u in units {
                var stars = 0, open: [Int] = []
                for i in u { if s[i] == 1 { stars += 1 } else if s[i] == 0 { open.append(i) } }
                if stars > k || stars + open.count < k { return false }
                if stars < k && capacity(open, k - stars) < k - stars { return false }
            }
            for i in 0..<cellCount where s[i] == 1 { for j in near[i] where s[j] == 1 { return false } }
            return true
        }
        func place(_ s: inout [Int], _ i: Int) {
            s[i] = 1
            for j in near[i] where s[j] == 0 { s[j] = 2 }
        }
        // 1단계. 바뀌었으면 true, 모순이면 nil
        func basic(_ s: inout [Int]) -> Bool? {
            var changed = false
            for u in units {
                var stars = 0, open: [Int] = []
                for i in u { if s[i] == 1 { stars += 1 } else if s[i] == 0 { open.append(i) } }
                if stars > k || stars + open.count < k { return nil }
                if stars == k && !open.isEmpty { for i in open { s[i] = 2 }; changed = true }
                else if !open.isEmpty && stars + open.count == k {
                    for i in open {
                        if near[i].contains(where: { s[$0] == 1 }) { return nil }
                        place(&s, i)
                    }
                    changed = true
                }
            }
            for i in 0..<cellCount where s[i] == 1 {
                for j in near[i] {
                    if s[j] == 1 { return nil }
                    if s[j] == 0 { s[j] = 2; changed = true }
                }
            }
            return changed
        }
        func linesOf(_ cells: [Int], row: Bool) -> [Int] {
            var out: [Int] = []
            for i in cells { let l = row ? i / n : i % n; if !out.contains(l) { out.append(l) } }
            return out
        }
        func openOf(_ s: [Int], _ u: [Int]) -> [Int] { u.filter { s[$0] == 0 } }
        func need(_ s: [Int], _ u: [Int]) -> Int { k - u.filter { s[$0] == 1 }.count }
        // 2단계
        func pointing(_ s: inout [Int]) -> Bool {
            var changed = false
            for g in 0..<n {
                let u = units[2 * n + g], open = openOf(s, u), want = need(s, u)
                if open.isEmpty || want == 0 { continue }
                for row in [true, false] {
                    let ls = linesOf(open, row: row)
                    guard ls.count == 1 else { continue }
                    let line = units[row ? ls[0] : n + ls[0]]
                    guard need(s, line) == want else { continue }
                    for i in openOf(s, line) where s[i] == 0 && !u.contains(i) { s[i] = 2; changed = true }
                }
            }
            for x in 0..<(2 * n) {
                let line = units[x], open = openOf(s, line), want = need(s, line)
                if open.isEmpty || want == 0 { continue }
                var gs: [Int] = []
                for i in open where !gs.contains(p.regions[i]) { gs.append(p.regions[i]) }
                guard gs.count == 1 else { continue }
                let region = units[2 * n + gs[0]]
                guard need(s, region) == want else { continue }
                for i in openOf(s, region) where !line.contains(i) { s[i] = 2; changed = true }
            }
            return changed
        }
        func killers(_ s: inout [Int]) -> Bool {
            var changed = false
            for i in 0..<cellCount where s[i] == 0 {
                var t = s
                place(&t, i)
                for x in unitsAt[i] where units[x].filter({ t[$0] == 1 }).count == k {
                    for j in units[x] where t[j] == 0 { t[j] = 2 }
                }
                if !consistent(t) { s[i] = 2; changed = true }
            }
            return changed
        }
        // 3단계: 구역 m개 ↔ 줄 m개
        func pigeon(_ s: inout [Int]) -> Bool {
            var changed = false
            let regs = (0..<n).filter { !openOf(s, units[2 * n + $0]).isEmpty && need(s, units[2 * n + $0]) > 0 }
            for row in [true, false] {
                func lineUnit(_ l: Int) -> [Int] { units[row ? l : n + l] }
                func pickRegs(_ from: Int, _ chosen: [Int], _ m: Int) {
                    if chosen.count == m {
                        let cells = chosen.flatMap { openOf(s, units[2 * n + $0]) }
                        let ls = linesOf(cells, row: row)
                        guard ls.count == m else { return }
                        let wantRegs = chosen.reduce(0) { $0 + need(s, units[2 * n + $1]) }
                        let wantLines = ls.reduce(0) { $0 + need(s, lineUnit($1)) }
                        guard wantRegs == wantLines else { return }
                        for l in ls { for i in openOf(s, lineUnit(l)) where !chosen.contains(p.regions[i]) { s[i] = 2; changed = true } }
                        return
                    }
                    if from < regs.count { for a in from..<regs.count { pickRegs(a + 1, chosen + [regs[a]], m) } }
                }
                let liveLines = (0..<n).filter { !openOf(s, lineUnit($0)).isEmpty && need(s, lineUnit($0)) > 0 }
                func pickLines(_ from: Int, _ chosen: [Int], _ m: Int) {
                    if chosen.count == m {
                        let cells = chosen.flatMap { openOf(s, lineUnit($0)) }
                        var gs: [Int] = []
                        for i in cells where !gs.contains(p.regions[i]) { gs.append(p.regions[i]) }
                        guard gs.count == m else { return }
                        let wantLines = chosen.reduce(0) { $0 + need(s, lineUnit($1)) }
                        let wantRegs = gs.reduce(0) { $0 + need(s, units[2 * n + $1]) }
                        guard wantRegs == wantLines else { return }
                        for g in gs { for i in openOf(s, units[2 * n + g]) where !chosen.contains(row ? i / n : i % n) { s[i] = 2; changed = true } }
                        return
                    }
                    if from < liveLines.count { for a in from..<liveLines.count { pickLines(a + 1, chosen + [liveLines[a]], m) } }
                }
                for m in [2, 3] { pickRegs(0, [], m); pickLines(0, [], m) }
            }
            return changed
        }
        enum Outcome { case solved, stuck, contra }
        func propagate(_ s: inout [Int], _ info: inout StarGrade?, _ upto: Int) -> Outcome {
            while true {
                guard let b = basic(&s), consistent(s) else { return .contra }
                if b { if info != nil { info!.tier = max(info!.tier, 1) }; continue }
                if !s.contains(0) {
                    return units.allSatisfy { u in u.filter { s[$0] == 1 }.count == k } ? .solved : .contra
                }
                if upto >= 2 && (pointing(&s) || killers(&s)) { if info != nil { info!.tier = max(info!.tier, 2) }; continue }
                if upto >= 3 && pigeon(&s) { if info != nil { info!.tier = max(info!.tier, 3); info!.steps += 1 }; continue }
                return .stuck
            }
        }
        var s = Array(repeating: 0, count: cellCount)
        var info: StarGrade? = StarGrade()
        while true {
            let r = propagate(&s, &info, min(3, maxTier))
            if r == .solved { return info }
            if r == .contra || maxTier < 4 { return nil }
            var found = false
            for i in 0..<cellCount where !found && s[i] == 0 {
                var t = s
                place(&t, i)
                var none: StarGrade? = nil
                if propagate(&t, &none, 3) == .contra { s[i] = 2; found = true }
            }
            if !found { return nil }
            info!.tier = 4
            info!.look += 1
        }
    }

    // MARK: 생성
    // 1. 별 정답을 먼저 놓는다. 2. 별을 씨앗으로 구역을 키운다(k=2면 가까운 별 둘을 한 구역으로).
    // 3. 답이 여럿이면 구역 경계의 칸 하나를 이웃 구역으로 넘기며 답이 하나가 될 때까지 고친다(정답은 그대로 맞다).
    static func placeStars<R: RandomNumberGenerator>(_ n: Int, _ k: Int, using rng: inout R) -> [Int]? {
        let combos = rowCombos(n, k)
        var colCnt = Array(repeating: 0, count: n), rows = Array(repeating: [Int](), count: n), budget = 20000
        func go(_ r: Int) -> Bool {
            if r == n { return true }
            budget -= 1
            if budget < 0 { return false }
            for cb in combos.shuffled(using: &rng) {
                if cb.contains(where: { colCnt[$0] >= k }) { continue }
                if r > 0 && cb.contains(where: { c in rows[r - 1].contains { abs($0 - c) <= 1 } }) { continue }
                for c in cb { colCnt[c] += 1 }
                rows[r] = cb
                if go(r + 1) { return true }
                for c in cb { colCnt[c] -= 1 }
            }
            return false
        }
        guard go(0) else { return nil }
        return rows.enumerated().flatMap { r, cb in cb.map { r * n + $0 } }
    }

    static func connected(_ owner: [Int], _ g: Int, size n: Int) -> Bool {
        let cells = owner.indices.filter { owner[$0] == g }
        guard let first = cells.first else { return false }
        var seen: Set<Int> = [first], stack = [first]
        while let x = stack.popLast() {
            for y in neighbors4(x, size: n) where owner[y] == g && !seen.contains(y) { seen.insert(y); stack.append(y) }
        }
        return seen.count == cells.count
    }

    static func growRegions<R: RandomNumberGenerator>(_ n: Int, _ k: Int, _ stars: [Int], using rng: inout R) -> [Int]? {
        var owner = Array(repeating: -1, count: n * n)
        var groups: [[Int]]
        if k == 1 {
            groups = stars.map { [$0] }
        } else {
            func d(_ a: Int, _ b: Int) -> Int { abs(a / n - b / n) + abs(a % n - b % n) }
            var left = stars.shuffled(using: &rng)
            groups = []
            while let a = left.popLast() {
                var bi = 0
                for (x, b) in left.enumerated() where d(a, b) < d(a, left[bi]) { bi = x }
                groups.append([a, left.remove(at: bi)])
            }
        }
        for (id, g) in groups.enumerated() {
            for s in g { owner[s] = id }
            if g.count == 2 {
                // 짝 별 사이를 잇는 길을 먼저 칠한다(다른 구역 칸은 건너뛴다)
                var r = g[0] / n, c = g[0] % n
                let br = g[1] / n, bc = g[1] % n
                while r != br || c != bc {
                    if r != br && (c == bc || Double.random(in: 0..<1, using: &rng) < 0.5) { r += (br - r).signum() } else { c += (bc - c).signum() }
                    if owner[r * n + c] == -1 { owner[r * n + c] = id }
                }
            }
        }
        while true {
            var options: [(Int, Int)] = []
            for i in 0..<(n * n) where owner[i] >= 0 { for j in neighbors4(i, size: n) where owner[j] == -1 { options.append((j, owner[i])) } }
            guard let (j, o) = options.randomElement(using: &rng) else { break }
            owner[j] = o
        }
        if owner.contains(-1) { return nil }
        for g in 0..<n where !connected(owner, g, size: n) { return nil }
        return owner
    }

    static func makeUnique<R: RandomNumberGenerator>(_ level: StarLevel, using rng: inout R) -> StarPuzzle? {
        let n = level.size, k = level.stars
        guard let stars = placeStars(n, k, using: &rng), let regions = growRegions(n, k, stars, using: &rng) else { return nil }
        let starSet = Set(stars)
        var p = StarPuzzle(size: n, k: k, regions: regions, solution: stars.sorted(), level: level)
        for _ in 0..<400 {
            if countSolutions(p) == 1 { return p }
            var cand: [(Int, Int)] = []
            for i in 0..<(n * n) where !starSet.contains(i) {
                for j in neighbors4(i, size: n) where p.regions[j] != p.regions[i] { cand.append((i, p.regions[j])) }
            }
            guard let (i, o) = cand.randomElement(using: &rng) else { return nil }
            let old = p.regions[i]
            p.regions[i] = o
            if !connected(p.regions, old, size: n) { p.regions[i] = old }
        }
        return nil
    }

    /// 범위에 맞는 판이 나오면 바로 낸다. searchSeconds가 있으면 그 시간 동안 만들어 보고 가장 어려운 판을 낸다.
    /// 시간 안에 범위에 맞는 판을 못 찾으면 그동안 가장 가까웠던 판을 낸다.
    static func generate<R: RandomNumberGenerator>(_ level: StarLevel, using rng: inout R) -> StarPuzzle {
        let start = Date(), wait = level.searchSeconds ?? 3
        var best: StarPuzzle?, bestScore = -1
        while true {
            if let p = makeUnique(level, using: &rng), let g = grade(p, maxTier: level.tier.upperBound) {
                let inRange = g.tier >= level.tier.lowerBound
                if inRange && level.searchSeconds == nil { return p }
                let score = (inRange ? 1_000_000 : 0) + g.tier * 1000 + g.look * 10 + g.steps
                if score > bestScore { best = p; bestScore = score }
            }
            if let best, Date().timeIntervalSince(start) > wait { return best }
        }
    }
}
