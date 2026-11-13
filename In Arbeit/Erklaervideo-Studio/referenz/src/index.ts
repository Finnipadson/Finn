import React from "react";
import { registerRoot } from "remotion";
import { RemotionRoot as AppleVideoRoot } from "./Apple Video/Root";
import { RemotionRoot as ErklaervideoTestRoot } from "./Erklaervideo Test/Root";
import { RemotionRoot as PythagorasRoot } from "./Satz des Pythagoras/Root";
import { RemotionRoot as KochSzeneHDRoot } from "./Koch Szene HD/Root";
import { RemotionRoot as ClaudeCodeRoot } from "./Claude Code Erklaerung/Root";

// Alle Videos im Studio anzeigen: jedes Video hat seinen eigenen Ordner mit Root.tsx
const AllVideos: React.FC = () =>
  React.createElement(
    React.Fragment,
    null,
    React.createElement(AppleVideoRoot),
    React.createElement(ErklaervideoTestRoot),
    React.createElement(PythagorasRoot),
    React.createElement(KochSzeneHDRoot),
    React.createElement(ClaudeCodeRoot),
  );

registerRoot(AllVideos);
