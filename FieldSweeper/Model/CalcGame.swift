import Foundation
import Observation

struct CalcSnapshot: Codable {
    var puzzle: CalcPuzzle
    var values: [Int]
    var notes: [UInt16]
    var elapsed: TimeInterval
    var counted: Bool
    var undosUsed: Int
    var savedAt: Date

    var progress: Double {
        let empty = puzzle.givens.filter { $0 == 0 }.count
        guard empty > 0 else { return 0 }
        return Double(zip(puzzle.givens, values).filter { $0 == 0 && $1 != 0 }.count) / Double(empty)
    }
}

enum CalcSave {
    static let file = "calc.json"
    static func load() -> CalcSnapshot? { JSONSave.load(CalcSnapshot.self, from: file) }
    static func save(_ snapshot: CalcSnapshot?) { JSONSave.save(snapshot, to: file) }
    static func clear() { JSONSave.clear(file) }
}

/// 셈네모: 가로줄·세로줄에 1…n을 겹치지 않게 넣고, 칸 묶음마다 적힌 계산을 맞춘다.
@MainActor
@Observable
final class CalcGame: HostedPuzzle {
    private struct Change {
        var index: Int
        var value: Int
        var notes: UInt16
    }

    private(set) var puzzle: CalcPuzzle?
    private(set) var values: [Int] = []
    private(set) var notes: [UInt16] = []
    private(set) var status: PuzzleStatus = .empty
    private(set) var isNewBest = false
    var selected: Int?
    var noteMode = false

    private var history: [[Change]] = []
    private(set) var counted = false
    private(set) var undosUsed = 0
    private var timer = PuzzleTimer()

    var level: CalcLevel { puzzle?.level ?? .easy }
    var levelID: Int? { puzzle?.level.rawValue }
    var size: Int { puzzle?.size ?? 4 }
    var undosLeft: Int? { UndoLimit.count(forLevel: level.name).map { max(0, $0 - undosUsed) } }
    var canUndo: Bool { !history.isEmpty && status == .playing && undosLeft != 0 }

    func elapsed(at now: Date) -> TimeInterval { timer.elapsed(at: now) }

    func start(_ puzzle: CalcPuzzle, saved: CalcSnapshot? = nil) {
        self.puzzle = puzzle
        values = saved?.values ?? puzzle.givens
        notes = saved?.notes ?? Array(repeating: 0, count: puzzle.size * puzzle.size)
        history = []
        selected = nil
        noteMode = false
        counted = saved?.counted ?? false
        undosUsed = saved?.undosUsed ?? 0
        isNewBest = false
        timer = PuzzleTimer(elapsed: saved?.elapsed ?? 0)
        timer.start()
        status = .playing
    }

    func restoreSaved() -> Bool {
        guard let s = CalcSave.load() else { return false }
        let cells = s.puzzle.size * s.puzzle.size
        guard cells > 0, s.values.count == cells, s.notes.count == cells, s.puzzle.givens.count == cells,
              s.puzzle.solution.count == cells, zip(s.puzzle.givens, s.values).allSatisfy({ $0 == 0 || $0 == $1 }) else { return false }
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
        CalcSave.save(CalcSnapshot(puzzle: puzzle, values: values, notes: notes, elapsed: elapsed(at: .now),
                                   counted: counted, undosUsed: undosUsed, savedAt: .now))
    }

    func pause() { timer.pause() }

    func resume() {
        guard status == .playing else { return }
        timer.start()
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
            StatsStore.recordStart(.calc)
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
        for c in last.reversed() {
            values[c.index] = c.value
            notes[c.index] = c.notes
        }
        undosUsed += 1
        selected = last.first?.index
    }

    private func checkWin() {
        guard let puzzle, CalcEngine.check(puzzle, values: values) else { return }
        timer.pause()
        status = .won
        selected = nil
        isNewBest = StatsStore.recordWinIsBest(.calc, difficulty: puzzle.level.name, seconds: Int(elapsed(at: .now).rounded()))
    }

    // MARK: 화면에 보여줄 정보

    var conflicts: Set<Int> {
        var out = Set<Int>()
        for i in values.indices where values[i] != 0 {
            if peers(i).contains(where: { values[$0] == values[i] }) { out.insert(i) }
        }
        return out
    }

    var wrongCages: Set<Int> {
        guard let puzzle else { return [] }
        return Set(CalcEngine.wrongCages(puzzle, values: values))
    }

    func placedCount(_ d: Int) -> Int { values.filter { $0 == d }.count }
}
