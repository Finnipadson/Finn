import React from "react";
import { Player, type PlayerRef } from "@remotion/player";
import { dauerInBildern, Erklaervideo } from "../video/Erklaervideo";
import type { Drehbuch, Timing } from "../drehbuch/typen";

/* Remotion-Player für ein Drehbuch – ohne Timing werden die Zeiten geschätzt. */
export const VorschauPlayer: React.FC<{
  drehbuch: Drehbuch; timing: Timing | null; audio: string | null;
  playerRef?: React.RefObject<PlayerRef | null>; maxHoehe?: string; autoPlay?: boolean;
}> = ({ drehbuch, timing, audio, playerRef, maxHoehe = "70vh", autoPlay }) => {
  const hoch = drehbuch.format === "hoch";
  return (
    <div className={`player-wrap ${hoch ? "hoch" : "quer"}`} style={hoch ? { height: `min(${maxHoehe}, 720px)` } : undefined}>
      <Player
        ref={playerRef as React.RefObject<PlayerRef>}
        component={Erklaervideo}
        inputProps={{ drehbuch, timing, audio }}
        durationInFrames={Math.max(30, dauerInBildern(drehbuch, timing))}
        fps={60}
        compositionWidth={hoch ? 1080 : 1920}
        compositionHeight={hoch ? 1920 : 1080}
        style={{ width: "100%", height: "100%" }}
        controls
        autoPlay={autoPlay}
        acknowledgeRemotionLicense
      />
    </div>
  );
};
