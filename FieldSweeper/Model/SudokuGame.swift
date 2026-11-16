import Foundation
import Observation

/// 진행 중인 스도쿠. 앱을 나가거나 메인 화면으로 돌아갈 때 저장한다.
struct SudokuSnapshot: Codable {
    var puzzle: SudokuPuzzle
    var values: [Int]
    var notes: [UInt16]
    var elapsed: TimeInterval
    var counted: Bool
    var savedAt: Date

    /// 빈칸 중 채운 비율.
    var progress: Double {
        let empty = puzzle.givens.filter { $0 == 0 }.count
        guard empty > 0 else { return 0 }
        let filled = zip(puzzle.givens, values).filter { $0 == 0 && $1 != 0 }.count
        return Double(filled) / Double(empty)
    }
}

/// 게임별 저장 파일. 기기 안의 Application Support에 JSON으로 둔다.
enum JSONSave {
    private static func url(_ name: String) -> URL { URL.applicationSupportDirectory.appending(path: name) }

    static func save<T: Encodable>(_ value: T?, to name: String) {
        guard let value else { return clear(name) }
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(value).write(to: url(name), options: .atomic)
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func clear(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }
}

enum SudokuSave {
    static let file = "sudoku.json"
    static func load() -> SudokuSnapshot? { JSONSave.load(SudokuSnapshot.self, from: file) }
    static func save(_ snapshot: SudokuSnapshot?) { JSONSave.save(snapshot, to: file) }
    static func clear() { JSONSave.clear(file) }
}

@MainActor
@Observable
final class SudokuGame {
    enum Status { case empty, playing, won }

    private struct Change {
        var index: Int
        var value: Int
        var notes: UInt16
    }

    private(set) var puzzle: SudokuPuzzle?
    private(set) var values: [Int] = Array(repeating: 0, count: 81)
    private(set) var notes: [UInt16] = Array(repeating: 0, count: 81)
    private(set) var status: Status = .empty
    private(set) var isNewBest = false
    var selected: Int?
    var noteMode = false

    /// 한 번의 입력이 바꾼 칸들. 숫자를 넣으면 이웃 칸의 메모도 함께 지워지므로 여러 칸일 수 있다.
    private var history: [[Change]] = []
    /// 첫 입력을 했는지. 이때 한 판으로 센다.
    private(set) var counted = false
    private var accumulated: TimeInterval = 0
    private var runningSince: Date?

    var level: SudokuLevel { puzzle?.level ?? .easy }
    var canUndo: Bool { !history.isEmpty && status == .playing }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    // MARK: 시작·저장

    func start(_ puzzle: SudokuPuzzle) {
        self.puzzle = puzzle
        values = puzzle.givens
        notes = Array(repeating: 0, count: 81)
        history = []
        selected = nil
        noteMode = false
        counted = false
        isNewBest = false
        accumulated = 0
        runningSince = .now
        status = .playing
    }

    func restore(_ s: SudokuSnapshot) -> Bool {
        guard s.values.count == 81, s.notes.count == 81, s.puzzle.givens.count == 81, s.puzzle.solution.count == 81,
              zip(s.puzzle.givens, s.values).allSatisfy({ $0 == 0 || $0 == $1 }) else { return false }
        puzzle = s.puzzle
        values = s.values
        notes = s.notes
        history = []
        selected = nil
        noteMode = false
        counted = s.counted
        isNewBest = false
        accumulated = s.elapsed
        runningSince = .now
        status = .playing
        return true
    }

    /// 같은 문제를 처음부터 다시 푼다.
    func restart() {
        guard let puzzle else { return }
        start(puzzle)
    }

    func snapshot() -> SudokuSnapshot? {
        guard status == .playing, let puzzle else { return nil }
        return SudokuSnapshot(puzzle: puzzle, values: values, notes: notes,
                              elapsed: elapsed(at: .now), counted: counted, savedAt: .now)
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

    /// 선택한 칸에 숫자를 넣거나(메모 모드면 후보를 켜고 끈다).
    func enter(_ d: Int) {
        guard status == .playing, let i = selected, !isGiven(i) else { return }
        if noteMode {
            guard values[i] == 0 else { return }
            record([Change(index: i, value: values[i], notes: notes[i])])
            notes[i] ^= 1 << UInt16(d)
        } else {
            // 같은 숫자를 다시 누르면 지운다.
            let newValue = values[i] == d ? 0 : d
            var changes = [Change(index: i, value: values[i], notes: notes[i])]
            if newValue != 0 {
                for p in SudokuGrid.peers[i] where notes[p] & (1 << UInt16(d)) != 0 {
                    changes.append(Change(index: p, value: values[p], notes: notes[p]))
                    notes[p] &= ~(1 << UInt16(d))
                }
            }
            record(changes)
            values[i] = newValue
            notes[i] = 0
        }
        markCounted()
        checkWin()
    }

    func erase() {
        guard status == .playing, let i = selected, !isGiven(i), values[i] != 0 || notes[i] != 0 else { return }
        record([Change(index: i, value: values[i], notes: notes[i])])
        values[i] = 0
        notes[i] = 0
    }

    func undo() {
        guard status == .playing, let last = history.popLast() else { return }
        for c in last.reversed() {
            values[c.index] = c.value
            notes[c.index] = c.notes
        }
        selected = last.first?.index
    }

    private func record(_ changes: [Change]) {
        history.append(changes)
        if history.count > 500 { history.removeFirst(history.count - 500) }
    }

    private func markCounted() {
        guard !counted else { return }
        counted = true
        StatsStore.recordStart(.sudoku)
    }

    private func checkWin() {
        guard let puzzle, values == puzzle.solution else { return }
        pause()
        status = .won
        selected = nil
        let seconds = Int(elapsed(at: .now).rounded())
        let previous = StatsStore.load(.sudoku).bestByDifficulty[puzzle.level.name]
        isNewBest = previous.map { seconds < $0 } ?? true
        StatsStore.recordWin(.sudoku, difficulty: puzzle.level.name, seconds: seconds)
    }

    // MARK: 화면에 보여줄 정보

    /// 같은 줄·열·구역에 같은 숫자가 있는 칸.
    var conflicts: Set<Int> {
        var out = Set<Int>()
        for i in 0..<81 where values[i] != 0 {
            if SudokuGrid.peers[i].contains(where: { values[$0] == values[i] }) { out.insert(i) }
        }
        return out
    }

    /// 정답과 다른 숫자를 넣은 칸.
    var mistakes: Set<Int> {
        guard let puzzle else { return [] }
        return Set((0..<81).filter { values[$0] != 0 && values[$0] != puzzle.solution[$0] })
    }

    /// 판에 이미 9번 놓인 숫자는 키패드에서 흐리게 보인다.
    func placedCount(_ d: Int) -> Int { values.filter { $0 == d }.count }

    var progress: Double {
        guard let puzzle else { return 0 }
        let empty = puzzle.givens.filter { $0 == 0 }.count
        guard empty > 0 else { return 0 }
        return Double(zip(puzzle.givens, values).filter { $0 == 0 && $1 != 0 }.count) / Double(empty)
    }
}
