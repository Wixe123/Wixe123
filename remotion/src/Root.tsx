import React from "react";
import { Composition } from "remotion";
import { ShortsForgeIntro } from "./ShortsForgeIntro";
import { ShortsForgeOutro } from "./ShortsForgeOutro";

// 9:16 vertical, matching the Shorts canvas the rest of the pipeline
// renders to (see explainer_visuals.py: width_px=1080, height_px=1920).
const WIDTH = 1080;
const HEIGHT = 1920;
const FPS = 30;

export const Root: React.FC = () => {
  return (
    <>
      <Composition
        id="ShortsForgeIntro"
        component={ShortsForgeIntro}
        durationInFrames={FPS * 2}
        fps={FPS}
        width={WIDTH}
        height={HEIGHT}
        defaultProps={{ channelName: "ShortsForge" }}
      />
      <Composition
        id="ShortsForgeOutro"
        component={ShortsForgeOutro}
        durationInFrames={Math.round(FPS * 1.5)}
        fps={FPS}
        width={WIDTH}
        height={HEIGHT}
        defaultProps={{ ctaText: "Subscribe for more" }}
      />
    </>
  );
};
