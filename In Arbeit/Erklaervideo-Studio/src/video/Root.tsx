import React from "react";
import { Composition } from "remotion";
import { DemoTitel } from "./DemoTitel";
import { dauerInBildern, Erklaervideo, type ErklaervideoProps } from "./Erklaervideo";
import pythagoras from "../../beispiele/pythagoras.json";
import type { Drehbuch } from "../drehbuch/typen";

export const Root: React.FC = () => (
  <>
    {/* Das eigentliche Video: spielt jedes Drehbuch ab. Props kommen beim Rendern aus tools/render.ts. */}
    <Composition
      id="Erklaervideo"
      component={Erklaervideo}
      fps={60}
      width={1080}
      height={1920}
      durationInFrames={600}
      defaultProps={{ drehbuch: pythagoras as Drehbuch, timing: null, audio: null } satisfies ErklaervideoProps}
      calculateMetadata={({ props }) => ({
        durationInFrames: dauerInBildern(props.drehbuch, props.timing),
        width: props.drehbuch.format === "hoch" ? 1080 : 1920,
        height: props.drehbuch.format === "hoch" ? 1920 : 1080,
      })}
    />
    <Composition id="DemoHoch" component={DemoTitel} durationInFrames={180} fps={60} width={1080} height={1920}
      defaultProps={{ titel: "Erklärvideo", unter: "Studio" }} />
    <Composition id="DemoQuer" component={DemoTitel} durationInFrames={180} fps={60} width={1920} height={1080}
      defaultProps={{ titel: "Erklärvideo", unter: "Studio" }} />
  </>
);
