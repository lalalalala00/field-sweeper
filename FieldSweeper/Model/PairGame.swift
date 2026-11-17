import Foundation
import Observation

struct PairSnapshot: Codable {
    var puzzle: PairPuzzle
    var paths: [[Int]]
    var elapsed: TimeInterval
    var counted: Bool
    var undosUsed: Int
    var savedAt: Date

    var progress: Double {
        let total = puzzle.clues.count / 2
        return total > 0 ? Double(paths.filter { PairGame.isComplete($0, puzzle) }.count) / Double(total) : 0
    }
}

enum PairSave {
    static let file = "pair.json"
    static func load() -> PairSnapshot? { JSONSave.load(PairSnapshot.self, from: file) }
    static func save(_ snapshot: PairSnapshot?) { JSONSave.save(snapshot, to: file) }
    static func clear() { JSONSave.clear(file) }
}

/// 짝네모: 같은 숫자끼리 숫자만큼의 칸으로 잇는다. 길은 겹칠 수 없다.
/// 각 길은 숫자 칸에서 시작하는 칸 배열이고, 짝 숫자에 닿기 전이면 끝이 빈칸이다(이어서 그릴 수 있다).
@MainActor
@Observable
final class PairGame: HostedPuzzle {
    private(set) var puzzle: PairPuzzle?
    private(set) var paths: [[Int]] = []
    private(set) var status: PuzzleStatus = .empty
    private(set) var isNewBest = false

    /// 바꾸기 전 paths를 통째로 담는다.
    private var history: [[[Int]]] = []
    private(set) var counted = false
    private(set) var undosUsed = 0
    private var timer = PuzzleTimer()

    var level: PairLevel { puzzle?.level ?? .easy }
    var levelID: Int? { puzzle?.level.rawValue }
    var size: Int { puzzle?.size ?? 5 }
    var undosLeft: Int? { UndoLimit.count(forLevel: level.name).map { max(0, $0 - undosUsed) } }
    var canUndo: Bool { !history.isEmpty && status == .playing && undosLeft != 0 }
    var totalPairs: Int { (puzzle?.clues.count ?? 0) / 2 }
    var completeCount: Int {
        guard let puzzle else { return 0 }
        return paths.filter { Self.isComplete($0, puzzle) }.count
    }

    nonisolated static func isComplete(_ path: [Int], _ p: PairPuzzle) -> Bool {
        guard path.count >= 2, let a = p.clues[path[0]], let b = p.clues[path[path.count - 1]] else { return false }
        return a == b && path.count == a
    }

    func elapsed(at now: Date) -> TimeInterval { timer.elapsed(at: now) }

    func start(_ puzzle: PairPuzzle, saved: PairSnapshot? = nil) {
        self.puzzle = puzzle
        paths = saved?.paths ?? []
        history = []
        counted = saved?.counted ?? false
        undosUsed = saved?.undosUsed ?? 0
        isNewBest = false
        timer = PuzzleTimer(elapsed: saved?.elapsed ?? 0)
        timer.start()
        status = .playing
    }

    func restoreSaved() -> Bool {
        guard let s = PairSave.load() else { return false }
        let cells = s.puzzle.size * s.puzzle.size
        guard s.puzzle.size >= 3, s.paths.allSatisfy({ $0.allSatisfy { (0..<cells).contains($0) } }) else { return false }
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
        PairSave.save(PairSnapshot(puzzle: puzzle, paths: paths, elapsed: elapsed(at: .now),
                                   counted: counted, undosUsed: undosUsed, savedAt: .now))
    }

    func pause() { timer.pause() }

    func resume() {
        guard status == .playing else { return }
        timer.start()
    }

    func clue(at i: Int) -> Int? { puzzle?.clues[i] }
    func isWall(_ i: Int) -> Bool { puzzle?.walls.contains(i) ?? false }

    func commit(_ next: [[Int]]) {
        guard status == .playing, let puzzle, next != paths else { return }
        history.append(paths)
        if history.count > 500 { history.removeFirst(history.count - 500) }
        paths = next
        if !counted {
            counted = true
            StatsStore.recordStart(.pair)
        }
        if PairEngine.check(puzzle, paths: paths).solved {
            timer.pause()
            status = .won
            isNewBest = StatsStore.recordWinIsBest(.pair, difficulty: puzzle.level.name, seconds: Int(elapsed(at: .now).rounded()))
        }
    }

    func remove(pathAt index: Int) {
        guard paths.indices.contains(index) else { return }
        var next = paths
        next.remove(at: index)
        commit(next)
    }

    func clearAll() { commit([]) }

    func undo() {
        guard canUndo, let last = history.popLast() else { return }
        paths = last
        undosUsed += 1
    }
}
