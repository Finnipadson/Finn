import fs from "node:fs";
import path from "node:path";
import { bundle } from "@remotion/bundler";
import { makeCancelSignal, renderMedia, renderStill, selectComposition } from "@remotion/renderer";
import type { Drehbuch, Timing } from "../src/drehbuch/typen";
import { coverBild } from "../src/drehbuch/pruefen";
import { ROOT } from "./projekte";

/* Rendert ein Drehbuch direkt aus dem Server (ohne Terminal): MP4 + Cover-Bild.
   Fortschritt kommt über `melde`, Abbrechen über die zurückgegebene Funktion. */

export type RenderAuftrag = {
  drehbuch: Drehbuch;
  timing: Timing | null;
  audio: string | null; // Pfad im public-Ordner, z. B. "ton/akku.wav"
  video: string;        // Zieldatei .mp4
  cover: string;        // Zieldatei .png
};

export class Abgebrochen extends Error {}

export const starteRender = (a: RenderAuftrag, melde: (status: string, fortschritt: number) => void) => {
  const { cancelSignal, cancel } = makeCancelSignal();
  let abgebrochen = false;
  const pruefeAbbruch = () => { if (abgebrochen) throw new Abgebrochen("Abgebrochen."); };

  const fertig = (async () => {
    const t0 = Date.now();
    // 1) Video-Code bündeln (Webpack, mit Cache → ab dem 2. Mal schnell). Kopiert public/ mit (Tonspur).
    melde("Video wird vorbereitet …", 0);
    const serveUrl = await bundle({
      entryPoint: path.join(ROOT, "src", "video", "index.ts"),
      publicDir: path.join(ROOT, "public"),
      onProgress: (p) => melde(`Video wird vorbereitet … ${p} %`, (p / 100) * 0.05),
    });
    pruefeAbbruch();

    const inputProps = { drehbuch: a.drehbuch, timing: a.timing, audio: a.audio };
    const composition = await selectComposition({ serveUrl, id: "Erklaervideo", inputProps });
    pruefeAbbruch();

    // 2) Video rendern – erst in eine Temp-Datei, damit ein Abbruch das alte Video nicht zerstört
    // gl "angle" = Grafikkarte: rund 8× schneller (Weichzeichner im Hintergrund). Klappt das nicht → normaler Modus.
    const tmp = `${a.video}.tmp.mp4`;
    let tStart = Date.now();
    const rendere = (gl: "angle" | null) => renderMedia({
      composition, serveUrl, inputProps, codec: "h264", outputLocation: tmp,
      crf: 16, audioBitrate: "256k", cancelSignal, chromiumOptions: gl ? { gl } : {},
      onProgress: ({ progress, renderedFrames }) => {
        const vergangen = (Date.now() - tStart) / 1000;
        const rest = progress > 0.03 ? Math.max(0, (vergangen / progress) * (1 - progress)) : null;
        melde(
          progress < 0.995
            ? `Bild ${renderedFrames} von ${composition.durationInFrames}${rest !== null ? ` · noch etwa ${rest < 60 ? `${Math.ceil(rest)} s` : `${Math.ceil(rest / 60)} min`}` : ""}`
            : "Video wird fertig gestellt …",
          0.05 + progress * 0.9,
        );
      },
    });
    try {
      await rendere("angle").catch((e) => {
        if (abgebrochen) throw e;
        console.warn("Rendern mit Grafikkarte fehlgeschlagen, versuche normalen Modus:", e instanceof Error ? e.message : e);
        melde("Grafikkarte nicht nutzbar – rendere im normalen Modus (langsamer) …", 0.05);
        tStart = Date.now();
        return rendere(null);
      });
    } catch (e) {
      fs.rmSync(tmp, { force: true });
      if (abgebrochen) throw new Abgebrochen("Abgebrochen.");
      throw e;
    }
    pruefeAbbruch();
    fs.renameSync(tmp, a.video);

    // 3) Cover-Bild (Titel-Szene, ohne Untertitel)
    melde("Cover-Bild wird erstellt …", 0.97);
    // Remotion nimmt die Props aus `composition.props` (nicht aus inputProps) → dort „cover“ setzen
    const coverProps = { ...inputProps, cover: true };
    const still = (gl: "angle" | null) => renderStill({
      composition: { ...composition, props: { ...composition.props, ...coverProps } }, serveUrl, output: a.cover, imageFormat: "png",
      frame: Math.min(composition.durationInFrames - 1, coverBild(a.drehbuch, a.timing)),
      inputProps: coverProps, chromiumOptions: gl ? { gl } : {},
    });
    await still("angle").catch(() => still(null));
    return { dauerMs: Date.now() - t0, bytes: fs.statSync(a.video).size, sekunden: composition.durationInFrames / composition.fps };
  })();

  return { fertig, abbrechen: () => { abgebrochen = true; cancel(); } };
};
