# ShortsForge Remotion project

Renders branded intro/outro cards (9:16, matching the rest of the
pipeline's Shorts canvas) as standalone MP4s using
[Remotion](https://github.com/remotion-dev/remotion).

This is intentionally separate from the main render pipeline in
`backend/app/services/ffmpeg_utils.py`, which already burns in captions,
watermark, and does the color grade/reframe/silence-removal work with
ffmpeg directly. Use this project to pre-render an intro/outro clip once,
then point the existing branding settings at the resulting file the same
way you would any other watermark/logo asset — there's no code change
needed in the backend to use a rendered clip this way.

## Setup

```bash
cd remotion
npm install
```

On first render, Remotion downloads its own headless Chrome build. If
you're running in a sandboxed environment with restricted network egress
and already have a Chromium/headless-shell binary available, point Remotion
at it instead of letting it download one:

```bash
npx remotion render src/index.ts ShortsForgeIntro out/intro.mp4 \
  --browser-executable=/path/to/headless_shell
```

## Preview (hot-reloading studio)

```bash
npm run preview
```

## Render

```bash
npm run render        # -> out/intro.mp4
npm run render:outro  # -> out/outro.mp4
```

## Compositions

- `ShortsForgeIntro` — animated channel-name card, `channelName` prop.
- `ShortsForgeOutro` — "Subscribe" card, `ctaText` prop.

Both use the same black/yellow/white palette as the faceless-video beat
visuals (`remotion/src/theme.ts` mirrors the constants in
`backend/app/services/explainer_visuals.py`) so a rendered intro/outro
cuts together with the rest of a generated Short instead of clashing.

Override props per-render, e.g.:

```bash
npx remotion render src/index.ts ShortsForgeOutro out/outro.mp4 \
  --props='{"ctaText":"Hit follow for daily clips"}'
```
