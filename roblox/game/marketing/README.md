# 🎬 +1 Pop! 숏폼 티저 파이프라인

`plus1pop-teaser.mp4` — 10초 · 1080×1920(9:16) · 30fps · 사운드 포함. 틱톡/쇼츠/릴스용.

## 재생성 방법 (코드로 영상을 만드는 파이프라인)

1. `python3 generate.py` — 팝 타임라인(schedule.json) + 팝 ASMR 사운드(audio.wav) 생성. **영상과 오디오가 같은 스케줄을 공유**해서 소리가 정확히 팝에 맞음
2. `npm i playwright-core` 후 `node record.js` — Chromium이 teaser.html을 열고 300프레임을 결정론적으로 캡처
3. `ffmpeg -framerate 30 -i frames/f%04d.png -i audio.wav -c:v libx264 -pix_fmt yuv420p -c:a aac plus1pop-teaser.mp4`

문구/색/속도는 `teaser.html`, 팝 페이스/사운드는 `generate.py`의 상수만 수정.

## 구성 (10초)

0.3~6.2s 팝 가속(0.42→0.05s 간격) → 6.25s ♻️ 리버스 ×2 플래시 → 6.5~8s 프렌지 → 8~10s 엔드카드(로고+CTA)

⚠️ 진짜 바이럴은 실제 게임플레이 캡처가 더 강함 — 이 티저는 인트로/브랜딩용. 게임플레이 클립 샷리스트는 게임 README의 Day 7 항목 참조.
