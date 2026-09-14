import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { ACCENT, BG, INK } from "./theme";

export const ShortsForgeIntro: React.FC<{ channelName: string }> = ({
  channelName,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const scale = spring({ frame, fps, config: { damping: 14, mass: 0.6 } });
  const barWidth = interpolate(frame, [10, 30], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: BG,
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <div
        style={{
          transform: `scale(${scale})`,
          textAlign: "center",
        }}
      >
        <div
          style={{
            color: INK,
            fontSize: 84,
            fontWeight: 800,
            fontFamily: "Arial, sans-serif",
            letterSpacing: -1,
          }}
        >
          {channelName}
        </div>
        <div
          style={{
            marginTop: 24,
            height: 6,
            width: 320 * barWidth,
            backgroundColor: ACCENT,
            marginLeft: "auto",
            marginRight: "auto",
          }}
        />
      </div>
    </AbsoluteFill>
  );
};
