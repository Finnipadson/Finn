import { Composition } from "remotion";
import { DURATION_IN_FRAMES, ErklaervideoTest, FPS } from "./Composition";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="ErklaervideoTest"
      component={ErklaervideoTest}
      durationInFrames={DURATION_IN_FRAMES}
      fps={FPS}
      width={1080}
      height={1920}
    />
  );
};
