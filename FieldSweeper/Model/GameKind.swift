import UIKit

/// 네모 안에 네모에 들어 있는 게임들. 순서가 메인 화면의 번호(01, 02…)가 된다.
enum GameKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case minesweeper, sudoku, shikaku, futoshiki
    case mirror, pair
    /// 저장·기록 키는 웹과 같은 "switch"
    case switchSquares = "switch"
    case calc, star

    var id: String { rawValue }

    var number: String { String(format: "%02d", (Self.allCases.firstIndex(of: self) ?? 0) + 1) }

    /// 게임 자체의 난이도(1 쉬움, 2 보통, 3 어려움). 메인 화면 카드에 작은 네모 세 개로 보인다. 웹 common.js의 KINDS.weight와 같다.
    var weight: Int {
        switch self {
        case .mirror: 1
        case .minesweeper, .shikaku, .pair, .calc, .star: 2
        case .sudoku, .futoshiki, .switchSquares: 3
        }
    }

    /// 게임 이름. 모든 언어에서 번역하지 않고 영어 그대로 쓴다.
    var title: String {
        switch self {
        case .minesweeper: "Field Sweeper"
        case .sudoku: "Sudoku"
        case .shikaku: "Shikaku"
        case .futoshiki: "Futoshiki"
        case .mirror: "Mirror Squares"
        case .pair: "Pair Paths"
        case .switchSquares: "Switch Squares"
        case .calc: "Calc Squares"
        case .star: "Star Squares"
        }
    }

    /// 한국어 이름. 한국어 화면의 메인 카드와 기록 창에서만 영어 이름 옆에 함께 보인다(웹 common.js의 KINDS.ko와 같다).
    var koreanTitle: String {
        switch self {
        case .minesweeper: "필드 스위퍼"
        case .sudoku: "스도쿠"
        case .shikaku: "시카쿠"
        case .futoshiki: "후토시키"
        case .mirror: "거울네모"
        case .pair: "짝네모"
        case .switchSquares: "스위치네모"
        case .calc: "셈네모"
        case .star: "별네모"
        }
    }

    /// 아직 만들지 않은 게임은 메인 화면에 '준비 중'으로 보인다.
    var isAvailable: Bool { true }

    /// 게임마다 하나씩 정한 카드 색 (시안 '메인 · 03 A + 04 A').
    var fill: UIColor {
        switch self {
        case .minesweeper: .dynamic(0xa0b894, 0x3e4d38)
        case .sudoku: .dynamic(0xe6dfb0, 0x3b3824)
        case .shikaku: .dynamic(0xe8c3a8, 0x45352a)
        case .futoshiki: .dynamic(0xa9bbd3, 0x2f3a4a)
        case .mirror: .dynamic(0xc3a8c6, 0x483c49)
        case .pair: .dynamic(0xdfb3b7, 0x55383a)
        case .switchSquares: .dynamic(0xbfd8cc, 0x2c3d35)
        case .calc: .dynamic(0xcfc9bb, 0x3a3832)
        case .star: .dynamic(0x9a9fc4, 0x33364d)
        }
    }

    /// 카드 글자. 진한 카드(01·04)는 흰색, 밝은 카드(02·03)는 Deep Green. 번호만 Paper.inkSoft.
    var text: UIColor {
        switch self {
        case .minesweeper, .futoshiki, .mirror, .star: .dynamic(0xffffff, 0xf2f6ee)
        case .sudoku, .shikaku, .pair, .switchSquares, .calc: Paper.ink
        }
    }
}
