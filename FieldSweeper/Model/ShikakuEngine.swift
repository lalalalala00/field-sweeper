import Foundation

/// 시카쿠 난이도. 판 크기와 영역 넓이 상한으로 정한다.
enum ShikakuLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
    case easy = 1, medium, hard, expert
    /// 판 크기와 영역 크기를 사용자가 정한다.
    case custom

    /// 난이도 고르기에 나오는 기본 난이도.
    static let presets: [ShikakuLevel] = [.easy, .medium, .hard, .expert]

    var id: Int { rawValue }
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .easy: "초급"
        case .medium: "중급"
        case .hard: "고급"
        case .expert: "전문가"
        case .custom: "커스텀"
        }
    }

    var size: Int {
        switch self {
        case .easy: 5
        case .medium: 7
        case .hard: 10
        case .expert, .custom: 12
        }
    }

    /// 한 영역의 최대 넓이. 판이 클수록 큰 직사각형이 나온다.
    var maxArea: Int {
        switch self {
        case .easy: 6
        case .medium: 9
        case .hard: 12
        case .expert, .custom: 16
        }
    }

    /// 몇 개를 만들어 그중 가장 생각이 많이 필요한 것을 고를지.
    fileprivate var picks: Int {
        switch self {
        case .easy: 4
        case .medium: 10
        case .hard, .expert, .custom: 16
        }
    }
}

/// 판 위의 직사각형. 칸 좌표는 (row, col), 크기는 height × width.
struct ShikakuRect: Codable, Hashable {
    var row: Int
    var col: Int
    var height: Int
    var width: Int

    var area: Int { height * width }

    func contains(_ r: Int, _ c: Int) -> Bool {
        r >= row && r < row + height && c >= col && c < col + width
    }

    func contains(index i: Int, size n: Int) -> Bool { contains(i / n, i % n) }

    func cells(size n: Int) -> [Int] {
        var out: [Int] = []
        out.reserveCapacity(area)
        for r in row..<(row + height) { for c in col..<(col + width) { out.append(r * n + c) } }
        return out
    }

    func intersects(_ o: ShikakuRect) -> Bool {
        row < o.row + o.height && o.row < row + height && col < o.col + o.width && o.col < col + width
    }

    /// 변이 맞닿아 있는지(모서리만 닿는 건 제외).
    func touches(_ o: ShikakuRect) -> Bool {
        let rowsOverlap = row < o.row + o.height && o.row < row + height
        let colsOverlap = col < o.col + o.width && o.col < col + width
        return (rowsOverlap && (col + width == o.col || o.col + o.width == col))
            || (colsOverlap && (row + height == o.row || o.row + o.height == row))
    }

    /// 두 칸을 양 끝으로 하는 직사각형.
    static func spanning(_ a: Int, _ b: Int, size n: Int) -> ShikakuRect {
        let r0 = min(a / n, b / n), r1 = max(a / n, b / n)
        let c0 = min(a % n, b % n), c1 = max(a % n, b % n)
        return ShikakuRect(row: r0, col: c0, height: r1 - r0 + 1, width: c1 - c0 + 1)
    }
}

struct ShikakuClue: Codable, Hashable {
    /// 숫자가 적힌 칸.
    var index: Int
    /// 영역의 넓이.
    var area: Int
}

struct ShikakuPuzzle: Codable, Equatable {
    var size: Int
    var clues: [ShikakuClue]
    /// clues와 같은 순서의 정답 영역.
    var solution: [ShikakuRect]
    var level: ShikakuLevel
}

enum ShikakuEngine {
    /// 숫자마다 놓을 수 있는 직사각형: 그 숫자를 포함하고, 넓이가 같고, 다른 숫자는 포함하지 않는다.
    static func candidates(size n: Int, clues: [ShikakuClue]) -> [[ShikakuRect]] {
        var clueAt = Array(repeating: -1, count: n * n)
        for (k, clue) in clues.enumerated() { clueAt[clue.index] = k }
        return clues.enumerated().map { k, clue in
            let r = clue.index / n, c = clue.index % n
            var out: [ShikakuRect] = []
            for h in 1...clue.area where clue.area % h == 0 {
                let w = clue.area / h
                guard h <= n, w <= n else { continue }
                for top in max(0, r - h + 1)...min(r, n - h) {
                    for left in max(0, c - w + 1)...min(c, n - w) {
                        let rect = ShikakuRect(row: top, col: left, height: h, width: w)
                        if rect.cells(size: n).allSatisfy({ clueAt[$0] == -1 || clueAt[$0] == k }) { out.append(rect) }
                    }
                }
            }
            return out
        }
    }

    /// 해의 개수를 limit까지 센다.
    static func countSolutions(size n: Int, clues: [ShikakuClue], limit: Int = 2) -> Int {
        guard clues.reduce(0, { $0 + $1.area }) == n * n else { return 0 }
        let cands = candidates(size: n, clues: clues)
        var covered = Array(repeating: false, count: n * n)
        var done = Array(repeating: false, count: clues.count)
        var count = 0

        func fits(_ rect: ShikakuRect) -> Bool { rect.cells(size: n).allSatisfy { !covered[$0] } }

        func search(_ left: Int) {
            if count >= limit { return }
            if left == 0 { count += 1; return }
            // 남은 후보가 가장 적은 숫자부터.
            var best = -1, bestList: [ShikakuRect] = []
            for k in clues.indices where !done[k] {
                let list = cands[k].filter(fits)
                if list.isEmpty { return }
                if best < 0 || list.count < bestList.count { best = k; bestList = list; if list.count == 1 { break } }
            }
            done[best] = true
            for rect in bestList {
                let cells = rect.cells(size: n)
                for i in cells { covered[i] = true }
                search(left - 1)
                for i in cells { covered[i] = false }
                if count >= limit { break }
            }
            done[best] = false
        }
        search(clues.count)
        return count
    }

    /// 추측 없이 규칙만으로 풀어 본다. 풀리면 clues 순서의 영역, 막히면 nil.
    static func solveLogically(size n: Int, clues: [ShikakuClue]) -> [ShikakuRect]? {
        solve(size: n, clues: clues).rects
    }

    /// 논리 풀이 결과와, 바로 정해지지 않아 규칙 2·3을 써야 했던 횟수(effort).
    /// effort가 클수록 한 번에 보이지 않는 추론이 많이 필요한 퍼즐이다.
    static func solve(size n: Int, clues: [ShikakuClue]) -> (rects: [ShikakuRect]?, effort: Int, forcedAtStart: Int, stuck: [Int]) {
        var effort = 0
        let forcedAtStart = candidates(size: n, clues: clues).filter { $0.count == 1 }.count
        var cands = candidates(size: n, clues: clues)
        var owner = Array(repeating: -1, count: n * n)
        var placed: [ShikakuRect?] = Array(repeating: nil, count: clues.count)

        func place(_ k: Int, _ rect: ShikakuRect) {
            placed[k] = rect
            cands[k] = [rect]
            for i in rect.cells(size: n) { owner[i] = k }
        }

        while placed.contains(where: { $0 == nil }) {
            var progress = false

            // 1. 이미 덮인 칸과 겹치는 후보를 지우고, 하나 남으면 확정.
            for k in clues.indices where placed[k] == nil {
                cands[k].removeAll { rect in rect.cells(size: n).contains { owner[$0] != -1 } }
                if cands[k].isEmpty { return (nil, effort, forcedAtStart, clues.indices.filter { placed[$0] == nil }) }
                if cands[k].count == 1 { place(k, cands[k][0]); progress = true }
            }
            if progress { continue }
            effort += 1

            // 2. 어떤 칸을 덮을 수 있는 숫자가 하나뿐이면, 그 숫자의 후보는 그 칸을 덮는 것만 남긴다.
            for i in 0..<(n * n) where owner[i] == -1 {
                var who = Set<Int>()
                for k in clues.indices where placed[k] == nil && cands[k].contains(where: { $0.contains(index: i, size: n) }) {
                    who.insert(k)
                }
                if who.isEmpty { return (nil, effort, forcedAtStart, clues.indices.filter { placed[$0] == nil }) }
                if who.count == 1, let k = who.first {
                    let before = cands[k].count
                    cands[k].removeAll { !$0.contains(index: i, size: n) }
                    if cands[k].count < before { progress = true }
                }
            }
            if progress { continue }
            effort += 2

            // 3. 한 숫자의 모든 후보가 함께 덮는 칸은 그 숫자 몫이다. 다른 숫자의 후보에서 그 칸을 뺀다.
            for k in clues.indices where placed[k] == nil {
                var common = Set(cands[k][0].cells(size: n))
                for rect in cands[k].dropFirst() { common.formIntersection(rect.cells(size: n)) }
                for j in clues.indices where j != k && placed[j] == nil {
                    let before = cands[j].count
                    cands[j].removeAll { rect in rect.cells(size: n).contains { common.contains($0) } }
                    if cands[j].isEmpty { return (nil, effort, forcedAtStart, clues.indices.filter { placed[$0] == nil }) }
                    if cands[j].count < before { progress = true }
                }
            }
            if !progress { return (nil, effort, forcedAtStart, clues.indices.filter { placed[$0] == nil }) }
        }
        return (placed.compactMap { $0 }, effort, forcedAtStart, [])
    }

    // MARK: 생성

    /// 판을 직사각형들로 나눈다. 1칸짜리는 다른 방법이 없을 때만 쓴다.
    static func partition<R: RandomNumberGenerator>(size n: Int, maxArea: Int, using rng: inout R) -> [ShikakuRect] {
        var owner = Array(repeating: false, count: n * n)
        var rects: [ShikakuRect] = []
        for start in 0..<(n * n) where !owner[start] {
            let r = start / n, c = start % n
            var options: [ShikakuRect] = []
            var maxW = n - c
            for h in 1...(n - r) {
                var w = 0
                while w < maxW && !owner[(r + h - 1) * n + c + w] { w += 1 }
                maxW = w
                if maxW == 0 { break }
                for width in 1...maxW where h * width <= maxArea {
                    options.append(ShikakuRect(row: r, col: c, height: h, width: width))
                }
            }
            let bigger = options.filter { $0.area >= 2 }
            let pool = bigger.isEmpty ? options : bigger
            // 너무 길쭉한 영역은 덜 나오게 한다.
            let weights = pool.map { rect -> Double in
                let ratio = Double(max(rect.height, rect.width)) / Double(min(rect.height, rect.width))
                return 1 / ratio
            }
            var pick = Double.random(in: 0..<weights.reduce(0, +), using: &rng)
            var chosen = pool[pool.count - 1]
            for (rect, w) in zip(pool, weights) {
                if pick < w { chosen = rect; break }
                pick -= w
            }
            for i in chosen.cells(size: n) { owner[i] = true }
            rects.append(chosen)
        }
        return rects
    }

    /// 커스텀 판 크기 범위.
    static let customSizes = 5...15

    /// 커스텀에서 고르는 영역 크기. 판 크기에 비례해 최대 넓이를 정한다.
    enum RegionSize: Int, CaseIterable {
        case small, medium, large

        var name: String {
            switch self {
            case .small: "작게"
            case .medium: "보통"
            case .large: "크게"
            }
        }

        func maxArea(for n: Int) -> Int {
            switch self {
            case .small: max(4, Int((Double(n) * 0.8).rounded()))
            case .medium: max(6, Int((Double(n) * 1.3).rounded()))
            case .large: max(8, Int((Double(n) * 1.6).rounded()))
            }
        }
    }

    /// 정답이 하나뿐이고 추측 없이 풀리는 퍼즐을 여러 개 만들어,
    /// 바로 정해지지 않아 더 생각해야 하는 것을 고른다.
    static func generate<R: RandomNumberGenerator>(_ level: ShikakuLevel, size: Int? = nil, maxArea: Int? = nil,
                                                   using rng: inout R) -> ShikakuPuzzle {
        let n = size ?? level.size
        let area = maxArea ?? level.maxArea
        var best: (puzzle: ShikakuPuzzle, score: Int)?
        // 큰 판은 한 개 만드는 데도 시간이 걸리므로, 시간 한도 안에서만 더 골라 본다.
        let deadline = Date.now.addingTimeInterval(1.5)
        for _ in 0..<level.picks {
            if best != nil && Date.now > deadline { break }
            let puzzle = generateOne(level, size: n, maxArea: area, using: &rng)
            let result = solve(size: n, clues: puzzle.clues)
            let score = result.effort * 10 - result.forcedAtStart
            if best.map({ score > $0.score }) ?? true { best = (puzzle, score) }
        }
        return best!.puzzle
    }

    private static func generateOne<R: RandomNumberGenerator>(_ level: ShikakuLevel, size n: Int, maxArea: Int,
                                                              using rng: inout R) -> ShikakuPuzzle {
        while true {
            let rects = partition(size: n, maxArea: maxArea, using: &rng)
            var clues = rects.map { rect in
                ShikakuClue(index: rect.cells(size: n).randomElement(using: &rng)!, area: rect.area)
            }
            // 논리 풀이가 막히면, 아직 못 정한 영역 하나의 숫자 위치만 옮겨 다시 풀어 본다.
            for _ in 0..<(rects.count * 4) {
                let result = solve(size: n, clues: clues)
                // 규칙(모두 확실한 추론)만으로 끝까지 풀렸다면 해는 하나뿐이고, 나눈 영역과 같다.
                if result.rects != nil {
                    return ShikakuPuzzle(size: n, clues: clues, solution: rects, level: level)
                }
                guard let k = result.stuck.randomElement(using: &rng) else { break }
                clues[k].index = rects[k].cells(size: n).randomElement(using: &rng)!
            }
        }
    }
}
