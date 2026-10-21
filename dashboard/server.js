import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const port = Number(process.env.PORT ?? 5173);
const apiOrigin = process.env.API_ORIGIN ?? 'http://localhost:3000';
const root = process.cwd();
const types = { '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.html': 'text/html; charset=utf-8' };

const proxy = (request, response) => {
  const upstream = http.request(new URL(request.url, apiOrigin), { method: request.method, headers: request.headers }, (upstreamResponse) => {
    response.writeHead(upstreamResponse.statusCode ?? 502, upstreamResponse.headers);
    upstreamResponse.pipe(response);
  });
  upstream.on('error', () => {
    response.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8' });
    response.end(JSON.stringify({ error: 'Cloud backend is unavailable. Start it from the cloud folder.' }));
  });
  request.pipe(upstream);
};

http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host}`);
  if (url.pathname === '/health' || url.pathname.startsWith('/api/')) return proxy(request, response);
  const requested = url.pathname === '/' ? '/index.html' : url.pathname;
  const filePath = normalize(join(root, requested));
  if (!filePath.startsWith(root)) { response.writeHead(403); return response.end(); }
  try {
    const content = await readFile(filePath);
    response.writeHead(200, { 'Content-Type': types[extname(filePath)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
    response.end(content);
  } catch {
    response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('Not found');
  }
}).listen(port, () => console.log(`Hospital dashboard ready at http://localhost:${port}`));
