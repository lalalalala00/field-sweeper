# 네모 안에 네모 (NEMO IN NEMO)

인터넷 없이 즐기는 두뇌 퍼즐 모음. 지뢰찾기가 들어 있고 스도쿠·시카쿠·후토시키를 준비 중입니다. iOS 앱과 웹 버전(지뢰찾기)이 한 저장소에 있습니다.

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
  index.html             웹 게임
  privacy.html           개인정보 처리방침
```

## iOS 앱

Xcode 16 이상에서 `FieldSweeper.xcodeproj`를 열고 실행합니다. iOS 17 이상, iPhone·iPad 모두 지원합니다.

## 웹

`docs/index.html` 하나로 동작하며 빌드가 필요 없습니다. 저장소 Settings → Pages에서 `main` 브랜치의 `/docs` 폴더를 배포 대상으로 지정하면 다음 주소로 열립니다.

- 게임: `https://lalalalala00.github.io/field-sweeper/`
- 개인정보 처리방침: `https://lalalalala00.github.io/field-sweeper/privacy.html`

게임 규칙은 앱(Swift)과 웹(JavaScript)에 각각 구현되어 있으므로 기능을 바꿀 때는 양쪽을 함께 수정합니다.
