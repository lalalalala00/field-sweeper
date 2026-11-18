import Foundation

/// 만드는 데 몇 초 걸리는 난이도의 다음 판을 미리 하나 만들어 두는 보관함.
/// 게임·난이도마다 판 하나만 기기 안(Application Support)에 JSON으로 둔다(판 하나에 수 KB).
/// 새 퍼즐을 시작할 때 있으면 바로 꺼내 쓰고 지운 뒤, 판을 시작하고 몇 초 지나 낮은 우선순위로 다음 판을 다시 만든다.
/// 미리 만든 판은 시작한 판이 아니라서 플레이 수나 기록에 들어가지 않는다. 웹(docs/assets/common.js의 Nemo.stock)과 같은 방식이다.
enum PuzzleStock {
    /// 엔진의 난이도 기준을 바꾸면 올린다. 버전이 다른 판은 버리고 새로 만든다(업데이트 뒤 옛 기준 판이 나오지 않게).
    static let version = 1

    /// 미리 만들어 둘 난이도: 만드는 데 1초 넘게 걸리는 것만.
    static func wanted(_ kind: GameKind, levelID: Int) -> Bool {
        switch (kind, levelID) {
        case (.star, StarLevel.expert.rawValue), (.calc, CalcLevel.hell.rawValue),
             (.pair, PairLevel.expert.rawValue), (.mirror, MirrorLevel.expert.rawValue): true
        default: false
        }
    }

    private struct Stocked<P: Codable>: Codable {
        var version: Int
        var puzzle: P
    }

    private static func file(_ kind: GameKind, _ levelID: Int) -> String { "stock-\(kind.rawValue)-\(levelID).json" }

    /// 미리 만든 판이 있으면 꺼내고(보관함에서는 지운다), 없거나 버전이 다르면 nil.
    static func take<P: Codable>(_ kind: GameKind, levelID: Int, as type: P.Type) -> P? {
        guard wanted(kind, levelID: levelID) else { return nil }
        let name = file(kind, levelID)
        let stocked = JSONSave.load(Stocked<P>.self, from: name)
        JSONSave.clear(name)
        guard let stocked, stocked.version == version else { return nil }
        return stocked.puzzle
    }

    /// 다음 판을 미리 만든다. 이미 있거나 만드는 중이면, 저전력 모드면 하지 않는다.
    /// 판을 막 시작한 화면과 겹치지 않게 몇 초 기다린 뒤, 가장 낮은 우선순위로 화면과 다른 줄에서 만든다.
    static func refill<P: Codable>(_ kind: GameKind, levelID: Int, make: @escaping @Sendable () -> P?) {
        guard wanted(kind, levelID: levelID) else { return }
        let name = file(kind, levelID)
        guard running.begin(name) else { return }
        Task.detached(priority: .background) {
            defer { running.end(name) }
            try? await Task.sleep(for: .seconds(3))
            if ProcessInfo.processInfo.isLowPowerModeEnabled { return }
            if let existing = JSONSave.load(Stocked<P>.self, from: name), existing.version == version { return }
            guard let puzzle = make() else { return }
            JSONSave.save(Stocked(version: version, puzzle: puzzle), to: name)
        }
    }

    /// 지금 만드는 중인 보관함(같은 판을 두 번 만들지 않게)
    private static let running = Running()
    private final class Running: @unchecked Sendable {
        private var names = Set<String>()
        private let lock = NSLock()
        func begin(_ name: String) -> Bool { lock.withLock { names.insert(name).inserted } }
        func end(_ name: String) { lock.withLock { _ = names.remove(name) } }
    }
}
