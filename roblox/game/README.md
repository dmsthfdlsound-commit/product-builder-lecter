# 🫧 +1 Pop! 뽁뽁이 탈출 (Bubble Wrap Escape) — v0.3

> **v0.3 게임 필 패치**: 속도 체감 강화(계수 0.06→0.45, FOV 연출), 뽁 쿨다운 1.5s→0.35s(매 걸음이 뽁),
> 물방울 '퐁' 사운드(랜덤 피치·저볼륨), 터진 자리에 "+N" 플로터, 눌림(squash) 애니메이션, 양옆 가드레일.
> 🔊 더 좋은 ASMR 팝 사운드를 원하면: Studio 툴박스에서 "bubble pop" 검색 → `Main.server.lua`의 `popSound` 안 `SoundId` 한 줄만 교체.

> +1 공식([분석 문서](../plus1-hypercasual-analysis.md))의 1호기. 뽁뽁이를 밟으면 +1 Speed, 스피드 게이트를 뚫고 탈출하는 하이퍼캐주얼.
> **이 폴더는 실제로 돌아가는 완성 코드입니다** — 아래 방법대로 열면 5분 안에 플레이됩니다.

## 0. 로블록스 게임은 어떻게 만드나 (큰 그림)

1. **Roblox Studio** (무료, Windows/Mac) — 에디터·테스트·배포가 전부 이 안에서 됨. [create.roblox.com](https://create.roblox.com)에서 다운로드, 로블록스 계정으로 로그인
2. **Luau 스크립트** — 게임 로직은 Luau(로블록스 방언 Lua)로 작성. **서버 스크립트**(ServerScriptService, 판정·데이터 등 진실의 원천)와 **클라이언트 스크립트**(StarterPlayerScripts, UI·연출)로 나뉨
3. **F5로 테스트 → Publish 버튼으로 배포** — 서버 호스팅·패치·설치 전부 로블록스가 대신 해줌. 우리는 코드와 콘텐츠만

이 게임도 정확히 그 구조입니다: 서버 스크립트 1개(맵 생성부터 저장까지) + 클라이언트 스크립트 1개(HUD).

## 1. 폴더 구성

```
game/
├── default.project.json              # Rojo 프로젝트 정의 (스크립트 → 서비스 매핑)
├── src/
│   ├── server/Main.server.lua        # 게임 전체 로직 (맵 생성·뽁 판정·게이트·리버스·저장)
│   └── client/HUD.client.lua         # 스피드 카운터 + 전광판 배너 UI
└── build/Plus1PopBubbleEscape.rbxlx  # 빌드된 place 파일 (Studio에서 바로 열림)
```

## 2. 여는 방법 (셋 중 하나)

### 방법 A — place 파일 열기 (가장 빠름, 1분)
1. `build/Plus1PopBubbleEscape.rbxlx` 다운로드
2. 더블클릭 (Roblox Studio가 열림)
3. **F5** → 플레이됨 🎉

### 방법 B — 복사·붙여넣기 (Studio가 처음이라면 이걸 추천, 5분)
1. Studio → **New → Baseplate**
2. 우측 Explorer에서 **ServerScriptService** 우클릭 → Insert Object → **Script** → 기본 내용 지우고 `src/server/Main.server.lua` 전체 붙여넣기
3. Explorer에서 **StarterPlayer > StarterPlayerScripts** 우클릭 → Insert Object → **LocalScript** → `src/client/HUD.client.lua` 전체 붙여넣기
4. **F5** → 맵은 코드가 자동 생성하므로 빈 Baseplate여도 됩니다

### 방법 C — Rojo 워크플로 (이 레포에서 git으로 개발할 때)
1. [Rojo](https://rojo.space) 설치 + Studio용 Rojo 플러그인 설치
2. 이 폴더에서 `rojo serve` → Studio 플러그인에서 Connect
3. 이제 VS Code에서 코드를 고치면 Studio에 실시간 반영 (이 레포에 커밋하며 개발)

## 3. 게임 내용 (v0.2)

- **코어 루프**: 뽁뽁이 밟기 = +1 Speed (터지는 소리+이펙트, 2.5초 후 재생성) → 걷기 속도도 같이 상승
- **스피드 게이트 5개**: Speed 50 / 150 / 300 / 500 / 800 — 미달이면 튕겨나고, 통과하면 다음 존(딸기→바나나→소다→멜론→포도)
- **WIN 패드**: 끝까지 가면 +1 Win, 스폰으로 귀환 (Speed 유지)
- **리버스 패드** (스폰 왼쪽 금색): Speed 1,000 소모 → 영구 뽁 배수 +1 (×2, ×3, …) — 서버 전체에 방송됨
- **저장**: Speed/Wins/Rebirths/트레일 보유·장착이 DataStore에 자동 저장 (퇴장 시 + 2분마다)
- **HUD**: 화면 상단 대형 카운터, +N 플로터, 서버 전광판 배너 (안달 엔진 훅② ③의 라이트 버전)
- **🛒 트레일 상점 (v0.2 신규)**: 우측 상단 상점 버튼 → ⭐ Wins로 구매하는 이동 트레일 3종
  - 🫧 비눗방울 3⭐ / 🌈 무지개 10⭐ / ⭐ 황금 25⭐ — 구매 즉시 장착, 클릭으로 장착/해제
  - 구매·장착 검증은 전부 서버에서 (클라이언트는 요청만) — 핵 대비 원칙 유지
  - 치장 전용: 과금 원칙("남을 이기는 힘은 팔지 않는다") 준수. 누가 사면 서버 전광판에 방송 → Wins의 사용처이자 과시 루프

밸런스는 전부 `Main.server.lua` 상단 `CONFIG` 테이블에서 조정합니다 (게이트 요구치, 쿨다운, 리버스 가격 등).

## 4. 테스트·배포 체크리스트

- [ ] **저장 테스트하려면**: Home → Game Settings → Security → **Enable Studio Access to API Services** 켜기 (안 켜도 게임은 돌아가고, 저장만 건너뜀)
- [ ] **혼자 말고 2인 테스트**: Test 탭 → Clients and Servers → 2 Players (전광판·경쟁 확인)
- [ ] **배포**: File → **Publish to Roblox As...** → 이름/설명 입력 → 처음엔 Private로 두고 친구 초대 테스트 → Game Settings → Permissions → Public 전환
- [ ] 이름 제안: `[🫧POP] +1 Speed Bubble Wrap Escape` (검색 밈 + 이모지 훅)
- [ ] 아이콘/썸네일: 뽁뽁이 클로즈업 + 큼직한 "+1" — CTR이 노출을 결정

## 5. 다음 스텝 (7일 스프린트 이어가기)

| Day | 할 일 |
|---|---|
| 2 | 진짜 뽁뽁이 ASMR 사운드로 교체(툴박스/직접 업로드), 존 배경 데코 |
| ~~3~~ | ~~Wins 사용처: 트레일 상점~~ ✅ **v0.2에서 완료** |
| 4 | 존 6~13 확장 + 장애물(사라지는 다리, 추격 젤리) |
| 5 | 글로벌 리더보드(OrderedDataStore) + 일일 보너스 |
| 6 | 아이콘/썸네일 3종, 게임패스(뽁 x2, 트레일 번들 — 남을 방해하는 힘은 금지) |
| 7 | 퍼블리시 + 15초 클립 3개(리버스 순간, 게이트 아슬아슬 통과) |

**+7일 판정 룰**: D1 리텐션 25% 미만이면 미련 없이 다음 소재([분석 문서 5장](../plus1-hypercasual-analysis.md) 소재 후보)로 회전.
