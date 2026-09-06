/**
 * KADO(kado.trade) 어댑터.
 *
 * kado.trade 의 내부 API 는 공개 문서가 없으므로 다음 순서로 동작한다.
 *  1) config.listUrl / config.detailUrl 이 있으면 JSON API 를 직접 호출 (discover 로 찾은 값)
 *  2) detailUrl 이 없으면 목록 응답에 prize 배열이 포함되어 있다고 가정
 *  3) JSON 이 아니면 HTML 에서 __NEXT_DATA__ / __NUXT_DATA__ / 인라인 JSON 을 추출해 시도
 *
 * 필드 이름은 normalize.js 의 자동 추론 또는 config.map 매핑을 따른다.
 */
import { extractPackList, normalizePack, isLimitedPack, getPath } from '../normalize.js';

const DEFAULT_HEADERS = {
  'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36',
  accept: 'application/json, text/plain, */*',
  'accept-language': 'ko-KR,ko;q=0.9',
};

export function createKadoAdapter(config, deps = {}) {
  const fetchImpl = deps.fetch ?? globalThis.fetch;
  const {
    baseUrl = 'https://kado.trade',
    listUrl,
    detailUrl,           // "{id}" 치환
    listPath,
    detailPath,          // 상세 응답에서 팩 객체 경로
    headers = {},
    map = {},
    limitedFilter = 'limit|리미티드|한정',
    timeoutMs = 15000,
    detailConcurrency = 4,
    ...opts
  } = config;

  const hdrs = { ...DEFAULT_HEADERS, ...headers };

  async function request(url) {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      const res = await fetchImpl(url, { headers: hdrs, signal: ctrl.signal });
      if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
      const ct = res.headers.get?.('content-type') ?? '';
      const text = await res.text();
      if (/json/i.test(ct) || /^\s*[\[{]/.test(text)) return JSON.parse(text);
      return extractJsonFromHtml(text);
    } finally {
      clearTimeout(t);
    }
  }

  function resolve(u) {
    return /^https?:/i.test(u) ? u : baseUrl.replace(/\/$/, '') + '/' + u.replace(/^\//, '');
  }

  return {
    name: 'kado',
    async fetchPacks() {
      if (!listUrl) throw new Error('config.listUrl 이 없습니다. `kado-monitor discover` 로 API 를 찾은 뒤 설정하세요.');
      const listData = await request(resolve(listUrl));
      const rawList = extractPackList(listData, listPath).filter((r) => isLimitedPack(r, limitedFilter));
      if (!detailUrl) return rawList.map((r) => normalizePack(r, map, opts));

      const out = [];
      let i = 0;
      const workers = Array.from({ length: Math.max(1, detailConcurrency) }, async () => {
        while (i < rawList.length) {
          const raw = rawList[i++];
          const id = map.id ? getPath(raw, map.id) : normalizePack(raw, map, opts).id;
          try {
            const d = await request(resolve(detailUrl.replace('{id}', encodeURIComponent(id))));
            const detail = detailPath ? getPath(d, detailPath) : (d?.data ?? d?.result ?? d);
            out.push(normalizePack({ ...raw, ...detail }, map, opts));
          } catch (e) {
            out.push({ ...normalizePack(raw, map, opts), error: String(e.message ?? e) });
          }
        }
      });
      await Promise.all(workers);
      return out;
    },
  };
}

/** HTML 문서에서 프레임워크가 심어둔 JSON 상태 추출 */
export function extractJsonFromHtml(html) {
  const next = html.match(/<script[^>]+id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (next) {
    const j = JSON.parse(next[1]);
    return j.props?.pageProps ?? j.props ?? j;
  }
  const nuxt = html.match(/<script[^>]+id="__NUXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (nuxt) return JSON.parse(nuxt[1]);
  const win = html.match(/window\.__(?:INITIAL_STATE|NUXT|PRELOADED_STATE|DATA)__\s*=\s*(\{[\s\S]*?\})\s*;?\s*<\/script>/);
  if (win) return JSON.parse(win[1]);
  // Next.js app router: self.__next_f.push([1,"..."]) 조각 안의 JSON 배열/객체 찾기
  const chunks = [...html.matchAll(/self\.__next_f\.push\(\[1,"([\s\S]*?)"\]\)/g)].map((m) => m[1]);
  if (chunks.length) {
    const joined = chunks.join('').replace(/\\"/g, '"').replace(/\\n/g, '');
    const arrays = [...joined.matchAll(/\[\{"[^"]+":[\s\S]*?\}\]/g)].map((m) => { try { return JSON.parse(m[0]); } catch { return null; } }).filter(Boolean);
    if (arrays.length) return { items: arrays.sort((a, b) => b.length - a.length)[0] };
  }
  throw new Error('응답이 JSON 도 아니고 HTML 에서 상태 JSON 도 찾지 못했습니다.');
}
