import Foundation
import Observation

struct MirrorSnapshot: Codable {
    var puzzle: MirrorPuzzle
    /// 처음 방향(처음부터 다시용)과 지금 방향.
    var initial: [Int: Int]
    var orient: [Int: Int]
    var history: [Int]
    var moves: Int
    var elapsed: TimeInterval
    var counted: Bool
    var savedAt: Date

    var progress: Double {
        let lit = MirrorEngine.trace(puzzle, orient: orient).lit
        return puzzle.stars.isEmpty ? 0 : Double(lit) / Double(puzzle.stars.count)
    }
}

enum MirrorSave {
    static let file = "mirror.json"
    static func load() -> MirrorSnapshot? { JSONSave.load(MirrorSnapshot.self, from: file) }
    static func save(_ snapshot: MirrorSnapshot?) { JSONSave.save(snapshot, to: file) }
    static func clear() { JSONSave.clear(file) }
}

/// 거울네모: 거울을 돌려 빛이 모든 별을 지나 목적지로 나가게 한다.
/// 되돌리기는 '같은 거울을 다시 돌리기'와 같아서 횟수 제한 없이 쓰되 조작 1회로 센다.
@MainActor
@Observable
final class MirrorGame: HostedPuzzle {
    private(set) var puzzle: MirrorPuzzle?
    private(set) var initial: [Int: Int] = [:]
    private(set) var orient: [Int: Int] = [:]
    private(set) var history: [Int] = []
    private(set) var moves = 0
    /// 처음 방향에서 정답과 다른 회전 거울 수 = 최소 조작 수
    private(set) var minimum = 0
    private(set) var trace: MirrorTrace?
    private(set) var status: PuzzleStatus = .empty
    private(set) var isNewBest = false

    private(set) var counted = false
    private var timer = PuzzleTimer()

    var level: MirrorLevel { puzzle?.level ?? .easy }
    var levelID: Int? { puzzle?.level.rawValue }
    var size: Int { puzzle?.size ?? 5 }

    func elapsed(at now: Date) -> TimeInterval { timer.elapsed(at: now) }

    func start(_ puzzle: MirrorPuzzle, saved: MirrorSnapshot? = nil) {
        self.puzzle = puzzle
        if let saved {
            initial = saved.initial
            orient = saved.orient
        } else {
            var rng = SystemRandomNumberGenerator()
            initial = MirrorEngine.scramble(puzzle, using: &rng)
            orient = initial
        }
        history = saved?.history ?? []
        moves = saved?.moves ?? 0
        minimum = MirrorEngine.minimumMoves(puzzle, initial: initial)
        counted = saved?.counted ?? false
        isNewBest = false
        timer = PuzzleTimer(elapsed: saved?.elapsed ?? 0)
        timer.start()
        status = .playing
        trace = MirrorEngine.trace(puzzle, orient: orient)
    }

    func restoreSaved() -> Bool {
        guard let s = MirrorSave.load() else { return false }
        guard s.puzzle.size >= 3, s.puzzle.cells.count == s.puzzle.size * s.puzzle.size,
              s.puzzle.rotatable.allSatisfy({ s.orient[$0] != nil && s.initial[$0] != nil }) else { return false }
        start(s.puzzle, saved: s)
        return true
    }

    /// 처음 방향으로 되돌린다. 시간은 이어서 잰다.
    func restart() {
        guard let puzzle else { return }
        start(puzzle, saved: MirrorSnapshot(puzzle: puzzle, initial: initial, orient: initial, history: [], moves: 0,
                                            elapsed: elapsed(at: .now), counted: counted, savedAt: .now))
    }

    func save() {
        guard status == .playing, let puzzle else { return }
        MirrorSave.save(MirrorSnapshot(puzzle: puzzle, initial: initial, orient: orient, history: history, moves: moves,
                                       elapsed: elapsed(at: .now), counted: counted, savedAt: .now))
    }

    func pause() { timer.pause() }

    func resume() {
        guard status == .playing else { return }
        timer.start()
    }

    func isRotatable(_ i: Int) -> Bool { puzzle?.cells[i].isRotatable ?? false }

    func isMirror(_ i: Int) -> Bool {
        if case .mirror = puzzle?.cells[i] { return true }
        return false
    }

    /// 돌릴 수 있는 거울이면 돌린다. 돌렸으면 true.
    @discardableResult
    func turn(_ i: Int) -> Bool {
        guard status == .playing, isRotatable(i), let o = orient[i] else { return false }
        orient[i] = 1 - o
        history.append(i)
        moves += 1
        if !counted {
            counted = true
            StatsStore.recordStart(.mirror)
        }
        after()
        return true
    }

    func undo() {
        guard status == .playing, let i = history.popLast(), let o = orient[i] else { return }
        orient[i] = 1 - o
        moves += 1
        after()
    }

    private func after() {
        guard let puzzle else { return }
        let t = MirrorEngine.trace(puzzle, orient: orient)
        trace = t
        if t.solved {
            timer.pause()
            status = .won
            isNewBest = StatsStore.recordWinIsBest(.mirror, difficulty: puzzle.level.name, seconds: Int(elapsed(at: .now).rounded()))
        }
    }
}
