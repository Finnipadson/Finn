import React from "react";
import { Composition } from "remotion";
import { DemoTitel } from "./DemoTitel";

export const Root: React.FC = () => (
  <>
    <Composition id="DemoHoch" component={DemoTitel} durationInFrames={180} fps={60} width={1080} height={1920}
      defaultProps={{ titel: "Erklärvideo", unter: "Studio · Phase 0" }} />
    <Composition id="DemoQuer" component={DemoTitel} durationInFrames={180} fps={60} width={1920} height={1080}
      defaultProps={{ titel: "Erklärvideo", unter: "Studio · Phase 0" }} />
  </>
);
