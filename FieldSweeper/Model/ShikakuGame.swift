import Foundation
import Observation

/// 사용자가 만든 영역과 그 영역에 배정된 색 번호.
struct ShikakuRegion: Codable, Hashable {
    var rect: ShikakuRect
    var color: Int
}

struct ShikakuSnapshot: Codable {
    var puzzle: ShikakuPuzzle
    var regions: [ShikakuRegion]
    var elapsed: TimeInterval
    var counted: Bool
    var savedAt: Date

    /// 영역으로 덮은 칸의 비율.
    var progress: Double {
        let total = puzzle.size * puzzle.size
        return total > 0 ? Double(regions.reduce(0) { $0 + $1.rect.area }) / Double(total) : 0
    }
}

enum ShikakuSave {
    static let file = "shikaku.json"
    static func load() -> ShikakuSnapshot? { JSONSave.load(ShikakuSnapshot.self, from: file) }
    static func save(_ snapshot: ShikakuSnapshot?) { JSONSave.save(snapshot, to: file) }
    static func clear() { JSONSave.clear(file) }
}

@MainActor
@Observable
final class ShikakuGame {
    enum Status { case empty, playing, won }

    /// 영역을 확정할 수 없는 이유. 화면에 안내로 보여준다.
    enum Problem: Equatable {
        case noClue
        case manyClues
        case wrongArea(need: Int, got: Int)
        case overlap
    }

    private enum Action {
        case add(ShikakuRegion)
        case remove(ShikakuRegion)
        case clear([ShikakuRegion])
    }

    /// 영역 색 개수(ShikakuColors.regions와 같아야 한다).
    static let colorCount = 6

    private(set) var puzzle: ShikakuPuzzle?
    private(set) var regions: [ShikakuRegion] = []
    private(set) var status: Status = .empty
    private(set) var isNewBest = false
    /// 지우기 대상으로 고른 영역.
    var selected: ShikakuRegion?

    private var history: [Action] = []
    private(set) var counted = false
    private var accumulated: TimeInterval = 0
    private var runningSince: Date?

    var level: ShikakuLevel { puzzle?.level ?? .easy }
    var size: Int { puzzle?.size ?? 5 }
    var canUndo: Bool { !history.isEmpty && status == .playing }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    var progress: Double {
        let total = size * size
        return Double(regions.reduce(0) { $0 + $1.rect.area }) / Double(max(total, 1))
    }

    // MARK: 시작·저장

    func start(_ puzzle: ShikakuPuzzle) {
        self.puzzle = puzzle
        regions = []
        history = []
        selected = nil
        counted = false
        isNewBest = false
        accumulated = 0
        runningSince = .now
        status = .playing
    }

    func restore(_ s: ShikakuSnapshot) -> Bool {
        let n = s.puzzle.size
        guard n > 0, s.puzzle.clues.count == s.puzzle.solution.count,
              s.regions.allSatisfy({ $0.rect.row >= 0 && $0.rect.col >= 0 && $0.rect.row + $0.rect.height <= n && $0.rect.col + $0.rect.width <= n })
        else { return false }
        puzzle = s.puzzle
        regions = s.regions
        history = []
        selected = nil
        counted = s.counted
        isNewBest = false
        accumulated = s.elapsed
        runningSince = .now
        status = .playing
        return true
    }

    func restart() {
        guard let puzzle else { return }
        start(puzzle)
    }

    func snapshot() -> ShikakuSnapshot? {
        guard status == .playing, let puzzle else { return nil }
        return ShikakuSnapshot(puzzle: puzzle, regions: regions, elapsed: elapsed(at: .now), counted: counted, savedAt: .now)
    }

    func pause() {
        guard let since = runningSince else { return }
        accumulated += Date.now.timeIntervalSince(since)
        runningSince = nil
    }

    func resume() {
        guard status == .playing, runningSince == nil else { return }
        runningSince = .now
    }

    // MARK: 영역

    func clue(at index: Int) -> ShikakuClue? { puzzle?.clues.first { $0.index == index } }

    func region(at index: Int) -> ShikakuRegion? {
        let n = size
        return regions.first { $0.rect.contains(index: index, size: n) }
    }

    /// 규칙상 놓을 수 있는지만 본다. 정답 위치인지는 확인하지 않는다.
    func problem(with rect: ShikakuRect) -> Problem? {
        guard let puzzle else { return .noClue }
        let n = puzzle.size
        if regions.contains(where: { $0.rect.intersects(rect) }) { return .overlap }
        let inside = puzzle.clues.filter { rect.contains(index: $0.index, size: n) }
        if inside.isEmpty { return .noClue }
        if inside.count > 1 { return .manyClues }
        if inside[0].area != rect.area { return .wrongArea(need: inside[0].area, got: rect.area) }
        return nil
    }

    /// 영역을 만든다. 놓을 수 없으면 이유를 돌려준다.
    @discardableResult
    func add(_ rect: ShikakuRect) -> Problem? {
        guard status == .playing else { return nil }
        if let problem = problem(with: rect) { return problem }
        let region = ShikakuRegion(rect: rect, color: color(for: rect))
        regions.append(region)
        history.append(.add(region))
        selected = nil
        if !counted {
            counted = true
            StatsStore.recordStart(.shikaku)
        }
        checkWin()
        return nil
    }

    func removeSelected() {
        guard status == .playing, let region = selected, let k = regions.firstIndex(where: { $0.rect == region.rect }) else { return }
        regions.remove(at: k)
        history.append(.remove(region))
        selected = nil
    }

    func clearAll() {
        guard status == .playing, !regions.isEmpty else { return }
        history.append(.clear(regions))
        regions = []
        selected = nil
    }

    func undo() {
        guard status == .playing, let last = history.popLast() else { return }
        switch last {
        case .add(let region): regions.removeAll { $0.rect == region.rect }
        case .remove(let region): regions.append(region)
        case .clear(let all): regions = all
        }
        selected = nil
    }

    /// 맞닿은 영역과 다른 색 중에서 가장 덜 쓴 색.
    /// 남는 색이 없을 때만, 그 색을 쓰는 이웃 영역을 다른 색으로 옮겨 자리를 만든다.
    private func color(for rect: ShikakuRect) -> Int {
        var usage = Array(repeating: 0, count: Self.colorCount)
        for r in regions { usage[r.color] += 1 }
        let byUsage = (0..<Self.colorCount).sorted { usage[$0] < usage[$1] }
        let neighbors = Set(regions.filter { $0.rect.touches(rect) }.map(\.color))
        if let free = byUsage.first(where: { !neighbors.contains($0) }) { return free }

        for c in byUsage {
            let blockers = regions.indices.filter { regions[$0].color == c && regions[$0].rect.touches(rect) }
            var moves: [(Int, Int)] = []
            for k in blockers {
                let around = Set(regions.filter { $0.rect != regions[k].rect && $0.rect.touches(regions[k].rect) }.map(\.color))
                // 옮긴 색끼리 서로 맞닿을 수도 있으니 이번에 옮긴 것도 피한다.
                let taken = around.union(moves.filter { regions[$0.0].rect.touches(regions[k].rect) }.map(\.1))
                guard let to = byUsage.first(where: { $0 != c && !taken.contains($0) }) else { break }
                moves.append((k, to))
            }
            if moves.count == blockers.count {
                for (k, to) in moves { regions[k].color = to }
                return c
            }
        }
        return byUsage[0]
    }

    private func checkWin() {
        guard let puzzle else { return }
        // 모든 영역은 놓을 때 규칙을 확인했으므로, 판이 빈틈없이 덮이면 완성이다.
        guard regions.reduce(0, { $0 + $1.rect.area }) == puzzle.size * puzzle.size else { return }
        pause()
        status = .won
        selected = nil
        let seconds = Int(elapsed(at: .now).rounded())
        let previous = StatsStore.load(.shikaku).bestByDifficulty[puzzle.level.name]
        isNewBest = previous.map { seconds < $0 } ?? true
        StatsStore.recordWin(.shikaku, difficulty: puzzle.level.name, seconds: seconds)
    }
}
