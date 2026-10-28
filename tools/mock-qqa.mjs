// Mock QQA console for exercising the Flutter app end to end.
//
// Implements exactly the contract the original Android app used, so whatever
// the UI shows here is what it would show against the real gateway:
//   GET  /api/status
//   GET  /api/sessions?limit=N
//   GET  /api/chats
//   GET  /api/chats/{key}/messages?limit=N
//   GET  /api/sessions/{id}
//   GET  /api/skills
//   POST /api/pause
//
// Everything is deterministic and shifts with the clock, so repeated refreshes
// visibly change the numbers instead of looking frozen.

import { createServer } from 'node:http';

const PORT = Number(process.env.PORT ?? 8788);

const startedAt = Date.now();
let paused = false;
let polls = 0;

const iso = (offsetMinutes) =>
  new Date(Date.now() + offsetMinutes * 60_000).toISOString();

const sessionDefs = [
  { id: 's-9f3a1c', status: 'running', sentCount: 4, summary: '帮我看看这个报错 [CQ:image,file=a.png] 下午三点前要' },
  { id: 's-2b7d40', status: 'waiting', sentCount: 1, summary: '把 build.gradle.kts 的 signingConfigs 挪到前面' },
  { id: 's-77e1aa', status: 'ended', sentCount: 9, summary: '统计这张图里所有积分消耗，加总 [CQ:image,file=b.png]' },
  { id: 's-5c08f2', status: 'ended', sentCount: 3, summary: '写一个 QQ 机器人的权限白名单，只认主人 openid' },
  { id: 's-a1b2c3', status: 'failed', sentCount: 0, summary: '在群里 @ 它测试群聊回复是否生效' },
  { id: 's-d4e5f6', status: 'ended', sentCount: 12, summary: '用 Rust + Flutter 重写这个 App，UI 照截图' },
];

const chatDefs = [
  { key: 'group:1905556262', name: '深测技术群', messages: [
    { role: 'user', text: '在吗 [CQ:at,qq=1905556262]' },
    { role: 'assistant', text: '在。有什么事？' },
    { role: 'user', text: '权限组的问题修好没有' },
    { role: 'assistant', text: '修好了。默认只认主人的 openid，陌生人在群里 @ 也只记日志不回复。' },
  ]},
  { key: 'private:C62E51C6291F70C23B368120EF53C44D', name: '主人私聊', messages: [
    { role: 'user', text: '把服务器的 web 关了' },
    { role: 'assistant', text: '已停掉 DSH-Web-Guard 计划任务，3752 端口关闭。桌面客户端还在跑。' },
    { role: 'user', text: '那客户端你能直接调用吗' },
    { role: 'assistant', text: '能。通过桌面 host 的 49800 走 Cookie 认证，隧道 13752 已经打通。' },
  ]},
];

const skills = [
  { id: 'dsh-qq-plugin', name: 'QQ 桥接', loaded: true, enabled: true, settingsUi: { file: 'settings.js', label: 'QQ 设置', views: [] } },
  { id: 'billion-context', name: '上下文压缩', loaded: true, enabled: true, settingsUi: { file: 'ctx.js', label: '压缩', views: [] } },
  { id: 'bettergi', name: 'BetterGI', loaded: false, enabled: false, settingsUi: { file: 'bgi.js', label: '原神', views: [] } },
];

const json = (res, body, status = 200) => {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(payload),
    'cache-control': 'no-store',
  });
  res.end(payload);
};

const notFound = (res) => json(res, { error: 'not found' }, 404);

const server = createServer((req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1');
  const path = url.pathname;

  if (req.method === 'POST' && path === '/api/pause') {
    let raw = '';
    req.on('data', (chunk) => { raw += chunk; });
    req.on('end', () => {
      try {
        paused = JSON.parse(raw || '{}').paused === true;
      } catch {
        return json(res, { error: 'bad json' }, 400);
      }
      json(res, { ok: true, paused });
    });
    return;
  }

  if (req.method !== 'GET') return notFound(res);

  if (path === '/api/status') {
    polls += 1;
    const calls = 119 + polls;
    return json(res, {
      onebot: { connected: true },
      paused,
      usage: {
        calls,
        totalTokens: 310_000 + polls * 137,
        promptTokens: 45_600 + polls * 61,
        completionTokens: 842 + polls * 3,
        cacheReadTokens: 264_000 + polls * 70,
      },
      cacheHitRate: 0.85,
      model: 'deepseek-flash',
      onebotTransport: 'reverse-ws',
      onebotUrl: 'ws://127.0.0.1:3002/onebot',
      uptimeSeconds: Math.round((Date.now() - startedAt) / 1000),
    });
  }

  if (path === '/api/sessions') {
    const limit = Number(url.searchParams.get('limit') ?? 50);
    return json(res, {
      sessions: sessionDefs.slice(0, limit).map((def, index) => ({
        id: def.id,
        status: def.status,
        endedAt: def.status === 'running' ? null : iso(-(index + 1) * 7),
        sentCount: def.sentCount,
        triggerSummary: def.summary,
      })),
    });
  }

  if (path === '/api/chats') {
    return json(res, {
      chats: chatDefs.map((chat, index) => ({
        key: chat.key,
        name: chat.name,
        lastMessage: chat.messages[chat.messages.length - 1].text,
        updatedAt: iso(-index * 3),
        count: chat.messages.length,
      })),
    });
  }

  if (path.startsWith('/api/chats/') && path.endsWith('/messages')) {
    const raw = decodeURIComponent(path.slice('/api/chats/'.length, -'/messages'.length));
    const key = raw.replace('_', ':');
    const chat = chatDefs.find((item) => item.key === key);
    if (!chat) return notFound(res);
    const limit = Number(url.searchParams.get('limit') ?? 80);
    return json(res, {
      messages: chat.messages.slice(-limit).map((message) => ({
        role: message.role,
        text: message.text,
      })),
    });
  }

  if (path.startsWith('/api/sessions/')) {
    const id = decodeURIComponent(path.slice('/api/sessions/'.length));
    const def = sessionDefs.find((item) => item.id === id);
    if (!def) return notFound(res);
    return json(res, {
      id: def.id,
      status: def.status,
      triggerSummary: def.summary,
      triggerText: def.summary,
      sent: [
        { type: 'text', text: '收到，我看一下。' },
        { type: 'text', text: '已经处理完了，结果在上面。' },
      ],
    });
  }

  if (path === '/api/skills') return json(res, { skills });

  return notFound(res);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`mock-qqa listening on http://127.0.0.1:${PORT}`);
});
