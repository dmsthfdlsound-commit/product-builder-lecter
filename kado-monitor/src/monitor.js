/**
 * 폴링 루프: 어댑터 → 분석 → 규칙 평가 → 알림 → 상태 저장.
 * 한 사이클을 순수하게 실행하는 runCycle 과, 주기 실행 startMonitor 로 나뉜다.
 */
import { mkdir, readFile, writeFile, appendFile } from 'node:fs/promises';
import { join } from 'node:path';
import { analyzePack, evaluateRules, pct, fmt } from './ev.js';

export function createMonitorState() {
  return { packs: new Map(), alerts: [], lastCycle: null, cycles: 0, errors: 0 };
}

/**
 * @param {object} ctx { adapter, notifier, state, config, now?, onUpdate? }
 */
export async function runCycle(ctx) {
  const { adapter, notifier, state, config } = ctx;
  const now = ctx.now ? ctx.now() : Date.now();
  const analysisOpts = config.analysis ?? {};
  const rules = config.rules ?? {};
  const cooldownMs = (config.alertCooldownSec ?? 600) * 1000;

  let snaps;
  try {
    snaps = await adapter.fetchPacks();
  } catch (e) {
    state.errors++;
    state.lastError = { at: now, msg: String(e.message ?? e) };
    ctx.onUpdate?.({ type: 'error', at: now, msg: state.lastError.msg });
    return { ok: false, error: state.lastError.msg };
  }

  const fired = [];
  const seen = new Set();
  for (const snap of snaps) {
    seen.add(snap.id);
    const a = analyzePack(snap, { ...analysisOpts, monteCarloTrials: analysisOpts.monteCarloTrials ?? 2000 });
    const prevEntry = state.packs.get(snap.id);
    const prev = prevEntry?.analysis ?? null;
    const triggers = evaluateRules(a, prev, rules);
    const lastFired = prevEntry?.lastFired ?? {};

    const deliverable = triggers.filter((t) => {
      if (t.level === 'warn') return false;
      const last = lastFired[t.rule] ?? 0;
      return now - last >= cooldownMs;
    });
    for (const t of deliverable) lastFired[t.rule] = now;

    const entry = {
      snapshot: snap, analysis: a, updatedAt: now, lastFired,
      history: [...(prevEntry?.history ?? []).slice(-((config.historyLength ?? 200) - 1)), { t: now, roi: a.roi, remaining: a.remaining, evNet: a.evNet }],
      changed: prev ? prev.remaining !== a.remaining : true,
    };
    state.packs.set(snap.id, entry);

    if (deliverable.length) {
      const msg = formatAlert(a, deliverable, snap);
      fired.push({ id: snap.id, at: now, ...msg });
      state.alerts.unshift({ id: snap.id, name: a.name, at: now, level: msg.level, triggers: deliverable });
      state.alerts = state.alerts.slice(0, 200);
      await notifier.send(msg);
    }
  }
  // 목록에서 사라진 팩은 품절/종료로 표시
  for (const [id, entry] of state.packs) {
    if (!seen.has(id) && !entry.gone) { entry.gone = true; entry.goneAt = now; }
  }

  state.lastCycle = now;
  state.cycles++;
  ctx.onUpdate?.({ type: 'cycle', at: now, packs: snaps.length, fired: fired.length });
  return { ok: true, packs: snaps.length, fired };
}

export function formatAlert(a, triggers, snap) {
  const level = triggers.some((t) => t.level === 'alert') ? 'alert' : 'info';
  const lines = [
    `가격 ${fmt(a.price)} · 잔여 ${a.remaining}/${a.totalInitial || '?'}장 · 순EV ${fmt(a.evNet)} · ROI ${pct(a.roi)}`,
    a.topPrize ? `최고가: ${a.topPrize.name} ${fmt(a.topPrize.value)} × ${a.topPrize.remaining}장 (${pct(a.topPrize.prob)})` : '',
    `1회 이득카드 확률 ${pct(a.profitProb1)} · 싹쓸이 ROI ${a.buyout ? pct(a.buyout.roi) : '-'}${a.bestK ? ` · 권장 ${a.bestK}회` : ''}`,
    ...triggers.map((t) => `• ${t.msg}`),
  ].filter(Boolean);
  return { title: a.name, level, lines, url: snap.url ?? undefined };
}

/** 상태 영속화 (state/packs.json + history.jsonl) */
export async function persistState(state, dir) {
  await mkdir(dir, { recursive: true });
  const packs = Object.fromEntries([...state.packs].map(([id, e]) => [id, { ...e, analysis: slimAnalysis(e.analysis) }]));
  await writeFile(join(dir, 'packs.json'), JSON.stringify({ savedAt: Date.now(), packs, alerts: state.alerts.slice(0, 50) }, null, 2));
  const line = { t: state.lastCycle, packs: [...state.packs.values()].filter((e) => !e.gone).map((e) => ({ id: e.snapshot.id, name: e.snapshot.name, roi: e.analysis.roi, remaining: e.analysis.remaining, evNet: e.analysis.evNet })) };
  await appendFile(join(dir, 'history.jsonl'), JSON.stringify(line) + '\n');
}

export async function loadState(dir) {
  const state = createMonitorState();
  try {
    const j = JSON.parse(await readFile(join(dir, 'packs.json'), 'utf8'));
    for (const [id, e] of Object.entries(j.packs ?? {})) state.packs.set(id, e);
    state.alerts = j.alerts ?? [];
  } catch { /* 첫 실행 */ }
  return state;
}

function slimAnalysis(a) {
  if (!a) return a;
  const { kCurve, prizes, ...rest } = a;
  return { ...rest, prizes: prizes?.slice(0, 30), kCurve: kCurve?.filter((c) => c.k <= 10) };
}

/** 주기 실행. stop() 반환. */
export function startMonitor(ctx) {
  const intervalMs = (ctx.config.intervalSec ?? 30) * 1000;
  let timer = null; let running = false; let stopped = false;
  const tick = async () => {
    if (running || stopped) return;
    running = true;
    try {
      await runCycle(ctx);
      if (ctx.config.stateDir) await persistState(ctx.state, ctx.config.stateDir);
    } catch (e) {
      ctx.onUpdate?.({ type: 'error', at: Date.now(), msg: String(e.message ?? e) });
    } finally {
      running = false;
      if (!stopped) timer = setTimeout(tick, jitter(intervalMs, ctx.config.jitter ?? 0.15));
    }
  };
  tick();
  return () => { stopped = true; if (timer) clearTimeout(timer); };
}

/** 폴링 간격에 무작위 흔들림을 줘서 봇 패턴을 완화 */
function jitter(ms, ratio) {
  return Math.round(ms * (1 + (Math.random() * 2 - 1) * ratio));
}
