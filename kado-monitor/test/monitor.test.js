import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runCycle, createMonitorState } from '../src/monitor.js';
import { createKadoAdapter } from '../src/adapters/kado.js';
import { createNotifier } from '../src/notify.js';

const mkPack = (remB) => ({ id: 'p1', name: 'P1', price: 1000, prizes: [{ name: 'A', value: 10000, remaining: 1, total: 1 }, { name: 'B', value: 500, remaining: remB, total: 19 }] });

test('runCycle: 알림 발화, 쿨다운, 히스토리, 사라진 팩 처리', async () => {
  let packs = [mkPack(9)];
  const adapter = { name: 't', fetchPacks: async () => packs };
  const sent = [];
  const notifier = { send: async (m) => sent.push(m) };
  const state = createMonitorState();
  let now = 1_000_000;
  const ctx = { adapter, notifier, state, config: { analysis: { monteCarloTrials: 0 }, rules: { roiAbove: 0, buyoutRoiAbove: 0.1 }, alertCooldownSec: 60 }, now: () => now };

  let r = await runCycle(ctx);
  assert.equal(r.ok, true); assert.equal(r.fired.length, 1); assert.equal(sent.length, 1);
  assert.ok(sent[0].lines.some((l) => l.includes('ROI')));

  now += 10_000; r = await runCycle(ctx);
  assert.equal(r.fired.length, 0, '임계 유지 중엔 재발화 없음');
  assert.equal(state.packs.get('p1').history.length, 2);

  // 하위 카드가 빠져 ROI 급등 → roi_jump (info) 발화
  packs = [mkPack(3)]; now += 10_000; r = await runCycle(ctx);
  assert.equal(r.fired.length, 1); assert.equal(sent.at(-1).level, 'info');

  packs = []; now += 10_000; await runCycle(ctx);
  assert.equal(state.packs.get('p1').gone, true);
});

test('runCycle: 어댑터 오류는 상태에 기록되고 루프는 계속', async () => {
  const state = createMonitorState();
  const r = await runCycle({ adapter: { name: 'x', fetchPacks: async () => { throw new Error('boom'); } }, notifier: { send: async () => {} }, state, config: {} });
  assert.equal(r.ok, false); assert.equal(state.errors, 1); assert.equal(state.lastError.msg, 'boom');
});

test('kado adapter: 목록 + 상세 병합, HTML 폴백', async () => {
  const calls = [];
  const fetch = async (url) => {
    calls.push(url);
    const json = (b) => ({ ok: true, status: 200, headers: { get: () => 'application/json' }, text: async () => JSON.stringify(b) });
    if (url.endsWith('/api/packs')) return json({ data: [{ id: 1, name: '리미티드 X', price: 1000 }, { id: 2, name: '일반', price: 500 }] });
    if (url.endsWith('/api/packs/1')) return json({ data: { prizes: [{ name: 'A', marketPrice: 5000, remaining: 2, total: 4 }] } });
    return { ok: true, status: 200, headers: { get: () => 'text/html' }, text: async () => '<script id="__NEXT_DATA__">{"props":{"pageProps":{"items":[{"id":9,"name":"리미티드 H","price":1,"prizes":[{"name":"Z","value":1,"remaining":1}]}]}}}</script>' };
  };
  const a = createKadoAdapter({ listUrl: '/api/packs', detailUrl: '/api/packs/{id}' }, { fetch });
  const packs = await a.fetchPacks();
  assert.equal(packs.length, 1);
  assert.equal(packs[0].name, '리미티드 X');
  assert.equal(packs[0].prizes[0].remaining, 2);
  assert.ok(calls.includes('https://kado.trade/api/packs/1'));

  const h = createKadoAdapter({ listUrl: '/limited' }, { fetch });
  const hp = await h.fetchPacks();
  assert.equal(hp[0].name, '리미티드 H');
});

test('notifier: 채널 전송 및 실패 격리', async () => {
  const posted = [];
  const fetch = async (url, init) => { posted.push({ url, body: JSON.parse(init.body) }); return { ok: !url.includes('bad') , status: url.includes('bad') ? 500 : 200 }; };
  const logs = [];
  const n = createNotifier([{ type: 'discord', url: 'https://d/ok' }, { type: 'telegram', token: 'T', chatId: '1' }, { type: 'webhook', url: 'https://bad' }], { fetch, log: (s) => logs.push(s) });
  await n.send({ title: 'T', level: 'alert', lines: ['a'] });
  assert.equal(posted.length, 3);
  assert.ok(posted[0].body.content.includes('[ALERT] T'));
  assert.ok(posted[1].url.includes('api.telegram.org/botT'));
  assert.ok(logs.some((l) => l.includes('알림 실패(webhook)')));
});
