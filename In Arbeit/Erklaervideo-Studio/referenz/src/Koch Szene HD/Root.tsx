import { Composition } from "remotion";
import { DURATION_IN_FRAMES, FPS, KochSzeneHD } from "./Composition";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="KochSzeneHD"
      component={KochSzeneHD}
      durationInFrames={DURATION_IN_FRAMES}
      fps={FPS}
      width={1080}
      height={1920}
    />
  );
};
