/* Übersetzt technische Fehlermeldungen (Python, FFmpeg, Remotion, Node) in verständliches Deutsch.
   Unbekanntes bleibt erhalten, damit man es notfalls nachschlagen kann. */

const REGELN: [RegExp, string][] = [
  [/FEHLER-INTERNET|NoAudioReceived|getaddrinfo|ClientConnector|Cannot connect to host|WSServerHandshakeError|ENOTFOUND|ECONNRESET|ETIMEDOUT/i,
    "Die Stimme braucht Internet (Microsoft-Sprachdienst), aber es kam keine Antwort. Bitte die Internetverbindung prüfen und es noch einmal versuchen."],
  [/No module named ['"]?edge_tts/i, "Das Python-Paket „edge-tts“ fehlt. Im Terminal ausführen: python -m pip install edge-tts"],
  [/ffmpeg.*(not found|nicht gefunden|No such file)|FileNotFoundError.*ffmpeg|WinError 2/i, "FFmpeg wurde nicht gefunden. Im Terminal ausführen: winget install Gyan.FFmpeg – danach die App neu starten."],
  [/Page crashed|Target closed|Out of memory|ENOMEM/i, "Der Render-Browser ist abgestürzt – meist zu wenig freier Arbeitsspeicher. Bitte andere Programme schließen und erneut rendern."],
  [/ENOSPC|No space left/i, "Die Festplatte ist voll. Bitte Platz schaffen und erneut versuchen."],
  [/EBUSY|EPERM|being used by another process|resource busy/i, "Die Datei ist noch in einem anderen Programm geöffnet (z. B. im Video-Player). Bitte dort schließen und erneut versuchen."],
  [/Could not find (a )?(Chrome|browser)|Failed to launch the browser/i, "Der Render-Browser konnte nicht gestartet werden. Bitte im Ordner des Studios `npx remotion browser ensure` ausführen."],
];

export const verstaendlich = (roh: string): string => {
  const text = roh.trim();
  for (const [muster, meldung] of REGELN) if (muster.test(text)) return meldung;
  // Unbekannt: die letzten aussagekräftigen Zeilen
  const zeilen = text.split(/\r?\n/).map((z) => z.trim()).filter(Boolean);
  return zeilen.slice(-3).join(" ").slice(0, 400) || "Unbekannter Fehler.";
};
