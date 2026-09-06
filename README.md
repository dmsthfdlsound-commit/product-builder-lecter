# 로또 번호 생성기 (Lotto 6/45)

배포·수익화 준비가 끝난 무료 로또 번호 생성 웹앱입니다. 프레임워크 없이 순수 HTML/CSS/JS로 만들어져 정적 호스팅(GitHub Pages, Firebase Hosting 등) 어디서나 바로 동작합니다.

## 기능

- 1~5게임 동시 생성 (동행복권 공식 볼 색상)
- 완전 랜덤 / 홀짝·구간 균형 모드
- 고정수·제외수 지정
- 번호 저장(localStorage), 복사, 공유(Web Share API)
- 모바일 반응형, SEO 메타태그, 광고 슬롯 내장

## 실행

정적 파일이므로 `index.html`을 열거나 아무 정적 서버로 서빙하면 됩니다.

```bash
npx serve .
```

## 배포 & 수익화

[`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md)에 7일 런칭·수익화 실행 플랜이 정리되어 있습니다.

## 부속 도구: KADO 리미티드 팩 감시기

[`kado-monitor/`](./kado-monitor/README.md) 에 kado.trade 리미티드 팩의 잔여 풀 기대값(EV)을 계산하고 +EV 진입 시점을 실시간 감시·알림하는 Node.js 도구가 있습니다. 정적 사이트 배포에는 포함되지 않습니다.
