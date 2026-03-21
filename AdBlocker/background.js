'use strict';

// ============================================================
// AD DOMAINS — Netzwerk-Requests dieser Domains blockieren
// ============================================================
const AD_DOMAINS = [
  'doubleclick.net',
  'googleadservices.com',
  'googlesyndication.com',
  'google-analytics.com',
  'adservice.google.com',
  'adservice.google.de',
  'pagead2.googlesyndication.com',
  'static.doubleclick.net',
  'stats.g.doubleclick.net',
  'www.googletagservices.com',
  'securepubads.g.doubleclick.net',
  'tpc.googlesyndication.com'
];

// YouTube-interne Ad-Endpunkte
const YT_AD_PATHS = [
  '/pagead/',
  '/ptracking',
  '/api/stats/ads',
  '/api/stats/qoe',
  '/get_midroll_info',
  '/youtubei/v1/log_event'
];

// ============================================================
// STATE
// ============================================================
let enabled = true;
let blockedCount = 0;

// Aus Storage laden
browser.storage.local.get(['enabled', 'blockedCount']).then(data => {
  if (data.enabled !== undefined) enabled = data.enabled;
  if (data.blockedCount !== undefined) blockedCount = data.blockedCount;
});

// ============================================================
// NETZWERK-BLOCKING
// ============================================================
browser.webRequest.onBeforeRequest.addListener(
  (details) => {
    if (!enabled) return { cancel: false };

    const url = details.url.toLowerCase();

    // Ad-Domain prüfen
    for (const domain of AD_DOMAINS) {
      if (url.includes(domain)) {
        incrementCounter();
        return { cancel: true };
      }
    }

    // YouTube-interne Ad-Pfade prüfen
    if (url.includes('youtube.com')) {
      for (const path of YT_AD_PATHS) {
        if (url.includes(path)) {
          incrementCounter();
          return { cancel: true };
        }
      }
    }

    return { cancel: false };
  },
  {
    urls: [
      '*://*.doubleclick.net/*',
      '*://*.googleadservices.com/*',
      '*://*.googlesyndication.com/*',
      '*://*.google-analytics.com/*',
      '*://www.youtube.com/pagead/*',
      '*://www.youtube.com/ptracking*',
      '*://www.youtube.com/api/stats/ads*',
      '*://www.youtube.com/get_midroll_info*'
    ]
  },
  ['blocking']
);

// ============================================================
// ZÄHLER
// ============================================================
function incrementCounter() {
  blockedCount++;
  browser.storage.local.set({ blockedCount });
  // Alle Tabs über neuen Zähler informieren
  browser.tabs.query({ url: '*://www.youtube.com/*' }).then(tabs => {
    for (const tab of tabs) {
      browser.tabs.sendMessage(tab.id, { type: 'COUNTER_UPDATE', count: blockedCount }).catch(() => {});
    }
  });
}

// ============================================================
// NACHRICHTEN VOM POPUP
// ============================================================
browser.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === 'GET_STATE') {
    sendResponse({ enabled, blockedCount });
    return true;
  }

  if (msg.type === 'SET_ENABLED') {
    enabled = msg.value;
    browser.storage.local.set({ enabled });
    // Content Scripts auf YouTube-Tabs informieren
    browser.tabs.query({ url: '*://www.youtube.com/*' }).then(tabs => {
      for (const tab of tabs) {
        browser.tabs.sendMessage(tab.id, { type: 'SET_ENABLED', value: enabled }).catch(() => {});
      }
    });
    sendResponse({ ok: true });
    return true;
  }

  if (msg.type === 'RESET_COUNTER') {
    blockedCount = 0;
    browser.storage.local.set({ blockedCount: 0 });
    sendResponse({ ok: true });
    return true;
  }
});
