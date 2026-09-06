import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizePack, extractPackList, isLimitedPack, toNumber, findPrizeArray } from '../src/normalize.js';
import { extractJsonFromHtml } from '../src/adapters/kado.js';

test('toNumber: 문자열 통화 파싱', () => {
  assert.equal(toNumber('12,000원'), 12000);
  assert.equal(toNumber(' 3 500 P'), 3500);
  assert.ok(Number.isNaN(toNumber('abc')));
});

test('normalizePack: 키 이름 자동 추론', () => {
  const raw = {
    packId: 7, title: '리미티드 팩', drawPrice: '5,000', saleStatus: 'ON_SALE',
    cardList: [
      { card_name: 'X', estimated_price: 100000, remain_count: 1, total_count: 2, grade: 'SAR' },
      { card: { name: 'Y', marketPrice: 200 }, stock: 5 },
    ],
  };
  const s = normalizePack(raw);
  assert.equal(s.id, '7'); assert.equal(s.price, 5000); assert.equal(s.status, 'ON_SALE');
  assert.equal(s.prizes.length, 2);
  assert.deepEqual(s.prizes[0], { name: 'X', value: 100000, remaining: 1, total: 2, tier: 'SAR' });
  assert.equal(s.prizes[1].name, 'Y'); assert.equal(s.prizes[1].value, 200); assert.equal(s.prizes[1].remaining, 5); assert.equal(s.prizes[1].total, 5);
  assert.equal(s.remaining, 6);
});

test('normalizePack: 명시 매핑 + overrides + multiplier', () => {
  const raw = { meta: { code: 'a1', label: 'L' }, sale: { won: 3000 }, detail: { cards: [{ nm: 'C', px: 10, left: 2, cap: 4 }] } };
  const map = { id: 'meta.code', name: 'meta.label', price: 'sale.won', prizes: 'detail.cards', prize: { name: 'nm', value: 'px', remaining: 'left', total: 'cap' } };
  const s = normalizePack(raw, map, { valueOverrides: { C: 50 }, valueMultiplier: 2 });
  assert.equal(s.id, 'a1'); assert.equal(s.price, 3000);
  assert.deepEqual(s.prizes[0], { name: 'C', value: 100, remaining: 2, total: 4, tier: null });
});

test('extractPackList / isLimitedPack', () => {
  const data = { result: { content: [{ id: 1, name: '리미티드 A', type: 'NORMAL' }, { id: 2, name: 'B', isLimited: true }, { id: 3, name: 'C' }] } };
  const list = extractPackList(data);
  assert.equal(list.length, 3);
  assert.deepEqual(list.filter((r) => isLimitedPack(r)).map((r) => r.id), [1, 2]);
  assert.equal(extractPackList(data, 'result.content').length, 3);
  assert.equal(isLimitedPack(list[2], false), true);
});

test('findPrizeArray: 중첩 탐색', () => {
  assert.equal(findPrizeArray({ data: { prizes: [{ a: 1 }] } }).length, 1);
  assert.equal(findPrizeArray({ foo: [{ remainCount: 1 }] }).length, 1);
  assert.equal(findPrizeArray({ foo: [1, 2] }), undefined);
});

test('extractJsonFromHtml: __NEXT_DATA__', () => {
  const html = `<html><script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{"packs":[{"id":1}]}}}</script></html>`;
  assert.deepEqual(extractJsonFromHtml(html), { packs: [{ id: 1 }] });
  assert.throws(() => extractJsonFromHtml('<html></html>'));
});
