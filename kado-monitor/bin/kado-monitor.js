#!/usr/bin/env node
/**
 * kado-monitor CLI
 *   analyze <file.json> [--fee 0.1] [--haircut 0.9] [--pack <id>]   파일 스냅샷 분석(표 출력)
 *   scan   [--config config.json]                                    1회 조회 후 요약표
 *   watch  [--config config.json] [--port 8787] [--no-serve]         실시간 감시 + 대시보드
 *   discover [--url https://kado.trade/] [--headed] [--out dir]      API 자동 탐지
 */
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { analyzePack } from '../src/ev.js';
import { createAdapter } from '../src/adapters/index.js';
import { createNotifier } from '../src/notify.js';
import { createMonitorState, loadState, startMonitor } from '../src/monitor.js';
import { startServer } from '../src/server.js';
import { summaryTable, detailReport } from '../src/format.js';

const [, , cmd = 'help', ...rest] = process.argv;
const args = parseArgs(rest);

function parseArgs(list) {
  const out = { _: [] };
  for (let i = 0; i < list.length; i++) {
    const a = list[i];
    if (a.startsWith('--')) {
      const k = a.slice(2);
      if (k.startsWith('no-')) out[k.slice(3)] = false;
      else if (list[i + 1] != null && !list[i + 1].startsWith('--')) out[k] = list[++i];
      else out[k] = true;
    } else out._.push(a);
  }
  return out;
}

async function loadConfig() {
  const p = resolve(args.config ?? 'config.json');
  try { return JSON.parse(await readFile(p, 'utf8')); }
  catch (e) { throw new Error(`설정 파일을 읽을 수 없습니다: ${p} (${e.message}). config.example.json 을 복사해 시작하세요.`); }
}

const analysisArgs = () => ({
  feeRate: args.fee != null ? Number(args.fee) : undefined,
  haircut: args.haircut != null ? Number(args.haircut) : undefined,
});

async function main() {
  if (cmd === 'analyze') {
    const file = args._[0];
    if (!file) throw new Error('분석할 JSON 파일 경로가 필요합니다.');
    const adapter = createAdapter({ source: 'file', path: file, limitedFilter: false });
    const snaps = await adapter.fetchPacks();
    const opts = Object.fromEntries(Object.entries(analysisArgs()).filter(([, v]) => v !== undefined));
    const analyses = snaps.map((s) => analyzePack(s, opts));
    console.log(summaryTable(analyses));
    const detail = args.pack ? analyses.filter((a) => a.id === args.pack || a.name === args.pack) : (analyses.length === 1 ? analyses : []);
    for (const a of detail) console.log('\n' + detailReport(a));
    return;
  }
  if (cmd === 'scan') {
    const config = await loadConfig();
    const adapter = createAdapter(config.adapter ?? config);
    const snaps = await adapter.fetchPacks();
    const analyses = snaps.map((s) => analyzePack(s, { ...(config.analysis ?? {}), ...Object.fromEntries(Object.entries(analysisArgs()).filter(([, v]) => v !== undefined)) }));
    console.log(summaryTable(analyses));
    if (args.detail) for (const a of analyses) console.log('\n' + detailReport(a));
    return;
  }
  if (cmd === 'watch') {
    const config = await loadConfig();
    config.stateDir = config.stateDir ?? 'state';
    const adapter = createAdapter(config.adapter ?? config);
    const notifier = createNotifier(config.notify ?? []);
    const state = config.resume === false ? createMonitorState() : await loadState(config.stateDir);
    let server = null;
    if (args.serve !== false && config.serve !== false) {
      server = startServer({ state, port: Number(args.port ?? config.port ?? 8787), host: config.host ?? '127.0.0.1', onListen: (u) => console.log(`대시보드: ${u}`) });
    }
    const stop = startMonitor({
      adapter, notifier, state, config,
      onUpdate: (ev) => {
        const ts = new Date(ev.at).toLocaleTimeString('ko-KR');
        if (ev.type === 'cycle') console.log(`[${ts}] ${adapter.name} 조회 ${ev.packs}팩, 알림 ${ev.fired}건`);
        else console.error(`[${ts}] 오류: ${ev.msg}`);
        server?.broadcast();
      },
    });
    const bye = () => { stop(); server?.close(); process.exit(0); };
    process.on('SIGINT', bye); process.on('SIGTERM', bye);
    return;
  }
  if (cmd === 'discover') {
    const { runDiscover } = await import('../src/discover.js');
    await runDiscover({ url: args.url, headed: !!args.headed, outDir: args.out, waitMs: args.wait ? Number(args.wait) : undefined, storageState: args.state });
    return;
  }
  console.log(`kado-monitor
  analyze <file.json> [--fee 0.1] [--haircut 0.9] [--pack <id>]
  scan     [--config config.json] [--detail]
  watch    [--config config.json] [--port 8787] [--no-serve]
  discover [--url https://kado.trade/] [--headed] [--out discover-out] [--state discover-out/storageState.json]`);
}

main().catch((e) => { console.error(e.message ?? e); process.exit(1); });
