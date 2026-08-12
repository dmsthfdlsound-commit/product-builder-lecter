/**
 * 자모 사과게임
 *
 * 규칙: 드래그한 사각형 안의 자모를 전부 사용해 (순서는 자유롭게) 단어를 만들 수 있으면 사라진다.
 * 사과게임의 "합이 10"이 순서와 무관한 것처럼, 여기서도 순서를 따지지 않는다 = 애너그램 판정.
 */
(function () {
    'use strict';

    // ─────────────────────────────────────────────────────────
    // 한글 자모 분해
    // ─────────────────────────────────────────────────────────

    const CHO = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];
    const JUNG = ['ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'];
    const JONG = ['', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];

    /** 겹자음·복합모음을 기본 자모의 조합으로 푼다. 판에는 기본 24자모만 올라간다. */
    const SPLIT = {
        'ㄲ': 'ㄱㄱ', 'ㄸ': 'ㄷㄷ', 'ㅃ': 'ㅂㅂ', 'ㅆ': 'ㅅㅅ', 'ㅉ': 'ㅈㅈ',
        'ㄳ': 'ㄱㅅ', 'ㄵ': 'ㄴㅈ', 'ㄶ': 'ㄴㅎ', 'ㄺ': 'ㄹㄱ', 'ㄻ': 'ㄹㅁ',
        'ㄼ': 'ㄹㅂ', 'ㄽ': 'ㄹㅅ', 'ㄾ': 'ㄹㅌ', 'ㄿ': 'ㄹㅍ', 'ㅀ': 'ㄹㅎ', 'ㅄ': 'ㅂㅅ',
        'ㅐ': 'ㅏㅣ', 'ㅒ': 'ㅑㅣ', 'ㅔ': 'ㅓㅣ', 'ㅖ': 'ㅕㅣ',
        'ㅘ': 'ㅗㅏ', 'ㅙ': 'ㅗㅏㅣ', 'ㅚ': 'ㅗㅣ',
        'ㅝ': 'ㅜㅓ', 'ㅞ': 'ㅜㅓㅣ', 'ㅟ': 'ㅜㅣ', 'ㅢ': 'ㅡㅣ',
    };

    const BASIC = ['ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
        'ㅏ', 'ㅑ', 'ㅓ', 'ㅕ', 'ㅗ', 'ㅛ', 'ㅜ', 'ㅠ', 'ㅡ', 'ㅣ'];
    const BASIC_INDEX = new Map(BASIC.map(function (j, i) { return [j, i]; }));

    function expand(jamo, out) {
        const split = SPLIT[jamo];
        if (!split) { out.push(jamo); return; }
        for (let i = 0; i < split.length; i++) out.push(split[i]);
    }

    /** 단어를 기본 자모 배열로 분해한다. 한글 음절이 아닌 글자가 있으면 null. */
    function decompose(word) {
        const out = [];
        for (let i = 0; i < word.length; i++) {
            const code = word.charCodeAt(i) - 0xac00;
            if (code < 0 || code > 11171) return null;
            expand(CHO[Math.floor(code / 588)], out);
            expand(JUNG[Math.floor((code % 588) / 28)], out);
            const jong = JONG[code % 28];
            if (jong) expand(jong, out);
        }
        for (let i = 0; i < out.length; i++) {
            if (!BASIC_INDEX.has(out[i])) return null;
        }
        return out;
    }

    /** 자모 개수 배열 → 정규화된 키. 순서가 달라도 같은 키가 나온다. */
    function keyFromCounts(counts) {
        let key = '';
        for (let i = 0; i < BASIC.length; i++) {
            for (let n = 0; n < counts[i]; n++) key += BASIC[i];
        }
        return key;
    }

    function keyFromJamo(jamo) {
        const counts = new Uint8Array(BASIC.length);
        for (let i = 0; i < jamo.length; i++) counts[BASIC_INDEX.get(jamo[i])]++;
        return keyFromCounts(counts);
    }

    // ─────────────────────────────────────────────────────────
    // 사전 색인
    // ─────────────────────────────────────────────────────────

    const MIN_JAMO = 2;
    const MAX_JAMO = 6;

    const DICT = new Map();       // 정규화 키 → 단어 배열
    const BY_LEN = {};            // 자모 개수 → {word, jamo} 배열
    const JAMO_WEIGHT = new Float64Array(BASIC.length);

    (function buildDictionary() {
        for (let n = MIN_JAMO; n <= MAX_JAMO; n++) BY_LEN[n] = [];
        const seen = new Set();

        WORD_LIST.forEach(function (word) {
            if (seen.has(word)) return;
            seen.add(word);
            const jamo = decompose(word);
            if (!jamo || jamo.length < MIN_JAMO || jamo.length > MAX_JAMO) return;

            const key = keyFromJamo(jamo);
            if (!DICT.has(key)) DICT.set(key, []);
            DICT.get(key).push(word);
            BY_LEN[jamo.length].push({ word: word, jamo: jamo });
            for (let i = 0; i < jamo.length; i++) JAMO_WEIGHT[BASIC_INDEX.get(jamo[i])]++;
        });
    })();

    // ─────────────────────────────────────────────────────────
    // 시드 난수 (오늘의 판은 전 세계가 같은 판을 푼다)
    // ─────────────────────────────────────────────────────────

    function mulberry32(seed) {
        let a = seed >>> 0;
        return function () {
            a = (a + 0x6d2b79f5) >>> 0;
            let t = a;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }

    function hashString(str) {
        let h = 2166136261;
        for (let i = 0; i < str.length; i++) {
            h ^= str.charCodeAt(i);
            h = Math.imul(h, 16777619);
        }
        return h >>> 0;
    }

    /** 한국 시간 기준 오늘 날짜 (YYYY-MM-DD). 자정에 판이 바뀌도록. */
    function todayKST() {
        const now = new Date();
        const kst = new Date(now.getTime() + (now.getTimezoneOffset() + 540) * 60000);
        const mm = String(kst.getMonth() + 1).padStart(2, '0');
        const dd = String(kst.getDate()).padStart(2, '0');
        return kst.getFullYear() + '-' + mm + '-' + dd;
    }

    // ─────────────────────────────────────────────────────────
    // 판 생성
    // ─────────────────────────────────────────────────────────

    const COLS = 10;
    const ROWS = 14;
    const CELL_COUNT = COLS * ROWS;

    /** 넓이별로 쓸 수 있는 직사각형 모양 (가로, 세로) */
    const SHAPES = [
        [1, 2], [2, 1],
        [1, 3], [3, 1],
        [1, 4], [4, 1], [2, 2],
        [1, 5], [5, 1],
        [1, 6], [6, 1], [2, 3], [3, 2],
    ];

    function shuffled(arr, rand) {
        const copy = arr.slice();
        for (let i = copy.length - 1; i > 0; i--) {
            const j = Math.floor(rand() * (i + 1));
            const t = copy[i]; copy[i] = copy[j]; copy[j] = t;
        }
        return copy;
    }

    function weightedJamo(rand) {
        let total = 0;
        for (let i = 0; i < JAMO_WEIGHT.length; i++) total += JAMO_WEIGHT[i];
        let r = rand() * total;
        for (let i = 0; i < JAMO_WEIGHT.length; i++) {
            r -= JAMO_WEIGHT[i];
            if (r <= 0) return BASIC[i];
        }
        return BASIC[0];
    }

    /**
     * 실제 단어를 직사각형 모양으로 깔아서 판을 만든다.
     * 무작위로 자모를 뿌리면 만들 수 있는 단어가 거의 없기 때문에,
     * "정답을 먼저 심고 섞는" 방식으로 시작 시점의 해답 수를 보장한다.
     */
    function generateBoard(rand) {
        const cells = new Array(CELL_COUNT).fill(null);

        for (let idx = 0; idx < CELL_COUNT; idx++) {
            if (cells[idx] !== null) continue;
            const r0 = Math.floor(idx / COLS);
            const c0 = idx % COLS;
            let placed = false;

            const shapes = shuffled(SHAPES, rand);
            for (let s = 0; s < shapes.length && !placed; s++) {
                const w = shapes[s][0];
                const h = shapes[s][1];
                if (c0 + w > COLS || r0 + h > ROWS) continue;

                let free = true;
                for (let r = r0; r < r0 + h && free; r++) {
                    for (let c = c0; c < c0 + w; c++) {
                        if (cells[r * COLS + c] !== null) { free = false; break; }
                    }
                }
                if (!free) continue;

                const pool = BY_LEN[w * h];
                if (!pool || !pool.length) continue;

                const entry = pool[Math.floor(rand() * pool.length)];
                const jamo = shuffled(entry.jamo, rand);
                let k = 0;
                for (let r = r0; r < r0 + h; r++) {
                    for (let c = c0; c < c0 + w; c++) cells[r * COLS + c] = jamo[k++];
                }
                placed = true;
            }

            // 어떤 모양도 안 들어가는 자투리 칸은 자모 빈도에 맞춰 채운다.
            if (!placed) cells[idx] = weightedJamo(rand);
        }

        return cells;
    }

    // ─────────────────────────────────────────────────────────
    // 해답 탐색
    // ─────────────────────────────────────────────────────────

    /**
     * 현재 판에서 지울 수 있는 직사각형을 찾는다.
     * 빈칸은 없는 셈 치므로, 판이 비어갈수록 멀리 떨어진 자모끼리도 묶인다.
     */
    function findSolutions(cells, limit) {
        const found = [];
        const counts = new Uint8Array(BASIC.length);

        for (let c1 = 0; c1 < COLS; c1++) {
            for (let c2 = c1; c2 < COLS; c2++) {
                for (let r1 = 0; r1 < ROWS; r1++) {
                    counts.fill(0);
                    let total = 0;
                    for (let r2 = r1; r2 < ROWS; r2++) {
                        for (let c = c1; c <= c2; c++) {
                            const jamo = cells[r2 * COLS + c];
                            if (jamo === null) continue;
                            counts[BASIC_INDEX.get(jamo)]++;
                            total++;
                        }
                        if (total > MAX_JAMO) break;
                        if (total < MIN_JAMO) continue;

                        const words = DICT.get(keyFromCounts(counts));
                        if (words) {
                            found.push({ r1: r1, c1: c1, r2: r2, c2: c2, word: words[0], size: total });
                            if (limit && found.length >= limit) return found;
                        }
                    }
                }
            }
        }
        return found;
    }

    // ─────────────────────────────────────────────────────────
    // 게임 상태
    // ─────────────────────────────────────────────────────────

    const ROUND_SECONDS = 120;
    const HINT_LIMIT = 3;
    const COMBO_WINDOW = 3000;   // 직전 제거로부터 이 시간 안에 또 지우면 콤보가 이어진다
    const COMBO_MAX_MULT = 3;
    const MODE_LABEL = { daily: '오늘의 판', free: '연습 모드', easy: '쉬움 모드' };
    const STORE = {
        best: 'jamo.best',
        bestEasy: 'jamo.best.easy',
        daily: 'jamo.daily',
        streak: 'jamo.streak',
        lastDaily: 'jamo.lastDaily',
    };

    /** 쉬움 모드는 최고 점수를 따로 적는다. 목록을 보고 낸 점수와 섞이면 기록이 의미를 잃는다. */
    function bestKey(mode) {
        return mode === 'easy' ? STORE.bestEasy : STORE.best;
    }

    const state = {
        cells: null,
        mode: 'daily',
        dateKey: todayKST(),
        score: 0,
        cleared: 0,
        words: [],
        combo: 0,
        maxCombo: 0,
        lastClearAt: 0,
        hintsLeft: HINT_LIMIT,
        showWords: false,
        running: false,
        endsAt: 0,
        timerId: 0,
        drag: null,
    };

    // ─────────────────────────────────────────────────────────
    // DOM
    // ─────────────────────────────────────────────────────────

    const $ = function (id) { return document.getElementById(id); };
    let boardEl, overlayEl, scoreEl, timeEl, timebarEl, statusEl, hintBtn, toastEl;
    let wordPanelEl, wordListEl, wordCountEl;
    let comboEl, comboTextEl, comboBarEl, modeTagEl;
    const tileEls = [];

    let toastTimer = 0;
    function toast(message) {
        toastEl.textContent = message;
        toastEl.classList.add('show');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(function () { toastEl.classList.remove('show'); }, 1800);
    }

    function readNumber(key) {
        const raw = localStorage.getItem(key);
        const value = raw === null ? 0 : parseInt(raw, 10);
        return Number.isFinite(value) ? value : 0;
    }

    function buildBoardDom() {
        boardEl.style.setProperty('--cols', COLS);
        boardEl.style.setProperty('--rows', ROWS);
        const frag = document.createDocumentFragment();
        for (let i = 0; i < CELL_COUNT; i++) {
            const cell = document.createElement('div');
            cell.className = 'cell';
            const tile = document.createElement('span');
            tile.className = 'tile';
            cell.appendChild(tile);
            frag.appendChild(cell);
            tileEls.push(tile);
        }
        boardEl.appendChild(frag);
    }

    function paintBoard() {
        for (let i = 0; i < CELL_COUNT; i++) {
            const tile = tileEls[i];
            const jamo = state.cells[i];
            tile.textContent = jamo === null ? '' : jamo;
            tile.className = jamo === null ? 'tile empty' : 'tile';
        }
    }

    /**
     * 쉬움 모드의 단어 목록.
     * 판이 바뀔 때마다 다시 계산하므로 "지금 이 판에서 실제로 만들 수 있는 단어"만 남는다.
     * 하나를 지우면 그 자모를 함께 쓰던 다른 단어들도 같이 사라진다.
     */
    function renderWordList() {
        if (!state.showWords) return;

        const words = Array.from(new Set(findSolutions(state.cells, 0).map(function (s) { return s.word; })));
        // 점수가 큰 긴 단어를 위에 둔다. 짧은 단어는 어차피 거의 항상 만들 수 있어 목표가 못 된다.
        words.sort(function (a, b) {
            const diff = decompose(b).length - decompose(a).length;
            return diff !== 0 ? diff : a.localeCompare(b, 'ko');
        });
        wordCountEl.textContent = words.length;

        if (!words.length) {
            wordListEl.replaceChildren(
                Object.assign(document.createElement('span'), {
                    className: 'word-empty',
                    textContent: '더 만들 수 있는 단어가 없습니다',
                }));
            return;
        }

        const frag = document.createDocumentFragment();
        words.forEach(function (word) {
            const chip = document.createElement('span');
            chip.className = 'word-chip len-' + decompose(word).length;
            chip.textContent = word;
            frag.appendChild(chip);
        });
        wordListEl.replaceChildren(frag);
    }

    /** 방금 맞힌 단어를 목록에서 지워지는 것처럼 보여준 뒤 목록을 새로 그린다. */
    function markWordFound(word) {
        if (!state.showWords) return;
        const chips = wordListEl.children;
        for (let i = 0; i < chips.length; i++) {
            if (chips[i].textContent === word) {
                chips[i].classList.add('found');
                break;
            }
        }
        setTimeout(renderWordList, 340);
    }

    // ─────────────────────────────────────────────────────────
    // 선택 · 판정
    // ─────────────────────────────────────────────────────────

    function cellFromPoint(x, y) {
        const rect = boardEl.getBoundingClientRect();
        const cw = rect.width / COLS;
        const ch = rect.height / ROWS;
        const c = Math.min(COLS - 1, Math.max(0, Math.floor((x - rect.left) / cw)));
        const r = Math.min(ROWS - 1, Math.max(0, Math.floor((y - rect.top) / ch)));
        return { r: r, c: c };
    }

    function selectionInfo(area) {
        const counts = new Uint8Array(BASIC.length);
        const indices = [];
        for (let r = area.r1; r <= area.r2; r++) {
            for (let c = area.c1; c <= area.c2; c++) {
                const idx = r * COLS + c;
                const jamo = state.cells[idx];
                if (jamo === null) continue;
                counts[BASIC_INDEX.get(jamo)]++;
                indices.push(idx);
            }
        }
        let words = null;
        if (indices.length >= MIN_JAMO && indices.length <= MAX_JAMO) {
            words = DICT.get(keyFromCounts(counts)) || null;
        }
        return { indices: indices, word: words ? words[0] : null };
    }

    function normalizeArea(a, b) {
        return {
            r1: Math.min(a.r, b.r), r2: Math.max(a.r, b.r),
            c1: Math.min(a.c, b.c), c2: Math.max(a.c, b.c),
        };
    }

    function drawOverlay(area, valid) {
        const rect = boardEl.getBoundingClientRect();
        const cw = rect.width / COLS;
        const ch = rect.height / ROWS;
        overlayEl.style.left = (area.c1 * cw) + 'px';
        overlayEl.style.top = (area.r1 * ch) + 'px';
        overlayEl.style.width = ((area.c2 - area.c1 + 1) * cw) + 'px';
        overlayEl.style.height = ((area.r2 - area.r1 + 1) * ch) + 'px';
        overlayEl.classList.toggle('valid', valid);
        overlayEl.hidden = false;
    }

    function highlight(indices, valid) {
        for (let i = 0; i < CELL_COUNT; i++) {
            tileEls[i].classList.remove('picked', 'picked-valid');
        }
        for (let i = 0; i < indices.length; i++) {
            tileEls[indices[i]].classList.add(valid ? 'picked-valid' : 'picked');
        }
    }

    function clearHighlight() {
        for (let i = 0; i < CELL_COUNT; i++) {
            tileEls[i].classList.remove('picked', 'picked-valid');
        }
        overlayEl.hidden = true;
    }

    function setStatus(indices, word) {
        if (!indices.length) {
            statusEl.textContent = '드래그해서 사각형을 그려보세요';
            statusEl.className = 'status';
            return;
        }
        const jamo = indices.map(function (i) { return state.cells[i]; }).join(' ');
        if (word) {
            statusEl.textContent = jamo + '  →  단어 완성!';
            statusEl.className = 'status ok';
        } else {
            statusEl.textContent = jamo + '  · ' + indices.length + '자모';
            statusEl.className = 'status';
        }
    }

    function onPointerDown(event) {
        if (!state.running) return;
        event.preventDefault();
        boardEl.setPointerCapture(event.pointerId);
        const start = cellFromPoint(event.clientX, event.clientY);
        state.drag = { start: start, pointerId: event.pointerId };
        updateDrag(event.clientX, event.clientY);
    }

    function onPointerMove(event) {
        if (!state.drag || event.pointerId !== state.drag.pointerId) return;
        event.preventDefault();
        updateDrag(event.clientX, event.clientY);
    }

    function updateDrag(x, y) {
        const area = normalizeArea(state.drag.start, cellFromPoint(x, y));
        const info = selectionInfo(area);
        state.drag.area = area;
        state.drag.info = info;
        drawOverlay(area, !!info.word);
        highlight(info.indices, !!info.word);
        setStatus(info.indices, info.word);
    }

    function onPointerUp(event) {
        if (!state.drag || event.pointerId !== state.drag.pointerId) return;
        const drag = state.drag;
        state.drag = null;
        clearHighlight();
        setStatus([], null);
        if (drag.info && drag.info.word) {
            acceptWord(drag.area, drag.info);
        }
    }

    function scoreFor(size) {
        return size + Math.max(0, size - 3) * 2;
    }

    /** 1콤보는 배수 없음. 이후 한 단계마다 0.5씩 붙고 ×3에서 멈춘다. */
    function comboMultiplier(combo) {
        if (combo < 2) return 1;
        return Math.min(COMBO_MAX_MULT, 1 + (combo - 1) * 0.5);
    }

    function formatMultiplier(mult) {
        return '×' + (mult % 1 === 0 ? mult : mult.toFixed(1));
    }

    /** 콤보 창이 열려 있는 동안 남은 시간을 막대로 보여준다. 닫히면 모드 이름으로 돌아간다. */
    function renderCombo(now) {
        const left = state.combo > 0 ? COMBO_WINDOW - (now - state.lastClearAt) : 0;
        if (left <= 0) {
            if (state.combo > 0) state.combo = 0;
            comboEl.hidden = true;
            modeTagEl.hidden = false;
            return;
        }
        const mult = comboMultiplier(state.combo);
        comboTextEl.textContent = state.combo < 2
            ? '3초 안에 하나 더!'
            : '🔥 ' + state.combo + '콤보 ' + formatMultiplier(mult);
        comboTextEl.classList.toggle('hot', state.combo >= 2);
        comboBarEl.style.width = (left / COMBO_WINDOW * 100) + '%';
        comboEl.hidden = false;
        modeTagEl.hidden = true;
    }

    function acceptWord(area, info) {
        const now = performance.now();
        const chained = state.combo > 0 && (now - state.lastClearAt) <= COMBO_WINDOW;
        state.combo = chained ? state.combo + 1 : 1;
        state.lastClearAt = now;
        state.maxCombo = Math.max(state.maxCombo, state.combo);

        const mult = comboMultiplier(state.combo);
        const gained = Math.round(scoreFor(info.indices.length) * mult);
        state.score += gained;
        state.cleared += info.indices.length;
        state.words.push(info.word);

        info.indices.forEach(function (idx) {
            state.cells[idx] = null;
            const tile = tileEls[idx];
            tile.classList.add('pop');
            setTimeout(function () {
                tile.textContent = '';
                tile.className = 'tile empty';
            }, 190);
        });

        scoreEl.textContent = state.score;
        scoreEl.classList.remove('bump');
        void scoreEl.offsetWidth;   // 연속으로 터뜨려도 애니메이션이 다시 시작되도록
        scoreEl.classList.add('bump');
        renderCombo(now);
        floatWord(area, info.word, gained, mult);
        markWordFound(info.word);

        if (!findSolutions(state.cells, 1).length) {
            setTimeout(function () { endGame('nomoves'); }, 400);
        }
    }

    function floatWord(area, word, gained, mult) {
        const rect = boardEl.getBoundingClientRect();
        const cw = rect.width / COLS;
        const ch = rect.height / ROWS;
        const label = document.createElement('div');
        label.className = 'float-word' + (mult > 1 ? ' boosted' : '');
        label.innerHTML = '<b>' + word + '</b><em>+' + gained + '</em>' +
            (mult > 1 ? '<i>' + formatMultiplier(mult) + '</i>' : '');
        // 가장자리에서 지워도 라벨이 판 밖으로 나가지 않도록 중심을 안쪽으로 당긴다.
        const centerX = (area.c1 + (area.c2 - area.c1 + 1) / 2) * cw;
        label.style.left = Math.min(Math.max(centerX, rect.width * 0.18), rect.width * 0.82) + 'px';
        label.style.top = ((area.r1 + (area.r2 - area.r1 + 1) / 2) * ch) + 'px';
        boardEl.parentNode.appendChild(label);
        setTimeout(function () { label.remove(); }, 900);
    }

    function useHint() {
        if (!state.running || state.hintsLeft <= 0) return;
        const solutions = findSolutions(state.cells, 40);
        if (!solutions.length) return;
        const pick = solutions[Math.floor(Math.random() * solutions.length)];
        state.hintsLeft--;
        hintBtn.textContent = '힌트 ' + state.hintsLeft;
        hintBtn.disabled = state.hintsLeft === 0;

        const marked = [];
        for (let r = pick.r1; r <= pick.r2; r++) {
            for (let c = pick.c1; c <= pick.c2; c++) {
                const tile = tileEls[r * COLS + c];
                if (state.cells[r * COLS + c] === null) continue;
                tile.classList.add('hinted');
                marked.push(tile);
            }
        }
        setTimeout(function () {
            marked.forEach(function (t) { t.classList.remove('hinted'); });
        }, 1400);
    }

    // ─────────────────────────────────────────────────────────
    // 진행 · 종료
    // ─────────────────────────────────────────────────────────

    function startGame(mode) {
        state.mode = mode;
        state.dateKey = todayKST();
        state.score = 0;
        state.cleared = 0;
        state.words = [];
        state.combo = 0;
        state.maxCombo = 0;
        state.lastClearAt = 0;
        state.hintsLeft = HINT_LIMIT;
        state.drag = null;
        state.showWords = mode === 'easy';

        const seed = mode === 'daily'
            ? hashString('jamo-' + state.dateKey)
            : (Math.random() * 4294967296) >>> 0;
        const rand = mulberry32(seed);

        // 시작 시점에 충분히 풀 거리가 있는 판이 나올 때까지 다시 뽑는다.
        let cells = generateBoard(rand);
        for (let attempt = 0; attempt < 8; attempt++) {
            if (findSolutions(cells, 25).length >= 25) break;
            cells = generateBoard(rand);
        }
        state.cells = cells;

        paintBoard();
        clearHighlight();
        setStatus([], null);
        scoreEl.textContent = '0';
        hintBtn.textContent = '힌트 ' + HINT_LIMIT;
        hintBtn.disabled = false;

        wordPanelEl.hidden = !state.showWords;
        renderWordList();

        $('start-screen').hidden = true;
        $('end-screen').hidden = true;
        $('game-screen').hidden = false;
        $('mode-tag').textContent = mode === 'daily'
            ? MODE_LABEL.daily + ' · ' + state.dateKey
            : MODE_LABEL[mode];

        document.body.classList.add('playing');
        state.running = true;
        state.endsAt = performance.now() + ROUND_SECONDS * 1000;
        clearInterval(state.timerId);
        state.timerId = setInterval(tick, 100);
        tick();
    }

    function tick() {
        const now = performance.now();
        renderCombo(now);
        const left = Math.max(0, state.endsAt - now);
        const seconds = left / 1000;
        timeEl.textContent = Math.ceil(seconds);
        timebarEl.style.width = (left / (ROUND_SECONDS * 1000) * 100) + '%';
        timebarEl.classList.toggle('urgent', seconds <= 15);
        if (left <= 0) endGame('timeup');
    }

    function endGame(reason) {
        if (!state.running) return;
        state.running = false;
        clearInterval(state.timerId);
        clearHighlight();
        state.combo = 0;
        renderCombo(performance.now());
        document.body.classList.remove('playing');

        const key = bestKey(state.mode);
        const best = readNumber(key);
        const isBest = state.score > best;
        if (isBest) localStorage.setItem(key, String(state.score));

        if (state.mode === 'daily') recordDaily();

        const longest = state.words.reduce(function (a, b) {
            return decompose(b).length > decompose(a || '').length ? b : a;
        }, '');

        $('end-title').textContent = reason === 'nomoves' ? '더 만들 단어가 없습니다' : '시간 종료';
        $('end-score').textContent = state.score;
        $('end-detail').textContent =
            '자모 ' + state.cleared + '개 · 단어 ' + state.words.length + '개' +
            (state.maxCombo >= 2 ? ' · 최고 ' + state.maxCombo + '콤보' : '') +
            (longest ? ' · 최장 「' + longest + '」' : '');
        $('end-best').textContent = (isBest ? '🎉 최고 기록 경신!' : '최고 기록 ' + best + '점')
            + (state.mode === 'easy' ? ' (쉬움 모드 기준)' : '');
        $('end-words').textContent = state.words.length
            ? state.words.join(', ')
            : '이번 판에서는 한 단어도 만들지 못했습니다.';
        $('game-screen').hidden = true;
        $('again-btn').textContent = state.mode === 'easy' ? '쉬움 모드 한 판 더' : '연습 한 판 더';
        $('end-screen').hidden = false;
        $('daily-note').hidden = state.mode !== 'daily';
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    function recordDaily() {
        const key = STORE.daily + '.' + state.dateKey;
        if (localStorage.getItem(key) !== null) return;
        localStorage.setItem(key, String(state.score));

        const last = localStorage.getItem(STORE.lastDaily);
        const yesterday = (function () {
            const d = new Date(state.dateKey + 'T00:00:00');
            d.setDate(d.getDate() - 1);
            return d.toISOString().slice(0, 10);
        })();
        const streak = last === yesterday ? readNumber(STORE.streak) + 1 : 1;
        localStorage.setItem(STORE.streak, String(streak));
        localStorage.setItem(STORE.lastDaily, state.dateKey);
    }

    function tierEmoji(score) {
        if (score >= 200) return '🏆';
        if (score >= 140) return '🥇';
        if (score >= 90) return '🥈';
        if (score >= 50) return '🥉';
        return '🌱';
    }

    function shareResult() {
        const longest = state.words.reduce(function (a, b) {
            return decompose(b).length > decompose(a || '').length ? b : a;
        }, '');
        const lines = [
            '자모 사과게임 · ' + MODE_LABEL[state.mode] +
            (state.mode === 'daily' ? ' (' + state.dateKey + ')' : ''),
            tierEmoji(state.score) + ' ' + state.score + '점 · 단어 ' + state.words.length + '개' +
            (state.maxCombo >= 2 ? ' · 🔥' + state.maxCombo + '콤보' : '') +
            (longest ? ' · 최장 「' + longest + '」' : ''),
            location.origin + location.pathname,
        ];
        const text = lines.join('\n');

        if (navigator.share) {
            navigator.share({ text: text }).catch(function () { /* 사용자가 취소 */ });
            return;
        }
        navigator.clipboard.writeText(text).then(
            function () { toast('결과를 복사했습니다'); },
            function () { toast('복사에 실패했습니다'); }
        );
    }

    // ─────────────────────────────────────────────────────────
    // 초기화
    // ─────────────────────────────────────────────────────────

    function refreshStartScreen() {
        const best = readNumber(STORE.best);
        const easy = readNumber(STORE.bestEasy);
        const streak = readNumber(STORE.streak);
        $('best-score').textContent = best ? best + '점' : '-';
        $('best-easy').textContent = easy ? easy + '점' : '-';
        $('streak').textContent = streak ? streak + '일' : '-';

        const played = localStorage.getItem(STORE.daily + '.' + todayKST());
        const dailyBtn = $('start-daily');
        if (played !== null) {
            dailyBtn.textContent = '오늘의 판 다시 보기 (' + played + '점)';
        }
        $('dict-size').textContent = DICT.size;
    }

    function init() {
        boardEl = $('board');
        overlayEl = $('selection');
        scoreEl = $('score');
        timeEl = $('time');
        timebarEl = $('timebar-fill');
        statusEl = $('status');
        hintBtn = $('hint-btn');
        toastEl = $('toast');
        wordPanelEl = $('word-panel');
        wordListEl = $('word-list');
        wordCountEl = $('word-count');
        comboEl = $('combo');
        comboTextEl = $('combo-text');
        comboBarEl = $('combo-bar-fill');
        modeTagEl = $('mode-tag');

        buildBoardDom();
        refreshStartScreen();

        boardEl.addEventListener('pointerdown', onPointerDown);
        boardEl.addEventListener('pointermove', onPointerMove);
        boardEl.addEventListener('pointerup', onPointerUp);
        boardEl.addEventListener('pointercancel', onPointerUp);
        boardEl.addEventListener('contextmenu', function (e) { e.preventDefault(); });

        $('start-easy').addEventListener('click', function () { startGame('easy'); });
        $('start-daily').addEventListener('click', function () { startGame('daily'); });
        $('start-free').addEventListener('click', function () { startGame('free'); });
        // 한 판 더는 방금 하던 모드를 그대로 이어간다 (오늘의 판은 하루 한 번이라 연습으로).
        $('again-btn').addEventListener('click', function () {
            startGame(state.mode === 'daily' ? 'free' : state.mode);
        });
        $('share-btn').addEventListener('click', shareResult);
        $('home-btn').addEventListener('click', function () {
            $('end-screen').hidden = true;
            $('game-screen').hidden = true;
            $('start-screen').hidden = false;
            refreshStartScreen();
        });
        hintBtn.addEventListener('click', useHint);
        $('give-up-btn').addEventListener('click', function () { endGame('timeup'); });

        window.addEventListener('resize', function () {
            if (state.drag && state.drag.area) drawOverlay(state.drag.area, !!state.drag.info.word);
        });
    }

    // 브라우저에서는 바로 시작하고, Node에서는 순수 로직만 꺼내 테스트할 수 있게 한다.
    if (typeof module !== 'undefined' && module.exports) {
        module.exports = {
            BASIC: BASIC, COLS: COLS, ROWS: ROWS, DICT: DICT, BY_LEN: BY_LEN,
            decompose: decompose, keyFromJamo: keyFromJamo, scoreFor: scoreFor,
            comboMultiplier: comboMultiplier, COMBO_WINDOW: COMBO_WINDOW,
            mulberry32: mulberry32, hashString: hashString,
            generateBoard: generateBoard, findSolutions: findSolutions,
        };
    } else if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
