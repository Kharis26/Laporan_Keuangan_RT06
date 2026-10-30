const CACHE_NAME = "keuangan-rt06-pwa-v1";
const APP_SHELL = ["./","./index.html","./styles.css?v=rt06-v6","./config.js?v=rt06-v5","./app.js?v=rt06-v7","./logo-rt06-rw08.jpg","./manifest.json","./offline.html","./icons/icon-192.png","./icons/icon-512.png","./icons/icon-512-maskable.png"];
self.addEventListener("install",e=>e.waitUntil(caches.open(CACHE_NAME).then(c=>c.addAll(APP_SHELL)).then(()=>self.skipWaiting())));
self.addEventListener("activate",e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE_NAME).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener("fetch",e=>{
 const r=e.request,u=new URL(r.url);
 if(u.origin!==self.location.origin||r.method!=="GET") return;
 if(r.mode==="navigate"){
  e.respondWith(fetch(r).then(res=>{const copy=res.clone();caches.open(CACHE_NAME).then(c=>c.put("./index.html",copy));return res;})
   .catch(async()=> (await caches.match(r))||(await caches.match("./index.html"))||(await caches.match("./offline.html"))));
  return;
 }
 e.respondWith(caches.match(r).then(hit=>hit||fetch(r).then(res=>{if(res.ok){const cp=res.clone();caches.open(CACHE_NAME).then(c=>c.put(r,cp));}return res;})));
});
