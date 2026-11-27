// Service worker: deixa o site abrir e funcionar sem internet.
// Os dados ficam no cache do Firestore (o próprio SDK guarda e reenvia as gravações quando a conexão volta).
const VERSION = "gym-v4";
const SHELL = ["/", "/index.html", "/style.css", "/app.js", "/edit.js", "/trainer.js", "/config.js", "/manifest.webmanifest",
  "/data/exercises.json", "/fonts/geist.woff2", "/fonts/geist-mono.woff2", "/fonts/bricolage-grotesque.woff2", "/fonts/silkscreen-400.woff2",
  "/icons/icon-192.png"];
const SDK = /^https:\/\/www\.gstatic\.com\/firebasejs\//;

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener("message", (e) => { if (e.data === "skip") self.skipWaiting(); });

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  // Firestore/Auth: nunca pelo cache do service worker (o SDK cuida do offline).
  if (url.hostname.includes("googleapis.com") || url.pathname.startsWith("/__/")) return;
  const sameOrigin = url.origin === location.origin;
  if (!sameOrigin && !SDK.test(req.url)) return;
  // Páginas: rede primeiro (pega versões novas), cache se estiver offline.
  if (req.mode === "navigate") {
    e.respondWith(fetch(req).then((r) => { cachePut("/index.html", r.clone()); return r; })
      .catch(() => caches.match(req).then((m) => m || caches.match("/index.html"))));
    return;
  }
  // Arquivos e SDK: cache primeiro e atualiza em segundo plano.
  e.respondWith(caches.match(req).then((hit) => {
    const net = fetch(req).then((r) => { if (r.ok) cachePut(req, r.clone()); return r; }).catch(() => hit);
    return hit || net;
  }));
});
function cachePut(key, res) { caches.open(VERSION).then((c) => c.put(key, res)).catch(() => {}); }
