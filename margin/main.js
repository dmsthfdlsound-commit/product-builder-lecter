/* ==========================================================
   셀러 마진 계산기 — main.js
   서버 없음. 네트워크 요청 없음. 입력값은 이 브라우저에만 남습니다.
   ========================================================== */

'use strict';

const LS_KEY = 'sellermargin:v1';

const DEFAULTS = {
    channel: '5.85',
    feeRate: 5.85,
    price: 19900,
    volume: 100,
    cost: 7000,
    shipping: 3000,
    packing: 300,
    adRate: 5,
    etc: 0,
    taxType: 'general',
    returnRate: 3,
    fixedCost: 0,
    targetMargin: 20,
};

/* 금액 칸(원 단위)과 비율 칸(%)을 나눠 서식을 다르게 적용합니다. */
const MONEY_FIELDS = ['price', 'volume', 'cost', 'shipping', 'packing', 'etc', 'fixedCost'];
const RATE_FIELDS  = ['feeRate', 'adRate', 'returnRate', 'targetMargin'];

const $ = (id) => document.getElementById(id);

/* ── 숫자 유틸 ──────────────────────────────────── */

function parseNum(raw) {
    if (typeof raw === 'number') return isFinite(raw) ? raw : 0;
    const n = parseFloat(String(raw ?? '').replace(/[^0-9.\-]/g, ''));
    return isFinite(n) ? n : 0;
}

const won      = (n) => `${Math.round(n).toLocaleString('ko-KR')}원`;
const pct      = (n) => `${(Math.round(n * 10) / 10).toLocaleString('ko-KR')}%`;
const intComma = (n) => Math.round(n).toLocaleString('ko-KR');

/* ── 손익 모델 ──────────────────────────────────────
   기준: "주문 1건 접수" — 그중 반품률만큼은 반품된다고 봅니다.
   반품 건은 매출과 수수료가 사라지고, 왕복 택배비와 재포장비만 남습니다.
   상품 자체는 되팔 수 있다고 가정하므로 매입원가는 소진되지 않습니다.
   광고비는 반품되더라도 이미 집행된 것으로 봅니다.
   ------------------------------------------------- */

function model(input, priceOverride, costOverride) {
    const P = priceOverride != null ? priceOverride : input.price;
    const C = costOverride  != null ? costOverride  : input.cost;

    const f = input.feeRate / 100;
    const a = input.adRate / 100;
    const r = Math.min(Math.max(input.returnRate / 100, 0), 1);

    const revenue = P * (1 - r);

    const items = [
        { key: 'cost', name: '매입원가',   color: 'var(--c-cost)', amount: C * (1 - r) },
        { key: 'fee',  name: '판매수수료', color: 'var(--c-fee)',  amount: P * f * (1 - r) },
        { key: 'ship', name: '택배비',     color: 'var(--c-ship)', amount: input.shipping * (1 + r) },
        { key: 'pack', name: '포장·부자재', color: 'var(--c-pack)', amount: input.packing },
        { key: 'ad',   name: '광고비',     color: 'var(--c-ad)',   amount: P * a },
        { key: 'etc',  name: '기타 비용',   color: 'var(--c-etc)',  amount: input.etc * (1 - r) },
    ];

    const totalCost = items.reduce((sum, it) => sum + it.amount, 0);

    // 일반과세자: 매출세액 - 매입세액. 부가세 포함가 기준이라 1/11.
    const vat = input.taxType === 'general' ? (revenue - totalCost) / 11 : 0;

    const net = revenue - totalCost - vat;
    const margin = revenue > 0 ? (net / revenue) * 100 : 0;

    return { price: P, revenue, items, totalCost, vat, net, margin };
}

/** 판매가가 오를수록 마진율도 오릅니다(고정비가 희석되므로).
    단조 증가라 이분탐색으로 목표 마진율 판매가를 찾습니다. */
function solvePrice(input, targetMarginPct) {
    let lo = 1;
    let hi = 1e9;

    if (model(input, hi).margin < targetMarginPct) return null; // 어떤 가격으로도 도달 불가

    for (let i = 0; i < 100; i++) {
        const mid = (lo + hi) / 2;
        if (model(input, mid).margin < targetMarginPct) lo = mid;
        else hi = mid;
    }
    return hi;
}

/** 매입원가가 오를수록 마진율은 떨어집니다. 목표 마진율을 지키는 최대 원가. */
function solveMaxCost(input, targetMarginPct) {
    if (model(input, null, 0).margin < targetMarginPct) return null; // 원가 0원이어도 불가

    let lo = 0;
    let hi = input.price * 5;

    for (let i = 0; i < 100; i++) {
        const mid = (lo + hi) / 2;
        if (model(input, null, mid).margin >= targetMarginPct) lo = mid;
        else hi = mid;
    }
    return lo;
}

/* ── 입력 읽기 / 쓰기 ───────────────────────────── */

function readInput() {
    const input = { taxType: $('taxType').value, channel: $('channel').value };
    MONEY_FIELDS.forEach((k) => { input[k] = parseNum($(k).value); });
    RATE_FIELDS.forEach((k)  => { input[k] = parseNum($(k).value); });
    return input;
}

function writeInput(input) {
    $('channel').value = input.channel;
    $('taxType').value = input.taxType;
    MONEY_FIELDS.forEach((k) => { $(k).value = intComma(input[k]); });
    RATE_FIELDS.forEach((k)  => { $(k).value = String(input[k]); });
}

/* ── 렌더링 ─────────────────────────────────────── */

function render() {
    const input = readInput();
    const res = model(input);

    // 헤드라인
    const tone = res.margin <= 0 ? 'is-bad' : res.margin < 10 ? 'is-warn' : '';
    $('headline').className = `headline ${tone}`.trim();
    $('netProfit').textContent = won(res.net);
    $('marginRate').textContent = pct(res.margin);

    renderVerdict(input, res);
    renderBar(input, res);
    renderPrices(input, res);
    renderMonthly(input, res);

    save(input);
}

function renderVerdict(input, res) {
    const box = $('verdict');
    const biggest = res.items.reduce((a, b) => (b.amount > a.amount ? b : a));
    const biggestShare = res.revenue > 0 ? (biggest.amount / res.revenue) * 100 : 0;
    const detail = `가장 큰 비용은 <strong>${biggest.name}</strong>으로 매출의 ${pct(biggestShare)}를 가져갑니다.`;

    let tone, msg;

    if (res.margin <= 0) {
        tone = 'is-bad';
        const gap = solvePrice(input, 0);
        msg = `<strong>팔수록 손해입니다.</strong> 한 건 팔 때마다 ${won(-res.net)}씩 빠집니다. ` +
              (gap ? `본전이라도 맞추려면 판매가가 최소 <strong>${won(gap)}</strong>이어야 합니다. ` : '') + detail;
    } else if (res.margin < 10) {
        tone = 'is-warn';
        msg = `<strong>여유가 없습니다.</strong> 마진율 ${pct(res.margin)}면 광고비가 조금만 올라가거나 ` +
              `반품이 몇 건 늘어도 바로 적자로 돌아섭니다. ${detail}`;
    } else if (res.margin < 20) {
        tone = '';
        msg = `무난한 구간입니다. 다만 광고비·반품률이 실제로 얼마인지 정산내역서로 다시 확인해보세요. ${detail}`;
    } else {
        tone = 'is-good';
        msg = `<strong>건전합니다.</strong> 마진율 ${pct(res.margin)}면 광고를 더 태워 판매량을 늘릴 여지가 있습니다. ${detail}`;
    }

    box.className = `verdict ${tone}`.trim();
    box.innerHTML = msg;
}

function renderBar(input, res) {
    const bar = $('bar');
    const legend = $('legend');
    bar.replaceChildren();
    legend.replaceChildren();

    const segments = res.items.filter((it) => it.amount > 0);
    if (res.vat > 0) segments.push({ name: '부가세', color: 'var(--c-vat)', amount: res.vat });

    // 적자면 비용 합이 매출을 넘으므로, 넘는 쪽을 기준으로 눈금을 잡습니다.
    const outflow = segments.reduce((s, it) => s + it.amount, 0);
    const scale = Math.max(res.revenue, outflow) || 1;

    const drawn = segments.slice();
    if (res.net > 0) drawn.push({ name: '순이익', color: 'var(--c-profit)', amount: res.net });

    drawn.forEach((it) => {
        const seg = document.createElement('span');
        seg.style.width = `${(it.amount / scale) * 100}%`;
        seg.style.background = it.color;
        seg.title = `${it.name} ${won(it.amount)}`;
        bar.appendChild(seg);
    });

    // 부가세가 환급(음수)이면 비용이 아니라 이익 쪽이므로 범례에만 표기합니다.
    const rows = segments.slice();
    if (res.vat < 0) rows.push({ name: '부가세 환급', color: 'var(--c-vat)', amount: res.vat });
    rows.push({ name: '순이익', color: 'var(--c-profit)', amount: res.net });

    rows.forEach((it) => {
        const li = document.createElement('li');

        const dot = document.createElement('span');
        dot.className = 'dot';
        dot.style.background = it.color;

        const name = document.createElement('span');
        name.className = 'name';
        name.textContent = it.name;

        const val = document.createElement('span');
        val.className = 'val';
        val.textContent = won(it.amount);

        li.append(dot, name, val);
        legend.appendChild(li);
    });

    $('bar-title').textContent = input.returnRate > 0
        ? `주문 1건당 ${won(input.price)}이 이렇게 쪼개집니다 (반품률 ${pct(input.returnRate)} 반영)`
        : `판매가 ${won(input.price)}은 이렇게 쪼개집니다`;
}

function renderPrices(input, res) {
    const bep = solvePrice(input, 0);
    const target = solvePrice(input, input.targetMargin);
    const maxCost = solveMaxCost(input, input.targetMargin);

    $('bepPrice').textContent = bep ? won(bep) : '계산 불가';
    $('targetPrice').textContent = target ? won(target) : '도달 불가';
    $('maxCost').textContent = maxCost != null ? won(maxCost) : '도달 불가';

    const notes = [];
    if (!target) {
        notes.push(`수수료 ${pct(input.feeRate)} + 광고비 ${pct(input.adRate)} 구조로는 목표 마진율 ` +
                   `${pct(input.targetMargin)}에 어떤 가격으로도 도달할 수 없습니다. 비용 구조를 먼저 바꿔야 합니다.`);
    } else if (target > input.price) {
        notes.push(`목표 마진율 ${pct(input.targetMargin)}을 맞추려면 판매가를 ` +
                   `${won(target - input.price)} 올리거나, 매입원가를 ${won(maxCost != null ? Math.max(0, input.cost - maxCost) : 0)} 낮춰야 합니다.`);
    } else {
        notes.push(`현재 판매가는 목표 마진율을 이미 넘습니다. ${won(input.price - target)}까지 내려도 목표를 지킵니다.`);
    }
    $('bepNote').textContent = notes.join(' ');
}

function renderMonthly(input, res) {
    const v = input.volume;
    const revenue = res.revenue * v;
    const gross = res.net * v;
    const net = gross - input.fixedCost;

    $('mRevenue').textContent = won(revenue);
    $('mGross').textContent = won(gross);
    $('mFixed').textContent = won(input.fixedCost);

    const netCell = $('mNet');
    netCell.textContent = won(net);
    netCell.className = net < 0 ? 'neg' : 'pos';

    const bepCell = $('bepVolume');
    if (res.net > 0) {
        const need = Math.ceil(input.fixedCost / res.net);
        bepCell.textContent = input.fixedCost > 0
            ? `${intComma(need)}개 / 월`
            : '고정비 없음';
        bepCell.className = '';
    } else {
        bepCell.textContent = '건당 순이익이 0 이하라 도달 불가';
        bepCell.className = 'neg';
    }
}

/* ── 저장 ───────────────────────────────────────── */

function save(input) {
    try { localStorage.setItem(LS_KEY, JSON.stringify(input)); }
    catch (err) { /* 사생활 보호 모드 등에서 실패할 수 있으나 계산에는 지장 없음 */ }
}

function load() {
    try {
        const raw = localStorage.getItem(LS_KEY);
        return raw ? { ...DEFAULTS, ...JSON.parse(raw) } : { ...DEFAULTS };
    } catch (err) {
        return { ...DEFAULTS };
    }
}

/* ── 이벤트 ─────────────────────────────────────── */

function bind() {
    $('channel').addEventListener('change', (e) => {
        if (e.target.value !== 'custom') $('feeRate').value = e.target.value;
        render();
    });

    // 수수료율을 직접 고치면 채널 선택은 '직접 입력'으로 넘깁니다.
    $('feeRate').addEventListener('input', () => {
        const sel = $('channel');
        if (sel.value !== 'custom' && parseNum($('feeRate').value) !== parseNum(sel.value)) {
            sel.value = 'custom';
        }
    });

    document.querySelectorAll('.inputs input, .inputs select').forEach((node) => {
        node.addEventListener('input', render);
    });

    // 금액 칸은 포커스를 벗어날 때 천 단위 구분 기호를 붙입니다.
    MONEY_FIELDS.forEach((k) => {
        $(k).addEventListener('blur', () => {
            $(k).value = intComma(parseNum($(k).value));
            render();
        });
    });

    $('btn-reset').addEventListener('click', () => {
        writeInput({ ...DEFAULTS });
        render();
    });
}

/* ── 시작 ───────────────────────────────────────── */

writeInput(load());
bind();
render();
