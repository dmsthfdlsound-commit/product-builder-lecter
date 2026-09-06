/**
 * API 탐지기: 실제 브라우저(Playwright/Chromium)로 kado.trade 를 열고
 * 페이지가 호출하는 JSON 응답을 전부 캡처한 뒤, 팩/카드/잔여수량처럼 보이는
 * 응답에 점수를 매겨 config 후보를 출력한다.
 *
 * 사용:  npx playwright install chromium  (최초 1회)
 *        node bin/kado-monitor.js discover --headed --url https://kado.trade/
 *   --headed 로 실행하면 창이 뜨므로 직접 로그인/리미티드 팩 메뉴 클릭 후
 *   터미널에서 Enter 를 누르면 캡처를 종료한다.
 *
 * 결과: discover-out/<n>.json (원본 응답), discover-out/report.json (후보 랭킹), 콘솔에 config 제안.
 */
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { findPrizeArray, findKey, extractPackList } from './normalize.js';

const KEYWORDS = /pack|limited|limit|prize|remain|stock|card|draw|gacha|oripa|lottery|lineup|reward|quantity|qty|left/i;

/** JSON 응답 하나를 채점: 리미티드 팩 데이터일 가능성 */
export function scoreResponse(url, body) {
  let score = 0;
  const reasons = [];
  if (KEYWORDS.test(url)) { score += 2; reasons.push('url 키워드'); }
  const text = JSON.stringify(body);
  if (/limit|리미티드|한정/i.test(text)) { score += 3; reasons.push('limited 문자열'); }
  const list = extractPackList(body);
  if (list.length) {
    score += 1; reasons.push(`목록 ${list.length}건`);
    const s = list[0];
    if (findKey(s, 'price') !== undefined) { score += 2; reasons.push('price'); }
    if (findKey(s, 'remaining') !== undefined) { score += 3; reasons.push('remaining'); }
    if (findPrizeArray(s)) { score += 4; reasons.push('prize 배열 내포'); }
  }
  const prizes = findPrizeArray(body) ?? findPrizeArray(body?.data ?? {});
  if (prizes) {
    score += 3; reasons.push(`prize 배열 ${prizes.length}`);
    const p = prizes[0];
    if (findKey(p, 'remaining') !== undefined) { score += 3; reasons.push('prize.remaining'); }
    if (findKey(p, 'value') !== undefined) { score += 3; reasons.push('prize.value'); }
  }
  return { score, reasons };
}

export function suggestConfig(ranked) {
  const list = ranked.find((r) => r.reasons.some((x) => x.startsWith('목록')));
  const detail = ranked.find((r) => r.reasons.some((x) => x.startsWith('prize 배열')) && r !== list);
  const cfg = { source: 'kado', listUrl: list?.url ?? 'TODO', intervalSec: 30 };
  if (detail) cfg.detailUrl = templateDetailUrl(detail.url, list?.sampleIds ?? []);
  if (list?.sampleKeys) cfg._listItemKeys = list.sampleKeys;
  if (detail?.prizeKeys) cfg._prizeKeys = detail.prizeKeys;
  return cfg;
}

/** 상세 URL 의 경로에서 팩 id 에 해당하는 조각을 {id} 로 치환 (호스트/포트는 건드리지 않음) */
export function templateDetailUrl(url, sampleIds = []) {
  let u;
  try { u = new URL(url); } catch { return url; }
  const ids = sampleIds.map(String).filter(Boolean);
  let inQuery = false;
  for (const [k, v] of [...u.searchParams]) if (ids.includes(v)) { u.searchParams.set(k, '{id}'); inQuery = true; }
  if (inQuery) return u.toString().replace(/%7Bid%7D/g, '{id}');
  const segs = u.pathname.split('/');
  let idx = -1;
  for (let i = segs.length - 1; i >= 0 && idx < 0; i--) if (ids.includes(decodeURIComponent(segs[i]))) idx = i;
  if (idx < 0) for (let i = segs.length - 1; i >= 0 && idx < 0; i--) if (/^\d+$/.test(segs[i]) || /^[\w-]*\d[\w-]*$/.test(segs[i])) idx = i;
  if (idx < 0) idx = segs.length - 1;
  segs[idx] = '{id}';
  u.pathname = segs.join('/');
  return u.toString().replace(/%7Bid%7D/g, '{id}');
}

export async function runDiscover({ url = 'https://kado.trade/', headed = false, outDir = 'discover-out', waitMs = 20000, storageState } = {}) {
  let chromium;
  try { ({ chromium } = await import('playwright')); }
  catch { throw new Error('playwright 가 없습니다. `npm i -D playwright && npx playwright install chromium` 후 다시 실행하세요.'); }

  await mkdir(outDir, { recursive: true });
  const browser = await chromium.launch({ headless: !headed });
  const context = await browser.newContext({ locale: 'ko-KR', storageState });
  const page = await context.newPage();
  const captured = [];

  page.on('response', async (res) => {
    try {
      const ct = res.headers()['content-type'] ?? '';
      if (!/json/i.test(ct)) return;
      const body = await res.json();
      const u = res.url();
      const idx = captured.length + 1;
      const file = join(outDir, `${String(idx).padStart(3, '0')}.json`);
      await writeFile(file, JSON.stringify({ url: u, status: res.status(), body }, null, 2));
      const { score, reasons } = scoreResponse(u, body);
      const list = extractPackList(body);
      const prizes = findPrizeArray(body) ?? (list[0] && findPrizeArray(list[0]));
      captured.push({ idx, url: u, file, score, reasons, sampleKeys: list[0] ? Object.keys(list[0]) : null, sampleIds: list.slice(0, 50).map((it) => findKey(it, 'id')).filter((v) => v != null), prizeKeys: prizes?.[0] ? Object.keys(prizes[0]) : null });
      if (score >= 5) console.log(`[후보 ${score}] ${u}  (${reasons.join(', ')})`);
    } catch { /* non-json */ }
  });

  console.log(`열기: ${url}`);
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  // 리미티드 팩 메뉴가 있으면 자동 클릭 시도
  for (const t of ['리미티드', 'Limited', 'LIMITED', '한정']) {
    const el = page.getByText(t, { exact: false }).first();
    if (await el.count().catch(() => 0)) { await el.click({ timeout: 3000 }).catch(() => {}); break; }
  }
  if (headed) {
    console.log('브라우저에서 로그인/리미티드 팩 페이지·상세를 열어보세요. 끝나면 이 터미널에서 Enter.');
    await new Promise((r) => process.stdin.once('data', r));
    await context.storageState({ path: join(outDir, 'storageState.json') }).catch(() => {});
  } else {
    await page.waitForTimeout(waitMs);
  }
  await browser.close();

  const ranked = captured.sort((a, b) => b.score - a.score);
  await writeFile(join(outDir, 'report.json'), JSON.stringify(ranked, null, 2));
  const cfg = suggestConfig(ranked);
  console.log(`\n캡처 ${captured.length}건 → ${outDir}/report.json`);
  console.log('추천 config (검토 후 config.json 에 반영):\n' + JSON.stringify(cfg, null, 2));
  return { ranked, cfg };
}
