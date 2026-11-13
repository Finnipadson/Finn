import { Composition } from "remotion";
import { ClaudeCodeErklaerung, DURATION_IN_FRAMES, FPS } from "./Composition";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="ClaudeCodeErklaerung"
      component={ClaudeCodeErklaerung}
      durationInFrames={DURATION_IN_FRAMES}
      fps={FPS}
      width={1920}
      height={1080}
    />
  );
};
