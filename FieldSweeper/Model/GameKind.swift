import UIKit

/// 네모 안에 네모에 들어 있는 게임들. 순서가 메인 화면의 번호(01, 02…)가 된다.
enum GameKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case minesweeper, sudoku, shikaku, futoshiki

    var id: String { rawValue }

    var number: String { String(format: "%02d", (Self.allCases.firstIndex(of: self) ?? 0) + 1) }

    /// 한국어 이름. 화면에는 tr()로 바꿔서 쓴다.
    var title: String {
        switch self {
        case .minesweeper: "필드 스위퍼"
        case .sudoku: "스도쿠"
        case .shikaku: "시카쿠"
        case .futoshiki: "후토시키"
        }
    }

    /// 아직 만들지 않은 게임은 메인 화면에 '준비 중'으로 보인다.
    var isAvailable: Bool { self == .minesweeper }

    /// 게임마다 하나씩 정한 카드 색 (시안 '메인 · 03 A + 04 A').
    var fill: UIColor {
        switch self {
        case .minesweeper: .dynamic(0xa0b894, 0x3e4d38)
        case .sudoku: .dynamic(0xe6dfb0, 0x3b3824)
        case .shikaku: .dynamic(0xe8c3a8, 0x45352a)
        case .futoshiki: .dynamic(0xa9bbd3, 0x2f3a4a)
        }
    }

    /// 카드 글자. 진한 카드(01·04)는 흰색, 밝은 카드(02·03)는 Deep Green. 번호만 Paper.inkSoft.
    var text: UIColor {
        switch self {
        case .minesweeper, .futoshiki: .dynamic(0xffffff, 0xf2f6ee)
        case .sudoku, .shikaku: Paper.ink
        }
    }
}
