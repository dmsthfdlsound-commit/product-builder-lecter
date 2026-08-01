/* ==========================================================
   클릭 견적서 — main.js
   서버 없음. 네트워크 요청 없음. 모든 데이터는 이 브라우저 안에만 남습니다.
   ========================================================== */

'use strict';

const LS_CURRENT = 'clickquote:current:v1';
const LS_DOCS    = 'clickquote:docs:v1';
const MIN_ROWS   = 5;

const DOCTYPES = {
    '견적서':     { lead: '아래와 같이 견적합니다.' },
    '거래명세서': { lead: '아래와 같이 거래 내역을 통지합니다.' },
    '청구서':     { lead: '아래와 같이 청구합니다.' },
};

const ITEM_COLS = [
    { key: 'name',  cls: 'c-name',   ph: '품목명' },
    { key: 'spec',  cls: 'c-spec',   ph: '' },
    { key: 'qty',   cls: 'c-qty num',   ph: '', numeric: true },
    { key: 'price', cls: 'c-price num', ph: '', numeric: true },
];

/* ── 요소 참조 ──────────────────────────────────────── */

const $  = (sel) => document.querySelector(sel);
const $$ = (sel) => Array.from(document.querySelectorAll(sel));

const el = {
    paper:       $('#paper'),
    docTitle:    $('#doc-title'),
    leadText:    $('#lead-text'),
    itemsBody:   $('#items-body'),
    logoImg:     $('#logo-img'),
    stampImg:    $('#stamp-img'),
    vatCheck:    $('#vat-check'),
    sumSupply:   $('#sum-supply'),
    sumVat:      $('#sum-vat'),
    sumTotal:    $('#sum-total'),
    grandHangul: $('#grand-hangul'),
    grandDigit:  $('#grand-digit'),
    modal:       $('#modal'),
    docList:     $('#doc-list'),
    toast:       $('#toast'),
};

let doctype = '견적서';

/* ── 숫자 유틸 ──────────────────────────────────────── */

/** "1,200,000원" 같은 입력에서도 숫자만 뽑아냅니다. */
function parseNum(raw) {
    if (typeof raw === 'number') return isFinite(raw) ? raw : 0;
    const cleaned = String(raw ?? '').replace(/[^0-9.\-]/g, '');
    const n = parseFloat(cleaned);
    return isFinite(n) ? n : 0;
}

function comma(n) {
    const rounded = Math.round((Number(n) || 0) * 100) / 100;
    return rounded.toLocaleString('ko-KR');
}

/** 금액을 한글로. 350000 → "삼십오만" */
function numToKorean(value) {
    let n = Math.floor(Math.abs(Number(value) || 0));
    if (n === 0) return '영';

    const D = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
    const U = ['', '십', '백', '천'];
    const B = ['', '만', '억', '조', '경'];

    let out = '';
    let bi = 0;

    while (n > 0 && bi < B.length) {
        let chunk = n % 10000;
        if (chunk > 0) {
            let part = '';
            let ui = 0;
            while (chunk > 0) {
                const d = chunk % 10;
                if (d > 0) {
                    // 십·백·천 앞의 '일'은 생략 (15 → 십오, 100 → 백)
                    const digit = (d === 1 && ui > 0) ? '' : D[d];
                    part = digit + U[ui] + part;
                }
                chunk = Math.floor(chunk / 10);
                ui++;
            }
            out = part + B[bi] + out;
        }
        n = Math.floor(n / 10000);
        bi++;
    }
    return out;
}

/* ── 상태 읽기 / 쓰기 ───────────────────────────────── */

function collectState() {
    const fields = {};
    $$('.paper [data-field]').forEach((node) => { fields[node.dataset.field] = node.value; });

    const items = Array.from(el.itemsBody.rows).map((row) => {
        const item = {};
        ITEM_COLS.forEach(({ key }) => {
            const input = row.querySelector(`[data-item="${key}"]`);
            item[key] = input ? input.value : '';
        });
        const noteInput = row.querySelector('[data-item="note"]');
        item.note = noteInput ? noteInput.value : '';
        return item;
    });

    return {
        version: 1,
        doctype,
        vat: el.vatCheck.checked,
        logo: el.logoImg.getAttribute('src') || '',
        stamp: el.stampImg.getAttribute('src') || '',
        fields,
        items,
    };
}

function applyState(state) {
    if (!state || typeof state !== 'object') return;

    setDoctype(DOCTYPES[state.doctype] ? state.doctype : '견적서');
    el.vatCheck.checked = state.vat !== false;

    setImage(el.logoImg, state.logo || '');
    setImage(el.stampImg, state.stamp || '');

    const fields = state.fields || {};
    $$('.paper [data-field]').forEach((node) => {
        node.value = typeof fields[node.dataset.field] === 'string' ? fields[node.dataset.field] : '';
    });

    const items = Array.isArray(state.items) && state.items.length ? state.items : [];
    renderItems(items);
    recalc();
}

function setImage(img, src) {
    if (src) {
        img.setAttribute('src', src);
        img.hidden = false;
    } else {
        img.removeAttribute('src');
        img.hidden = true;
    }
}

/* ── 품목 행 ────────────────────────────────────────── */

function makeRow(item = {}) {
    const tr = document.createElement('tr');

    const noCell = document.createElement('td');
    noCell.className = 'row-no';
    tr.appendChild(noCell);

    ITEM_COLS.forEach((col) => {
        const td = document.createElement('td');
        td.className = col.cls;
        const input = document.createElement('input');
        input.dataset.item = col.key;
        input.placeholder = col.ph;
        input.value = item[col.key] ?? '';
        if (col.numeric) {
            input.inputMode = 'decimal';
            input.addEventListener('blur', () => {
                if (input.value.trim() !== '') input.value = comma(parseNum(input.value));
            });
        }
        td.appendChild(input);
        tr.appendChild(td);
    });

    const amountCell = document.createElement('td');
    amountCell.className = 'c-amount cell-amount';
    tr.appendChild(amountCell);

    const noteCell = document.createElement('td');
    noteCell.className = 'c-note';
    const noteInput = document.createElement('input');
    noteInput.dataset.item = 'note';
    noteInput.value = item.note ?? '';
    noteCell.appendChild(noteInput);
    tr.appendChild(noteCell);

    const delCell = document.createElement('td');
    delCell.className = 'c-del no-print';
    const delBtn = document.createElement('button');
    delBtn.type = 'button';
    delBtn.className = 'del-btn';
    delBtn.title = '이 행 삭제';
    delBtn.setAttribute('aria-label', '이 행 삭제');
    delBtn.textContent = '×';
    delBtn.addEventListener('click', () => {
        tr.remove();
        ensureMinRows();
        recalc();
        scheduleAutosave();
    });
    delCell.appendChild(delBtn);
    tr.appendChild(delCell);

    return tr;
}

function renderItems(items) {
    el.itemsBody.replaceChildren();
    items.forEach((item) => el.itemsBody.appendChild(makeRow(item)));
    ensureMinRows();
}

function ensureMinRows() {
    while (el.itemsBody.rows.length < MIN_ROWS) {
        el.itemsBody.appendChild(makeRow());
    }
}

function isRowFilled(row) {
    return ITEM_COLS.some(({ key }) => {
        const input = row.querySelector(`[data-item="${key}"]`);
        return input && input.value.trim() !== '';
    });
}

/** 마지막 행에 입력이 생기면 빈 행을 하나 더 붙여줍니다. */
function autoGrow() {
    const rows = el.itemsBody.rows;
    const last = rows[rows.length - 1];
    if (last && isRowFilled(last)) {
        el.itemsBody.appendChild(makeRow());
        renumber();
    }
}

function renumber() {
    Array.from(el.itemsBody.rows).forEach((row, i) => {
        row.querySelector('.row-no').textContent = isRowFilled(row) ? String(i + 1) : '';
    });
}

/* ── 계산 ───────────────────────────────────────────── */

function recalc() {
    let supply = 0;

    Array.from(el.itemsBody.rows).forEach((row) => {
        const qty   = parseNum(row.querySelector('[data-item="qty"]').value);
        const price = parseNum(row.querySelector('[data-item="price"]').value);
        const cell  = row.querySelector('.cell-amount');

        if (!isRowFilled(row)) { cell.textContent = ''; return; }

        const amount = Math.round(qty * price);
        supply += amount;
        cell.textContent = amount ? comma(amount) : '';
    });

    const vat   = el.vatCheck.checked ? Math.round(supply * 0.1) : 0;
    const total = supply + vat;

    el.sumSupply.textContent = comma(supply);
    el.sumVat.textContent    = el.vatCheck.checked ? comma(vat) : '-';
    el.sumTotal.textContent  = comma(total);

    el.grandHangul.textContent = `일금 ${numToKorean(total)}원정`;
    el.grandDigit.textContent  = `(₩${comma(total)})`;

    renumber();
}

/* ── 문서 종류 ──────────────────────────────────────── */

function setDoctype(next) {
    doctype = next;
    el.docTitle.textContent = next;
    el.leadText.textContent = DOCTYPES[next].lead;
    $$('.doctype-btn').forEach((btn) => {
        const active = btn.dataset.doctype === next;
        btn.classList.toggle('is-active', active);
        btn.setAttribute('aria-selected', String(active));
    });
}

/* ── 저장소 ─────────────────────────────────────────── */

function readJSON(key, fallback) {
    try {
        const raw = localStorage.getItem(key);
        return raw ? JSON.parse(raw) : fallback;
    } catch (err) {
        console.warn('저장된 데이터를 읽지 못했습니다.', err);
        return fallback;
    }
}

function writeJSON(key, value) {
    try {
        localStorage.setItem(key, JSON.stringify(value));
        return true;
    } catch (err) {
        // 용량 초과(로고·도장 이미지가 큰 경우)가 가장 흔한 원인입니다.
        console.warn('저장하지 못했습니다.', err);
        return false;
    }
}

let autosaveTimer = null;
function scheduleAutosave() {
    clearTimeout(autosaveTimer);
    autosaveTimer = setTimeout(() => { writeJSON(LS_CURRENT, collectState()); }, 400);
}

function suggestName() {
    const client = ($('[data-field="clientName"]').value || '거래처').trim();
    const date   = ($('[data-field="docDate"]').value || todayISO()).trim();
    return `${doctype}_${client}_${date}`;
}

function saveDoc() {
    const name = window.prompt('저장할 이름을 입력하세요.', suggestName());
    if (name === null) return;

    const docs = readJSON(LS_DOCS, []);
    const entry = {
        id: `d${Date.now()}${Math.floor(Math.random() * 1000)}`,
        name: name.trim() || suggestName(),
        savedAt: new Date().toISOString(),
        state: collectState(),
    };
    docs.unshift(entry);

    if (writeJSON(LS_DOCS, docs)) {
        toast('저장했습니다.');
    } else {
        toast('저장 공간이 부족합니다. 로고·도장 이미지를 줄이거나 오래된 문서를 지워주세요.');
    }
}

function openDocList() {
    const docs = readJSON(LS_DOCS, []);
    el.docList.replaceChildren();

    if (!docs.length) {
        const li = document.createElement('li');
        li.className = 'empty';
        li.textContent = '아직 저장한 문서가 없습니다.';
        el.docList.appendChild(li);
    }

    docs.forEach((entry) => {
        const li = document.createElement('li');

        const info = document.createElement('div');
        info.className = 'doc-info';

        const name = document.createElement('div');
        name.className = 'doc-name';
        name.textContent = entry.name;

        const sub = document.createElement('div');
        sub.className = 'doc-sub';
        sub.textContent = formatSavedAt(entry.savedAt);

        info.append(name, sub);

        const loadBtn = document.createElement('button');
        loadBtn.className = 'btn btn-sm';
        loadBtn.textContent = '불러오기';
        loadBtn.addEventListener('click', () => {
            applyState(entry.state);
            scheduleAutosave();
            closeModal();
            toast('불러왔습니다.');
        });

        const delBtn = document.createElement('button');
        delBtn.className = 'btn btn-sm btn-danger';
        delBtn.textContent = '삭제';
        delBtn.addEventListener('click', () => {
            if (!window.confirm(`"${entry.name}"을(를) 삭제할까요?`)) return;
            writeJSON(LS_DOCS, readJSON(LS_DOCS, []).filter((d) => d.id !== entry.id));
            openDocList();
        });

        li.append(info, loadBtn, delBtn);
        el.docList.appendChild(li);
    });

    el.modal.hidden = false;
}

function closeModal() { el.modal.hidden = true; }

function formatSavedAt(iso) {
    const d = new Date(iso);
    if (isNaN(d)) return '';
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())} 저장`;
}

/* ── 파일 내보내기 / 가져오기 ───────────────────────── */

function exportJSON() {
    const blob = new Blob([JSON.stringify(collectState(), null, 2)], {
        type: 'application/json',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${suggestName()}.json`;
    a.click();
    URL.revokeObjectURL(url);
    toast('백업 파일을 내려받았습니다.');
}

function importJSON(file) {
    const reader = new FileReader();
    reader.onload = () => {
        try {
            applyState(JSON.parse(reader.result));
            scheduleAutosave();
            toast('불러왔습니다.');
        } catch (err) {
            toast('이 파일은 읽을 수 없습니다. 내보내기로 만든 JSON 파일인지 확인해주세요.');
        }
    };
    reader.onerror = () => toast('파일을 읽지 못했습니다.');
    reader.readAsText(file);
}

function loadImage(file, img) {
    if (file.size > 1.5 * 1024 * 1024) {
        toast('이미지가 너무 큽니다. 1.5MB 이하로 줄여주세요.');
        return;
    }
    const reader = new FileReader();
    reader.onload = () => {
        setImage(img, reader.result);
        scheduleAutosave();
    };
    reader.onerror = () => toast('이미지를 읽지 못했습니다.');
    reader.readAsDataURL(file);
}

/* ── 인쇄 ───────────────────────────────────────────── */

function printDoc() {
    // 브라우저는 document.title 을 PDF 기본 파일명으로 씁니다.
    const original = document.title;
    document.title = suggestName();
    const restore = () => { document.title = original; };
    window.addEventListener('afterprint', restore, { once: true });
    window.print();
    setTimeout(restore, 3000); // afterprint 를 안 쏘는 브라우저 대비
}

/* ── 기타 ───────────────────────────────────────────── */

function todayISO() {
    const d = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

let toastTimer = null;
function toast(message) {
    el.toast.textContent = message;
    el.toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { el.toast.hidden = true; }, 2600);
}

function resetDoc() {
    if (!window.confirm('현재 내용을 비우고 새 문서를 시작할까요? 저장하지 않은 내용은 사라집니다.')) return;
    applyState({ doctype, vat: true, logo: '', stamp: '', fields: {}, items: [] });
    $('[data-field="docDate"]').value = todayISO();
    scheduleAutosave();
    toast('새 문서를 시작했습니다.');
}

/* ── 이벤트 연결 ────────────────────────────────────── */

function bind() {
    $$('.doctype-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
            setDoctype(btn.dataset.doctype);
            scheduleAutosave();
        });
    });

    el.paper.addEventListener('input', (e) => {
        if (e.target.matches('[data-item]')) {
            autoGrow();
            recalc();
        }
        scheduleAutosave();
    });

    el.vatCheck.addEventListener('change', () => { recalc(); scheduleAutosave(); });

    $('#btn-add-row').addEventListener('click', () => {
        const row = makeRow();
        el.itemsBody.appendChild(row);
        row.querySelector('[data-item="name"]').focus();
    });

    $('#btn-print').addEventListener('click', printDoc);
    $('#btn-save').addEventListener('click', saveDoc);
    $('#btn-open').addEventListener('click', openDocList);
    $('#btn-export').addEventListener('click', exportJSON);
    $('#btn-reset').addEventListener('click', resetDoc);
    $('#btn-close-modal').addEventListener('click', closeModal);

    el.modal.addEventListener('click', (e) => { if (e.target === el.modal) closeModal(); });
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !el.modal.hidden) closeModal();
        if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
            e.preventDefault();
            saveDoc();
        }
    });

    $('#logo-input').addEventListener('change', (e) => {
        if (e.target.files[0]) loadImage(e.target.files[0], el.logoImg);
        e.target.value = '';
    });
    $('#stamp-input').addEventListener('change', (e) => {
        if (e.target.files[0]) loadImage(e.target.files[0], el.stampImg);
        e.target.value = '';
    });
    $('#import-input').addEventListener('change', (e) => {
        if (e.target.files[0]) importJSON(e.target.files[0]);
        e.target.value = '';
    });
}

/* ── 시작 ───────────────────────────────────────────── */

function init() {
    bind();

    const saved = readJSON(LS_CURRENT, null);
    if (saved) {
        applyState(saved);
    } else {
        applyState({ doctype: '견적서', vat: true, fields: {}, items: [] });
        $('[data-field="docDate"]').value = todayISO();
        $('[data-field="docNo"]').value = `${new Date().getFullYear()}-0001`;
    }
    recalc();
}

init();
