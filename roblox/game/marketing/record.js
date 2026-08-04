// 10초 × 30fps = 300 프레임을 결정론적으로 캡처
const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');
const { globSync } = require('fs');

const DIR = __dirname;
const FPS = 30, DUR = 10.0;

function findChrome() {
  const base = '/opt/pw-browsers';
  for (const d of fs.readdirSync(base)) {
    if (d.startsWith('chromium-')) {
      const p = path.join(base, d, 'chrome-linux', 'chrome');
      if (fs.existsSync(p)) return p;
    }
  }
  const direct = path.join(base, 'chromium');
  if (fs.existsSync(direct)) return direct;
  throw new Error('chromium not found');
}

(async () => {
  // 스케줄 주입
  const schedule = fs.readFileSync(path.join(DIR, 'schedule.json'), 'utf8');
  const html = fs.readFileSync(path.join(DIR, 'teaser.html'), 'utf8')
    .replace('__SCHEDULE__', schedule);
  const pagePath = path.join(DIR, 'teaser.built.html');
  fs.writeFileSync(pagePath, html);

  const framesDir = path.join(DIR, 'frames');
  fs.rmSync(framesDir, { recursive: true, force: true });
  fs.mkdirSync(framesDir);

  const browser = await chromium.launch({
    executablePath: findChrome(),
    args: ['--no-sandbox', '--force-device-scale-factor=2', '--hide-scrollbars'],
  });
  const page = await browser.newPage({
    viewport: { width: 540, height: 960 },
    deviceScaleFactor: 2,
  });
  await page.goto('file://' + pagePath);
  await page.waitForFunction('window.ready === true');

  const total = Math.round(DUR * FPS);
  for (let i = 0; i < total; i++) {
    const t = i / FPS;
    await page.evaluate(tt => window.setT(tt), t);
    await page.screenshot({
      path: path.join(framesDir, 'f' + String(i).padStart(4, '0') + '.png'),
    });
    if (i % 60 === 0) console.log(`frame ${i}/${total}`);
  }
  await browser.close();
  console.log('frames done:', total);
})().catch(e => { console.error(e); process.exit(1); });
