import Foundation
import Observation

struct SwitchSnapshot: Codable {
    var puzzle: SwitchPuzzle
    /// 처음 판에서 누른 칸들. 상태는 이것을 다시 적용해 만든다.
    var history: [Int]
    var moves: Int
    var elapsed: TimeInterval
    var counted: Bool
    var savedAt: Date

    var progress: Double {
        var state = puzzle.start
        for i in history { SwitchEngine.press(&state, at: i, size: puzzle.size) }
        return Double(state.filter { $0 }.count) / Double(max(state.count, 1))
    }
}

enum SwitchSave {
    static let file = "switch.json"
    static func load() -> SwitchSnapshot? { JSONSave.load(SwitchSnapshot.self, from: file) }
    static func save(_ snapshot: SwitchSnapshot?) { JSONSave.save(snapshot, to: file) }
    static func clear() { JSONSave.clear(file) }

    /// 최근에 낸 판(회전·뒤집기 포함)은 다시 내지 않는다.
    static var recent: [String] {
        get { UserDefaults.standard.stringArray(forKey: "switch.recent") ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(50)), forKey: "switch.recent") }
    }
}

/// 스위치네모: 누른 칸의 가로줄과 세로줄이 모두 바뀐다. 불을 모두 켜면 완성.
/// 되돌리기는 '같은 칸 다시 누르기'와 같아서 횟수 제한 없이 쓰되 조작 1회로 센다.
@MainActor
@Observable
final class SwitchGame: HostedPuzzle {
    private(set) var puzzle: SwitchPuzzle?
    private(set) var state: [Bool] = []
    private(set) var history: [Int] = []
    /// 누른 횟수. 되돌려도 줄지 않는다.
    private(set) var moves = 0
    private(set) var status: PuzzleStatus = .empty
    /// 지옥에서 최소 횟수를 다 쓰고도 못 푼 상태. 판이 멈춘다.
    private(set) var failed = false
    private(set) var isNewBest = false
    /// 방금 바뀐 칸들(살짝 튀는 효과용).
    private(set) var flashed: Set<Int> = []
    private(set) var flashID = 0

    private(set) var counted = false
    private var timer = PuzzleTimer()

    var level: SwitchLevel { puzzle?.level ?? .easy }
    var levelID: Int? { puzzle?.level.rawValue }
    var size: Int { puzzle?.size ?? 4 }
    var isLocked: Bool { failed }
    var minimum: Int { puzzle?.solution.count ?? 0 }
    var lit: Int { state.filter { $0 }.count }

    func elapsed(at now: Date) -> TimeInterval { timer.elapsed(at: now) }

    func start(_ puzzle: SwitchPuzzle, saved: SwitchSnapshot? = nil) {
        self.puzzle = puzzle
        history = saved?.history ?? []
        moves = saved?.moves ?? 0
        state = puzzle.start
        for i in history { SwitchEngine.press(&state, at: i, size: puzzle.size) }
        counted = saved?.counted ?? false
        isNewBest = false
        flashed = []
        timer = PuzzleTimer(elapsed: saved?.elapsed ?? 0)
        timer.start()
        status = .playing
        failed = false
        if outOfMoves { fail() }
    }

    func restoreSaved() -> Bool {
        guard let s = SwitchSave.load() else { return false }
        let cells = s.puzzle.size * s.puzzle.size
        guard s.puzzle.size >= 2, s.puzzle.start.count == cells, s.history.allSatisfy({ (0..<cells).contains($0) }) else { return false }
        start(s.puzzle, saved: s)
        return true
    }

    /// 처음 판으로 돌아간다. 시간은 이어서 잰다.
    func restart() {
        guard let puzzle else { return }
        let elapsed = elapsed(at: .now), wasCounted = counted
        start(puzzle, saved: SwitchSnapshot(puzzle: puzzle, history: [], moves: 0, elapsed: elapsed, counted: wasCounted, savedAt: .now))
    }

    func save() {
        guard status == .playing, let puzzle else { return }
        SwitchSave.save(SwitchSnapshot(puzzle: puzzle, history: history, moves: moves, elapsed: elapsed(at: .now),
                                       counted: counted, savedAt: .now))
    }

    func pause() { timer.pause() }

    func resume() {
        guard status == .playing, !failed else { return }
        timer.start()
    }

    private var outOfMoves: Bool {
        level.limitsMoves && moves >= minimum && !state.allSatisfy { $0 }
    }

    private func fail() {
        failed = true
        timer.pause()
    }

    func press(_ i: Int) {
        guard status == .playing, !failed, let puzzle else { return }
        SwitchEngine.press(&state, at: i, size: puzzle.size)
        history.append(i)
        moves += 1
        if !counted {
            counted = true
            StatsStore.recordStart(.switchSquares)
        }
        flash(i)
        if !checkWin() && outOfMoves { fail() }
    }

    func undo() {
        guard status == .playing, !failed, let puzzle, let i = history.popLast() else { return }
        SwitchEngine.press(&state, at: i, size: puzzle.size)
        moves += 1
        flash(i)
        if outOfMoves { fail() }
    }

    private func flash(_ i: Int) {
        let n = size
        flashed = Set((0..<(n * n)).filter { $0 / n == i / n || $0 % n == i % n })
        flashID += 1
    }

    @discardableResult
    private func checkWin() -> Bool {
        guard let puzzle, state.allSatisfy({ $0 }) else { return false }
        timer.pause()
        status = .won
        isNewBest = StatsStore.recordWinIsBest(.switchSquares, difficulty: puzzle.level.name, seconds: Int(elapsed(at: .now).rounded()))
        return true
    }
}
