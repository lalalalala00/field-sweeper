import Foundation

/// 난이도별 되돌리기 횟수. 초급과 커스텀은 무제한(nil)이고, 난이도가 오를수록 줄어 지옥에는 없다.
/// 숫자 지우기, 영역 지우기, 같은 칸 다시 누르기처럼 직접 고치는 것은 횟수와 상관없이 언제든 할 수 있다.
/// 난이도는 기록과 같은 한국어 이름으로 구분한다. 웹(docs/assets/common.js)도 같은 표를 쓴다.
/// 스위치네모·거울네모는 예외: 되돌리기가 '같은 칸 다시 누르기'와 같아서 횟수 제한 없이 쓰고 조작 1회로 센다.
enum UndoLimit {
    static func count(forLevel name: String) -> Int? {
        switch name {
        case "중급": 10
        case "고급": 5
        case "전문가": 3
        case "지옥": 0
        default: nil
        }
    }
}
