# KADO 리미티드 팩 EV 감시기

[kado.trade](https://kado.trade) 의 리미티드 팩(카드 풀이 고정된 디지털 오리파)에서 **투자 대비 이득이 되는 순간**을 계산하고, 실시간으로 감시해 알림을 보내는 도구입니다. 의존성 없는 Node.js(20+) 로 동작합니다.

## 왜 "지점"이 생기는가

리미티드 팩은 카드 풀이 정해져 있고 뽑힌 카드는 풀에서 빠집니다. 따라서 **하위 카드만 빠지고 상위 카드가 남으면 남은 풀의 기대값이 팩 가격을 넘는 구간**이 생깁니다. 이 도구는 매 폴링마다 잔여 풀로 다음을 계산합니다.

| 지표 | 정의 |
| --- | --- |
| 총기대값 `evGross` | Σ(잔여 수량 × 시세) ÷ 잔여 총수 |
| 순기대값 `evNet` | `evGross × (1 − feeRate) × haircut` (판매 수수료·현금화 손실 반영) |
| ROI | `evNet ÷ 가격 − 1` (0 이상이면 +EV) |
| 이득 카드 확률 | 1회 뽑기에서 순가치 ≥ 가격인 카드가 나올 확률 |
| 최고가 카드 확률 | 초기하분포 기반, k회 뽑기에 1장 이상 포함될 확률 |
| 싹쓸이 ROI | 남은 전량 구매 비용 대비 가치 (라스트원 보너스 포함) |
| k회 손익분기 확률 | 비복원 추출 몬테카를로. k회 뽑았을 때 손실이 없을 확률과 P10/P50/P90 |
| 권장 뽑기 수 | 손익분기 확률이 최대인 k (최대치가 50% 미만이면 권장 안 함) |

## 빠른 시작

```bash
cd kado-monitor
npm test                                   # 단위 테스트
npm run analyze                            # 샘플 데이터 분석
node bin/kado-monitor.js analyze fixtures/sample-packs.json --fee 0.1 --haircut 0.9 --pack lp-1001
node bin/kado-monitor.js watch --config config.file-demo.json   # 파일 기반 데모 감시 + http://127.0.0.1:8787
```

## kado.trade 연결하기

kado.trade 는 공개 API 문서가 없습니다. 브라우저가 실제로 호출하는 JSON 을 자동으로 찾아 설정을 만듭니다.

```bash
npm i -D playwright && npx playwright install chromium     # 최초 1회
node bin/kado-monitor.js discover --headed --url https://kado.trade/
```

1. 창이 뜨면 로그인하고 리미티드 팩 목록과 상세 페이지를 한 번씩 엽니다.
2. 터미널에서 Enter 를 누르면 `discover-out/` 에 응답 원본과 `report.json`(후보 랭킹) 이 저장되고, 추천 `config` 가 출력됩니다.
3. `config.example.json` 을 `config.json` 으로 복사한 뒤 `listUrl`, `detailUrl`(있으면) 을 채웁니다. 로그인이 필요하면 개발자도구 Network 탭의 `cookie`/`authorization` 헤더를 `adapter.headers` 에 넣습니다.
4. `node bin/kado-monitor.js scan --detail` 로 파싱이 맞는지 확인합니다. 필드 인식이 틀리면 `adapter.map` 에 경로를 지정합니다.
5. `node bin/kado-monitor.js watch` 로 감시를 시작합니다.

필드 이름은 자동 추론됩니다(`price/amount/cost`, `remaining/remain/stock/left/qty`, `total/count/max`, `value/marketPrice/refPrice/estimatedPrice` 등). 사이트가 카드 시세를 주지 않으면 `valueOverrides` 로 카드명별 시세를 직접 넣을 수 있습니다.

discover 로 캡처한 JSON 은 파일 어댑터로 바로 재생할 수 있습니다.

```json
{ "adapter": { "source": "file", "path": "discover-out/007.json" } }
```

## 알림 규칙 (`rules`)

| 키 | 의미 |
| --- | --- |
| `roiAbove` | 순기대값 ROI 가 이 값 이상으로 **진입**할 때 (기본 0) |
| `buyoutRoiAbove` | 싹쓸이 ROI 진입 (기본 0.1) |
| `topProbAbove` | 최고가 카드 1회 확률 진입 |
| `profitProbAbove` | 이득 카드 1회 확률 진입 |
| `remainingBelow` | 잔여 수량이 이하이면서 이득 카드가 남아 있을 때 |
| `roiJump` | 직전 조회 대비 ROI 상승폭 (하위 카드가 빠졌다는 신호) |
| `minValueCoverage` | 시세를 아는 카드 비율이 이보다 낮으면 알림 억제 |

임계값을 넘어선 순간에만 1회 발화하고, 같은 규칙은 `alertCooldownSec` 동안 재발화하지 않습니다. 알림은 콘솔, Discord, Slack, Telegram, 일반 webhook, 대시보드의 브라우저 알림으로 전달됩니다.

## 대시보드

`watch` 실행 시 `http://127.0.0.1:8787` 에서 SSE 로 실시간 갱신되는 표를 제공합니다. 행을 클릭하면 잔여 카드별 확률·EV 기여와 k회 뽑기 손익 곡선이 펼쳐지고, 추세 열은 ROI 이력 스파크라인입니다. 상태는 `state/packs.json`, `state/history.jsonl` 에 저장되어 재시작 후에도 이어집니다.

## 구조

```
bin/kado-monitor.js   CLI (analyze / scan / watch / discover)
src/ev.js             기대값·확률·시뮬레이션 엔진 (순수 함수)
src/normalize.js      임의 JSON → 표준 스냅샷 (자동 추론 + 매핑)
src/adapters/kado.js  kado.trade HTTP 어댑터 (JSON, __NEXT_DATA__ 폴백)
src/adapters/file.js  로컬 JSON 어댑터
src/monitor.js        폴링·규칙 평가·쿨다운·상태 저장
src/notify.js         알림 채널
src/server.js         대시보드 서버 (SSE)
src/discover.js       Playwright 기반 API 탐지
dashboard/index.html  대시보드 UI
```

## 주의

- 시세(`value`)의 품질이 결과를 좌우합니다. 카도 내부 참고가나 마켓 최근 체결가를 쓰고, 현금화 손실은 `haircut` 으로 보수적으로 잡으세요.
- 폴링 간격은 30초 이상을 권장합니다(`jitter` 로 무작위성이 더해집니다). 사이트 이용약관을 확인하세요.
- 기대값이 양수라도 분산이 큽니다. k회 손익분기 확률과 P10 을 함께 보세요.
