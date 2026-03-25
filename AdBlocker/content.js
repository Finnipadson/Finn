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
  // NOTE: .ad-showing / .ad-interrupting sind Klassen auf dem Player-Container
  // — diese NICHT entfernen, nur zur Erkennung verwenden (s. handleVideoAd)
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

// Skip-Button Selektoren — alle bekannten YouTube-Varianten
const SKIP_SELECTORS = [
  '.ytp-ad-skip-button',
  '.ytp-ad-skip-button-modern',
  '.ytp-ad-skip-button-container button',
  '.ytp-skip-ad-button',
  '[class*="skip-button"]',
  '[class*="skip_button"]',
  'button[id*="skip"]'
];

// Verhindert doppeltes Anhängen der Event-Listener am selben Video-Element
let adVideoEl = null;

function skipVideoNow(video) {
  if (!video) return;
  // 1. Skip-Button klicken (sofortiger, sauberer Skip)
  for (const sel of SKIP_SELECTORS) {
    const btn = document.querySelector(sel);
    if (btn) { btn.click(); return; }
  }
  // 2. Ans Ende spulen wenn Duration bekannt
  if (video.duration && isFinite(video.duration) && video.duration > 0) {
    video.currentTime = video.duration;
  }
}

function handleVideoAd() {
  if (!enabled) return;

  const video = document.querySelector('video');
  if (!video) return;

  // Ad-Erkennung: Klassen auf dem Player-Container (NICHT entfernen)
  const adShowing = document.querySelector('.ad-showing, .ad-interrupting');
  const adBadge   = document.querySelector('.ytp-ad-simple-ad-badge, .ytp-ad-preview-container, .ytp-ad-duration-remaining');

  if (adShowing || adBadge) {
    // Sofort stummschalten
    if (!video.muted) video.muted = true;
    // Sofort maximale Playback-Rate — Ad rauscht durch, auch wenn Skip fehlschlägt
    if (video.playbackRate < 16) video.playbackRate = 16;

    // Skip sofort versuchen
    skipVideoNow(video);

    // Event-Listener anhängen sobald Duration verfügbar — einmalig pro Ad-Video
    if (adVideoEl !== video) {
      adVideoEl = video;

      const onReady = () => {
        if (!enabled) return;
        const stillAd = document.querySelector('.ad-showing, .ad-interrupting, .ytp-ad-simple-ad-badge');
        if (stillAd) skipVideoNow(video);
      };

      video.addEventListener('loadedmetadata', onReady, { once: true });
      video.addEventListener('durationchange', onReady, { once: true });
      video.addEventListener('canplay',        onReady, { once: true });
    }
  } else {
    // Kein Ad aktiv — alles zurücksetzen
    adVideoEl = null;
    if (video.muted) video.muted = false;
    if (video.playbackRate !== 1) video.playbackRate = 1;
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
let videoListenerAttached = false;

function attachVideoListener() {
  const video = document.querySelector('video');
  if (!video || videoListenerAttached) return;
  // timeupdate feuert mehrmals pro Sekunde während das Video läuft
  // → sofortige Ad-Erkennung ohne auf den 300ms-Interval warten zu müssen
  video.addEventListener('timeupdate', handleVideoAd, { passive: true });
  videoListenerAttached = true;
}

function startAdCheck() {
  if (adCheckInterval) return;
  adCheckInterval = setInterval(() => {
    if (!enabled) return;
    attachVideoListener();
    handleVideoAd();
    removeAdElements();
  }, 100);
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
