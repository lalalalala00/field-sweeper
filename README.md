# 네모 안에 네모 (NEMO IN NEMO)

인터넷 없이 즐기는 두뇌 퍼즐 모음. 지뢰찾기·스도쿠·시카쿠·후토시키가 들어 있고, 스위치네모·거울네모는 웹에 먼저 나왔으며 짝네모를 준비 중입니다. iOS 앱과 웹 버전이 한 저장소에 있습니다.

## 지뢰찾기

- 보드 크기·지뢰 수 커스텀 (iPad는 최대 50×50)
- 깃발·지뢰 모양을 이모지나 내 사진으로 변경
- 필드 색 프리셋과 직접 고르기
- 자동 저장과 이어하기, 일시정지, 시간 표시 끄기
- Apple Pencil Pro 쥐기·2세대 두 번 탭으로 열기 ↔ 깃발 전환 (iOS 17.5 이상)

## 구조

```
FieldSweeper.xcodeproj   iOS 앱 프로젝트
FieldSweeper/            앱 코드 (SwiftUI + UIKit 보드)
  Model/                 게임 규칙, 저장, 모양·색 설정
  UI/                    화면
docs/                    GitHub Pages로 배포되는 웹
  index.html             메인 화면 (게임 카드, 기록, 설정)
  minesweeper.html       지뢰찾기
  sudoku.html            스도쿠
  shikaku.html           시카쿠
  futoshiki.html         후토시키
  mirror.html            거울네모 (앱 화면은 Xcode 설치 후)
  switch.html            스위치네모 (앱 화면은 Xcode 설치 후)
  privacy.html           개인정보 처리방침
  assets/                공통 스타일·부품, 퍼즐 엔진, 번역표
```

## iOS 앱

Xcode 16 이상에서 `FieldSweeper.xcodeproj`를 열고 실행합니다. iOS 17 이상, iPhone·iPad 모두 지원합니다.

## 웹

빌드가 필요 없는 정적 파일입니다. 로컬에서는 서버를 띄워 확인합니다.

```
python3 -m http.server 8000 -d docs
```

브라우저에서 `http://localhost:8000`을 엽니다. 저장소 Settings → Pages에서 `main` 브랜치의 `/docs` 폴더를 배포 대상으로 지정하면 다음 주소로 열립니다.

- 메인 화면: `https://lalalalala00.github.io/field-sweeper/`
- 개인정보 처리방침: `https://lalalalala00.github.io/field-sweeper/privacy.html`

게임 규칙은 앱(Swift)과 웹(JavaScript)에 각각 구현되어 있으므로 기능을 바꿀 때는 양쪽을 함께 수정합니다. 퍼즐 엔진은 `FieldSweeper/Model/*Engine.swift`와 `docs/assets/*-engine.js`가 짝입니다.

웹 문구 번역은 앱의 `Localizable.xcstrings`에서 만든 `docs/assets/i18n.js`를 씁니다. 앱에 문구를 추가했다면 `python3 scripts/gen-web-i18n.py`로 다시 만듭니다.
