import Foundation

/// 시카쿠 난이도. 판 크기와 영역 넓이 상한으로 정한다.
enum ShikakuLevel: Int, Codable, CaseIterable, Identifiable, Comparable {
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
        case .medium: 7
        case .hard: 10
        case .expert: 12
        }
    }

    /// 한 영역의 최대 넓이. 판이 클수록 큰 직사각형이 나온다.
    var maxArea: Int {
        switch self {
        case .easy: 6
        case .medium: 9
        case .hard: 12
        case .expert: 16
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
                if cands[k].isEmpty { return nil }
                if cands[k].count == 1 { place(k, cands[k][0]); progress = true }
            }
            if progress { continue }

            // 2. 어떤 칸을 덮을 수 있는 숫자가 하나뿐이면, 그 숫자의 후보는 그 칸을 덮는 것만 남긴다.
            for i in 0..<(n * n) where owner[i] == -1 {
                var who = Set<Int>()
                for k in clues.indices where placed[k] == nil && cands[k].contains(where: { $0.contains(index: i, size: n) }) {
                    who.insert(k)
                }
                if who.isEmpty { return nil }
                if who.count == 1, let k = who.first {
                    let before = cands[k].count
                    cands[k].removeAll { !$0.contains(index: i, size: n) }
                    if cands[k].count < before { progress = true }
                }
            }
            if progress { continue }

            // 3. 한 숫자의 모든 후보가 함께 덮는 칸은 그 숫자 몫이다. 다른 숫자의 후보에서 그 칸을 뺀다.
            for k in clues.indices where placed[k] == nil {
                var common = Set(cands[k][0].cells(size: n))
                for rect in cands[k].dropFirst() { common.formIntersection(rect.cells(size: n)) }
                for j in clues.indices where j != k && placed[j] == nil {
                    let before = cands[j].count
                    cands[j].removeAll { rect in rect.cells(size: n).contains { common.contains($0) } }
                    if cands[j].isEmpty { return nil }
                    if cands[j].count < before { progress = true }
                }
            }
            if !progress { return nil }
        }
        return placed.compactMap { $0 }
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

    /// 정답이 하나뿐이고 추측 없이 풀리는 퍼즐을 만든다.
    static func generate<R: RandomNumberGenerator>(_ level: ShikakuLevel, using rng: inout R) -> ShikakuPuzzle {
        let n = level.size
        while true {
            let rects = partition(size: n, maxArea: level.maxArea, using: &rng)
            // 같은 나눔에서 숫자 위치만 바꿔 여러 번 시도한다.
            for _ in 0..<30 {
                let clues = rects.map { rect in
                    ShikakuClue(index: rect.cells(size: n).randomElement(using: &rng)!, area: rect.area)
                }
                guard let solved = solveLogically(size: n, clues: clues) else { continue }
                // 논리로 풀린 답이 나눈 영역과 같아야 하고, 다른 해가 없어야 한다.
                guard solved == rects, countSolutions(size: n, clues: clues) == 1 else { continue }
                return ShikakuPuzzle(size: n, clues: clues, solution: rects, level: level)
            }
        }
    }
}
