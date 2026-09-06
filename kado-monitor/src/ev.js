/**
 * 리미티드 팩(비복원 추출 오리파) 기대값 엔진.
 *
 * 입력 스냅샷 형식 (normalize.js 가 만들어 줌):
 * {
 *   id, name, price,            // price: 1회 뽑기 가격(원 또는 포인트)
 *   prizes: [{ name, value, remaining, total, tier? }],
 *   lastOne?: { name, value }   // 라스트원 보너스(마지막 1장 뽑은 사람에게 지급) - 선택
 * }
 *
 * 모든 함수는 순수 함수이며 외부 상태를 갖지 않는다.
 */

/** 로그 이항계수: ln C(n, k). n < k 이면 -Infinity. */
export function logChoose(n, k) {
  if (k < 0 || k > n) return -Infinity;
  if (k === 0 || k === n) return 0;
  k = Math.min(k, n - k);
  let s = 0;
  for (let i = 1; i <= k; i++) s += Math.log(n - k + i) - Math.log(i);
  return s;
}

/** 초기하분포: N개 중 H개가 "당첨"일 때 k개를 비복원 추출해 1개 이상 당첨될 확률. */
export function hitProbability(N, H, k) {
  if (N <= 0 || k <= 0 || H <= 0) return 0;
  if (k >= N) return 1;
  if (H >= N) return 1;
  const miss = Math.exp(logChoose(N - H, k) - logChoose(N, k));
  return Math.min(1, Math.max(0, 1 - miss));
}

/** 잔여 풀만 남긴 prize 배열 (remaining>0) */
export function livePrizes(prizes) {
  return prizes.filter((p) => (p.remaining ?? 0) > 0 && Number.isFinite(p.value));
}

/**
 * 스냅샷 하나를 분석한다.
 * @param {object} snap  정규화된 팩 스냅샷
 * @param {object} opts
 *   feeRate       판매/환급 시 차감 비율 (예: 0.1 = 10% 수수료). 기본 0
 *   haircut       시세 대비 실제 현금화 비율 보정 (예: 0.9). 기본 1
 *   profitThreshold  "이득 카드" 기준: value*net >= price*profitThreshold. 기본 1
 *   monteCarloTrials  k회 뽑기 시뮬레이션 횟수. 기본 4000. 0이면 생략
 *   maxK          시뮬레이션 최대 뽑기 수. 기본 min(N, 30)
 *   seed          시뮬레이션 시드
 */
export function analyzePack(snap, opts = {}) {
  const feeRate = opts.feeRate ?? 0;
  const haircut = opts.haircut ?? 1;
  const netMult = (1 - feeRate) * haircut;
  const profitThreshold = opts.profitThreshold ?? 1;
  const price = Number(snap.price) || 0;

  const live = livePrizes(snap.prizes ?? []);
  const N = live.reduce((a, p) => a + p.remaining, 0);
  const totalInitial = (snap.prizes ?? []).reduce((a, p) => a + (p.total ?? p.remaining ?? 0), 0);

  if (N === 0 || price <= 0) {
    return {
      id: snap.id, name: snap.name, price, remaining: N, totalInitial,
      soldOut: N === 0, evGross: 0, evNet: 0, roi: -1, edge: -price,
      profitCards: 0, profitProb1: 0, topPrize: null, prizes: [], buyout: null, kCurve: [],
      valueCoverage: 0,
    };
  }

  const sumGross = live.reduce((a, p) => a + p.remaining * p.value, 0);
  const evGross = sumGross / N;
  const evNet = evGross * netMult;
  const roi = evNet / price - 1; // 0 이상이면 기대값상 +EV
  const edge = evNet - price;

  // 카드별 현재 확률·기여도
  const prizes = live
    .map((p) => {
      const prob = p.remaining / N;
      const netValue = p.value * netMult;
      return {
        name: p.name, tier: p.tier ?? null, value: p.value, netValue,
        remaining: p.remaining, total: p.total ?? null,
        prob, evShare: prob * netValue,
        profitable: netValue >= price * profitThreshold,
        // 초기 대비 소진율. 상위 카드가 안 빠지고 하위만 빠지면 EV 상승
        depletion: p.total ? 1 - p.remaining / p.total : null,
      };
    })
    .sort((a, b) => b.value - a.value);

  const profitCards = prizes.filter((p) => p.profitable).reduce((a, p) => a + p.remaining, 0);
  const profitProb1 = profitCards / N;
  const topPrize = prizes[0] ?? null;

  // 가치 커버리지: 잔여 카드 중 시세를 아는 카드 비율 (value 누락된 카드가 많으면 신뢰도 낮음)
  const allRemaining = (snap.prizes ?? []).reduce((a, p) => a + (p.remaining ?? 0), 0);
  const valueCoverage = allRemaining ? N / allRemaining : 0;

  // 싹쓸이(전량 구매) 분석: 남은 N장을 모두 뽑는 비용 vs 가치
  const lastOneValue = snap.lastOne?.value ? snap.lastOne.value * netMult : 0;
  const buyoutCost = N * price;
  const buyoutValue = sumGross * netMult + lastOneValue;
  const buyout = {
    remaining: N, cost: buyoutCost, value: buyoutValue,
    roi: buyoutValue / buyoutCost - 1,
    lastOneValue,
  };

  // k회 뽑기 곡선: 기대값(선형), 목표 카드 1장 이상 확률, 손익분기 확률(시뮬)
  const maxK = Math.min(N, opts.maxK ?? 30);
  const trials = opts.monteCarloTrials ?? 4000;
  const sim = trials > 0 ? simulateDraws(live, price, netMult, maxK, trials, opts.seed ?? 1) : null;
  const kCurve = [];
  for (let k = 1; k <= maxK; k++) {
    kCurve.push({
      k,
      cost: k * price,
      ev: k * evNet,
      hitProfitCard: hitProbability(N, profitCards, k),
      hitTop: topPrize ? hitProbability(N, topPrize.remaining, k) : 0,
      profitProb: sim ? sim.profitProb[k - 1] : null,
      p10: sim ? sim.p10[k - 1] : null,
      p50: sim ? sim.p50[k - 1] : null,
      p90: sim ? sim.p90[k - 1] : null,
    });
  }

  // 권장 뽑기 수: 손익분기 확률이 가장 높은 k (동률이면 작은 k). 최대치가 50% 미만이면 권장하지 않음
  let bestK = null;
  if (sim) {
    let best = -1;
    kCurve.forEach((c) => { if (c.profitProb > best + 1e-9) { best = c.profitProb; bestK = c.k; } });
    if (best < (opts.recommendMinProfitProb ?? 0.5)) bestK = null;
  }

  return {
    id: snap.id, name: snap.name, price, remaining: N, totalInitial,
    soldOut: false, evGross, evNet, roi, edge,
    profitCards, profitProb1, topPrize, prizes, buyout, kCurve, bestK, valueCoverage,
    netMult,
  };
}

/**
 * 비복원 추출 몬테카를로. 각 k에 대해 (k회 누적 순가치 - k*price >= 0) 확률과 분위수를 구한다.
 * 한 번의 셔플로 모든 k를 동시에 평가하므로 trials × N 비용.
 */
export function simulateDraws(live, price, netMult, maxK, trials, seed = 1) {
  const pool = [];
  for (const p of live) for (let i = 0; i < p.remaining; i++) pool.push(p.value * netMult);
  const N = pool.length;
  const rnd = mulberry32(seed);
  const profitCount = new Array(maxK).fill(0);
  const samples = Array.from({ length: maxK }, () => new Float64Array(trials));

  for (let t = 0; t < trials; t++) {
    // 부분 Fisher-Yates: 앞 maxK개만 섞으면 충분
    for (let i = 0; i < maxK; i++) {
      const j = i + Math.floor(rnd() * (N - i));
      const tmp = pool[i]; pool[i] = pool[j]; pool[j] = tmp;
    }
    let cum = 0;
    for (let k = 0; k < maxK; k++) {
      cum += pool[k];
      const net = cum - (k + 1) * price;
      samples[k][t] = net;
      if (net >= 0) profitCount[k]++;
    }
  }
  const profitProb = profitCount.map((c) => c / trials);
  const q = (arr, p) => { const s = Float64Array.from(arr).sort(); return s[Math.min(s.length - 1, Math.floor(p * s.length))]; };
  return {
    profitProb,
    p10: samples.map((s) => q(s, 0.1)),
    p50: samples.map((s) => q(s, 0.5)),
    p90: samples.map((s) => q(s, 0.9)),
  };
}

export function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * "이득 지점" 판정. 규칙별 트리거 목록을 반환한다.
 * @param {object} a  analyzePack 결과
 * @param {object} prev  이전 분석 결과(없으면 null)
 * @param {object} rules
 *   roiAbove        기본 0      : 순기대값 ROI 가 이 값 이상
 *   buyoutRoiAbove  기본 0.1    : 싹쓸이 ROI 가 이 값 이상
 *   topProbAbove    기본 null   : 1회 뽑기 최고가 카드 확률이 이 값 이상
 *   profitProbAbove 기본 null   : 1회 뽑기 "이득 카드" 확률이 이 값 이상
 *   remainingBelow  기본 null   : 잔여 수량이 이 값 이하 (상위 카드 잔존 시)
 *   minValueCoverage 기본 0.8   : 시세 미확인 카드가 많으면 알림 억제
 */
export function evaluateRules(a, prev, rules = {}) {
  const r = { roiAbove: 0, buyoutRoiAbove: 0.1, minValueCoverage: 0.8, ...rules };
  const out = [];
  if (a.soldOut) {
    if (prev && !prev.soldOut) out.push({ rule: 'sold_out', level: 'info', msg: '품절됨' });
    return out;
  }
  if (a.valueCoverage < r.minValueCoverage) {
    return [{ rule: 'low_coverage', level: 'warn', msg: `시세 확인된 카드 비율 ${(a.valueCoverage * 100).toFixed(0)}% — 판단 보류` }];
  }
  if (!prev) out.push({ rule: 'new_pack', level: 'info', msg: '신규 감지' });

  if (a.roi >= r.roiAbove && !(prev && prev.roi >= r.roiAbove))
    out.push({ rule: 'roi_above', level: 'alert', msg: `순기대값 ROI ${pct(a.roi)} (EV ${fmt(a.evNet)} / 가격 ${fmt(a.price)})` });

  if (a.buyout && a.buyout.roi >= r.buyoutRoiAbove && !(prev && prev.buyout && prev.buyout.roi >= r.buyoutRoiAbove))
    out.push({ rule: 'buyout_roi_above', level: 'alert', msg: `싹쓸이 ROI ${pct(a.buyout.roi)} (잔여 ${a.remaining}장, 비용 ${fmt(a.buyout.cost)} → 가치 ${fmt(a.buyout.value)})` });

  if (r.topProbAbove != null && a.topPrize && a.topPrize.prob >= r.topProbAbove && !(prev && prev.topPrize && prev.topPrize.prob >= r.topProbAbove))
    out.push({ rule: 'top_prob_above', level: 'alert', msg: `최고가 카드 ${a.topPrize.name} 확률 ${pct(a.topPrize.prob)} (잔여 ${a.topPrize.remaining}장)` });

  if (r.profitProbAbove != null && a.profitProb1 >= r.profitProbAbove && !(prev && prev.profitProb1 >= r.profitProbAbove))
    out.push({ rule: 'profit_prob_above', level: 'alert', msg: `1회 이득 카드 확률 ${pct(a.profitProb1)}` });

  if (r.remainingBelow != null && a.remaining <= r.remainingBelow && a.profitCards > 0 && !(prev && prev.remaining <= r.remainingBelow))
    out.push({ rule: 'remaining_below', level: 'alert', msg: `잔여 ${a.remaining}장, 이득 카드 ${a.profitCards}장 잔존` });

  // 추세: 이전 대비 ROI가 개선(하위 카드만 빠짐)
  if (prev && Number.isFinite(prev.roi) && a.roi - prev.roi >= (r.roiJump ?? 0.05))
    out.push({ rule: 'roi_jump', level: 'info', msg: `ROI ${pct(prev.roi)} → ${pct(a.roi)} (잔여 ${prev.remaining} → ${a.remaining})` });

  return out;
}

export const pct = (x) => `${(x * 100).toFixed(1)}%`;
export const fmt = (x) => Math.round(x).toLocaleString('ko-KR');
