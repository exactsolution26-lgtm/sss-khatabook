"""Cache public build assets only. Never cache API responses or user records."""
import json
import sys
from pathlib import Path


def install(root: Path, revision: str):
    index = root / 'index.html'
    source = index.read_text()
    source = source.replace('</body>', "<script>if ('serviceWorker' in navigator) { navigator.serviceWorker.register('./sss-sw.js').catch(() => {}); }</script>\n</body>")
    index.write_text(source)
    resources = sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name != 'sss-sw.js')
    worker = '''const CACHE = __CACHE__;
const FILES = __FILES__;
const ROOT = new URL('./', self.location.href);
self.addEventListener('install', event => event.waitUntil((async () => {
  try { await (await caches.open(CACHE)).addAll(FILES.map(file => new URL(file, ROOT).href)); }
  catch (error) { await caches.delete(CACHE); throw error; }
})()));
self.addEventListener('activate', event => event.waitUntil((async () => {
  for (const name of await caches.keys()) if (name.startsWith('sss-static-') && name !== CACHE) await caches.delete(name);
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== ROOT.origin || !url.pathname.startsWith(ROOT.pathname)) return;
  const file = url.pathname.substring(ROOT.pathname.length);
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(async () => (await caches.open(CACHE)).match(new URL('index.html', ROOT).href)));
  } else if (FILES.includes(file)) {
    event.respondWith((async () => (await (await caches.open(CACHE)).match(new URL(file, ROOT).href, {ignoreSearch:true})) || fetch(request))());
  }
});
'''.replace('__CACHE__', json.dumps('sss-static-' + revision)).replace('__FILES__', json.dumps(resources))
    (root / 'sss-sw.js').write_text(worker)
    return resources


if __name__ == '__main__':
    print(f'Offline public assets: {len(install(Path(sys.argv[1]), sys.argv[2]))}')
