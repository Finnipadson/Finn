import { Composition } from "remotion";
import { DURATION_IN_FRAMES, FPS, SatzDesPythagoras } from "./Composition";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="SatzDesPythagoras"
      component={SatzDesPythagoras}
      durationInFrames={DURATION_IN_FRAMES}
      fps={FPS}
      width={1080}
      height={1920}
    />
  );
};
