import Foundation
import Observation

struct StarSnapshot: Codable {
    var puzzle: StarPuzzle
    var marks: [UInt8]
    var elapsed: TimeInterval
    var counted: Bool
    var undosUsed: Int
    var savedAt: Date

    var progress: Double {
        let total = puzzle.size * puzzle.k
        return total > 0 ? Double(marks.filter { $0 == StarGame.star }.count) / Double(total) : 0
    }
}

enum StarSave {
    static let file = "star.json"
    static func load() -> StarSnapshot? { JSONSave.load(StarSnapshot.self, from: file) }
    static func save(_ snapshot: StarSnapshot?) { JSONSave.save(snapshot, to: file) }
    static func clear() { JSONSave.clear(file) }
}

/// 별네모: 가로줄·세로줄·구역마다 정해진 수의 별을 놓되, 별끼리는 대각선으로도 닿지 않게 한다.
@MainActor
@Observable
final class StarGame: HostedPuzzle {
    /// 칸 표시: 빈칸, 점(별 없음 표시), 별
    static let empty: UInt8 = 0, dot: UInt8 = 1, star: UInt8 = 2

    private(set) var puzzle: StarPuzzle?
    private(set) var marks: [UInt8] = []
    private(set) var status: PuzzleStatus = .empty
    private(set) var isNewBest = false

    /// 바꾸기 전 marks를 통째로 담는다.
    private var history: [[UInt8]] = []
    private(set) var counted = false
    private(set) var undosUsed = 0
    private var timer = PuzzleTimer()

    var level: StarLevel { puzzle?.level ?? .easy }
    var levelID: Int? { puzzle?.level.rawValue }
    var size: Int { puzzle?.size ?? 5 }
    var undosLeft: Int? { UndoLimit.count(forLevel: level.name).map { max(0, $0 - undosUsed) } }
    var canUndo: Bool { !history.isEmpty && status == .playing && undosLeft != 0 }
    var stars: [Int] { marks.indices.filter { marks[$0] == Self.star } }

    func elapsed(at now: Date) -> TimeInterval { timer.elapsed(at: now) }

    func start(_ puzzle: StarPuzzle, saved: StarSnapshot? = nil) {
        self.puzzle = puzzle
        marks = saved?.marks ?? Array(repeating: Self.empty, count: puzzle.size * puzzle.size)
        history = []
        counted = saved?.counted ?? false
        undosUsed = saved?.undosUsed ?? 0
        isNewBest = false
        timer = PuzzleTimer(elapsed: saved?.elapsed ?? 0)
        timer.start()
        status = .playing
    }

    func restoreSaved() -> Bool {
        guard let s = StarSave.load() else { return false }
        let cells = s.puzzle.size * s.puzzle.size
        guard s.puzzle.size >= 4, s.puzzle.k >= 1, s.puzzle.regions.count == cells, s.marks.count == cells,
              s.marks.allSatisfy({ $0 <= Self.star }) else { return false }
        start(s.puzzle, saved: s)
        return true
    }

    func restart() {
        guard let puzzle else { return }
        let used = undosUsed, wasCounted = counted
        start(puzzle)
        undosUsed = used
        counted = wasCounted
    }

    func save() {
        guard status == .playing, let puzzle else { return }
        StarSave.save(StarSnapshot(puzzle: puzzle, marks: marks, elapsed: elapsed(at: .now),
                                   counted: counted, undosUsed: undosUsed, savedAt: .now))
    }

    func pause() { timer.pause() }

    func resume() {
        guard status == .playing else { return }
        timer.start()
    }

    /// 바뀐 판을 한 번에 받는다(누르기 한 번, 끌기 한 번이 되돌리기 한 번).
    func commit(_ next: [UInt8]) {
        guard status == .playing, let puzzle, next != marks else { return }
        history.append(marks)
        if history.count > 500 { history.removeFirst(history.count - 500) }
        marks = next
        if !counted {
            counted = true
            StatsStore.recordStart(.star)
        }
        if StarEngine.check(puzzle, stars: stars).solved {
            timer.pause()
            status = .won
            isNewBest = StatsStore.recordWinIsBest(.star, difficulty: puzzle.level.name, seconds: Int(elapsed(at: .now).rounded()))
        }
    }

    /// 누르면 빈칸 → 점 → 별 → 빈칸.
    func cycle(_ i: Int) {
        var next = marks
        next[i] = (next[i] + 1) % 3
        commit(next)
    }

    func clearAll() {
        commit(Array(repeating: Self.empty, count: marks.count))
    }

    func undo() {
        guard canUndo, let last = history.popLast() else { return }
        marks = last
        undosUsed += 1
    }

    /// 규칙에 어긋난 별(맞닿았거나 너무 많은 줄·구역).
    func bad(for marks: [UInt8]) -> Set<Int> {
        guard let puzzle else { return [] }
        return StarEngine.check(puzzle, stars: marks.indices.filter { marks[$0] == Self.star }).bad
    }
}
