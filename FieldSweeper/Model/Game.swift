import Foundation
import Observation

enum CellState: UInt8 { case hidden, open, flagged }
enum GameStatus: Equatable { case ready, playing, won, lost }
enum Feedback { case none, reveal, flag, unflag, denied, boom, win }

@MainActor
@Observable
final class Game {
    private(set) var config: BoardConfig
    private(set) var cols = 0
    private(set) var rows = 0
    private(set) var isMine: [Bool] = []
    private(set) var adjacent: [UInt8] = []
    private(set) var state: [CellState] = []
    private(set) var status: GameStatus = .ready
    private(set) var flags = 0
    private(set) var opened = 0
    private(set) var hitIndex: Int?
    private(set) var isNewBest = false
    /// 새 게임마다 증가. 보드 뷰가 화면 맞춤을 다시 할 때 쓴다.
    private(set) var generation = 0
    /// 칸 상태가 바뀔 때마다 증가. 보드 뷰가 다시 그릴 때 쓴다.
    private(set) var version = 0

    private var accumulated: TimeInterval = 0
    private var runningSince: Date?

    init(config: BoardConfig) {
        self.config = config
        reset(config: config, portrait: true)
    }

    var mines: Int { config.mines }
    var minesLeft: Int { mines - flags }
    var safeLeft: Int { cols * rows - mines - opened }
    var isOver: Bool { status == .won || status == .lost }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    /// 화면 방향에 맞춰 보드의 긴 변을 맞춘다 (세로 화면이면 세로로 긴 보드).
    func reset(config: BoardConfig, portrait: Bool) {
        self.config = config
        var c = config.cols, r = config.rows
        if c != r && portrait != (r > c) { swap(&c, &r) }
        cols = c
        rows = r
        let n = c * r
        isMine = Array(repeating: false, count: n)
        adjacent = Array(repeating: 0, count: n)
        state = Array(repeating: .hidden, count: n)
        status = .ready
        flags = 0
        opened = 0
        hitIndex = nil
        isNewBest = false
        accumulated = 0
        runningSince = nil
        generation += 1
        version += 1
    }

    /// 진행 중일 때만 저장할 내용이 있다.
    func snapshot() -> GameSnapshot? {
        guard status == .playing else { return nil }
        return GameSnapshot(config: config, cols: cols, rows: rows,
                            mineIndices: isMine.indices.filter { isMine[$0] },
                            state: state.map(\.rawValue),
                            elapsed: elapsed(at: .now), savedAt: .now)
    }

    func restore(_ s: GameSnapshot) -> Bool {
        let n = s.cols * s.rows
        guard n > 0, s.state.count == n, s.mineIndices.allSatisfy({ (0..<n).contains($0) }) else { return false }
        config = s.config
        cols = s.cols
        rows = s.rows
        isMine = Array(repeating: false, count: n)
        for i in s.mineIndices { isMine[i] = true }
        state = s.state.map { CellState(rawValue: $0) ?? .hidden }
        computeAdjacent()
        flags = state.filter { $0 == .flagged }.count
        opened = state.filter { $0 == .open }.count
        status = .playing
        hitIndex = nil
        isNewBest = false
        accumulated = s.elapsed
        runningSince = .now
        generation += 1
        version += 1
        return true
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

    func neighbors(of i: Int) -> [Int] {
        let x = i % cols, y = i / cols
        var out: [Int] = []
        out.reserveCapacity(8)
        for dy in -1...1 {
            for dx in -1...1 where dx != 0 || dy != 0 {
                let nx = x + dx, ny = y + dy
                if nx >= 0, ny >= 0, nx < cols, ny < rows { out.append(ny * cols + nx) }
            }
        }
        return out
    }

    /// alternate: 길게 누르기. flagMode가 켜져 있으면 탭과 길게 누르기의 역할이 바뀐다.
    func act(on i: Int, alternate: Bool, flagMode: Bool) -> Feedback {
        guard !isOver, state.indices.contains(i) else { return .none }
        defer { version += 1 }
        if state[i] == .open { return chord(i) }
        let flagging = alternate != flagMode
        if flagging && status != .ready { return toggleFlag(i) }
        if state[i] == .hidden { return reveal(i) }
        return .none
    }

    private func toggleFlag(_ i: Int) -> Feedback {
        if state[i] == .flagged {
            state[i] = .hidden
            flags -= 1
            return .unflag
        }
        state[i] = .flagged
        flags += 1
        return .flag
    }

    private func reveal(_ i: Int) -> Feedback {
        if status == .ready {
            placeMines(avoiding: i)
            status = .playing
            runningSince = .now
        }
        guard state[i] == .hidden else { return .none }
        if isMine[i] {
            lose(at: i)
            return .boom
        }
        var stack = [i]
        while let k = stack.popLast() {
            guard state[k] == .hidden else { continue }
            state[k] = .open
            opened += 1
            if adjacent[k] == 0 {
                for m in neighbors(of: k) where state[m] == .hidden { stack.append(m) }
            }
        }
        return checkWin() ? .win : .reveal
    }

    /// 숫자 주변의 깃발 수가 맞으면 나머지 칸을 한 번에 연다.
    private func chord(_ i: Int) -> Feedback {
        let ns = neighbors(of: i)
        let flagged = ns.filter { state[$0] == .flagged }.count
        let hasHidden = ns.contains { state[$0] == .hidden }
        guard adjacent[i] > 0, flagged == Int(adjacent[i]) else { return hasHidden ? .denied : .none }
        var result = Feedback.none
        for k in ns where state[k] == .hidden && status == .playing {
            let r = reveal(k)
            if r != .none { result = r }
        }
        return result
    }

    /// 첫 칸과 그 주변 3×3에는 지뢰를 두지 않는다 (칸이 모자라면 첫 칸만 비운다).
    private func placeMines(avoiding safe: Int) {
        let n = cols * rows
        var avoid: Set<Int> = [safe]
        if n - 9 >= mines { avoid.formUnion(neighbors(of: safe)) }
        var pool = (0..<n).filter { !avoid.contains($0) }
        let count = min(mines, pool.count)
        for k in 0..<count {
            let j = Int.random(in: k..<pool.count)
            pool.swapAt(k, j)
            isMine[pool[k]] = true
        }
        computeAdjacent()
    }

    private func computeAdjacent() {
        adjacent = isMine.indices.map { i in
            UInt8(neighbors(of: i).reduce(0) { $0 + (isMine[$1] ? 1 : 0) })
        }
    }

    private func lose(at i: Int) {
        status = .lost
        hitIndex = i
        pause()
    }

    private func checkWin() -> Bool {
        guard status == .playing, opened == cols * rows - mines else { return false }
        status = .won
        pause()
        for k in state.indices where isMine[k] { state[k] = .flagged }
        flags = mines
        let seconds = max(1, Int(accumulated.rounded()))
        isNewBest = RecordStore.submit(seconds, for: config.recordKey)
        return true
    }
}
