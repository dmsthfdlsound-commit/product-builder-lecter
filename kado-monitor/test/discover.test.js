import { test } from 'node:test';
import assert from 'node:assert/strict';
import { scoreResponse, suggestConfig, templateDetailUrl } from '../src/discover.js';

test('templateDetailUrl: 호스트 숫자는 보존하고 id 조각만 치환', () => {
  assert.equal(templateDetailUrl('http://127.0.0.1:8799/api/v1/packs/lp-1001', ['lp-1001']), 'http://127.0.0.1:8799/api/v1/packs/{id}');
  assert.equal(templateDetailUrl('https://kado.trade/api/packs/12345/detail', []), 'https://kado.trade/api/packs/{id}/detail');
  assert.equal(templateDetailUrl('https://kado.trade/api/pack?packId=77', ['77']), 'https://kado.trade/api/pack?packId={id}');
  assert.equal(templateDetailUrl('https://kado.trade/api/limited', []), 'https://kado.trade/api/{id}');
});

test('scoreResponse / suggestConfig', () => {
  const list = scoreResponse('https://k/api/packs', { data: [{ id: 1, name: '리미티드', price: 1, remaining: 3 }] });
  const detail = scoreResponse('https://k/api/packs/1', { data: { prizes: [{ name: 'a', value: 1, remaining: 1 }] } });
  const noise = scoreResponse('https://k/api/me', { user: { name: 'x' } });
  assert.ok(list.score > noise.score && detail.score > noise.score);
  const cfg = suggestConfig([
    { url: 'https://k/api/packs/1', ...detail, prizeKeys: ['name'] },
    { url: 'https://k/api/packs', ...list, sampleKeys: ['id'], sampleIds: [1] },
    { url: 'https://k/api/me', ...noise },
  ]);
  assert.equal(cfg.listUrl, 'https://k/api/packs');
  assert.equal(cfg.detailUrl, 'https://k/api/packs/{id}');
});
