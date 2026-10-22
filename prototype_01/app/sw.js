/* OneStop Snake Watch — offline app shell */
const V = "snakewatch-v3";
const SHELL = [
  "./app.html",
  "./OneStop Snake Watch.dc.html",
  "./snake-map.html",
  "./snake-clear.html",
  "./support.js",
  "./manifest.webmanifest",
  "./data/map-features.js",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./icons/icon-maskable-512.png",
  "./assets/one-stop-logo.svg"
];

self.addEventListener("install", e => {
  e.waitUntil((async () => {
    const c = await caches.open(V);
    await Promise.all(SHELL.map(u => c.add(new Request(u, { cache: "reload" })).catch(() => {})));
    self.skipWaiting();
  })());
});

self.addEventListener("activate", e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== V).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

const isDoc = (req, url) =>
  req.mode === "navigate" || /\.(html|js|json|webmanifest)$/i.test(url.pathname);

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  const tile = /tile\.openstreetmap\.org|basemaps\.cartocdn|arcgisonline|unpkg\.com|fonts\.(googleapis|gstatic)\.com/.test(url.host);
  const same = url.origin === location.origin;
  if (!same && !tile) return;

  // HTML / JS / manifest: network-first so edits and redeploys land immediately
  if (same && isDoc(req, url)) {
    e.respondWith((async () => {
      const c = await caches.open(V);
      try {
        const res = await fetch(req, { cache: "no-store" });
        if (res && res.ok) c.put(req, res.clone()).catch(() => {});
        return res;
      } catch (err) {
        return (await c.match(req, { ignoreSearch: true })) || new Response("", { status: 504 });
      }
    })());
    return;
  }

  // images, fonts, map tiles: cache-first, refreshed in the background
  e.respondWith((async () => {
    const c = await caches.open(V);
    const hit = await c.match(req, { ignoreSearch: same });
    const net = fetch(req).then(res => {
      if (res && (res.ok || res.type === "opaque")) c.put(req, res.clone()).catch(() => {});
      return res;
    }).catch(() => null);
    if (hit) { net; return hit; }
    return (await net) || new Response("", { status: 504 });
  })());
});

// local alert notifications posted from the app
self.addEventListener("message", e => {
  const d = e.data || {};
  if (d.type === "notify") {
    self.registration.showNotification(d.title || "Snake Watch", {
      body: d.body || "",
      icon: "icons/icon-192.png",
      badge: "icons/icon-192.png",
      vibrate: [90, 50, 90],
      tag: d.tag || "snake-alert",
      renotify: true,
      data: { url: "./app.html" }
    });
  }
});

self.addEventListener("notificationclick", e => {
  e.notification.close();
  e.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    const open = all.find(c => c.url.indexOf("app.html") > -1);
    if (open) return open.focus();
    return self.clients.openWindow("./app.html");
  })());
});
