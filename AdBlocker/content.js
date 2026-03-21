'use strict';

// ============================================================
// STATE
// ============================================================
let enabled = true;
let domBlockedCount = 0;

// ============================================================
// AD-SELEKTOREN — DOM-Elemente die entfernt werden
// ============================================================
const AD_SELECTORS = [
  // Video-Ad Overlay & Player
  '.ad-showing',
  '.ad-interrupting',
  '#player-ads',
  '.ytp-ad-module',
  '.ytp-ad-overlay-container',
  '.ytp-ad-text-overlay',
  '.ytp-ad-player-overlay',
  '.ytp-ad-image-overlay',

  // Seitenleiste & Feed
  '#masthead-ad',
  'ytd-banner-promo-renderer',
  'ytd-statement-banner-renderer',
  'ytd-ad-slot-renderer',
  'ytd-in-feed-ad-layout-renderer',
  'ytd-promoted-sparkles-web-renderer',
  'ytd-promoted-video-renderer',
  'ytd-display-ad-renderer',
  'ytd-compact-promoted-item-renderer',

  // Weitere bekannte Ad-Container
  '#ad-container',
  '.ytd-rich-item-renderer[is-ad]',
  'tp-yt-paper-dialog:has(.ytd-ad-slot-renderer)'
];

// ============================================================
// DOM ADS ENTFERNEN
// ============================================================
function removeAdElements() {
  if (!enabled) return;
  for (const selector of AD_SELECTORS) {
    try {
      document.querySelectorAll(selector).forEach(el => {
        if (el && el.parentNode) {
          el.remove();
          domBlockedCount++;
          notifyBackground();
        }
      });
    } catch (e) {
      // Ungültiger Selektor ignorieren
    }
  }
}

// ============================================================
// VIDEO-AD AUTO-SKIP
// ============================================================
function handleVideoAd() {
  if (!enabled) return;

  const video = document.querySelector('video');
  if (!video) return;

  // Prüfen ob gerade eine Ad läuft
  const adBadge = document.querySelector('.ytp-ad-simple-ad-badge, .ytp-ad-preview-container');
  const adShowing = document.querySelector('.ad-showing');

  if (adShowing || adBadge) {
    // 1. Versuch: Skip-Button klicken
    const skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, [class*="skip-button"]');
    if (skipBtn) {
      skipBtn.click();
      return;
    }

    // 2. Versuch: Video ans Ende spulen
    if (video.duration && isFinite(video.duration) && video.duration > 0) {
      video.currentTime = video.duration;
      // Playback-Rate erhöhen damit die Ad schneller vorbei ist
      video.playbackRate = 16;
    }
  } else {
    // Normale Playback-Rate wiederherstellen
    if (video.playbackRate !== 1) {
      video.playbackRate = 1;
    }
  }
}

// ============================================================
// MUTATION OBSERVER — Dynamisch geladene Ads abfangen
// ============================================================
const observer = new MutationObserver(() => {
  if (!enabled) return;
  removeAdElements();
  handleVideoAd();
});

function startObserver() {
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true
  });
}

// Video-Ad Polling (alle 300ms) weil YouTube den DOM oft nicht ändert
let adCheckInterval = null;

function startAdCheck() {
  if (adCheckInterval) return;
  adCheckInterval = setInterval(() => {
    if (!enabled) return;
    handleVideoAd();
    removeAdElements();
  }, 300);
}

function stopAdCheck() {
  if (adCheckInterval) {
    clearInterval(adCheckInterval);
    adCheckInterval = null;
  }
}

// ============================================================
// HINTERGRUND BENACHRICHTIGEN (Zähler)
// ============================================================
let notifyTimeout = null;
function notifyBackground() {
  // Debounced um nicht jeden einzelnen removal zu senden
  if (notifyTimeout) return;
  notifyTimeout = setTimeout(() => {
    notifyTimeout = null;
    // Zähler wird im background.js über webRequest verwaltet
    // DOM-Blocks hier nur lokal tracked
  }, 500);
}

// ============================================================
// NACHRICHTEN VOM BACKGROUND / POPUP
// ============================================================
browser.runtime.onMessage.addListener((msg) => {
  if (msg.type === 'SET_ENABLED') {
    enabled = msg.value;
    if (enabled) {
      startObserver();
      startAdCheck();
      removeAdElements();
    } else {
      stopAdCheck();
      // Video-Playback-Rate zurücksetzen
      const video = document.querySelector('video');
      if (video) video.playbackRate = 1;
    }
  }
});

// ============================================================
// INIT
// ============================================================
browser.storage.local.get('enabled').then(data => {
  if (data.enabled !== undefined) enabled = data.enabled;

  if (enabled) {
    removeAdElements();
    startObserver();
    startAdCheck();
  }
});
