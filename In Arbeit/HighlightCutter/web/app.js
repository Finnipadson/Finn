/* Highlight Cutter – Oberfläche (Vanilla JS, kein Build-Schritt). Spricht nur mit der lokalen API. */
'use strict';

const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];

const S = {
  view: 'aufnahmen',
  videos: [],            // aus Videos\NVIDIA
  extra: [],             // per Dialog / Drag & Drop hinzugefügt
  auswahl: new Set(),    // gewählte Pfade
  offen: {},             // Spiel → Gruppe aufgeklappt?
  mehr: {},              // Spiel → alle Zeilen zeigen?
  filter: '',
  geladen: false,
  einst: null,
  clips: null,           // null = noch keine Analyse
  analysen: {},          // Video-Pfad → Analyse
  analyseVideos: [],
  analyseEinst: null,
  exportErgebnis: null,
  pid: null,             // id des Clips im Player
  montage: false,
  drag: false,
  info: {},
};

const ANALYSE_FELDER = ['eigene_tode', 'champion', 'nachlauf', 'zusammenfassen', 'max_vorlauf'];
const SPEICHER_KEY = 'highlightcutter_sitzung_v1';

// ------------------------------------------------------------------ Format-Helfer
const komma = (n, d = 1) => n.toFixed(d).replace('.', ',');
function fmtZeit(s, dez = true) {
  s = dez ? Math.round(Math.max(0, s) * 10) / 10 : Math.floor(Math.max(0, s));
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
  const sek = dez ? komma(r).padStart(4, '0') : String(Math.floor(r)).padStart(2, '0');
  return (h ? `${h}:${String(m).padStart(2, '0')}` : `${m}`) + ':' + sek;
}
function fmtLaenge(s) {
  s = Math.max(0, Math.round(s));
  const m = Math.floor(s / 60);
  return `${m}:${String(s % 60).padStart(2, '0')}`;
}
function fmtGroesse(b) {
  if (b >= 1e9) return komma(b / 1e9, 1) + ' GB';
  if (b >= 1e6) return Math.round(b / 1e6) + ' MB';
  return Math.max(1, Math.round(b / 1e3)) + ' KB';
}
const DATUM = new Intl.DateTimeFormat('de-DE', { weekday: 'short', day: '2-digit', month: '2-digit', year: 'numeric' });
const UHR = new Intl.DateTimeFormat('de-DE', { hour: '2-digit', minute: '2-digit' });
function fmtDatum(iso) {
  const d = new Date(iso);
  return isNaN(d) ? '' : `${DATUM.format(d)} · ${UHR.format(d)}`;
}
const runde = (t) => Math.round(t * 10) / 10;
const klemme = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const istVideoName = (n) => /\.(mp4|mkv|mov)$/i.test(n);
let idZaehler = 0;
const neueId = () => 'c' + (++idZaehler) + '_' + Date.now().toString(36);

// ------------------------------------------------------------------ API
async function api(pfad, opt = {}) {
  let r;
  try {
    r = await fetch(pfad, {
      method: opt.method || 'GET',
      headers: opt.body !== undefined ? { 'Content-Type': 'application/json' } : {},
      body: opt.body !== undefined ? JSON.stringify(opt.body) : undefined,
    });
  } catch {
    throw new Error('Keine Verbindung zum Highlight Cutter. Läuft das Konsolenfenster noch?');
  }
  let d = null;
  try { d = await r.json(); } catch { /* keine JSON-Antwort */ }
  if (!r.ok) throw new Error((d && d.fehler) || `Der Server meldet Fehler ${r.status}.`);
  return d;
}

// ------------------------------------------------------------------ Toasts
function toast(text, { art = '', knopf = null, aktion = null, dauer = 4500 } = {}) {
  const el = document.createElement('div');
  el.className = 'toast ' + art;
  el.innerHTML = `<span>${esc(text)}</span>`;
  if (knopf && aktion) {
    const b = document.createElement('button');
    b.textContent = knopf;
    b.onclick = () => { el.remove(); aktion(); };
    el.append(b);
  }
  $('#toasts').append(el);
  setTimeout(() => el.remove(), dauer);
}

function setzeMock(an) {
  if (an) $('#demo').hidden = false;
}

// ------------------------------------------------------------------ 1 · Aufnahmen
async function ladeVideos() {
  S.geladen = false;
  renderListe();
  try {
    S.videos = await api('/api/videos');
  } catch (e) {
    S.videos = [];
    toast(e.message);
  }
  S.geladen = true;
  const pfade = new Set([...S.videos, ...S.extra].map((v) => v.pfad));
  for (const p of [...S.auswahl]) if (!pfade.has(p)) S.auswahl.delete(p);
  renderListe();
  renderAuswahl();
}

function alleVideos() {
  const gesehen = new Set();
  const alle = [];
  for (const v of [...S.extra, ...S.videos]) {
    if (gesehen.has(v.pfad.toLowerCase())) continue;
    gesehen.add(v.pfad.toLowerCase());
    alle.push(v);
  }
  return alle;
}

const hatProfil = (spiel) => /apex/i.test(spiel);

function renderListe() {
  const box = $('#liste');
  if (!S.geladen) { box.innerHTML = '<div class="leer"><p>Lade Aufnahmen …</p></div>'; return; }
  const alle = alleVideos();
  if (!alle.length) {
    box.innerHTML = `
      <div class="leer">
        <div class="leer-icon"><svg viewBox="0 0 24 24"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3"/><path d="M3 3l18 18"/></svg></div>
        <h3>Keine Aufnahmen gefunden</h3>
        <p>In <b>${esc(S.info.nvidia_ordner || 'Videos\\NVIDIA')}</b> liegt noch kein Video.</p>
        <p>Nimm eine Runde mit NVIDIA Instant Replay oder der Aufnahme-Funktion (Alt + F9) auf – oder wähl ein Video von woanders.</p>
        <button class="btn primary" data-aktion="datei">Datei auswählen …</button>
        <button class="btn ghost" data-aktion="neu-laden">Nochmal suchen</button>
      </div>`;
    return;
  }
  const q = S.filter.trim().toLowerCase();
  const gruppen = new Map();
  for (const v of alle) {
    if (q && !`${v.name} ${v.spiel} ${fmtDatum(v.datum)}`.toLowerCase().includes(q)) continue;
    if (!gruppen.has(v.spiel)) gruppen.set(v.spiel, []);
    gruppen.get(v.spiel).push(v);
  }
  if (!gruppen.size) {
    box.innerHTML = `<div class="leer"><h3>Nichts gefunden</h3><p>Keine Aufnahme passt zu „${esc(S.filter)}“.</p></div>`;
    return;
  }
  const rang = (spiel) => (spiel === 'Eigene Dateien' ? 0 : hatProfil(spiel) ? 1 : 2);
  const sortiert = [...gruppen.entries()].sort((a, b) =>
    rang(a[0]) - rang(b[0]) || (b[1][0].datum || '').localeCompare(a[1][0].datum || ''));
  const html = [];
  for (const [spiel, liste] of sortiert) {
    const offen = S.offen[spiel] ?? (rang(spiel) < 2 || !!q);
    const gewaehlt = liste.filter((v) => S.auswahl.has(v.pfad)).length;
    const limit = S.mehr[spiel] || q ? liste.length : 30;
    const zeilen = liste.slice(0, limit).map((v) => `
      <div class="video-zeile ${S.auswahl.has(v.pfad) ? 'gewaehlt' : ''}" data-pfad="${esc(v.pfad)}" role="checkbox" aria-checked="${S.auswahl.has(v.pfad)}" tabindex="0">
        <span class="haken"><svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></span>
        <span class="video-titel"><b>${esc(fmtDatum(v.datum))}</b><small>${esc(v.name)}</small></span>
        <span>${/\.dvr\./i.test(v.name) ? '<span class="tag dvr">Instant Replay</span>' : ''}</span>
        <span class="video-groesse">${fmtGroesse(v.groesse)}</span>
      </div>`).join('');
    html.push(`
      <section class="gruppe ${offen ? 'offen' : ''}" data-spiel="${esc(spiel)}">
        <button class="gruppe-kopf" data-aktion="gruppe">
          <svg class="pfeil" viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg>
          <span class="gruppe-name">${esc(spiel)}</span>
          <span class="gruppe-anzahl">${liste.length} ${liste.length === 1 ? 'Aufnahme' : 'Aufnahmen'}${gewaehlt ? ` · <b style="color:var(--accent)">${gewaehlt} gewählt</b>` : ''}</span>
          ${hatProfil(spiel) ? '<span class="tag profil">Kill-Erkennung</span>' : ''}
          <span class="spacer"></span>
          ${offen ? `<span class="gruppe-alle" data-aktion="alle">${gewaehlt === liste.length ? 'Keine' : 'Alle'} wählen</span>` : ''}
        </button>
        <div class="gruppe-inhalt">
          ${!hatProfil(spiel) && spiel !== 'Eigene Dateien' ? '<div class="gruppe-hinweis">Für dieses Spiel gibt es noch keine Kill-Erkennung – hier werden vermutlich keine Highlights gefunden.</div>' : ''}
          ${zeilen}
          ${liste.length > limit ? `<button class="mehr-zeigen" data-aktion="mehr">Weitere ${liste.length - limit} Aufnahmen zeigen</button>` : ''}
        </div>
      </section>`);
  }
  box.innerHTML = html.join('');
}

function gewaehlteVideos() {
  // Reihenfolge im fertigen Video: älteste Aufnahme zuerst
  return alleVideos().filter((v) => S.auswahl.has(v.pfad)).sort((a, b) => (a.datum || '').localeCompare(b.datum || ''));
}

function renderAuswahl() {
  const g = gewaehlteVideos();
  const summe = g.reduce((s, v) => s + v.groesse, 0);
  $('#auswahl-info').innerHTML = g.length
    ? `<b>${g.length}</b>${g.length === 1 ? 'Aufnahme' : 'Aufnahmen'}<small>${fmtGroesse(summe)} · im Video älteste zuerst</small>`
    : '<small>Noch nichts gewählt. Klick links auf eine Runde.</small>';
  $('#auswahl-chips').innerHTML = g.map((v) => `
    <li><span title="${esc(v.pfad)}">${esc(v.spiel === 'Eigene Dateien' ? v.name : fmtDatum(v.datum))}</span>
    <button data-weg="${esc(v.pfad)}" title="Entfernen" aria-label="Entfernen">✕</button></li>`).join('');
  $('#btn-finden').disabled = !g.length;
}

function waehle(pfad, an) {
  if (an ?? !S.auswahl.has(pfad)) S.auswahl.add(pfad); else S.auswahl.delete(pfad);
  renderListe();
  renderAuswahl();
}

function fuegeHinzu(videos) {
  let neu = 0;
  const bekannt = new Map(alleVideos().map((v) => [v.pfad.toLowerCase(), v]));
  for (const v of videos) {
    const vorhanden = bekannt.get(v.pfad.toLowerCase());
    if (!vorhanden) { S.extra.unshift({ ...v, spiel: v.spiel === 'Sonstige' || !v.spiel ? 'Eigene Dateien' : v.spiel }); }
    S.auswahl.add(vorhanden ? vorhanden.pfad : v.pfad);
    if (vorhanden) S.offen[vorhanden.spiel] = true;
    neu++;
  }
  renderListe();
  renderAuswahl();
  if (neu) toast(`${neu} ${neu === 1 ? 'Video' : 'Videos'} hinzugefügt und ausgewählt`, { art: 'ok', dauer: 2500 });
}

async function dateiDialog() {
  const knoepfe = $$('[data-aktion="datei"], #btn-datei');
  knoepfe.forEach((b) => (b.disabled = true));
  toast('Dateidialog ist offen – falls du ihn nicht siehst, liegt er hinter diesem Fenster.', { dauer: 3500 });
  try {
    const d = await api('/api/pfad-waehlen', { method: 'POST', body: {} });
    if (d.videos.length) fuegeHinzu(d.videos);
  } catch (e) {
    toast(e.message);
  } finally {
    knoepfe.forEach((b) => (b.disabled = false));
  }
}

async function dropDateien(files) {
  const videos = files.filter((f) => istVideoName(f.name));
  if (!videos.length) { toast('Das sind keine Videos. Erlaubt sind .mp4, .mkv und .mov.'); return; }
  let antwort;
  try {
    antwort = await api('/api/dateien-finden', { method: 'POST', body: { dateien: videos.map((f) => ({ name: f.name, groesse: f.size })) } });
  } catch (e) { toast(e.message); return; }
  const gefunden = antwort.filter((a) => a.video).map((a) => a.video);
  const fehlt = antwort.length - gefunden.length;
  if (gefunden.length) fuegeHinzu(gefunden);
  if (fehlt) {
    toast(`${fehlt === 1 ? 'Eine Datei' : fehlt + ' Dateien'} konnte ich auf der Festplatte nicht finden (der Browser verrät den Ordner nicht).`,
      { knopf: 'Datei auswählen …', aktion: dateiDialog, dauer: 9000 });
  }
}

// ------------------------------------------------------------------ Aufträge (Analyse / Export)
let auftragId = null;
let nochmalAktion = null;

function zeigeAuftrag(titel) {
  $('#auftrag').hidden = false;
  $('#auftrag').classList.remove('fehler');
  $('#auftrag-titel').textContent = titel;
  $('#auftrag-prozent').textContent = '0 %';
  $('#auftrag-balken').style.width = '0%';
  $('#auftrag-text').textContent = 'Startet …';
  $('#auftrag-fehler').hidden = true;
  $('#btn-abbrechen').hidden = false;
  $('#btn-abbrechen').disabled = false;
  $('#btn-abbrechen').textContent = 'Abbrechen';
  $('#btn-nochmal').hidden = true;
  $('#btn-schliessen').hidden = true;
}

function zeigeAuftragFehler(text) {
  $('#auftrag').hidden = false;
  $('#auftrag').classList.add('fehler');
  $('#auftrag-fehler').hidden = false;
  $('#auftrag-fehler').textContent = text;
  $('#btn-abbrechen').hidden = true;
  $('#btn-nochmal').hidden = !nochmalAktion;
  $('#btn-schliessen').hidden = false;
}

function verfolge(id, titel, nochmal) {
  auftragId = id;
  nochmalAktion = nochmal || null;
  zeigeAuftrag(titel);
  let fehlversuche = 0;
  return new Promise((resolve) => {
    const tick = async () => {
      if (auftragId !== id) return resolve(null);
      let a;
      try {
        a = await api('/api/auftrag/' + id);
        fehlversuche = 0;
      } catch (e) {
        if (++fehlversuche >= 8) { $('#auftrag-text').textContent = ''; zeigeAuftragFehler(e.message); return resolve(null); }
        setTimeout(tick, 800);
        return;
      }
      setzeMock(a.mock);
      const pz = Math.floor(a.anteil * 100);
      $('#auftrag-prozent').textContent = pz + ' %';
      $('#auftrag-balken').style.width = pz + '%';
      $('#auftrag-text').textContent = a.text || '';
      if (a.status === 'laeuft') { setTimeout(tick, 400); return; }
      auftragId = null;
      if (a.status === 'fertig') {
        $('#auftrag-prozent').textContent = '100 %';
        $('#auftrag-balken').style.width = '100%';
        setTimeout(() => { $('#auftrag').hidden = true; resolve(a); }, 350);
      } else if (a.status === 'abgebrochen') {
        $('#auftrag').hidden = true;
        toast('Abgebrochen.', { dauer: 2500 });
        resolve(null);
      } else {
        zeigeAuftragFehler(a.fehler || 'Unbekannter Fehler.');
        resolve(null);
      }
    };
    tick();
  });
}

async function abbrechen() {
  if (!auftragId) return;
  const b = $('#btn-abbrechen');
  b.disabled = true;
  b.textContent = 'Wird abgebrochen …';
  try { await api(`/api/auftrag/${auftragId}/abbrechen`, { method: 'POST', body: {} }); } catch (e) { toast(e.message); }
}

async function starteAnalyse(videos = gewaehlteVideos().map((v) => v.pfad)) {
  if (!videos.length) return;
  let id;
  try {
    ({ id } = await api('/api/analyse', { method: 'POST', body: { videos, einstellungen: S.einst } }));
  } catch (e) {
    nochmalAktion = () => starteAnalyse(videos);
    zeigeAuftrag('Suche Highlights');
    $('#auftrag-text').textContent = '';
    zeigeAuftragFehler(e.message);
    return;
  }
  const a = await verfolge(id, 'Suche Highlights', () => starteAnalyse(videos));
  if (!a) return;
  S.analysen = Object.fromEntries(a.ergebnis.analysen.map((x) => [x.video, x]));
  S.clips = a.ergebnis.clips.map((c) => ({ ...c, _id: neueId() }));
  S.analyseVideos = videos;
  S.analyseEinst = Object.fromEntries(ANALYSE_FELDER.map((k) => [k, S.einst[k]]));
  S.pid = null;
  $('#player').removeAttribute('src');
  $('#player').dataset.src = '';
  $('#player-leer').hidden = false;
  speichereSitzung();
  zeigeView('clips');
  renderClips();
  pruefeAnalyseHinweis();
  if (S.clips.length) toast(`${S.clips.length} ${S.clips.length === 1 ? 'Highlight' : 'Highlights'} gefunden`, { art: 'ok', dauer: 2500 });
}

const ohneIntern = (c) => { const { _id, _fenster, ...rest } = c; return rest; };

async function starteExport() {
  if (!S.clips || !S.clips.some((c) => c.aktiv)) { toast('Schalte mindestens einen Clip an.'); return; }
  $('#player').pause();
  S.montage = false; montageKnopf();
  let id;
  try {
    ({ id } = await api('/api/export', { method: 'POST', body: { clips: S.clips.map(ohneIntern), einstellungen: S.einst } }));
  } catch (e) {
    nochmalAktion = starteExport;
    zeigeAuftrag('Video wird erstellt');
    $('#auftrag-text').textContent = '';
    zeigeAuftragFehler(e.message);
    return;
  }
  const a = await verfolge(id, 'Video wird erstellt', starteExport);
  if (!a) return;
  S.exportErgebnis = a.ergebnis;
  zeigeFertig();
}

function zeigeFertig() {
  const r = S.exportErgebnis;
  const p = $('#ergebnis-player');
  p.src = '/api/video?pfad=' + encodeURIComponent(r.pfad) + '&v=' + Date.now();
  const info = () => {
    const teile = [];
    if (isFinite(p.duration)) teile.push(p.duration < 60 ? Math.round(p.duration) + ' s' : fmtLaenge(p.duration) + ' min');
    if (r.groesse) teile.push(fmtGroesse(r.groesse));
    teile.push(S.einst.format === '9:16' ? 'Hochkant 9:16' : 'Quer 16:9');
    $('#fertig-info').textContent = teile.join(' · ');
  };
  info();
  p.addEventListener('loadedmetadata', info, { once: true });
  $('#fertig-pfad').textContent = r.pfad;
  zeigeView('fertig');
}

async function oeffne(pfad, aktion) {
  try { await api('/api/oeffnen', { method: 'POST', body: { pfad, aktion } }); } catch (e) { toast(e.message); }
}


// ------------------------------------------------------------------ Ansichten (Editor-Layout)
S.tab = 'clip';          // rechtes Paneel: 'clip' | 'einst'
S.mSkala = null;         // feste Montage-Länge, solange in der Zeitleiste gezogen wird

const ANSICHT_TEILE = {
  aufnahmen: ['#v-aufnahmen', '#a-aufnahmen'],
  clips: ['#v-clips', '#buehne', '#a-clips', '#montage-panel'],
  clipsLeer: ['#clips-leer'],
  fertig: ['#v-fertig'],
};

function zeigeView(v) {
  S.view = v;
  document.body.dataset.view = v;
  const leer = v === 'clips' && (!S.clips || !S.clips.length);
  const sichtbar = new Set(v === 'clips' ? ANSICHT_TEILE[leer ? 'clipsLeer' : 'clips'] : ANSICHT_TEILE[v]);
  for (const teile of Object.values(ANSICHT_TEILE)) for (const s of teile) $(s).hidden = !sichtbar.has(s);
  $('#btn-export').classList.toggle('aus-leer', leer);
  $('#seg-format-mini').classList.toggle('aus-leer', leer);
  if (v !== 'clips') { $('#player').pause(); S.montage = false; montageKnopf(); }
  if (v !== 'fertig') $('#ergebnis-player').pause();
  for (const b of $$('.step, .rail-btn[data-view]')) {
    const ziel = b.dataset.view;
    const erreichbar = ziel === 'aufnahmen' || (ziel === 'clips' && S.clips !== null) || (ziel === 'fertig' && !!S.exportErgebnis);
    b.disabled = !erreichbar;
    b.classList.toggle('erreichbar', erreichbar);
    b.classList.toggle('aktiv', ziel === v);
  }
  // Einstellungen: ein Block, hängt je nach Ansicht in der passenden Seitenleiste
  const platz = v === 'aufnahmen' ? '#einst-platz-aufnahmen' : '#einst-platz-clips';
  if ($('#einst-block').parentElement !== $(platz)) $(platz).append($('#einst-block'));
  $('#main').scrollTop = 0;
  renderProjekt();
  if (v === 'aufnahmen') zeigeWeiterKnopf();
}

function renderProjekt() {
  if (S.view === 'aufnahmen' || !S.analyseVideos || !S.analyseVideos.length) {
    $('#projekt').textContent = 'Highlight Cutter';
    $('#projekt-sub').textContent = '';
    return;
  }
  const bekannt = new Map(alleVideos().map((v) => [v.pfad, v]));
  const erste = bekannt.get(S.analyseVideos[0]);
  const spiel = erste && erste.spiel !== 'Eigene Dateien' ? erste.spiel : videoName(S.analyseVideos[0]).replace(/\.\w+$/, '');
  const datum = erste && erste.datum ? new Date(erste.datum) : null;
  $('#projekt').textContent = datum && !isNaN(datum) ? `${spiel} · ${datum.toLocaleDateString('de-DE')}` : spiel;
  const n = S.analyseVideos.length;
  $('#projekt-sub').textContent = `${n} ${n === 1 ? 'Aufnahme' : 'Aufnahmen'}`;
}

function zeigeTab(t) {
  S.tab = t;
  $$('#a-clips .tab').forEach((b) => b.classList.toggle('an', b.dataset.tab === t));
  $('#tab-clip').hidden = t !== 'clip';
  $('#tab-einst').hidden = t !== 'einst';
}

// ------------------------------------------------------------------ 2 · Clips – Daten
function clipNach(id) { return (S.clips || []).find((c) => c._id === id); }
function videoDauer(c) { const a = S.analysen[c.video]; return a ? a.dauer : Math.max(c.ende + 30, 60); }
function videoName(p) { return p.split(/[\\/]/).pop(); }
function aktiveClips() { return (S.clips || []).filter((c) => c.aktiv); }
function uebergang() { return S.einst ? S.einst.uebergang : 0; }

function gesamtLaenge() {
  const a = aktiveClips();
  const summe = a.reduce((s, c) => s + (c.ende - c.start), 0);
  return Math.max(0, summe - Math.max(0, a.length - 1) * uebergang());
}

function bildUrl(video, t, breite) {
  return `/api/bild?pfad=${encodeURIComponent(video)}&t=${Math.max(0, t).toFixed(1)}&breite=${breite}`;
}

function grundKlasse(g) {
  return /champion/i.test(g) ? 'champion' : /tod/i.test(g) ? 'tod' : /knock/i.test(g) ? 'knock' : '';
}
const EV_NAMEN = { kill: 'Kill', knock: 'Knock', tod: 'Eigener Tod', champion: 'Champion' };
function videoEvents(c) { return (S.analysen[c.video] || { events: c.events }).events || []; }

function renderStats() {
  const a = aktiveClips();
  const n = (S.clips || []).length;
  const kills = a.reduce((s, c) => s + c.events.filter((e) => e.typ === 'kill').length, 0);
  $('#stat-clips').textContent = n && a.length !== n ? `${a.length}/${n}` : String(a.length);
  $('#stat-kills').textContent = kills;
  $('#stat-laenge').textContent = fmtLaenge(gesamtLaenge());
  $('#stat-titel').textContent = `${n} ${n === 1 ? 'Highlight' : 'Highlights'}`;
  const nA = S.analyseVideos.length;
  $('#clips-sub').textContent = `${a.length} im Video · aus ${nA} ${nA === 1 ? 'Aufnahme' : 'Aufnahmen'}`;
  const u = uebergang();
  $('#montage-info').textContent = a.length
    ? `${a.length} ${a.length === 1 ? 'Clip' : 'Clips'} · ${fmtLaenge(gesamtLaenge())} min · ${u > 0 ? 'Übergang ' + komma(u) + ' s' : 'harte Schnitte'}`
    : 'Kein Clip ist an';
  $('#btn-export').disabled = !a.length;
  $('#btn-montage').disabled = !a.length;
  renderExportInfo();
}

function renderExportInfo() {
  if (!S.einst) return;
  const e = S.einst;
  const fmt = e.format === '9:16' ? 'Hochkant 1080×1920' : `${e.hoehe}p`;
  const ueb = e.uebergang > 0 ? `Übergang ${komma(e.uebergang)} s` : 'harte Schnitte';
  $('#export-info').textContent = `${fmtLaenge(gesamtLaenge())} min · ${fmt} · ${e.fps} fps · ${ueb}`;
}

// ------------------------------------------------------------------ Clip-Raster (links)
function renderClips() {
  const n = S.clips.length;
  if (!n) {
    const extraKnopf = !S.einst.eigene_tode || !S.einst.champion
      ? '<button class="btn" data-aktion="mit-toden">Mit eigenen Toden + Champion nochmal suchen</button>' : '';
    $('#clips-leer').innerHTML = `
      <div class="leer">
        <div class="leer-icon"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/><path d="M9 9l6 6M15 9l-6 6"/></svg></div>
        <h3>Keine Highlights gefunden</h3>
        <p>In ${S.analyseVideos.length === 1 ? 'dieser Aufnahme' : 'diesen Aufnahmen'} wurde kein eigener Kill erkannt. Mögliche Gründe:</p>
        <ul>
          <li>Es gab in der Aufnahme wirklich keinen Kill (Knocks ohne Kill zählen nicht).</li>
          <li>Die Aufnahme ist nicht aus Apex Legends – andere Spiele werden noch nicht erkannt.</li>
          <li>Das HUD war ausgeblendet oder stark verkleinert.</li>
        </ul><br>
        <button class="btn primary" data-aktion="zurueck">Andere Aufnahmen wählen</button>
        ${extraKnopf}
      </div>`;
    S.pid = null;
    renderStats();
    if (S.view === 'clips') zeigeView('clips');
    return;
  }
  const box = $('#kacheln');
  box.innerHTML = '';
  const tpl = $('#t-kachel');
  S.clips.forEach((c, i) => {
    const el = tpl.content.firstElementChild.cloneNode(true);
    el.dataset.id = c._id;
    const t = c.events.length ? c.events[0].t : (c.start + c.ende) / 2;
    $('img', el).src = bildUrl(c.video, t, 320);
    aktualisiereKachel(el, c, i);
    box.append(el);
  });
  if (!clipNach(S.pid)) {
    const erst = aktiveClips()[0] || S.clips[0];
    waehleClip(erst, false);
  } else {
    renderDetail();
  }
  renderMontage();
  renderStats();
  if (S.view === 'clips') zeigeView('clips');
}

function kachelEl(id) { return $(`.kachel[data-id="${id}"]`); }

function aktualisiereKachel(el, c, i = S.clips.indexOf(c)) {
  el.classList.toggle('aus', !c.aktiv);
  el.classList.toggle('gewaehlt', S.pid === c._id);
  $('.nr', el).textContent = '#' + (i + 1);
  $('.dauer', el).textContent = fmtLaenge(c.ende - c.start);
  const g = $('.grund', el);
  g.textContent = c.grund;
  g.className = 'grund ' + grundKlasse(c.grund);
  $('.k-zeit', el).textContent = fmtZeit(c.start, false);
  el.title = `${c.grund} · ${videoName(c.video)} bei ${fmtZeit(c.start, false)}`;
  $('.k-an', el).title = c.aktiv ? 'Ist im Video – klicken zum Weglassen' : 'Nicht im Video – klicken zum Verwenden';
}

function aktualisiereAuswahl() {
  $$('.kachel').forEach((el) => el.classList.toggle('gewaehlt', el.dataset.id === S.pid));
  $$('.m-strip').forEach((el) => el.classList.toggle('gewaehlt', el.dataset.id === S.pid));
  renderDetail();
}

function waehleClip(c, abspielen) {
  if (!c) return;
  if (abspielen) { S.montage = false; montageKnopf(); }
  ladeClip(c, c.start, !!abspielen);
  const el = kachelEl(c._id);
  if (el) el.scrollIntoView({ block: 'nearest' });
}

function setzeAktiv(c, an) {
  c.aktiv = an;
  const el = kachelEl(c._id);
  if (el) aktualisiereKachel(el, c);
  if (S.pid === c._id) aktualisiereDetail();
  renderMontage();
  renderStats();
  speichereSitzung();
}

function verschiebe(id, richtung) {
  const i = S.clips.findIndex((c) => c._id === id);
  const j = i + richtung;
  if (i < 0 || j < 0 || j >= S.clips.length) return;
  [S.clips[i], S.clips[j]] = [S.clips[j], S.clips[i]];
  renderClips();
  speichereSitzung();
}

// Reihenfolge per Drag & Drop im Raster
let ziehId = null;
function initKachelDnD(box) {
  const ziel = (e) => {
    const el = e.target.closest('.kachel');
    if (!el || el.dataset.id === ziehId) return null;
    const r = el.getBoundingClientRect();
    return { el, vor: e.clientX < r.left + r.width / 2 };
  };
  box.addEventListener('dragstart', (e) => {
    const el = e.target.closest('.kachel');
    if (!el) return;
    ziehId = el.dataset.id;
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', ziehId);
    setTimeout(() => el.classList.add('zieht'), 0);
  });
  box.addEventListener('dragover', (e) => {
    if (!ziehId) return;
    e.preventDefault();
    $$('.kachel', box).forEach((k) => k.classList.remove('ziel-vor', 'ziel-nach'));
    const z = ziel(e);
    if (z) z.el.classList.add(z.vor ? 'ziel-vor' : 'ziel-nach');
  });
  box.addEventListener('drop', (e) => {
    if (!ziehId) return;
    e.preventDefault();
    e.stopPropagation();
    const z = ziel(e);
    if (z) {
      const von = S.clips.findIndex((c) => c._id === ziehId);
      const [c] = S.clips.splice(von, 1);
      let nach = S.clips.findIndex((x) => x._id === z.el.dataset.id);
      if (!z.vor) nach++;
      S.clips.splice(nach, 0, c);
      renderClips();
      speichereSitzung();
    }
  });
  box.addEventListener('dragend', () => {
    ziehId = null;
    $$('.kachel', box).forEach((k) => k.classList.remove('zieht', 'ziel-vor', 'ziel-nach'));
  });
}

// ------------------------------------------------------------------ Clip-Details (rechts)
function renderDetail() {
  const box = $('#detail');
  const c = clipNach(S.pid);
  if (!c) { box.innerHTML = '<div class="d-sec keine-momente">Wähl links einen Clip aus.</div>'; box.dataset.id = ''; $('#tab-clip-name').textContent = 'Clip'; return; }
  if (box.dataset.id !== c._id) {
    box.innerHTML = '';
    box.append($('#t-detail').content.cloneNode(true));
    box.dataset.id = c._id;
    c._fenster = fenster(c);
  }
  aktualisiereDetail();
}

function fenster(c) {
  const dauer = videoDauer(c);
  const rand = Math.max(8, (c.ende - c.start) * 0.6);
  return [Math.max(0, c.start - rand), Math.min(dauer, c.ende + rand)];
}

function aktualisiereDetail() {
  const box = $('#detail');
  const c = clipNach(S.pid);
  if (!c || box.dataset.id !== c._id) return;
  const i = S.clips.indexOf(c);
  $('#tab-clip-name').textContent = 'Clip ' + (i + 1);
  const g = $('.grund', box);
  g.textContent = c.grund;
  g.className = 'grund ' + grundKlasse(c.grund);
  $('.d-dauer', box).innerHTML = `${komma(c.ende - c.start)}<small>s</small>`;
  $('.d-quelle', box).textContent = videoName(c.video);
  $('.d-quelle', box).title = c.video;
  $('.t-start', box).textContent = fmtZeit(c.start);
  $('.t-ende', box).textContent = fmtZeit(c.ende);
  $('.d-an', box).checked = c.aktiv;
  $('[data-move="-1"]', box).disabled = i === 0;
  $('[data-move="1"]', box).disabled = i === S.clips.length - 1;

  // Feinschnitt-Leiste
  if (!c._fenster || (!S.drag && (c.start < c._fenster[0] || c.ende > c._fenster[1]))) c._fenster = fenster(c);
  const [w0, w1] = c._fenster;
  const pos = (t) => ((t - w0) / (w1 - w0)) * 100;
  const b = $('.tl-bereich', box);
  b.style.left = pos(c.start) + '%';
  b.style.width = (pos(c.ende) - pos(c.start)) + '%';
  const tl = $('.tl', box);
  $$('.tl-ev', tl).forEach((m) => m.remove());
  const events = videoEvents(c);
  for (const ev of events) {
    if (ev.t < w0 || ev.t > w1) continue;
    const m = document.createElement('span');
    m.className = 'tl-ev ' + ev.typ;
    m.style.left = pos(ev.t) + '%';
    if (ev.t < c.start || ev.t > c.ende) m.style.opacity = '.35';
    m.title = `${EV_NAMEN[ev.typ] || ev.typ} bei ${fmtZeit(ev.t)}`;
    tl.append(m);
  }

  // Momente-Liste (nur beim Ziehen nicht ständig neu bauen)
  if (!S.drag) {
    const nah = events.filter((ev) => ev.t >= w0 && ev.t <= w1);
    $('.momente', box).innerHTML = nah.length
      ? nah.map((ev) => `<button class="moment ${ev.typ} ${ev.t < c.start || ev.t > c.ende ? 'draussen' : ''}" data-t="${ev.t}"
          title="${ev.t < c.start || ev.t > c.ende ? 'Liegt außerhalb des Clips – ' : ''}Klicken zum Hinspringen"><i></i>${EV_NAMEN[ev.typ] || ev.typ}<small>${fmtZeit(ev.t)}</small></button>`).join('')
      : '<div class="keine-momente">Keine erkannten Momente in der Nähe.</div>';
  }
}

function nachAenderung(c) {
  const el = kachelEl(c._id);
  if (el) aktualisiereKachel(el, c);
  aktualisiereDetail();
  renderStats();
}

function justiere(c, feld, delta) {
  const dauer = videoDauer(c);
  if (feld === 'start') c.start = runde(klemme(c.start + delta, 0, c.ende - 1));
  else c.ende = runde(klemme(c.ende + delta, c.start + 1, dauer));
  nachAenderung(c);
  renderMontage();
  speichereSitzung();
  if (S.pid === c._id) zeigeBild(c, feld === 'start' ? c.start : Math.max(c.start, c.ende - 0.05));
}

// Feinschnitt-Leiste: Griffe ziehen (Start/Ende), Bereich ziehen (verschieben), Spur klicken (springen)
function zeitleisteStart(e) {
  const tl = e.target.closest('.tl');
  const c = clipNach(S.pid);
  if (!c || e.button !== 0) return;
  e.preventDefault();
  const rect = tl.getBoundingClientRect();
  const [w0, w1] = c._fenster;
  const tBei = (x) => w0 + klemme((x - rect.left) / rect.width, 0, 1) * (w1 - w0);
  const modus = e.target.classList.contains('links') ? 'start'
    : e.target.classList.contains('rechts') ? 'ende'
      : e.target.classList.contains('tl-bereich') ? 'schieben' : 'springen';
  if (modus === 'springen') { zeigeBild(c, tBei(e.clientX)); return; }
  const t0 = tBei(e.clientX), s0 = c.start, e0 = c.ende, dauer = videoDauer(c);
  ziehe(tl, e, (ev) => {
    const t = tBei(ev.clientX);
    if (modus === 'start') c.start = runde(klemme(t, 0, c.ende - 1));
    else if (modus === 'ende') c.ende = runde(klemme(t, c.start + 1, dauer));
    else {
      const d = klemme(t - t0, -s0, dauer - e0);
      c.start = runde(s0 + d);
      c.ende = runde(e0 + d);
    }
    return modus === 'ende' ? c.ende : c.start;
  }, c);
}

// Gemeinsamer Zieh-Ablauf für Feinschnitt-Leiste und Montage-Griffe
function ziehe(ziel, e, bewege, c) {
  S.drag = true;
  S.mSkala = Math.max(gesamtLaenge(), 1);
  try { ziel.setPointerCapture(e.pointerId); } catch { /* egal */ }
  let letzterSeek = 0;
  const bewegen = (ev) => {
    const t = bewege(ev);
    nachAenderung(c);
    renderMontage(false);
    const jetzt = performance.now();
    if (jetzt - letzterSeek > 120) { letzterSeek = jetzt; zeigeBild(c, t); }
  };
  const ende = () => {
    S.drag = false;
    S.mSkala = null;
    ziel.removeEventListener('pointermove', bewegen);
    ziel.removeEventListener('pointerup', ende);
    ziel.removeEventListener('pointercancel', ende);
    c._fenster = fenster(c);
    nachAenderung(c);
    renderMontage();
    speichereSitzung();
  };
  ziel.addEventListener('pointermove', bewegen);
  ziel.addEventListener('pointerup', ende);
  ziel.addEventListener('pointercancel', ende);
}

// ------------------------------------------------------------------ Montage-Zeitleiste (unten)
function montageLayout() {
  const a = aktiveClips();
  const u = uebergang();
  const teile = [];
  let t = 0;
  a.forEach((c, i) => {
    const d = c.ende - c.start;
    if (i > 0) t -= Math.min(u, d / 2);
    teile.push({ c, s: t, d });
    t += d;
  });
  return { teile, laenge: Math.max(t, 0.001) };
}

function renderMontage(voll = true) {
  const { teile, laenge } = montageLayout();
  const skala = S.mSkala ? Math.max(S.mSkala, laenge) : laenge;
  const pz = (t) => (t / skala) * 100;
  const spur = $('#spur-clips');

  // Streifen: beim Ziehen nur verschieben, sonst neu bauen (Bilder kommen aus dem Cache)
  const vorhanden = $$('.m-strip', spur);
  const gleich = !voll && vorhanden.length === teile.length && vorhanden.every((el, i) => el.dataset.id === teile[i].c._id);
  if (!gleich) {
    spur.innerHTML = '';
    const breite = spur.clientWidth || 800;
    teile.forEach(({ c, d }, i) => {
      const el = document.createElement('div');
      el.className = 'm-strip' + (c._id === S.pid ? ' gewaehlt' : '');
      el.dataset.id = c._id;
      el.title = `#${S.clips.indexOf(c) + 1} · ${c.grund} · ${komma(d)} s`;
      const anzahl = klemme(Math.round(((d / laenge) * breite) / 92), 1, 6);
      for (let k = 0; k < anzahl; k++) {
        const t = Math.round((c.start + (d * (k + 0.5)) / anzahl) / 2) * 2;   // auf 2 s gerundet → Cache-Treffer
        const img = document.createElement('img');
        img.src = bildUrl(c.video, t, 160);
        img.alt = '';
        img.loading = 'lazy';
        el.append(img);
      }
      el.insertAdjacentHTML('beforeend', `<span class="t">#${S.clips.indexOf(c) + 1}</span><span class="m-griff links" data-griff="start"></span><span class="m-griff rechts" data-griff="ende"></span>`);
      spur.append(el);
      void i;
    });
  }
  $$('.m-strip', spur).forEach((el, i) => {
    el.style.left = pz(teile[i].s) + '%';
    el.style.width = pz(teile[i].d) + '%';
  });
  $$('.m-ueb', spur).forEach((m) => m.remove());
  if (uebergang() > 0) teile.slice(1).forEach(({ s }) => spur.insertAdjacentHTML('beforeend', `<span class="m-ueb" style="left:${pz(s + Math.min(uebergang(), 1) / 2)}%" title="Überblendung"></span>`));

  // Momente
  const mom = $('#spur-momente');
  mom.innerHTML = '';
  for (const { c, s } of teile) {
    for (const ev of videoEvents(c)) {
      if (ev.t < c.start || ev.t > c.ende) continue;
      mom.insertAdjacentHTML('beforeend', `<span class="m-ev ${ev.typ}" style="left:${pz(s + ev.t - c.start)}%" title="${EV_NAMEN[ev.typ] || ev.typ}"></span>`);
    }
  }

  // Lineal
  const schritte = [2, 5, 10, 15, 20, 30, 60, 120, 300];
  const schritt = schritte.find((x) => skala / x <= 9) || 600;
  let html = '';
  for (let t = 0; t <= skala + 0.01; t += schritt) html += `<span style="left:${Math.max(pz(t), 1.2)}%">${fmtLaenge(t)}</span>`;
  $('#lineal').innerHTML = html;

  $$('.montage-leer', $('#montage')).forEach((m) => m.remove());
  if (!teile.length) $('#montage').insertAdjacentHTML('beforeend', '<div class="montage-leer">Kein Clip ist an – schalte links einen an.</div>');
  S._montage = { teile, skala };
}

function montageZeitBei(x) {
  const r = $('#montage').getBoundingClientRect();
  return klemme((x - r.left) / r.width, 0, 1) * (S._montage ? S._montage.skala : 0);
}

function montageKlick(e) {
  if (e.button !== 0 || !S._montage) return;
  const griff = e.target.closest('.m-griff');
  const strip = e.target.closest('.m-strip');
  if (griff && strip && strip.dataset.id === S.pid) { montageGriff(e, griff.dataset.griff); return; }
  if (strip && strip.dataset.id !== S.pid) { waehleClip(clipNach(strip.dataset.id), false); return; }
  // Leere Stelle / Lineal / gewählter Streifen: an diese Stelle der Montage springen
  const t = montageZeitBei(e.clientX);
  const teil = S._montage.teile.find((x) => t >= x.s && t <= x.s + x.d) || S._montage.teile[S._montage.teile.length - 1];
  if (!teil) return;
  const ziel = teil.c.start + klemme(t - teil.s, 0, teil.d);
  if (teil.c._id !== S.pid) ladeClip(teil.c, ziel, false); else zeigeBild(teil.c, ziel);
}

function montageGriff(e, feld) {
  e.preventDefault();
  const c = clipNach(S.pid);
  if (!c) return;
  const breite = $('#montage').getBoundingClientRect().width;
  const sProPx = Math.max(gesamtLaenge(), 1) / breite;
  const x0 = e.clientX, s0 = c.start, e0 = c.ende, dauer = videoDauer(c);
  ziehe($('#montage'), e, (ev) => {
    const d = (ev.clientX - x0) * sProPx;
    if (feld === 'start') c.start = runde(klemme(s0 + d, 0, c.ende - 1));
    else c.ende = runde(klemme(e0 + d, c.start + 1, dauer));
    return feld === 'start' ? c.start : c.ende;
  }, c);
}

// ------------------------------------------------------------------ Vorschau-Player
const P = () => $('#player');

function ladeClip(c, t, abspielen) {
  const p = P();
  const src = '/api/video?pfad=' + encodeURIComponent(c.video);
  const wechsel = S.pid !== c._id;
  S.pid = c._id;
  if (wechsel) aktualisiereAuswahl();
  $('#player-leer').hidden = true;
  const los = () => {
    p.currentTime = t;
    if (abspielen) p.play().catch(() => {});
    else p.pause();
  };
  // Standbild als Platzhalter, bis das Video an der Stelle ist (und falls es die Vorschau nicht abspielen kann)
  p.poster = bildUrl(c.video, t, 1280);
  if (p.dataset.src !== src) {
    p.dataset.src = src;
    p.src = src;
    p.addEventListener('loadedmetadata', los, { once: true });
  } else los();
}

function zeigeBild(c, t) {
  if (S.pid !== c._id || !P().getAttribute('src')) { ladeClip(c, t, false); return; }
  const p = P();
  p.pause();
  p.currentTime = t;
}

function playPause() {
  const p = P();
  const c = S.pid && clipNach(S.pid);
  if (!c) { const erst = aktiveClips()[0] || (S.clips || [])[0]; if (erst) waehleClip(erst, true); return; }
  if (p.paused) {
    if (!p.getAttribute('src')) { ladeClip(c, c.start, true); return; }
    if (p.currentTime >= c.ende - 0.1 || p.currentTime < c.start - 0.5) p.currentTime = c.start;
    p.play().catch(() => {});
  } else p.pause();
}

function nachbar(richtung) {
  if (!S.clips || !S.clips.length) return;
  const i = S.clips.findIndex((c) => c._id === S.pid);
  const j = klemme((i < 0 ? 0 : i + richtung), 0, S.clips.length - 1);
  if (j !== i) waehleClip(S.clips[j], !P().paused);
}

function montageKnopf() {
  $('#btn-montage').textContent = S.montage ? '■ Stopp' : '▶ Alle nacheinander';
}

function starteMontage() {
  if (S.montage) { S.montage = false; P().pause(); montageKnopf(); return; }
  const erst = aktiveClips()[0];
  if (!erst) return;
  ladeClip(erst, erst.start, true);
  S.montage = true;
  montageKnopf();
}

// Scrub-Leiste unter der Vorschau (springt innerhalb des gewählten Clips)
function scrubStart(e) {
  const c = clipNach(S.pid);
  if (!c || e.button !== 0) return;
  e.preventDefault();
  const el = $('#scrub');
  const r = el.getBoundingClientRect();
  const setze = (x) => zeigeBild(c, c.start + klemme((x - r.left) / r.width, 0, 1) * (c.ende - c.start));
  setze(e.clientX);
  try { el.setPointerCapture(e.pointerId); } catch { /* egal */ }
  const bewegen = (ev) => setze(ev.clientX);
  const ende = () => { el.removeEventListener('pointermove', bewegen); el.removeEventListener('pointerup', ende); el.removeEventListener('pointercancel', ende); };
  el.addEventListener('pointermove', bewegen);
  el.addEventListener('pointerup', ende);
  el.addEventListener('pointercancel', ende);
}

function playerSchleife() {
  const p = P();
  const c = S.pid && S.clips ? clipNach(S.pid) : null;
  if (c && S.view === 'clips') {
    if (!p.paused && p.currentTime >= c.ende) {
      const a = aktiveClips();
      const naechster = S.montage ? a[a.indexOf(c) + 1] : null;
      if (naechster) ladeClip(naechster, naechster.start, true);
      else { p.pause(); p.currentTime = c.ende; S.montage = false; montageKnopf(); }
    }
    const len = c.ende - c.start;
    const rel = klemme(p.currentTime - c.start, 0, len);
    const anteil = p.getAttribute('src') ? (len > 0 ? rel / len : 0) : 0;
    $('#scrub-voll').style.width = anteil * 100 + '%';
    $('#scrub-knopf').style.left = anteil * 100 + '%';
    $('#zeit-links').textContent = fmtZeit(p.getAttribute('src') ? rel : 0);
    $('#zeit-rechts').textContent = fmtZeit(len);
    const a = aktiveClips();
    $('#player-zeit').textContent = c.aktiv
      ? `Clip ${S.clips.indexOf(c) + 1} · ${a.indexOf(c) + 1} von ${a.length} im Video`
      : `Clip ${S.clips.indexOf(c) + 1} · nicht im Video`;
    // Abspielkopf in der Feinschnitt-Leiste
    const k = $('#detail .tl-kopf');
    if (k && c._fenster) {
      const [w0, w1] = c._fenster;
      const t = p.currentTime;
      k.hidden = t < w0 || t > w1 || !p.getAttribute('src');
      k.style.left = ((t - w0) / (w1 - w0)) * 100 + '%';
    }
    // Abspielkopf in der Montage
    const mk = $('#m-kopf');
    const teil = S._montage && S._montage.teile.find((x) => x.c === c);
    if (teil && p.getAttribute('src')) {
      mk.hidden = false;
      mk.style.left = ((teil.s + rel) / S._montage.skala) * 100 + '%';
    } else mk.hidden = true;
  }
  const btn = $('#btn-play');
  const spielt = !p.paused;
  if (btn.dataset.spielt !== String(spielt)) {
    btn.dataset.spielt = String(spielt);
    btn.innerHTML = spielt
      ? '<svg viewBox="0 0 24 24"><rect x="6.5" y="5" width="3.8" height="14" rx="1" class="fill"/><rect x="13.7" y="5" width="3.8" height="14" rx="1" class="fill"/></svg>'
      : '<svg viewBox="0 0 24 24"><path d="M8 5l11 7-11 7z" class="fill"/></svg>';
  }
  requestAnimationFrame(playerSchleife);
}

// ------------------------------------------------------------------ Einstellungen
let speicherTimer = null;
function renderEinst() {
  const e = S.einst;
  $$('#seg-format button, #seg-format-mini button').forEach((b) => b.classList.toggle('an', b.dataset.format === e.format));
  $('#e-tode').checked = e.eigene_tode;
  $('#e-champion').checked = e.champion;
  $('#e-uebergang').value = e.uebergang;
  $('#o-uebergang').textContent = e.uebergang > 0 ? komma(e.uebergang) + ' s' : 'Harter Schnitt';
  for (const k of ['nachlauf', 'zusammenfassen', 'max_vorlauf']) {
    $('#e-' + k).value = e[k];
    $('#o-' + k).textContent = komma(e[k], k === 'nachlauf' ? 1 : 0) + ' s';
  }
  renderExportInfo();
}

function setzeEinst(k, v) {
  S.einst[k] = v;
  renderEinst();
  if (S.clips && S.clips.length) {
    renderStats();
    if (k === 'uebergang') renderMontage(false);
  }
  pruefeAnalyseHinweis();
  clearTimeout(speicherTimer);
  speicherTimer = setTimeout(async () => {
    try { S.einst = { ...S.einst, ...(await api('/api/einstellungen', { method: 'PUT', body: S.einst })) }; }
    catch (e) { toast('Einstellungen nicht gespeichert: ' + e.message); }
  }, 300);
}

function pruefeAnalyseHinweis() {
  const anders = S.clips !== null && S.analyseEinst && ANALYSE_FELDER.some((k) => S.analyseEinst[k] !== S.einst[k]);
  $('#hinweis-neu').hidden = !anders;
}

// ------------------------------------------------------------------ Sitzung merken (nur Komfort)
let sitzungTimer = null;
function speichereSitzung() {
  clearTimeout(sitzungTimer);
  sitzungTimer = setTimeout(() => {
    try {
      localStorage.setItem(SPEICHER_KEY, JSON.stringify({
        clips: (S.clips || []).map(ohneIntern), analysen: S.analysen, analyseVideos: S.analyseVideos,
        analyseEinst: S.analyseEinst, zeit: Date.now(),
      }));
    } catch { /* egal */ }
  }, 400);
}

function ladeSitzung() {
  try {
    const d = JSON.parse(localStorage.getItem(SPEICHER_KEY) || 'null');
    if (d && Array.isArray(d.clips) && d.clips.length) return d;
  } catch { /* egal */ }
  return null;
}

function zeigeWeiterKnopf() {
  const b = $('#btn-weiter');
  if (S.clips !== null) {
    b.hidden = false;
    b.textContent = `Zurück zu den Highlights (${S.clips.length} Clips)`;
    b.onclick = () => zeigeView('clips');
    return;
  }
  const d = ladeSitzung();
  if (!d) { b.hidden = true; return; }
  b.hidden = false;
  b.textContent = `Letzte Highlights weiter bearbeiten (${d.clips.length} Clips)`;
  b.onclick = () => {
    S.clips = d.clips.map((c) => ({ ...c, _id: neueId() }));
    S.analysen = d.analysen || {};
    S.analyseVideos = d.analyseVideos || [];
    S.analyseEinst = d.analyseEinst || null;
    S.pid = null;
    b.hidden = true;
    zeigeView('clips');
    renderClips();
    pruefeAnalyseHinweis();
  };
}

// ------------------------------------------------------------------ Ereignisse verdrahten
function verdrahte() {
  $$('.step, .rail-btn[data-view]').forEach((b) => b.addEventListener('click', () => { if (!b.disabled) zeigeView(b.dataset.view); }));
  $('#rail-einst').addEventListener('click', () => {
    if (S.view === 'aufnahmen') { $('#einst-block').scrollIntoView({ behavior: 'smooth', block: 'start' }); return; }
    if (S.clips && S.clips.length) { zeigeView('clips'); zeigeTab('einst'); }
    else zeigeView('aufnahmen');
  });

  // Aufnahmen-Liste (Delegation)
  $('#liste').addEventListener('click', (e) => {
    const akt = e.target.closest('[data-aktion]');
    if (akt) {
      const gruppe = akt.closest('.gruppe');
      const spiel = gruppe && gruppe.dataset.spiel;
      const a = akt.dataset.aktion;
      if (a === 'alle') {
        e.stopPropagation();
        const liste = alleVideos().filter((v) => v.spiel === spiel);
        const alleDrin = liste.every((v) => S.auswahl.has(v.pfad));
        liste.forEach((v) => (alleDrin ? S.auswahl.delete(v.pfad) : S.auswahl.add(v.pfad)));
        renderListe(); renderAuswahl();
      } else if (a === 'gruppe') {
        S.offen[spiel] = !gruppe.classList.contains('offen');
        renderListe();
      } else if (a === 'mehr') { S.mehr[spiel] = true; renderListe(); }
      else if (a === 'datei') dateiDialog();
      else if (a === 'neu-laden') ladeVideos();
      return;
    }
    const z = e.target.closest('.video-zeile');
    if (z) waehle(z.dataset.pfad);
  });
  $('#liste').addEventListener('keydown', (e) => {
    const z = e.target.closest('.video-zeile');
    if (z && (e.key === ' ' || e.key === 'Enter')) { e.preventDefault(); waehle(z.dataset.pfad); }
  });
  $('#auswahl-chips').addEventListener('click', (e) => {
    const b = e.target.closest('[data-weg]');
    if (b) waehle(b.dataset.weg, false);
  });
  $('#suche').addEventListener('input', (e) => { S.filter = e.target.value; renderListe(); });
  $('#btn-neu-laden').addEventListener('click', ladeVideos);
  $('#btn-datei').addEventListener('click', dateiDialog);
  $('#btn-finden').addEventListener('click', () => starteAnalyse());

  // Drag & Drop eigener Dateien (überall im Fenster, solange Schritt 1 offen ist)
  let dragTiefe = 0;
  const hatDateien = (e) => e.dataTransfer && [...e.dataTransfer.types].includes('Files');
  window.addEventListener('dragenter', (e) => {
    if (!hatDateien(e)) return;
    e.preventDefault();
    dragTiefe++;
    if (S.view === 'aufnahmen') { $('#drop-overlay').hidden = false; $('#drop').classList.add('aktiv'); }
  });
  window.addEventListener('dragover', (e) => { if (hatDateien(e)) e.preventDefault(); });
  window.addEventListener('dragleave', (e) => {
    if (!hatDateien(e)) return;
    if (--dragTiefe <= 0) { dragTiefe = 0; $('#drop-overlay').hidden = true; $('#drop').classList.remove('aktiv'); }
  });
  window.addEventListener('drop', (e) => {
    if (!hatDateien(e)) return;
    e.preventDefault();
    dragTiefe = 0;
    $('#drop-overlay').hidden = true;
    $('#drop').classList.remove('aktiv');
    if (S.view !== 'aufnahmen') { toast('Videos hinzufügen geht in Schritt 1 „Aufnahmen“.', { knopf: 'Hin', aktion: () => zeigeView('aufnahmen') }); return; }
    dropDateien([...e.dataTransfer.files]);
  });

  // Keine Highlights
  $('#clips-leer').addEventListener('click', (e) => {
    const akt = e.target.closest('[data-aktion]');
    if (!akt) return;
    if (akt.dataset.aktion === 'zurueck') zeigeView('aufnahmen');
    if (akt.dataset.aktion === 'mit-toden') {
      S.einst.eigene_tode = true;
      setzeEinst('champion', true);
      starteAnalyse(S.analyseVideos);
    }
  });

  // Clip-Raster
  const box = $('#kacheln');
  box.addEventListener('click', (e) => {
    const el = e.target.closest('.kachel');
    if (!el) return;
    const c = clipNach(el.dataset.id);
    if (e.target.closest('.k-an')) { setzeAktiv(c, !c.aktiv); return; }
    if (S.pid !== c._id) waehleClip(c, false);
  });
  box.addEventListener('dblclick', (e) => {
    const el = e.target.closest('.kachel');
    if (el && !e.target.closest('.k-an')) waehleClip(clipNach(el.dataset.id), true);
  });
  box.addEventListener('keydown', (e) => {
    const el = e.target.closest('.kachel');
    if (el && e.key === 'Enter') { e.preventDefault(); waehleClip(clipNach(el.dataset.id), true); }
  });
  initKachelDnD(box);

  // Details
  const d = $('#detail');
  d.addEventListener('click', (e) => {
    const c = clipNach(S.pid);
    if (!c) return;
    const j = e.target.closest('[data-j]');
    if (j) { justiere(c, j.dataset.j, parseFloat(j.dataset.d)); return; }
    const m = e.target.closest('[data-move]');
    if (m) { verschiebe(c._id, parseInt(m.dataset.move, 10)); return; }
    const mo = e.target.closest('.moment');
    if (mo) zeigeBild(c, Math.max(0, parseFloat(mo.dataset.t) - 1.5));
  });
  d.addEventListener('change', (e) => {
    if (e.target.matches('.d-an')) setzeAktiv(clipNach(S.pid), e.target.checked);
  });
  d.addEventListener('pointerdown', (e) => { if (e.target.closest('.tl')) zeitleisteStart(e); });
  $$('#a-clips .tab').forEach((b) => b.addEventListener('click', () => zeigeTab(b.dataset.tab)));

  // Montage
  $('#montage').addEventListener('pointerdown', montageKlick);
  window.addEventListener('resize', () => { if (S.view === 'clips' && S.clips && S.clips.length) renderMontage(); });

  // Player
  $('#btn-play').addEventListener('click', playPause);
  $('#player').addEventListener('click', playPause);
  $('#btn-prev').addEventListener('click', () => nachbar(-1));
  $('#btn-next').addEventListener('click', () => nachbar(1));
  $('#scrub').addEventListener('pointerdown', scrubStart);
  $('#btn-montage').addEventListener('click', starteMontage);
  $('#btn-export').addEventListener('click', starteExport);
  $('#btn-neu-berechnen').addEventListener('click', () => starteAnalyse(S.analyseVideos));
  $('#btn-neu-berechnen-klein').addEventListener('click', () => starteAnalyse(S.analyseVideos));
  $('#player').addEventListener('error', () => {
    if ($('#player').getAttribute('src')) toast('Dieses Video kann die Vorschau nicht abspielen (Format?). Der Export klappt trotzdem.');
  });

  document.addEventListener('keydown', (e) => {
    if (S.view !== 'clips' || !$('#auftrag').hidden) return;
    if (e.target.closest && e.target.closest('input, textarea, select, summary')) return;
    if (e.key === ' ') { e.preventDefault(); playPause(); }
    else if (e.key === 'ArrowLeft') { e.preventDefault(); nachbar(-1); }
    else if (e.key === 'ArrowRight') { e.preventDefault(); nachbar(1); }
  });

  // Auftrag
  $('#btn-abbrechen').addEventListener('click', abbrechen);
  $('#btn-schliessen').addEventListener('click', () => { $('#auftrag').hidden = true; });
  $('#btn-nochmal').addEventListener('click', () => { $('#auftrag').hidden = true; if (nochmalAktion) nochmalAktion(); });

  // Fertig
  $('#btn-ordner').addEventListener('click', () => oeffne(S.exportErgebnis.pfad, 'zeigen'));
  $('#btn-abspielen').addEventListener('click', () => oeffne(S.exportErgebnis.pfad, 'abspielen'));
  $('#btn-zurueck-clips').addEventListener('click', () => zeigeView('clips'));
  $('#btn-neue-runde').addEventListener('click', () => { zeigeView('aufnahmen'); });

  // Einstellungen
  $$('#seg-format button, #seg-format-mini button').forEach((b) => b.addEventListener('click', () => setzeEinst('format', b.dataset.format)));
  $('#e-tode').addEventListener('change', (e) => setzeEinst('eigene_tode', e.target.checked));
  $('#e-champion').addEventListener('change', (e) => setzeEinst('champion', e.target.checked));
  $('#e-uebergang').addEventListener('input', (e) => setzeEinst('uebergang', parseFloat(e.target.value)));
  for (const k of ['nachlauf', 'zusammenfassen', 'max_vorlauf']) {
    $('#e-' + k).addEventListener('input', (e) => setzeEinst(k, parseFloat(e.target.value)));
  }
}

async function start() {
  verdrahte();
  zeigeView('aufnahmen');
  try {
    S.info = await api('/api/info');
    setzeMock(S.info.mock);
    $('#ausgabe-ordner').textContent = 'Fertige Videos landen in ' + S.info.ausgabe;
  } catch { /* zeigt sich gleich beim Laden der Liste */ }
  try { S.einst = await api('/api/einstellungen'); } catch (e) {
    toast(e.message);
    S.einst = { format: '16:9', eigene_tode: false, champion: false, uebergang: 0.3, nachlauf: 3, zusammenfassen: 10, max_vorlauf: 25, hoehe: 1080, fps: 60 };
  }
  renderEinst();
  zeigeWeiterKnopf();
  requestAnimationFrame(playerSchleife);
  await ladeVideos();
}

start();
