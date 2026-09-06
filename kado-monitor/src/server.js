/**
 * 의존성 없는 로컬 대시보드 서버.
 *  GET /            dashboard/index.html
 *  GET /api/state   현재 팩 분석 + 알림
 *  GET /events      SSE (사이클마다 state push)
 */
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

export function serializeState(state) {
  return {
    lastCycle: state.lastCycle, cycles: state.cycles, errors: state.errors, lastError: state.lastError ?? null,
    alerts: state.alerts.slice(0, 50),
    packs: [...state.packs.values()].map((e) => {
      const a = e.analysis;
      return {
        id: e.snapshot.id, name: e.snapshot.name, url: e.snapshot.url ?? null, gone: !!e.gone, updatedAt: e.updatedAt,
        price: a.price, remaining: a.remaining, totalInitial: a.totalInitial, evNet: a.evNet, evGross: a.evGross, roi: a.roi,
        profitProb1: a.profitProb1, profitCards: a.profitCards, buyoutRoi: a.buyout?.roi ?? null, bestK: a.bestK ?? null,
        topPrize: a.topPrize, valueCoverage: a.valueCoverage, soldOut: a.soldOut,
        prizes: (a.prizes ?? []).slice(0, 40),
        kCurve: (a.kCurve ?? []).filter((c) => c.k <= 10),
        history: e.history ?? [],
      };
    }),
  };
}

export function startServer({ state, port = 8787, host = '127.0.0.1', onListen }) {
  const clients = new Set();
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname === '/api/state') {
      res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
      res.end(JSON.stringify(serializeState(state)));
    } else if (url.pathname === '/events') {
      res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store', connection: 'keep-alive' });
      res.write(`data: ${JSON.stringify(serializeState(state))}\n\n`);
      clients.add(res);
      req.on('close', () => clients.delete(res));
    } else if (url.pathname === '/' || url.pathname === '/index.html') {
      const html = await readFile(join(here, '..', 'dashboard', 'index.html'));
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      res.end(html);
    } else {
      res.writeHead(404); res.end('not found');
    }
  });
  server.listen(port, host, () => onListen?.(`http://${host}:${port}`));
  const ping = setInterval(() => { for (const c of clients) c.write(': ping\n\n'); }, 25000);
  return {
    broadcast() {
      const data = `data: ${JSON.stringify(serializeState(state))}\n\n`;
      for (const c of clients) c.write(data);
    },
    close() { clearInterval(ping); for (const c of clients) c.end(); server.close(); },
  };
}
