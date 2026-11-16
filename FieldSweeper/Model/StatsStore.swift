import Foundation

/// 게임 하나의 누적 기록. 난이도는 한국어 이름(초급, 중급…)으로 구분한다.
struct GameStats: Codable {
    var plays = 0
    var completions = 0
    var totalSeconds = 0
    var completionsByDifficulty: [String: Int] = [:]
    var bestByDifficulty: [String: Int] = [:]

    var completionRate: Double? { plays > 0 ? Double(completions) / Double(plays) : nil }
    var averageSeconds: Int? { completions > 0 ? totalSeconds / completions : nil }

    /// 기록이 있는 난이도만, 완료 횟수가 많은 순서로.
    var difficulties: [String] {
        completionsByDifficulty.keys.sorted { (completionsByDifficulty[$0] ?? 0, $1) > (completionsByDifficulty[$1] ?? 0, $0) }
    }
}

/// 게임별 통계. 기기 안(UserDefaults)에만 저장한다.
enum StatsStore {
    private static func key(_ kind: GameKind) -> String { "stats.\(kind.rawValue)" }

    static func load(_ kind: GameKind) -> GameStats {
        guard let data = UserDefaults.standard.data(forKey: key(kind)),
              let stats = try? JSONDecoder().decode(GameStats.self, from: data) else { return GameStats() }
        return stats
    }

    /// 첫 수를 둔 순간 한 판으로 센다.
    static func recordStart(_ kind: GameKind) {
        update(kind) { $0.plays += 1 }
    }

    static func recordWin(_ kind: GameKind, difficulty: String, seconds: Int) {
        update(kind) { stats in
            stats.completions += 1
            stats.totalSeconds += seconds
            stats.completionsByDifficulty[difficulty, default: 0] += 1
            if let best = stats.bestByDifficulty[difficulty], best <= seconds { return }
            stats.bestByDifficulty[difficulty] = seconds
        }
    }

    static var totalPlays: Int { GameKind.allCases.reduce(0) { $0 + load($1).plays } }

    private static func update(_ kind: GameKind, _ change: (inout GameStats) -> Void) {
        var stats = load(kind)
        change(&stats)
        UserDefaults.standard.set(try? JSONEncoder().encode(stats), forKey: key(kind))
    }
}
