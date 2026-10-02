/**
 * MindMaster — Service Worker
 * Version: 1.1.0
 *
 * Cache-first offline strategy. The entire app is static, so we
 * precache every game page and asset at install time and serve
 * from cache first, falling back to network only for misses.
 */

const CACHE_NAME = 'mindmaster-v1.1.0';

const CORE_ASSETS = [
  './',
  './index.html',
  './math-sprint.html',
  './logic-puzzles.html',
  './color-match.html',
  './focus-grid.html',
  './memory-matrix.html',
  './pattern-recall.html',
  './assets/css/styles.css',
  './assets/js/core/game-engine.js',
  './assets/js/core/storage.js',
  './assets/js/core/audio.js',
  './assets/js/core/haptics.js',
  './assets/js/core/mouse-tracker.js',
  './assets/js/core/notifications.js',
  './assets/js/games/shared/components.js',
  './assets/js/games/math_sprint/math_sprint.js',
  './assets/js/games/logic_puzzles/logic_puzzles.js',
  './assets/js/games/color_match/color_match.js',
  './assets/js/games/focus_grid/focus_grid.js',
  './assets/js/games/memory_matrix/memory_matrix.js',
  './assets/js/games/pattern_recall/pattern_recall.js',
  './manifest.json',
];

// Install: precache the whole app shell.
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      // Use addAll with individual error tolerance: a single missing
      // asset must not break the whole install.
      return Promise.allSettled(
        CORE_ASSETS.map((url) =>
          cache.add(url).catch((err) =>
            console.warn('[SW] cache-add failed:', url, err)
          )
        )
      );
    })
  );
  self.skipWaiting();
});

// Activate: drop old caches.
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.map((k) => (k !== CACHE_NAME ? caches.delete(k) : null)))
    )
  );
  self.clients.claim();
});

// Fetch: cache-first, then network, then cache fallback.
self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Only handle GET requests.
  if (request.method !== 'GET') return;

  // Never touch cross-origin requests (fonts, analytics, etc.).
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) return cached;

      return fetch(request)
        .then((response) => {
          // Cache successful same-origin responses for offline use.
          if (response && response.status === 200 && response.type === 'basic') {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        })
        .catch(() => caches.match('./index.html'));
    })
  );
});
