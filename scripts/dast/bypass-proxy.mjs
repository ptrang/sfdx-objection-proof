// Local reverse proxy for DAST against a protected Vercel preview.
// Forwards every request to TARGET_URL and adds the x-vercel-protection-bypass
// header, so ZAP's attack requests reach the app instead of the Vercel login.
//   TARGET_URL=https://<preview>.vercel.app VERCEL_BYPASS=... node bypass-proxy.mjs
import http from 'node:http';
import https from 'node:https';

const target = new URL(process.env.TARGET_URL);
const bypass = process.env.VERCEL_BYPASS;
const port = Number(process.env.PROXY_PORT || 8787);
if (!bypass) throw new Error('VERCEL_BYPASS is required');
let forwarded = 0;

http.createServer((req, res) => {
  const headers = { ...req.headers, host: target.host, 'x-vercel-protection-bypass': bypass };
  delete headers['accept-encoding']; // keep responses readable for ZAP
  const up = https.request(
    { hostname: target.hostname, port: 443, path: req.url, method: req.method, headers },
    (r) => { res.writeHead(r.statusCode || 502, r.headers); r.pipe(res); },
  );
  up.on('error', (e) => { res.writeHead(502); res.end(String(e.message)); });
  req.pipe(up);
  forwarded++;
}).listen(port, '127.0.0.1', () => console.log(`bypass proxy on http://127.0.0.1:${port} -> ${target.origin}`));

process.on('SIGTERM', () => { console.log(`forwarded ${forwarded} requests`); process.exit(0); });
