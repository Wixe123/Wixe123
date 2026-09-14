import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { ACCENT, BG, INK } from "./theme";

export const ShortsForgeOutro: React.FC<{ ctaText: string }> = ({
  ctaText,
}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: BG,
        alignItems: "center",
        justifyContent: "center",
        opacity,
      }}
    >
      <div
        style={{
          color: ACCENT,
          fontSize: 56,
          fontWeight: 700,
          fontFamily: "Arial, sans-serif",
          textAlign: "center",
          padding: "0 80px",
        }}
      >
        {ctaText}
      </div>
      <div
        style={{
          position: "absolute",
          bottom: 140,
          color: INK,
          fontSize: 28,
          fontFamily: "Arial, sans-serif",
          opacity: 0.7,
        }}
      >
        ShortsForge
      </div>
    </AbsoluteFill>
  );
};
