import Foundation

/// 판을 푸는 동안 흐르는 시간. 일시정지하면 쌓아 두고 멈춘다.
struct PuzzleTimer {
    private var accumulated: TimeInterval = 0
    private var runningSince: Date?

    init(elapsed: TimeInterval = 0) { accumulated = elapsed }

    var isRunning: Bool { runningSince != nil }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    mutating func start() {
        if runningSince == nil { runningSince = .now }
    }

    mutating func pause() {
        guard let since = runningSince else { return }
        accumulated += Date.now.timeIntervalSince(since)
        runningSince = nil
    }
}

enum PuzzleStatus { case empty, playing, won }

/// PuzzleHost가 다루는 게임. 판을 만들고 푸는 일은 게임마다, 나머지(창·저장·시간)는 PuzzleHost가 맡는다.
@MainActor
protocol HostedPuzzle: AnyObject {
    var status: PuzzleStatus { get }
    /// 판을 더 만질 수 없는 상태(스위치네모 지옥에서 횟수를 다 쓴 경우). 시간도 멈춘다.
    var isLocked: Bool { get }
    var isNewBest: Bool { get }
    /// 이 판에 손을 댔는지(첫 수를 뒀는지). 새 퍼즐을 만들기 전에 물어볼지 정한다.
    var counted: Bool { get }
    /// 지금 판의 난이도 번호(rawValue).
    var levelID: Int? { get }
    func elapsed(at now: Date) -> TimeInterval
    func pause()
    func resume()
    func restart()
    /// 진행 중이면 저장한다.
    func save()
    /// 저장된 판을 불러온다. 없거나 깨졌으면 false.
    func restoreSaved() -> Bool
}

extension HostedPuzzle {
    var isLocked: Bool { false }
}
