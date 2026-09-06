import { pct, fmt } from './ev.js';

export function table(rows, cols) {
  const widths = cols.map((c) => Math.max(strWidth(c.h), ...rows.map((r) => strWidth(String(c.f(r))))));
  const line = (cells) => cells.map((s, i) => pad(String(s), widths[i], cols[i].align)).join('  ');
  return [line(cols.map((c) => c.h)), line(widths.map((w) => '-'.repeat(w))), ...rows.map((r) => line(cols.map((c) => c.f(r))))].join('\n');
}
function strWidth(s) { let w = 0; for (const ch of s) w += /[ᄀ-ᇿ　-〿가-힯＀-￯一-鿿]/.test(ch) ? 2 : 1; return w; }
function pad(s, w, align) { const d = w - strWidth(s); return align === 'r' ? ' '.repeat(d) + s : s + ' '.repeat(d); }

export function summaryTable(analyses) {
  const rows = [...analyses].sort((a, b) => b.roi - a.roi);
  return table(rows, [
    { h: '팩', f: (a) => a.name.slice(0, 28) },
    { h: '가격', f: (a) => fmt(a.price), align: 'r' },
    { h: '잔여', f: (a) => `${a.remaining}/${a.totalInitial || '?'}`, align: 'r' },
    { h: '순EV', f: (a) => fmt(a.evNet), align: 'r' },
    { h: 'ROI', f: (a) => pct(a.roi), align: 'r' },
    { h: '이득확률', f: (a) => pct(a.profitProb1), align: 'r' },
    { h: '싹쓸이ROI', f: (a) => (a.buyout ? pct(a.buyout.roi) : '-'), align: 'r' },
    { h: '최고가(잔여)', f: (a) => (a.topPrize ? `${fmt(a.topPrize.value)}(${a.topPrize.remaining})` : '-'), align: 'r' },
    { h: '커버', f: (a) => pct(a.valueCoverage), align: 'r' },
  ]);
}

export function detailReport(a) {
  const head = [
    `# ${a.name}`,
    `가격 ${fmt(a.price)} · 잔여 ${a.remaining}/${a.totalInitial || '?'} · 총기대값 ${fmt(a.evGross)} · 순기대값 ${fmt(a.evNet)} (반영 배율 ${a.netMult ?? 1})`,
    `ROI ${pct(a.roi)} · 1회 순이득 ${fmt(a.edge)} · 이득 카드 ${a.profitCards}장 (${pct(a.profitProb1)}) · 시세 커버리지 ${pct(a.valueCoverage)}`,
    a.buyout ? `싹쓸이: ${a.remaining}장 × ${fmt(a.price)} = ${fmt(a.buyout.cost)} → 가치 ${fmt(a.buyout.value)} (ROI ${pct(a.buyout.roi)}${a.buyout.lastOneValue ? `, 라스트원 ${fmt(a.buyout.lastOneValue)} 포함` : ''})` : '',
    a.bestK ? `권장 뽑기 수(손익분기 확률 최대): ${a.bestK}회` : '',
    '',
    '## 잔여 카드',
    table(a.prizes, [
      { h: '카드', f: (p) => p.name.slice(0, 30) },
      { h: '등급', f: (p) => p.tier ?? '' },
      { h: '시세', f: (p) => fmt(p.value), align: 'r' },
      { h: '순가치', f: (p) => fmt(p.netValue), align: 'r' },
      { h: '잔여', f: (p) => `${p.remaining}/${p.total ?? '?'}`, align: 'r' },
      { h: '확률', f: (p) => pct(p.prob), align: 'r' },
      { h: 'EV기여', f: (p) => fmt(p.evShare), align: 'r' },
      { h: '이득', f: (p) => (p.profitable ? '★' : '') },
    ]),
    '',
    '## k회 뽑기',
    table(a.kCurve.filter((c) => c.k <= 10 || c.k % 5 === 0), [
      { h: 'k', f: (c) => c.k, align: 'r' },
      { h: '비용', f: (c) => fmt(c.cost), align: 'r' },
      { h: '기대가치', f: (c) => fmt(c.ev), align: 'r' },
      { h: '이득카드≥1', f: (c) => pct(c.hitProfitCard), align: 'r' },
      { h: '최고가≥1', f: (c) => pct(c.hitTop), align: 'r' },
      { h: '손익분기P', f: (c) => (c.profitProb == null ? '-' : pct(c.profitProb)), align: 'r' },
      { h: 'P10', f: (c) => (c.p10 == null ? '-' : fmt(c.p10)), align: 'r' },
      { h: 'P50', f: (c) => (c.p50 == null ? '-' : fmt(c.p50)), align: 'r' },
      { h: 'P90', f: (c) => (c.p90 == null ? '-' : fmt(c.p90)), align: 'r' },
    ]),
  ];
  return head.filter((l) => l !== null).join('\n');
}
