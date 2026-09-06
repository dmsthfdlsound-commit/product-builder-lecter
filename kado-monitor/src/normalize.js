/**
 * 임의 형태의 API 응답 → 표준 팩 스냅샷 변환.
 *
 * 두 가지 모드:
 *  1) 명시 매핑: config.map 에 점(.) 경로를 지정
 *  2) 자동 추론: 키 이름 동의어 사전으로 필드를 찾음 (API 구조를 모를 때)
 *
 * 표준 스냅샷:
 * { id, name, price, currency?, url?, remaining?, total?, status?,
 *   prizes: [{ name, value, remaining, total, tier? }], lastOne?: {name, value} }
 */

const SYN = {
  id: ['id', 'packId', 'pack_id', 'productId', 'product_id', 'uid', 'seq', 'no', 'code', 'slug'],
  name: ['name', 'title', 'packName', 'pack_name', 'productName', 'product_name', 'cardName', 'card_name', 'label'],
  price: ['price', 'unitPrice', 'unit_price', 'drawPrice', 'draw_price', 'amount', 'cost', 'point', 'points', 'salePrice', 'sale_price'],
  remaining: ['remaining', 'remain', 'remainCount', 'remain_count', 'remainingCount', 'remaining_count', 'stock', 'stockCount', 'stock_count', 'left', 'leftCount', 'left_count', 'quantity', 'qty', 'availableCount', 'available_count', 'restCount', 'rest_count', 'remainQty', 'remain_qty'],
  total: ['total', 'totalCount', 'total_count', 'count', 'max', 'maxCount', 'max_count', 'initialCount', 'initial_count', 'supply', 'totalQty', 'total_qty', 'quantityTotal'],
  value: ['value', 'marketPrice', 'market_price', 'referencePrice', 'reference_price', 'refPrice', 'estimatedPrice', 'estimated_price', 'estimatePrice', 'cardPrice', 'card_price', 'sellPrice', 'sell_price', 'buybackPrice', 'buyback_price', 'pointValue', 'point_value', 'worth', 'priceKrw', 'price_krw', 'marketValue', 'market_value', 'lastPrice', 'avgPrice'],
  tier: ['tier', 'grade', 'rank', 'rarity', 'rarityName', 'prizeRank', 'level', 'class'],
  prizes: ['prizes', 'cards', 'items', 'rewards', 'pool', 'contents', 'lineup', 'lineups', 'prizeList', 'prize_list', 'cardList', 'card_list', 'packCards', 'pack_cards', 'results', 'entries', 'products'],
  status: ['status', 'state', 'saleStatus', 'sale_status', 'isSoldOut', 'soldOut', 'sold_out'],
  url: ['url', 'link', 'href', 'detailUrl', 'detail_url'],
};

export function getPath(obj, path) {
  if (path == null || path === '') return obj;
  return String(path).split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);
}

/** 키 동의어로 값 찾기 (얕은 탐색, 대소문자 무시) */
export function findKey(obj, kind, exclude = []) {
  if (!obj || typeof obj !== 'object') return undefined;
  const keys = Object.keys(obj);
  const lower = new Map(keys.map((k) => [k.toLowerCase(), k]));
  for (const s of SYN[kind]) {
    const k = lower.get(s.toLowerCase());
    if (k && !exclude.includes(k) && obj[k] != null) return obj[k];
  }
  return undefined;
}

export function toNumber(v) {
  if (v == null) return NaN;
  if (typeof v === 'number') return v;
  if (typeof v === 'boolean') return v ? 1 : 0;
  const s = String(v).replace(/[,\s원₩P]/g, '');
  const n = Number(s);
  return Number.isFinite(n) ? n : NaN;
}

/** prize 배열 후보 찾기: 객체 배열이면서 항목에 이름/수량/가치 비슷한 키가 있는 것 */
export function findPrizeArray(obj) {
  if (!obj || typeof obj !== 'object') return undefined;
  const direct = findKey(obj, 'prizes');
  if (Array.isArray(direct) && direct.length && typeof direct[0] === 'object') return direct;
  // 한 단계 더 깊이 탐색 (data.prizes 등)
  for (const v of Object.values(obj)) {
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      const found = findKey(v, 'prizes');
      if (Array.isArray(found) && found.length && typeof found[0] === 'object') return found;
    }
    if (Array.isArray(v) && v.length && typeof v[0] === 'object' && findKey(v[0], 'remaining') !== undefined) return v;
  }
  return undefined;
}

function normalizePrize(raw, map = {}, opts = {}) {
  const pick = (kind) => (map[kind] ? getPath(raw, map[kind]) : findKey(raw, kind));
  const name = String(pick('name') ?? raw.card?.name ?? raw.product?.name ?? '?');
  let value = toNumber(pick('value'));
  if (!Number.isFinite(value) && raw.card) value = toNumber(findKey(raw.card, 'value'));
  if (!Number.isFinite(value) && raw.product) value = toNumber(findKey(raw.product, 'value'));
  if (opts.valueOverrides && opts.valueOverrides[name] != null) value = toNumber(opts.valueOverrides[name]);
  if (Number.isFinite(value) && opts.valueMultiplier) value *= opts.valueMultiplier;
  const remaining = toNumber(pick('remaining'));
  const total = toNumber(pick('total'));
  const tier = pick('tier');
  return {
    name,
    value: Number.isFinite(value) ? value : NaN,
    remaining: Number.isFinite(remaining) ? remaining : (Number.isFinite(total) ? total : 0),
    total: Number.isFinite(total) ? total : (Number.isFinite(remaining) ? remaining : null),
    tier: tier == null ? null : String(tier),
  };
}

/**
 * 팩 하나를 정규화.
 * @param raw   API 원본 객체
 * @param map   { id, name, price, remaining, total, status, url, prizes, prize: { name, value, remaining, total, tier } }
 * @param opts  { valueOverrides, valueMultiplier, priceMultiplier }
 */
export function normalizePack(raw, map = {}, opts = {}) {
  const pick = (kind) => (map[kind] ? getPath(raw, map[kind]) : findKey(raw, kind));
  const prizesRaw = map.prizes ? getPath(raw, map.prizes) : findPrizeArray(raw);
  const prizes = Array.isArray(prizesRaw) ? prizesRaw.map((p) => normalizePrize(p, map.prize ?? {}, opts)) : [];
  let price = toNumber(pick('price'));
  if (opts.priceMultiplier) price *= opts.priceMultiplier;
  const remaining = toNumber(pick('remaining'));
  const total = toNumber(pick('total'));
  const status = pick('status');
  const lastOneRaw = map.lastOne ? getPath(raw, map.lastOne) : raw.lastOne ?? raw.last_one ?? raw.lastOnePrize ?? null;
  const lastOne = lastOneRaw && typeof lastOneRaw === 'object'
    ? { name: String(findKey(lastOneRaw, 'name') ?? '라스트원'), value: toNumber(findKey(lastOneRaw, 'value')) || 0 }
    : null;
  return {
    id: String(pick('id') ?? pick('name') ?? ''),
    name: String(pick('name') ?? pick('id') ?? '이름없음'),
    price: Number.isFinite(price) ? price : 0,
    remaining: Number.isFinite(remaining) ? remaining : prizes.reduce((a, p) => a + p.remaining, 0),
    total: Number.isFinite(total) ? total : null,
    status: status == null ? null : String(status),
    url: pick('url') ?? null,
    prizes,
    lastOne,
  };
}

/** 응답에서 팩 목록 배열 찾기 */
export function extractPackList(data, listPath) {
  if (listPath) {
    const v = getPath(data, listPath);
    return Array.isArray(v) ? v : [];
  }
  if (Array.isArray(data)) return data;
  for (const key of ['data', 'result', 'results', 'items', 'list', 'packs', 'products', 'content', 'rows', 'payload']) {
    const v = data?.[key];
    if (Array.isArray(v)) return v;
    if (v && typeof v === 'object') {
      const inner = extractPackList(v);
      if (inner.length) return inner;
    }
  }
  return [];
}

/** 리미티드 팩만 필터 (이름/타입/플래그에 limited·리미티드 포함) */
export function isLimitedPack(raw, filter) {
  if (filter === false) return true;
  const re = filter instanceof RegExp ? filter : new RegExp(filter || 'limit|리미티드|한정', 'i');
  const hay = JSON.stringify({
    n: findKey(raw, 'name'), t: raw.type ?? raw.packType ?? raw.pack_type ?? raw.category ?? raw.kind,
    f: raw.isLimited ?? raw.is_limited ?? raw.limited,
  });
  return re.test(hay) || raw.isLimited === true || raw.is_limited === true || raw.limited === true;
}
