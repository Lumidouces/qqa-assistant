// Rewrites Host/Origin so the QQA console (which only trusts 127.0.0.1:3210)
// accepts requests arriving through a public tunnel.
const http = require('http');

const LISTEN = Number(process.env.LISTEN_PORT || 13211);
const UP_HOST = process.env.UP_HOST || '127.0.0.1';
const UP_PORT = Number(process.env.UP_PORT || 13210);
const FAKE_AUTH = `127.0.0.1:${process.env.ORIGIN_PORT || 3210}`;

http
  .createServer((req, res) => {
    if (process.env.LOG_REQ === '1') {
      console.log(new Date().toISOString(), req.method, req.url, '|', req.headers.host, '|', req.headers['user-agent'] || '-');
    }
    const headers = { ...req.headers, host: FAKE_AUTH };
    if (headers.origin) headers.origin = `http://${FAKE_AUTH}`;
    if (headers.referer) headers.referer = `http://${FAKE_AUTH}/`;
    delete headers['x-forwarded-for'];
    delete headers['cf-connecting-ip'];
    delete headers['cf-ipcountry'];

    const up = http.request(
      { host: UP_HOST, port: UP_PORT, path: req.url, method: req.method, headers },
      (r) => {
        res.writeHead(r.statusCode || 502, r.headers);
        r.pipe(res);
      },
    );
    up.on('error', (e) => {
      res.writeHead(502, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: `upstream: ${e.message}` }));
    });
    req.pipe(up);
  })
  .listen(LISTEN, '127.0.0.1', () => {
    console.log(`qqa-proxy ${LISTEN} -> ${UP_HOST}:${UP_PORT} (host=${FAKE_AUTH})`);
  });
