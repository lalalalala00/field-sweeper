import UIKit

struct BoardConfig: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var cols: Int
    var rows: Int
    var mines: Int

    /// 가로/세로가 뒤집혀도 같은 기록으로 취급한다.
    var recordKey: String { "\(min(cols, rows))x\(max(cols, rows))m\(mines)" }

    static func custom(cols: Int, rows: Int, mines: Int) -> BoardConfig {
        BoardConfig(id: "custom", name: "커스텀", cols: cols, rows: rows, mines: mines)
    }
}

/// iPad는 더 많은 칸, iPhone은 손가락으로 누르기 좋은 크기의 보드를 쓴다.
enum DeviceClass {
    case phone, pad

    @MainActor static var current: DeviceClass {
        UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
    }

    var presets: [BoardConfig] {
        switch self {
        case .pad:
            return [
                BoardConfig(id: "easy", name: "초급", cols: 12, rows: 12, mines: 26),
                BoardConfig(id: "normal", name: "중급", cols: 24, rows: 16, mines: 80),
                BoardConfig(id: "hard", name: "고급", cols: 30, rows: 20, mines: 140),
                BoardConfig(id: "expert", name: "전문가", cols: 36, rows: 24, mines: 210),
                BoardConfig(id: "hell", name: "지옥", cols: 40, rows: 26, mines: 270),
            ]
        case .phone:
            return [
                BoardConfig(id: "easy", name: "초급", cols: 9, rows: 9, mines: 13),
                BoardConfig(id: "normal", name: "중급", cols: 11, rows: 16, mines: 35),
                BoardConfig(id: "hard", name: "고급", cols: 13, rows: 24, mines: 72),
                BoardConfig(id: "hell", name: "지옥", cols: 13, rows: 24, mines: 85),
            ]
        }
    }

    var limits: (cols: Int, rows: Int) {
        self == .pad ? (50, 50) : (30, 40)
    }

    /// 새 게임에서 화면에 맞출 때 쓰는 칸 크기(pt) 범위. 핀치로는 이보다 더 줄이거나 키울 수 있다.
    var fitPitch: ClosedRange<CGFloat> {
        self == .pad ? 28...56 : 28...46
    }

    var label: String { self == .pad ? "iPad 보드" : "iPhone 보드" }

    func resolve(_ config: BoardConfig?) -> BoardConfig {
        guard let config else { return presets[1] }
        if config.id == "custom" {
            return .custom(cols: min(config.cols, limits.cols), rows: min(config.rows, limits.rows), mines: config.mines)
        }
        return presets.first { $0.id == config.id } ?? presets[1]
    }
}
