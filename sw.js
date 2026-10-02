// Service Worker: macht Ballonalarm offline spielbar.
// Nach jeder Änderung an den Dateien VERSION hochzählen, damit alle Geräte die neue Fassung laden.
const VERSION = 'ballonalarm-v1';
const ASSETS = [
  './',
  'index.html',
  'config.js',
  'manifest.webmanifest',
  'fonts/lilita-one-latin.woff2',
  'fonts/nunito-latin.woff2',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'icons/icon-maskable-512.png',
  'icons/apple-touch-icon.png',
  'icons/favicon-32.png',
  'vendor/supabase.js',
  'legal.css',
  'impressum.html',
  'datenschutz.html'
];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(VERSION).then(cache => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // Supabase & Co. gehen immer direkt ins Netz

  // Seitenaufrufe: erst Netz (damit Updates sofort ankommen), offline aus dem Cache.
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then(res => {
          if (res.ok) { const copy = res.clone(); caches.open(VERSION).then(c => c.put('index.html', copy)); }
          return res;
        })
        .catch(() => caches.match(req).then(hit => hit || caches.match('index.html')))
    );
    return;
  }

  // Alles andere: sofort aus dem Cache, im Hintergrund auffrischen.
  event.respondWith(
    caches.match(req).then(cached => {
      const fresh = fetch(req)
        .then(res => {
          if (res.ok) { const copy = res.clone(); caches.open(VERSION).then(c => c.put(req, copy)); }
          return res;
        })
        .catch(() => cached);
      return cached || fresh;
    })
  );
});
