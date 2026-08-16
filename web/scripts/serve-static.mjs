#!/usr/bin/env node
// Minimal static file server for `out/`, used by the Playwright suite.
//
// Deliberately tiny and dependency-free: adding a server package to serve a
// static export would be an unauthorized dependency under the accepted refreeze,
// and the suite needs nothing more than "return these bytes over HTTP".

import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, extname, dirname, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'out');
const PORT = Number(process.env.PORT ?? 4321);

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.txt': 'text/plain; charset=utf-8',
};

async function resolve(urlPath) {
  // Contain traversal: normalise, strip leading separators, and refuse anything
  // that escapes the export root.
  const clean = normalize(decodeURIComponent(urlPath.split('?')[0])).replace(/^([/\\])+/, '');
  const base = join(OUT, clean);
  if (!base.startsWith(OUT)) return null;
  for (const candidate of [base, `${base}.html`, join(base, 'index.html')]) {
    try {
      const s = await stat(candidate);
      if (s.isFile()) return candidate;
    } catch { /* try the next shape */ }
  }
  return null;
}

createServer(async (req, res) => {
  const file = await resolve(req.url === '/' ? '/index.html' : req.url);
  if (!file) {
    res.writeHead(404, { 'content-type': 'text/plain' });
    res.end('not found');
    return;
  }
  const body = await readFile(file);
  res.writeHead(200, { 'content-type': TYPES[extname(file)] ?? 'application/octet-stream' });
  res.end(body);
}).listen(PORT, () => console.log(`static export served on http://127.0.0.1:${PORT}`));
