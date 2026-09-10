# ShortsForge — Personal AI Shorts Studio

Turns long-form video into YouTube Shorts: AI clip detection, animated
subtitles, auto vertical reframing, branding, AI-generated metadata, and
one-click upload to your own YouTube channel via the YouTube Data API.

Built for **personal/single-tenant use**. It is not multi-tenant SaaS and
has no billing, public signup, or content-moderation layer.

## What's actually implemented

This is a real, runnable pipeline — not a mockup — but it does not include
things nobody can honestly ship in one repo: a proprietary "virality"
model, a GPU cluster, or a cloud deployment of your own infrastructure.
Concretely:

| Feature | Status |
|---|---|
| Google login + JWT sessions | Implemented |
| Upload (drag & drop, multi-file) | Implemented |
| Import from YouTube URL (`yt-dlp`) | Implemented |
| Transcription (word-level timestamps) | Implemented via `faster-whisper` |
| Clip candidate detection | Implemented — **heuristic** scorer (audio energy, speech rate, keyword/question/emotion hits, sentence boundaries), not a trained virality model |
| Auto 9:16 reframe | Implemented — OpenCV face detection samples the clip in windows and the crop pans smoothly between them, following the subject through movement/cuts instead of one static crop; falls back to a centered crop when no face is found |
| Auto color grade | Implemented — subtle contrast/saturation lift (ffmpeg `eq`) applied to every render by default |
| Silence removal / loudness normalization | Implemented via ffmpeg `silencedetect` + `acompressor` + `loudnorm` |
| Word-by-word animated subtitles | Implemented — ASS subtitles generated from Whisper word timestamps, burned in with ffmpeg |
| Branding (logo/watermark/intro/outro/fonts/colors, presets) | Implemented |
| AI metadata (title/description/hashtags/SEO score) | Implemented — template-based generator, or set `ANTHROPIC_API_KEY` to use Claude instead |
| Queue (parallel jobs, retry/pause/resume/cancel) | Implemented via Celery + Redis |
| Scheduling + visibility (public/unlisted/private/draft) | Implemented |
| YouTube upload (OAuth, metadata, thumbnail, playlist) | Implemented via `google-api-python-client`, requires your own OAuth client credentials |
| Live YouTube Analytics (views, watch time, subscribers, likes, per-clip performance) | Implemented via the YouTube Analytics API (`yt-analytics.readonly` scope) — see the Analytics page. Channels connected before this feature was added need to hit "Reconnect" in Settings once to grant the new permission. |
| Dashboard (today's stats, queue, storage/API usage) | Implemented |
| Mobile / iPhone use | Implemented as a responsive web app — collapsible sidebar becomes a bottom tab bar on small screens, tables scroll horizontally, and it's installable to the iOS home screen ("Add to Home Screen" in Safari) via `manifest.json` + Apple touch icons for an app-like feel. This is Safari-based, not a native Swift app. |
| Faceless explainer video generation | Implemented — writes a from-scratch Vox-style Short (topic + script via Claude, narration via `edge-tts`/`espeak-ng`, charts/Wikimedia photos/text callouts, captions) instead of cutting a clip from your own footage. Requires `ANTHROPIC_API_KEY`. See below. |
| GPU acceleration / 50 videos-per-day throughput | **Not provisioned here.** The pipeline is GPU-ready (`faster-whisper` and ffmpeg both use CUDA when available) — running it at that volume is a matter of running more Celery workers on GPU-backed machines, which is an infra/ops decision for your own cloud account, not something a repo can pre-package.
| Cloud deployment (Terraform/GCP/AWS) | Not included — `docker-compose.yml` covers local/single-VM deployment. Point it at a GPU box and it will use the GPU. |

## Architecture

```
frontend/   Next.js 14 (App Router) + TypeScript + Tailwind + Framer Motion
backend/    FastAPI + SQLAlchemy + Alembic + Celery
            ffmpeg / faster-whisper / opencv-python for the media pipeline
            google-api-python-client for YouTube
postgres    metadata (users, videos, clips, jobs, branding, settings)
redis       Celery broker/result backend + job queue state
```

Pipeline: `upload → transcribe → score & pick clips → render (pan-tracking
reframe + color grade + subtitles + branding + silence removal + audio
compression/loudness norm) → generate metadata → your review/approval →
upload to YouTube`.

## Running it

```bash
cp .env.example .env        # fill in secrets, see below
docker compose up --build
```

- Frontend: http://localhost:3000
- Backend API docs: http://localhost:8000/docs

### Required credentials (`.env`)

- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` — a Google Cloud OAuth client
  (used both for logging into the dashboard and, with the YouTube scope,
  for uploading). Create it in Google Cloud Console, enable the
  **YouTube Data API v3**, and add `http://localhost:8000/api/auth/*/callback`
  as an authorized redirect URI.
- `SECRET_KEY` — random string for JWT signing.
- `FERNET_KEY` — random 32-byte urlsafe-base64 key (`python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`) used to encrypt stored OAuth refresh tokens at rest.
- `ANTHROPIC_API_KEY` (optional) — enables LLM-generated titles/descriptions/hashtags instead of the template fallback.

You are responsible for complying with the YouTube API Services Terms of
Service and YouTube's Community Guidelines for anything this app uploads.

### Fixing "Please sign in" when importing from a YouTube URL

YouTube increasingly rejects automated download requests — even for
ordinary public videos — unless they look like they're coming from a real
logged-in browser session. If importing a video by URL fails with
`ERROR: [youtube] ...: Please sign in`, give it your own session cookies:

1. Install a cookie-export browser extension, e.g. "Get cookies.txt
   LOCALLY" (Chrome/Firefox).
2. While logged into YouTube, use the extension to export cookies for
   `youtube.com` to a file.
3. In this project's folder, create a `secrets/` folder (next to
   `docker-compose.yml`) and save the exported file as
   `secrets/youtube_cookies.txt`.
4. In `.env`, uncomment/set:
   ```
   YTDLP_COOKIES_FILE=/secrets/youtube_cookies.txt
   ```
5. Restart: `docker compose up --build`.

`secrets/` is git-ignored — this file never gets committed. Treat it like
a password: it's your real login session, so don't share it, and re-export
it if imports start failing again (cookies expire).

### Daily YouTube/Shorts trends email digest

A `beat` container fires a scheduled job once a day that pulls recent
posts from a few creator-economy sources (YouTube's official blog,
TubeFilter, Social Media Today, VidIQ's blog), optionally summarizes them
with Claude if `ANTHROPIC_API_KEY` is set (otherwise it emails a plain
grouped headline list), and sends it to you by email. This is general
trend/news commentary, not an analysis of your own channel's numbers —
that's what the in-app Analytics page is for.

**This only fires on days your Docker stack is actually running** — it's
not a cloud service, so if `docker compose` isn't up at the scheduled
hour, that day's email just doesn't go out.

Setup (uses your existing Gmail account, no new service to sign up for):

1. Turn on 2-Step Verification on your Google account if it isn't already
   (required for the next step): `myaccount.google.com/security`.
2. Generate an App Password: `myaccount.google.com/apppasswords` — name it
   anything (e.g. "ShortsForge"), copy the 16-character password it gives
   you.
3. In `.env`, set:
   ```
   SMTP_USERNAME=your.email@gmail.com
   SMTP_PASSWORD=<the 16-character app password, no spaces>
   DIGEST_RECIPIENT_EMAIL=your.email@gmail.com
   ```
   (`SMTP_USERNAME` and `DIGEST_RECIPIENT_EMAIL` can be different people —
   e.g. send from a throwaway Gmail to your main inbox.)
4. Optionally change `DIGEST_HOUR_UTC` (default 8, i.e. 8am UTC — convert
   your local send time to UTC).
5. Restart: `docker compose up --build`.

### Fully hands-off pipeline (auto-import + auto-upload)

Two independent Settings toggles let the whole thing run without touching
it, video in → Short out:

- **Auto-import new uploads from my channel** — polls your connected
  channel's uploads every 30 minutes (via the same `beat` container as the
  digest above) and automatically starts the clip pipeline on anything
  new, same as pasting the URL in yourself. Requires YouTube connected in
  Settings.
- **Auto-upload clips above a score threshold** — clips scoring at or
  above the threshold you set skip manual review entirely and upload as
  soon as they're rendered. Anything below the bar still lands in the
  normal review queue. **On by default at a threshold of 7** (out of a
  roughly 0-10 range) — turn it off or change the number in Settings if
  you'd rather review everything yourself.

Both only pull from **your own** connected channel — there's no "find
trending videos from other creators" mode, since auto-downloading and
re-uploading someone else's content without permission is copyright
infringement and would violate YouTube's Terms of Service. Use the Style
Analyzer page instead to learn from other creators' technique without
touching their actual content.

Like the digest, this only runs on days your Docker stack is up.

### Faceless explainer videos

Settings → **Faceless videos** lets you generate a Short from scratch,
with no source footage of your own required — a Vox-style explainer, not a
clip cut from a longer video:

1. Set a **channel niche** (e.g. "space exploration", "ancient history").
2. Claude picks one specific, narrow topic within that niche (avoiding
   recently-covered topics) and writes a 45-65 second script broken into
   beats — one or two sentences of narration each, paired with a visual:
   a chart (only when the script has real numbers to plot), a photo/map
   search query, or a text callout.
3. Narration is synthesized with `edge-tts` (free, no API key), falling
   back to offline `espeak-ng` if that endpoint is ever unreachable from
   your network.
4. Each beat's visual is rendered — a `matplotlib` chart, a licensed
   photo from Wikimedia Commons (public domain/CC only), or a big text
   callout — and given a slow Ken Burns pan/zoom for its share of the
   narration's runtime.
5. Segments are stitched together, muxed with the narration, and captions
   + your default watermark are burned in — landing as a normal
   Video + Clip that flows through the same review/approve/upload path
   as any other clip, including **auto-upload** if you flip that toggle.

Click **Generate one now** to trigger a run on demand — there's no
automatic recurring schedule for this yet, so it stays a deliberate,
per-click action rather than something silently generating content on its
own. Requires `ANTHROPIC_API_KEY` (used for both topic/script writing and,
optionally, metadata generation) — there's no template fallback for
picking a real topic and writing accurate narration.

## Using it from your iPhone

The dashboard is responsive (bottom tab bar, scrollable tables, "Add to
Home Screen" support), so the UI itself works fine in Safari. The catch
is Google OAuth: Google only allows an `http://` redirect URI for
`localhost` — any other address (like your computer's LAN IP) must be
`https://`, or the Google/YouTube login step will fail. So `http://<your
LAN IP>:3000` from your phone gets you the UI but not a working login.
Two ways around that:

1. **Tunnel (fastest, good for trying it out):** run something like
   `cloudflared tunnel --url http://localhost:3000` (or `ngrok http 3000`,
   plus one for port 8000) to get a temporary `https://...` URL. Set
   `FRONTEND_URL`, `GOOGLE_REDIRECT_URI`, and `YOUTUBE_REDIRECT_URI` in
   `.env` to the tunneled HTTPS URLs, add them as authorized redirect URIs
   in Google Cloud Console, rebuild the frontend with
   `NEXT_PUBLIC_API_URL` pointing at the tunneled backend URL, and open
   the tunneled frontend URL on your iPhone.
2. **Real deployment (durable):** put this on a small VPS behind a domain
   with real TLS (e.g. Caddy for automatic Let's Encrypt certs), point
   the same three env vars and the Google redirect URIs at that domain.
   Then any device, iPhone included, just works like a normal website.

Either way, uploading large source videos is still easiest from a
computer — the iPhone view is most useful for the review/approve step
once clips exist.

## Scaling beyond one box

The worker count is configured via `CELERY_CONCURRENCY`; run
`docker compose up --scale worker=4` (or deploy `worker` on a GPU VM) to
raise throughput toward the 50 videos/day target. Whisper model size and
export resolution/quality are configurable in Settings and trade off
directly against processing time.

## Repo layout

```
backend/
  app/
    core/       config, JWT, encryption
    db/         SQLAlchemy models + session
    schemas/    Pydantic request/response models
    api/routes/ FastAPI routers
    services/   ffmpeg, whisper, scoring, subtitles, YouTube client, AI metadata
    workers/    Celery app + tasks
  alembic/      migrations
frontend/
  app/          dashboard, upload, review, queue, settings, branding pages
  components/   dashboard UI components
  lib/          API client + types
```
