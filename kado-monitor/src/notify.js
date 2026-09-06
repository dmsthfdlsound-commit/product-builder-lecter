/**
 * 알림 채널: stdout, Discord/Slack/Telegram/generic webhook.
 * config.notify = [{ type: 'discord', url }, { type: 'telegram', token, chatId }, { type: 'slack', url }, { type: 'webhook', url }]
 */
export function createNotifier(channels = [], deps = {}) {
  const fetchImpl = deps.fetch ?? globalThis.fetch;
  const log = deps.log ?? console.log;

  async function post(url, body, headers = {}) {
    const res = await fetchImpl(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...headers },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`notify HTTP ${res.status}`);
  }

  return {
    /** @param {{title:string, lines:string[], level:string, url?:string}} m */
    async send(m) {
      const text = [`[${m.level.toUpperCase()}] ${m.title}`, ...m.lines, m.url ?? ''].filter(Boolean).join('\n');
      log(text);
      await Promise.allSettled(channels.map(async (c) => {
        try {
          if (c.type === 'discord') await post(c.url, { content: text.slice(0, 1900) });
          else if (c.type === 'slack') await post(c.url, { text });
          else if (c.type === 'telegram') await post(`https://api.telegram.org/bot${c.token}/sendMessage`, { chat_id: c.chatId, text, disable_web_page_preview: true });
          else if (c.type === 'webhook') await post(c.url, { ...m, text }, c.headers ?? {});
        } catch (e) {
          log(`알림 실패(${c.type}): ${e.message}`);
        }
      }));
    },
  };
}
