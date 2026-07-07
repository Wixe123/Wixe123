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
| Auto 9:16 reframe | Implemented — OpenCV face detection drives crop window; falls back to center crop |
| Silence removal / loudness normalization | Implemented via ffmpeg `silencedetect` + `loudnorm` |
| Word-by-word animated subtitles | Implemented — ASS subtitles generated from Whisper word timestamps, burned in with ffmpeg |
| Branding (logo/watermark/intro/outro/fonts/colors, presets) | Implemented |
| AI metadata (title/description/hashtags/SEO score) | Implemented — template-based generator, or set `ANTHROPIC_API_KEY` to use Claude instead |
| Queue (parallel jobs, retry/pause/resume/cancel) | Implemented via Celery + Redis |
| Scheduling + visibility (public/unlisted/private/draft) | Implemented |
| YouTube upload (OAuth, metadata, thumbnail, playlist) | Implemented via `google-api-python-client`, requires your own OAuth client credentials |
| Dashboard (today's stats, queue, storage/API usage) | Implemented |
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

Pipeline: `upload → transcribe → score & pick clips → render (reframe +
subtitles + branding + silence removal + loudness norm) → generate
metadata → your review/approval → upload to YouTube`.

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
