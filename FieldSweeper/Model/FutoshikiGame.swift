import Foundation
import Observation

struct FutoshikiSnapshot: Codable {
    var puzzle: FutoshikiPuzzle
    var values: [Int]
    var notes: [UInt16]
    var elapsed: TimeInterval
    var counted: Bool
    var savedAt: Date
    /// 이 판에서 쓴 되돌리기 횟수. 예전 저장에는 없다.
    var undosUsed: Int? = nil

    var progress: Double {
        let empty = puzzle.givens.filter { $0 == 0 }.count
        guard empty > 0 else { return 0 }
        return Double(zip(puzzle.givens, values).filter { $0 == 0 && $1 != 0 }.count) / Double(empty)
    }
}

enum FutoshikiSave {
    static let file = "futoshiki.json"
    static func load() -> FutoshikiSnapshot? { JSONSave.load(FutoshikiSnapshot.self, from: file) }
    static func save(_ snapshot: FutoshikiSnapshot?) { JSONSave.save(snapshot, to: file) }
    static func clear() { JSONSave.clear(file) }
}

@MainActor
@Observable
final class FutoshikiGame {
    enum Status { case empty, playing, won }

    private struct Change {
        var index: Int
        var value: Int
        var notes: UInt16
    }

    private(set) var puzzle: FutoshikiPuzzle?
    private(set) var values: [Int] = []
    private(set) var notes: [UInt16] = []
    private(set) var status: Status = .empty
    private(set) var isNewBest = false
    var selected: Int?
    var noteMode = false

    private var history: [[Change]] = []
    private(set) var counted = false
    /// 이 판에서 쓴 되돌리기 횟수. 난이도별 한도는 UndoLimit.
    private(set) var undosUsed = 0
    private var accumulated: TimeInterval = 0
    private var runningSince: Date?

    var level: FutoshikiLevel { puzzle?.level ?? .easy }
    var size: Int { puzzle?.size ?? 4 }
    var canUndo: Bool { !history.isEmpty && status == .playing && undosLeft != 0 }
    /// 남은 되돌리기 횟수. nil이면 무제한.
    var undosLeft: Int? { UndoLimit.count(forLevel: level.name).map { max(0, $0 - undosUsed) } }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    // MARK: 시작·저장

    func start(_ puzzle: FutoshikiPuzzle) {
        self.puzzle = puzzle
        values = puzzle.givens
        notes = Array(repeating: 0, count: puzzle.size * puzzle.size)
        history = []
        selected = nil
        noteMode = false
        counted = false
        undosUsed = 0
        isNewBest = false
        accumulated = 0
        runningSince = .now
        status = .playing
    }

    func restore(_ s: FutoshikiSnapshot) -> Bool {
        let cells = s.puzzle.size * s.puzzle.size
        guard cells > 0, s.values.count == cells, s.notes.count == cells, s.puzzle.givens.count == cells,
              s.puzzle.solution.count == cells, s.puzzle.horizontal.count == cells, s.puzzle.vertical.count == cells,
              zip(s.puzzle.givens, s.values).allSatisfy({ $0 == 0 || $0 == $1 }) else { return false }
        puzzle = s.puzzle
        values = s.values
        notes = s.notes
        history = []
        selected = nil
        noteMode = false
        counted = s.counted
        undosUsed = s.undosUsed ?? 0
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

    func snapshot() -> FutoshikiSnapshot? {
        guard status == .playing, let puzzle else { return nil }
        return FutoshikiSnapshot(puzzle: puzzle, values: values, notes: notes,
                                 elapsed: elapsed(at: .now), counted: counted, savedAt: .now, undosUsed: undosUsed)
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

    // MARK: 입력

    func isGiven(_ i: Int) -> Bool { puzzle?.givens[i] ?? 0 != 0 }

    private func peers(_ i: Int) -> [Int] {
        let n = size, r = i / n, c = i % n
        return (0..<n).flatMap { [r * n + $0, $0 * n + c] }.filter { $0 != i }
    }

    func enter(_ d: Int) {
        guard status == .playing, let i = selected, !isGiven(i), (1...size).contains(d) else { return }
        if noteMode {
            guard values[i] == 0 else { return }
            history.append([Change(index: i, value: values[i], notes: notes[i])])
            notes[i] ^= 1 << UInt16(d)
        } else {
            let newValue = values[i] == d ? 0 : d
            var changes = [Change(index: i, value: values[i], notes: notes[i])]
            if newValue != 0 {
                for p in peers(i) where notes[p] & (1 << UInt16(d)) != 0 {
                    changes.append(Change(index: p, value: values[p], notes: notes[p]))
                    notes[p] &= ~(1 << UInt16(d))
                }
            }
            history.append(changes)
            values[i] = newValue
            notes[i] = 0
        }
        if history.count > 500 { history.removeFirst(history.count - 500) }
        if !counted {
            counted = true
            StatsStore.recordStart(.futoshiki)
        }
        checkWin()
    }

    func erase() {
        guard status == .playing, let i = selected, !isGiven(i), values[i] != 0 || notes[i] != 0 else { return }
        history.append([Change(index: i, value: values[i], notes: notes[i])])
        values[i] = 0
        notes[i] = 0
    }

    /// 내가 넣은 숫자나 메모가 있는지.
    var hasEntries: Bool { values.indices.contains { !isGiven($0) && (values[$0] != 0 || notes[$0] != 0) } }

    /// 내가 넣은 숫자와 메모를 모두 지운다. 주어진 숫자는 그대로이고, 되돌리기 한 번으로 살릴 수 있다.
    func clearAll() {
        guard status == .playing else { return }
        let changes = values.indices
            .filter { !isGiven($0) && (values[$0] != 0 || notes[$0] != 0) }
            .map { Change(index: $0, value: values[$0], notes: notes[$0]) }
        guard !changes.isEmpty else { return }
        history.append(changes)
        for c in changes {
            values[c.index] = 0
            notes[c.index] = 0
        }
        selected = nil
    }

    func undo() {
        guard canUndo, let last = history.popLast() else { return }
        undosUsed += 1
        for c in last.reversed() {
            values[c.index] = c.value
            notes[c.index] = c.notes
        }
        selected = last.first?.index
    }

    private func checkWin() {
        guard let puzzle, values == puzzle.solution else { return }
        pause()
        status = .won
        selected = nil
        let seconds = Int(elapsed(at: .now).rounded())
        let previous = StatsStore.load(.futoshiki).bestByDifficulty[puzzle.level.name]
        isNewBest = previous.map { seconds < $0 } ?? true
        StatsStore.recordWin(.futoshiki, difficulty: puzzle.level.name, seconds: seconds)
    }

    // MARK: 화면에 보여줄 정보

    /// 같은 가로·세로줄에 같은 숫자가 있는 칸.
    var conflicts: Set<Int> {
        var out = Set<Int>()
        for i in values.indices where values[i] != 0 {
            if peers(i).contains(where: { values[$0] == values[i] }) { out.insert(i) }
        }
        return out
    }

    /// 부등호를 어긴 칸(양쪽 모두).
    var violations: Set<Int> {
        guard let puzzle else { return [] }
        var out = Set<Int>()
        for (s, b) in puzzle.relations where values[s] != 0 && values[b] != 0 && values[s] >= values[b] {
            out.insert(s)
            out.insert(b)
        }
        return out
    }

    func placedCount(_ d: Int) -> Int { values.filter { $0 == d }.count }

    var progress: Double {
        guard let puzzle else { return 0 }
        let empty = puzzle.givens.filter { $0 == 0 }.count
        guard empty > 0 else { return 0 }
        return Double(zip(puzzle.givens, values).filter { $0 == 0 && $1 != 0 }.count) / Double(empty)
    }
}
