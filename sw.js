/* sw.js — espotifai Service Worker */
const CACHE = 'espotifai-v1';
const STATIC = [
  '/',
  '/index.html',
  '/css/base.css',
  '/css/layout.css',
  '/css/components.css',
  '/css/utils.css',
  '/css/player.css',
  '/css/profile.css',
  '/views/search/search.css',
  '/views/library/library.css',
  '/views/import/import.css',
  '/views/stats/stats.css',
  '/views/search/search.html',
  '/views/library/library.html',
  '/views/import/import.html',
  '/views/stats/stats.html',
  '/js/app.js',
  '/js/player.js',
  '/js/search.js',
  '/js/library.js',
  '/js/import.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches
      .open(CACHE)
      .then((c) => c.addAll(STATIC))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  // API siempre network-first
  if (url.pathname.startsWith('/api/')) {
    e.respondWith(
      fetch(e.request).catch(
        () =>
          new Response(JSON.stringify({ error: 'offline' }), {
            headers: { 'Content-Type': 'application/json' },
          })
      )
    );
    return;
  }
  // Streams y descargas: solo network
  if (url.pathname.startsWith('/stream/') || url.pathname.startsWith('/downloads/')) {
    e.respondWith(fetch(e.request));
    return;
  }
  // Estáticos: cache-first
  e.respondWith(
    caches.match(e.request).then(
      (cached) =>
        cached ||
        fetch(e.request).then((res) => {
          if (res.ok) {
            const clone = res.clone();
            caches.open(CACHE).then((c) => c.put(e.request, clone));
          }
          return res;
        })
    )
  );
});
