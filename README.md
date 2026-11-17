# 네모 안에 네모 (NEMO IN NEMO)

인터넷 없이 즐기는 두뇌 퍼즐 모음. 로그인 없이 플레이하고, 기록과 진행 상황은 기기 안에만 저장합니다. iOS 앱과 웹 버전이 한 저장소에 있습니다.

## 게임

| 번호 | 게임 | 한 줄 설명 | 난이도 | 앱 | 웹 |
|---|---|---|---|---|---|
| 01 | Field Sweeper | 숫자를 단서로 지뢰의 위치를 추론하고, 안전한 칸을 모두 여는 논리 퍼즐 | 초급~지옥, 커스텀 | ✓ | ✓ |
| 02 | Sudoku | 가로줄, 세로줄, 3×3 구역에 1부터 9까지의 숫자를 채우는 논리 퍼즐 | 초급~전문가 | ✓ | ✓ |
| 03 | Shikaku | 숫자에 맞춰 판을 여러 개의 사각형으로 나누는 논리 퍼즐 | 초급~전문가, 커스텀 | ✓ | ✓ |
| 04 | Futoshiki | 칸 사이의 부등호를 지키며 가로줄과 세로줄에 숫자를 채우는 논리 퍼즐 | 초급~전문가 | ✓ | ✓ |
| 05 | Mirror Squares | 거울의 방향을 바꿔 빛이 모든 별을 지나 목적지에 도달하도록 만드는 논리 퍼즐 | 초급~전문가 | 엔진만 | ✓ |
| 06 | Pair Paths | 같은 숫자가 적힌 두 칸을 정해진 길이로 연결하는 논리 퍼즐 | 초급~전문가 | 엔진만 | ✓ |
| 07 | Switch Squares | 칸을 눌러 가로줄과 세로줄의 불을 바꾸고, 모든 불을 켜는 논리 퍼즐 | 초급~지옥 | 엔진만 | ✓ |

"엔진만"은 규칙·문제 생성 코드(`FieldSweeper/Model/*Engine.swift`)는 앱에 있고 화면은 아직 없다는 뜻입니다.

### 공통

- 퍼즐은 매번 새로 만들고, 정답이 하나뿐인지 확인한 판만 냅니다(스도쿠·시카쿠·후토시키·거울네모·스위치네모, 짝네모 중급 이상). 지뢰찾기는 첫 칸과 그 주변만 안전하게 보장합니다.
- 자동 저장과 이어하기, 일시정지, 시간 표시 끄기
- 메인 화면 카드의 작은 네모 세 개는 게임 자체 난이도입니다(채운 수: 1 쉬움 · 2 보통 · 3 어려움). 거울네모 1, 지뢰찾기·시카쿠·짝네모 2, 스도쿠·후토시키·스위치네모 3.
- 헤더의 새 퍼즐 버튼: 지금 난이도로 바로 새 판. 손댄 판이 있으면 먼저 묻습니다. 난이도는 ⋯ 메뉴에서 바꿉니다.
- 게임별 기록: 플레이 수, 완료 수, 완료율, 평균 시간, 난이도별 최고 기록. 메인 화면의 `no.`는 지금까지 시작한 판 수입니다.
- 처음 들어간 게임은 규칙을 한 번 보여주고, ⋯ 메뉴의 "규칙 보기"로 다시 볼 수 있습니다.
- 한국어, 영어, 일본어, 중국어(간체)

### 되돌리기

| 게임 | 초급·커스텀 | 중급 | 고급 | 전문가 | 지옥 |
|---|---|---|---|---|---|
| 스도쿠·시카쿠·후토시키·짝네모 | 무제한 | 10회 | 5회 | 3회 | — |
| 거울네모·스위치네모 | 무제한, 대신 쓸 때마다 조작 1회로 셉니다 | | | | |
| 지뢰찾기 | 없음 | | | | |

숫자 지우기, 영역·길 지우기, 같은 칸 다시 누르기처럼 직접 고치는 것은 횟수와 상관없습니다.

### 게임별로 더 있는 것

- **지뢰찾기**: 보드 크기·지뢰 수 커스텀(iPad는 최대 50×50), 깃발·지뢰 모양을 이모지나 내 사진으로 변경, 필드 색 프리셋과 직접 고르기, 물음표 표시
- **스도쿠·후토시키**: 메모, 중복·부등호 위반 표시, iPad에서 Apple Pencil 손글씨로 숫자 입력(앱)
- **시카쿠**: 끌어서 사각형 그리기, 두 번 탭이나 지우개로 지우기, 커스텀 판(5×5~15×15, 영역 크기 3단계)
- **거울네모**: 빛 경로 실시간 표시, 고정 거울과 벽, 조작 수와 최소 조작 수
- **짝네모**: 끌어서 길 그리기(길이 표시). 중급(7×7)부터 모든 칸 채우기. 사람처럼 푸는 풀이기로 판을 재서, 중급은 쉬운 판, 고급(8×8)은 넓게 따져야 하는 판, 전문가(10×10, 긴 길)는 2.5초 동안 만들어 본 판 중 가정이 가장 많이 필요한 판을 냅니다.
- **스위치네모**: 짝수 판만 써서 답이 하나뿐, 고급부터 최소 조작 수 표시, 지옥은 최소 횟수 안에 풀어야 성공
- **Apple Pencil(앱, iOS 17.5 이상)**: Pencil Pro 쥐기·2세대 두 번 탭으로 지뢰찾기 열기 ↔ 깃발, 스도쿠·후토시키 메모, 시카쿠 지우개 전환

## 구조

```
FieldSweeper.xcodeproj   iOS 앱 프로젝트 (폴더 안 파일을 자동으로 포함)
FieldSweeper/            앱 코드 (SwiftUI + UIKit 보드)
  Model/                 게임 규칙·문제 생성(*Engine.swift), 진행·저장, 기록, 되돌리기 횟수(UndoLimit)
  UI/                    화면
  Localizable.xcstrings  앱 문구와 번역
docs/                    GitHub Pages로 배포되는 웹
  index.html             메인 화면 (게임 카드, 기록, 설정)
  minesweeper.html       지뢰찾기
  sudoku.html            스도쿠
  shikaku.html           시카쿠
  futoshiki.html         후토시키
  mirror.html            거울네모
  pair.html              짝네모
  switch.html            스위치네모
  privacy.html           개인정보 처리방침
  assets/
    *-engine.js          퍼즐 엔진 (앱의 *Engine.swift와 짝)
    common.js            공통 부품: 저장, 번역, 기록, 타이머, 상단 막대, 겹쳐 보이는 창, 되돌리기 횟수
    number-puzzle.js     스도쿠·후토시키가 함께 쓰는 진행 코드
    rules.js             게임별 한 줄 설명·규칙·조작법과 번역
    paper.css            메모지 스타일과 게임별 색
    i18n.js              앱 문구에서 만든 웹 번역표
scripts/
  gen-web-i18n.py        Localizable.xcstrings → docs/assets/i18n.js
```

## iOS 앱

Xcode 16 이상에서 `FieldSweeper.xcodeproj`를 열고 실행합니다. iOS 17 이상, iPhone·iPad 모두 지원합니다.

Xcode가 없어도 규칙 코드는 Command Line Tools의 `swiftc`로 컴파일하고 테스트할 수 있습니다. `Model/`의 엔진 파일은 Foundation만 씁니다.

## 웹

빌드가 필요 없는 정적 파일입니다. 로컬에서는 서버를 띄워 확인합니다.

```
python3 -m http.server 8000 -d docs
```

브라우저에서 `http://localhost:8000`을 엽니다. 저장소 Settings → Pages에서 `main` 브랜치의 `/docs` 폴더를 배포 대상으로 지정하면 다음 주소로 열립니다.

- 메인 화면: `https://lalalalala00.github.io/field-sweeper/`
- 개인정보 처리방침: `https://lalalalala00.github.io/field-sweeper/privacy.html`

## 고칠 때 함께 바꿀 곳

- **게임 규칙·문제 생성**: 앱(Swift)과 웹(JavaScript)에 각각 있습니다. `FieldSweeper/Model/*Engine.swift`와 `docs/assets/*-engine.js`를 함께 고칩니다.
- **게임 자체 난이도**: `docs/assets/common.js`의 `KINDS.weight`와 `FieldSweeper/Model/GameKind.swift`의 `weight`가 같아야 합니다.
- **되돌리기 횟수**: `FieldSweeper/Model/UndoLimit.swift`와 `docs/assets/common.js`의 표가 같아야 합니다.
- **규칙 문구**: `docs/assets/rules.js`에 있습니다. `{ text, app: true }`로 적은 줄은 앱 전용 기능이라 웹에서는 보이지 않습니다. 앱에 규칙 화면을 만들 때 이 문구를 옮깁니다.
- **문구 번역**: 웹은 앱의 `Localizable.xcstrings`에서 만든 `docs/assets/i18n.js`를 씁니다. 앱에 문구를 추가했다면 `python3 scripts/gen-web-i18n.py`로 다시 만듭니다. 웹에만 있는 문구는 `common.js`의 번역표에 있습니다.
