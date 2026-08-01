const MIN = 1;
const MAX = 45;
const PICKS = 6;
const MAX_FIXED = 5;
const STORAGE_KEY = 'lotto_saved_games';

const generateBtn = document.getElementById('generate-btn');
const resultsEl = document.getElementById('results');
const resultActions = document.getElementById('result-actions');
const errorMsg = document.getElementById('error-msg');
const fixedInput = document.getElementById('fixed-input');
const excludedInput = document.getElementById('excluded-input');
const savedCard = document.getElementById('saved-card');
const savedList = document.getElementById('saved-list');
const toast = document.getElementById('toast');

let currentGames = [];
let toastTimer = null;

// --- 옵션(세그먼트 버튼) ---

function setupSegmented(selector, onSelect) {
    document.querySelectorAll(selector).forEach((btn) => {
        btn.addEventListener('click', () => {
            btn.parentElement.querySelectorAll('.seg-btn').forEach((b) => b.classList.remove('active'));
            btn.classList.add('active');
            onSelect?.(btn);
        });
    });
}

setupSegmented('#game-count .seg-btn');
setupSegmented('.mode-btn');

function getGameCount() {
    return Number(document.querySelector('#game-count .seg-btn.active').dataset.count);
}

function getMode() {
    return document.querySelector('.mode-btn.active').dataset.mode;
}

// --- 입력 파싱 ---

function parseNumbers(value) {
    const seen = new Set();
    for (const token of value.split(/[,\s]+/)) {
        if (!token) continue;
        const n = Number(token);
        if (!Number.isInteger(n) || n < MIN || n > MAX) {
            throw new Error(`"${token}"은(는) 1~45 사이의 숫자가 아닙니다.`);
        }
        seen.add(n);
    }
    return [...seen];
}

function readOptions() {
    const fixed = parseNumbers(fixedInput.value);
    const excluded = parseNumbers(excludedInput.value);

    if (fixed.length > MAX_FIXED) {
        throw new Error(`고정수는 최대 ${MAX_FIXED}개까지 지정할 수 있습니다.`);
    }
    const overlap = fixed.filter((n) => excluded.includes(n));
    if (overlap.length) {
        throw new Error(`${overlap.join(', ')}번은 고정수와 제외수에 동시에 지정할 수 없습니다.`);
    }
    if (MAX - excluded.length < PICKS) {
        throw new Error('제외수가 너무 많아 6개를 뽑을 수 없습니다.');
    }
    return { fixed, excluded };
}

// --- 번호 생성 ---

function drawGame(fixed, excluded) {
    const pool = [];
    for (let n = MIN; n <= MAX; n++) {
        if (!excluded.includes(n) && !fixed.includes(n)) pool.push(n);
    }
    const picks = new Set(fixed);
    while (picks.size < PICKS) {
        const idx = Math.floor(Math.random() * pool.length);
        picks.add(pool.splice(idx, 1)[0]);
    }
    return [...picks].sort((a, b) => a - b);
}

// 균형 모드: 홀짝이 2:4~4:2 범위이고, 같은 10구간에 4개 이상 몰리지 않는 조합이 나올 때까지 재추첨
function isBalanced(numbers) {
    const odd = numbers.filter((n) => n % 2 === 1).length;
    if (odd < 2 || odd > 4) return false;
    const buckets = {};
    for (const n of numbers) {
        const b = Math.floor((n - 1) / 10);
        buckets[b] = (buckets[b] || 0) + 1;
        if (buckets[b] >= 4) return false;
    }
    return true;
}

function generateGames(count, mode, fixed, excluded) {
    const games = [];
    for (let i = 0; i < count; i++) {
        let game = drawGame(fixed, excluded);
        if (mode === 'balanced') {
            // 고정수/제외수 조합에 따라 균형 조건을 만족하는 조합이 없을 수 있으므로 시도 횟수를 제한
            for (let attempt = 0; attempt < 200 && !isBalanced(game); attempt++) {
                game = drawGame(fixed, excluded);
            }
        }
        games.push(game);
    }
    return games;
}

// --- 렌더링 ---

function ballColorClass(n) {
    return `b${Math.min(Math.floor((n - 1) / 10) + 1, 5)}`;
}

function renderBalls(numbers, fixed = []) {
    const wrap = document.createElement('div');
    wrap.className = 'balls';
    numbers.forEach((n, i) => {
        const ball = document.createElement('div');
        ball.className = `ball ${ballColorClass(n)}`;
        if (fixed.includes(n)) ball.classList.add('fixed');
        ball.style.animationDelay = `${i * 60}ms`;
        ball.textContent = n;
        wrap.appendChild(ball);
    });
    return wrap;
}

function renderResults(games, fixed) {
    resultsEl.innerHTML = '';
    games.forEach((game, i) => {
        const row = document.createElement('div');
        row.className = 'game-row';
        const label = document.createElement('span');
        label.className = 'game-label';
        label.textContent = String.fromCharCode(65 + i); // A, B, C...
        row.appendChild(label);
        row.appendChild(renderBalls(game, fixed));
        resultsEl.appendChild(row);
    });
    resultActions.hidden = games.length === 0;
}

// --- 저장 (localStorage) ---

function loadSaved() {
    try {
        return JSON.parse(localStorage.getItem(STORAGE_KEY)) || [];
    } catch {
        return [];
    }
}

function persistSaved(items) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
}

function renderSaved() {
    const items = loadSaved();
    savedCard.hidden = items.length === 0;
    savedList.innerHTML = '';
    items.forEach((item, idx) => {
        const li = document.createElement('li');
        li.className = 'saved-item';
        li.appendChild(renderBalls(item.numbers));

        const meta = document.createElement('div');
        meta.className = 'saved-meta';
        const date = document.createElement('span');
        date.className = 'saved-date';
        date.textContent = item.date;
        const del = document.createElement('button');
        del.className = 'delete-btn';
        del.setAttribute('aria-label', '이 번호 삭제');
        del.textContent = '×';
        del.addEventListener('click', () => {
            const next = loadSaved();
            next.splice(idx, 1);
            persistSaved(next);
            renderSaved();
        });
        meta.appendChild(date);
        meta.appendChild(del);
        li.appendChild(meta);
        savedList.appendChild(li);
    });
}

// --- 토스트 / 공유 ---

function showToast(message) {
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 2000);
}

function gamesToText(games) {
    return games
        .map((g, i) => `${String.fromCharCode(65 + i)}: ${g.join(', ')}`)
        .join('\n');
}

// --- 이벤트 ---

generateBtn.addEventListener('click', () => {
    errorMsg.hidden = true;
    try {
        const { fixed, excluded } = readOptions();
        currentGames = generateGames(getGameCount(), getMode(), fixed, excluded);
        renderResults(currentGames, fixed);
    } catch (err) {
        errorMsg.textContent = err.message;
        errorMsg.hidden = false;
        resultsEl.innerHTML = '';
        resultActions.hidden = true;
        currentGames = [];
    }
});

document.getElementById('save-btn').addEventListener('click', () => {
    if (!currentGames.length) return;
    const items = loadSaved();
    const date = new Date().toLocaleDateString('ko-KR', { month: 'short', day: 'numeric' });
    for (const numbers of currentGames) {
        items.unshift({ numbers, date });
    }
    persistSaved(items.slice(0, 50));
    renderSaved();
    showToast('번호를 저장했습니다');
});

document.getElementById('copy-btn').addEventListener('click', async () => {
    if (!currentGames.length) return;
    try {
        await navigator.clipboard.writeText(gamesToText(currentGames));
        showToast('클립보드에 복사했습니다');
    } catch {
        showToast('복사에 실패했습니다');
    }
});

document.getElementById('share-btn').addEventListener('click', async () => {
    if (!currentGames.length) return;
    const text = `이번 주 로또 번호 🍀\n${gamesToText(currentGames)}`;
    if (navigator.share) {
        try {
            await navigator.share({ title: '로또 번호 생성기', text });
        } catch {
            /* 사용자가 공유를 취소한 경우 */
        }
    } else {
        try {
            await navigator.clipboard.writeText(text);
            showToast('공유 문구를 복사했습니다');
        } catch {
            showToast('공유에 실패했습니다');
        }
    }
});

document.getElementById('clear-saved-btn').addEventListener('click', () => {
    persistSaved([]);
    renderSaved();
});

renderSaved();
