import { test } from 'node:test';
import assert from 'node:assert/strict';
import { analyzePack, hitProbability, logChoose, evaluateRules, simulateDraws } from '../src/ev.js';

const pack = {
  id: 'p', name: 'p', price: 1000,
  prizes: [
    { name: 'A', value: 10000, remaining: 1, total: 1 },
    { name: 'B', value: 500, remaining: 9, total: 19 },
  ],
};

test('logChoose / hitProbability', () => {
  assert.equal(Math.round(Math.exp(logChoose(5, 2))), 10);
  assert.equal(hitProbability(10, 1, 10), 1);
  assert.equal(hitProbability(10, 0, 3), 0);
  // 10장 중 1장 당첨, 3장 뽑기: 1 - C(9,3)/C(10,3) = 1 - 84/120 = 0.3
  assert.ok(Math.abs(hitProbability(10, 1, 3) - 0.3) < 1e-12);
});

test('analyzePack: EV, ROI, 확률, 싹쓸이', () => {
  const a = analyzePack(pack, { monteCarloTrials: 0 });
  assert.equal(a.remaining, 10);
  assert.equal(a.totalInitial, 20);
  assert.equal(a.evGross, (10000 + 9 * 500) / 10); // 1450
  assert.ok(Math.abs(a.roi - 0.45) < 1e-12);
  assert.equal(a.profitCards, 1);
  assert.equal(a.profitProb1, 0.1);
  assert.equal(a.topPrize.name, 'A');
  assert.equal(a.buyout.cost, 10000);
  assert.equal(a.buyout.value, 14500);
  assert.equal(a.kCurve.length, 10);
  assert.ok(Math.abs(a.kCurve[2].hitTop - 0.3) < 1e-12);
  assert.equal(a.valueCoverage, 1);
});

test('analyzePack: 수수료·헤어컷 반영', () => {
  const a = analyzePack(pack, { feeRate: 0.1, haircut: 0.5, monteCarloTrials: 0 });
  assert.ok(Math.abs(a.evNet - 1450 * 0.45) < 1e-9);
  assert.ok(a.roi < 0);
  assert.equal(a.profitCards, 1); // 10000*0.45=4500 >= 1000
});

test('analyzePack: 라스트원 보너스는 싹쓸이에만 반영', () => {
  const a = analyzePack({ ...pack, lastOne: { name: 'L', value: 3000 } }, { monteCarloTrials: 0 });
  assert.equal(a.buyout.value, 14500 + 3000);
  assert.equal(a.evGross, 1450);
});

test('analyzePack: 품절 / 시세 누락 커버리지', () => {
  const s = analyzePack({ ...pack, prizes: pack.prizes.map((p) => ({ ...p, remaining: 0 })) }, { monteCarloTrials: 0 });
  assert.equal(s.soldOut, true);
  assert.equal(s.roi, -1);
  const c = analyzePack({ ...pack, prizes: [...pack.prizes, { name: '?', value: NaN, remaining: 10, total: 10 }] }, { monteCarloTrials: 0 });
  assert.equal(c.valueCoverage, 0.5);
});

test('simulateDraws: 결정적이며 손익분기 확률이 이론값에 근접', () => {
  const live = pack.prizes;
  const s1 = simulateDraws(live, 1000, 1, 3, 3000, 7);
  const s2 = simulateDraws(live, 1000, 1, 3, 3000, 7);
  assert.deepEqual(s1.profitProb, s2.profitProb);
  // 1회 뽑기 이득은 A 뽑을 때만: 0.1
  assert.ok(Math.abs(s1.profitProb[0] - 0.1) < 0.03);
  // 3회: A 포함 확률 0.3 (B 3장 = 1500 < 3000 이므로 손실)
  assert.ok(Math.abs(s1.profitProb[2] - 0.3) < 0.03);
});

test('evaluateRules: 임계 진입 시 1회, 유지 중엔 재발화 안 함', () => {
  const a = analyzePack(pack, { monteCarloTrials: 0 });
  const first = evaluateRules(a, null, { roiAbove: 0, buyoutRoiAbove: 0.1 });
  assert.ok(first.some((t) => t.rule === 'new_pack'));
  assert.ok(first.some((t) => t.rule === 'roi_above'));
  assert.ok(first.some((t) => t.rule === 'buyout_roi_above'));
  const again = evaluateRules(a, a, { roiAbove: 0, buyoutRoiAbove: 0.1 });
  assert.equal(again.length, 0);
});

test('evaluateRules: ROI 상승·품절·커버리지 부족', () => {
  const before = analyzePack(pack, { monteCarloTrials: 0 });
  const after = analyzePack({ ...pack, prizes: [pack.prizes[0], { ...pack.prizes[1], remaining: 4 }] }, { monteCarloTrials: 0 });
  const t = evaluateRules(after, before, { roiAbove: 5, buyoutRoiAbove: 5, roiJump: 0.05 });
  assert.ok(t.some((x) => x.rule === 'roi_jump'));
  const sold = analyzePack({ ...pack, prizes: pack.prizes.map((p) => ({ ...p, remaining: 0 })) }, { monteCarloTrials: 0 });
  assert.deepEqual(evaluateRules(sold, before).map((x) => x.rule), ['sold_out']);
  const low = analyzePack({ ...pack, prizes: [...pack.prizes, { name: '?', value: NaN, remaining: 30 }] }, { monteCarloTrials: 0 });
  assert.deepEqual(evaluateRules(low, null).map((x) => x.rule), ['low_coverage']);
});
