import logging
import os
import shutil
import subprocess
from datetime import datetime, timedelta

from googleapiclient.errors import HttpError

from app.core.config import get_settings
from app.core.security import decrypt_secret
from app.db.models import (
    BrandingPreset,
    Clip,
    ClipStatus,
    JobStatus,
    JobType,
    ProcessingJob,
    StyleProfile,
    User,
    UserSettings,
    Video,
    VideoStatus,
    Visibility,
)
from app.db.session import SessionLocal
from app.services import ffmpeg_utils, storage, subtitles, video_import, youtube_client
from app.services.algorithm_digest import build_digest_email, fetch_recent_articles
from app.services.clip_scoring import find_candidates
from app.services.email_utils import send_email
from app.services.metadata_ai import generate_metadata
from app.services.style_analysis import analyze_style
from app.services.transcription import transcribe
from app.services.youtube_client import YOUTUBE_SCOPES
from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)
settings = get_settings()


def _job(db, job_id: str | None) -> ProcessingJob | None:
    return db.get(ProcessingJob, job_id) if job_id else None


def _mark(db, job: ProcessingJob | None, status: JobStatus, progress: float | None = None, error: str = ""):
    if not job:
        return
    job.status = status
    if progress is not None:
        job.progress = progress
    job.error_message = error
    db.commit()


def _is_transient(exc: Exception) -> bool:
    """Failures worth retrying: ffmpeg/ffprobe blips, dropped connections,
    timeouts, and 5xx responses from Google's API. Everything else (bad
    input, missing credentials, 4xx auth/quota errors) is permanent — retrying
    it would just burn the same error again, so those fail the job immediately."""
    if isinstance(exc, (subprocess.CalledProcessError, ConnectionError, TimeoutError, OSError)):
        return True
    if isinstance(exc, HttpError):
        return exc.resp is not None and exc.resp.status >= 500
    return False


def _retry_backoff_seconds(retries: int) -> int:
    return min(2**retries * 15, 300)


@celery_app.task(bind=True, max_retries=2)
def import_from_url_task(self, video_id: str, job_id: str | None = None):
    db = SessionLocal()
    try:
        video = db.get(Video, video_id)
        job = _job(db, job_id)
        _mark(db, job, JobStatus.RUNNING, progress=0.1)

        out_dir = storage.uploads_dir(video.owner_id)
        file_path, title = video_import.download_video(video.source_url, out_dir)

        video.file_path = file_path
        video.title = video.title or title
        video.size_bytes = storage.path_size_bytes(file_path)
        video.duration_seconds = ffmpeg_utils.get_duration_seconds(file_path)
        db.commit()

        _mark(db, job, JobStatus.SUCCESS, progress=1.0)
        analyze_video_task.delay(video_id)
    except Exception as exc:  # noqa: BLE001
        logger.exception("import_from_url_task failed (attempt %s)", self.request.retries)
        if _is_transient(exc) and self.request.retries < self.max_retries:
            raise self.retry(exc=exc, countdown=_retry_backoff_seconds(self.request.retries))
        video = db.get(Video, video_id)
        if video:
            video.status = VideoStatus.FAILED
            video.error_message = str(exc)
            db.commit()
        _mark(db, _job(db, job_id), JobStatus.FAILED, error=str(exc))
    finally:
        db.close()


@celery_app.task(bind=True, max_retries=2)
def analyze_video_task(self, video_id: str, job_id: str | None = None):
    db = SessionLocal()
    try:
        video = db.get(Video, video_id)
        if not video:
            return
        job = _job(db, job_id)
        _mark(db, job, JobStatus.RUNNING, progress=0.05)

        user_settings = db.query(UserSettings).filter_by(user_id=video.owner_id).first()
        min_s = user_settings.clip_min_seconds if user_settings else 15
        max_s = user_settings.clip_max_seconds if user_settings else 60
        max_clips = user_settings.max_clips_per_video if user_settings else 6
        sensitivity = user_settings.ai_sensitivity if user_settings else 0.5

        video.status = VideoStatus.TRANSCRIBING
        db.commit()

        work_dir = storage.clips_dir(video.id)
        wav_path = os.path.join(work_dir, "audio.wav")
        ffmpeg_utils.extract_audio(video.file_path, wav_path)

        _mark(db, job, JobStatus.RUNNING, progress=0.35)
        transcript = transcribe(wav_path, language=(user_settings.subtitle_language if user_settings else None))
        video.transcript = transcript
        video.status = VideoStatus.ANALYZING
        db.commit()

        _mark(db, job, JobStatus.RUNNING, progress=0.6)
        candidates = find_candidates(
            transcript["segments"], wav_path,
            min_seconds=min_s, max_seconds=max_s,
            max_clips=max_clips, sensitivity=sensitivity,
        )

        default_style = {}
        if user_settings:
            default_style = {
                "font": user_settings.subtitle_font,
                "color": user_settings.subtitle_color,
                "highlight_color": user_settings.subtitle_highlight_color,
                "stroke_color": user_settings.subtitle_stroke_color,
                "position": user_settings.subtitle_position,
                "emoji_enabled": user_settings.subtitle_emoji_enabled,
            }

        for cand in candidates:
            clip = Clip(
                video_id=video.id,
                start_seconds=cand.start,
                end_seconds=cand.end,
                score=cand.score,
                score_reasons=cand.reasons,
                status=ClipStatus.PENDING_RENDER,
                subtitle_style=default_style,
                branding_preset_id=user_settings.default_branding_preset_id if user_settings else None,
                visibility=user_settings.default_visibility if user_settings else Visibility.PRIVATE,
            )
            db.add(clip)
            db.commit()
            db.refresh(clip)
            render_job = ProcessingJob(job_type=JobType.RENDER_CLIP, video_id=video.id, clip_id=clip.id)
            db.add(render_job)
            db.commit()
            render_clip_task.delay(clip.id, render_job.id)

        video.status = VideoStatus.ANALYZED
        db.commit()
        _mark(db, job, JobStatus.SUCCESS, progress=1.0)
    except Exception as exc:  # noqa: BLE001
        logger.exception("analyze_video_task failed (attempt %s)", self.request.retries)
        if _is_transient(exc) and self.request.retries < self.max_retries:
            raise self.retry(exc=exc, countdown=_retry_backoff_seconds(self.request.retries))
        video = db.get(Video, video_id)
        if video:
            video.status = VideoStatus.FAILED
            video.error_message = str(exc)
            db.commit()
        _mark(db, _job(db, job_id), JobStatus.FAILED, error=str(exc))
    finally:
        db.close()


@celery_app.task(bind=True, max_retries=2)
def render_clip_task(self, clip_id: str, job_id: str | None = None):
    db = SessionLocal()
    try:
        clip = db.get(Clip, clip_id)
        if not clip:
            return
        video = db.get(Video, clip.video_id)
        job = _job(db, job_id)
        _mark(db, job, JobStatus.RUNNING, progress=0.1)

        clip.status = ClipStatus.RENDERING
        db.commit()

        work_dir = storage.clips_dir(video.id)
        ass_path = os.path.join(work_dir, f"{clip.id}.ass")
        words = (video.transcript or {}).get("words", [])
        subtitles.build_ass(words, clip.start_seconds, clip.end_seconds, clip.subtitle_style or {}, ass_path)

        watermark_path = None
        if clip.branding_preset_id:
            preset = db.get(BrandingPreset, clip.branding_preset_id)
            if preset and preset.watermark_path and os.path.exists(preset.watermark_path):
                watermark_path = preset.watermark_path

        user_settings = db.query(UserSettings).filter_by(user_id=video.owner_id).first()
        quality = user_settings.export_quality if user_settings else "1080p"

        out_path = os.path.join(work_dir, f"{clip.id}.mp4")
        _mark(db, job, JobStatus.RUNNING, progress=0.4)
        ffmpeg_utils.render_clip(
            video.file_path, out_path, clip.start_seconds, clip.end_seconds,
            subtitle_ass_path=ass_path, watermark_path=watermark_path, quality=quality,
        )

        thumb_path = os.path.join(work_dir, f"{clip.id}_thumb.jpg")
        ffmpeg_utils.generate_thumbnail(out_path, thumb_path)

        _mark(db, job, JobStatus.RUNNING, progress=0.8)
        segment_text = " ".join(
            s["text"] for s in (video.transcript or {}).get("segments", [])
            if s["start"] >= clip.start_seconds and s["end"] <= clip.end_seconds
        ) or " ".join(w["word"] for w in words)

        style_guide = ""
        if user_settings and user_settings.active_style_profile_id:
            style_profile = db.get(StyleProfile, user_settings.active_style_profile_id)
            if style_profile and style_profile.status == "ready":
                style_guide = style_profile.summary or "\n".join(
                    filter(None, [style_profile.hook_analysis, style_profile.pacing_analysis, style_profile.structure_analysis])
                )

        meta = generate_metadata(segment_text, clip.score_reasons or [], style_guide=style_guide)

        clip.file_path = out_path
        clip.thumbnail_path = thumb_path
        clip.title = meta.get("title", "")
        clip.description = meta.get("description", "")
        clip.hashtags = meta.get("hashtags", [])
        clip.keywords = meta.get("keywords", [])
        clip.seo_score = meta.get("seo_score", 0)
        clip.status = ClipStatus.READY_FOR_REVIEW
        db.commit()

        threshold = user_settings.auto_approve_score_threshold if user_settings else None
        if threshold is not None and clip.score >= threshold:
            clip.status = ClipStatus.APPROVED
            db.commit()
            upload_job = ProcessingJob(job_type=JobType.UPLOAD_CLIP, video_id=clip.video_id, clip_id=clip.id)
            db.add(upload_job)
            db.commit()
            upload_clip_task.delay(clip.id, upload_job.id)

        _mark(db, job, JobStatus.SUCCESS, progress=1.0)
    except Exception as exc:  # noqa: BLE001
        logger.exception("render_clip_task failed (attempt %s)", self.request.retries)
        if _is_transient(exc) and self.request.retries < self.max_retries:
            raise self.retry(exc=exc, countdown=_retry_backoff_seconds(self.request.retries))
        clip = db.get(Clip, clip_id)
        if clip:
            clip.status = ClipStatus.FAILED
            clip.error_message = str(exc)
            db.commit()
        _mark(db, _job(db, job_id), JobStatus.FAILED, error=str(exc))
    finally:
        db.close()


@celery_app.task(bind=True, max_retries=3)
def upload_clip_task(self, clip_id: str, job_id: str | None = None):
    db = SessionLocal()
    try:
        clip = db.get(Clip, clip_id)
        if not clip:
            return
        video = db.get(Video, clip.video_id)
        user = db.get(User, video.owner_id)
        job = _job(db, job_id)
        _mark(db, job, JobStatus.RUNNING, progress=0.1)

        if not user.youtube_credential:
            raise RuntimeError("YouTube channel not connected. Connect it in Settings first.")

        refresh_token = decrypt_secret(user.youtube_credential.encrypted_refresh_token)
        credentials = youtube_client.credentials_from_refresh_token(refresh_token, YOUTUBE_SCOPES)

        clip.status = ClipStatus.UPLOADING
        db.commit()

        publish_at = clip.scheduled_at.isoformat() + "Z" if clip.scheduled_at else None
        video_id = youtube_client.upload_video(
            credentials,
            file_path=clip.file_path,
            title=clip.title or "Untitled Short",
            description=clip.description,
            tags=clip.keywords or [],
            privacy_status=clip.visibility.value if clip.visibility else "private",
            playlist_id=clip.playlist_id or None,
            thumbnail_path=clip.thumbnail_path or None,
            publish_at=publish_at,
        )

        clip.youtube_video_id = video_id
        clip.status = ClipStatus.UPLOADED
        db.commit()
        _mark(db, job, JobStatus.SUCCESS, progress=1.0)
    except Exception as exc:  # noqa: BLE001
        logger.exception("upload_clip_task failed (attempt %s)", self.request.retries)
        if _is_transient(exc) and self.request.retries < self.max_retries:
            raise self.retry(exc=exc, countdown=_retry_backoff_seconds(self.request.retries))
        clip = db.get(Clip, clip_id)
        if clip:
            clip.status = ClipStatus.FAILED
            clip.error_message = str(exc)
            db.commit()
        _mark(db, _job(db, job_id), JobStatus.FAILED, error=str(exc))
    finally:
        db.close()


@celery_app.task(bind=True, max_retries=3)
def send_algorithm_digest_task(self):
    """Runs on Celery Beat's daily schedule (see celery_app.py). Not tied to
    any Video/Clip/ProcessingJob — this is a standalone scheduled mailing,
    not part of the per-video pipeline."""
    try:
        articles = fetch_recent_articles()
        email_content = build_digest_email(articles)
        send_email(
            to=settings.DIGEST_RECIPIENT_EMAIL,
            subject=email_content["subject"],
            html_body=email_content["html_body"],
            text_body=email_content["text_body"],
        )
        logger.info("Sent daily algorithm digest to %s", settings.DIGEST_RECIPIENT_EMAIL)
    except Exception as exc:  # noqa: BLE001
        logger.exception("send_algorithm_digest_task failed (attempt %s)", self.request.retries)
        if _is_transient(exc) and self.request.retries < self.max_retries:
            raise self.retry(exc=exc, countdown=_retry_backoff_seconds(self.request.retries))
        raise


@celery_app.task(bind=True, max_retries=2)
def analyze_style_task(self, style_profile_id: str):
    db = SessionLocal()
    try:
        profile = db.get(StyleProfile, style_profile_id)
        if not profile:
            return

        work_dir = storage.style_profile_dir(profile.id)
        video_path, _title = video_import.download_video(profile.source_url, work_dir)
        wav_path = os.path.join(work_dir, "audio.wav")
        ffmpeg_utils.extract_audio(video_path, wav_path)
        transcript = transcribe(wav_path)

        findings = analyze_style(transcript)
        profile.hook_analysis = findings["hook_analysis"]
        profile.pacing_analysis = findings["pacing_analysis"]
        profile.structure_analysis = findings["structure_analysis"]
        profile.summary = findings["summary"]
        profile.status = "ready"
        db.commit()
    except Exception as exc:  # noqa: BLE001
        logger.exception("analyze_style_task failed (attempt %s)", self.request.retries)
        if _is_transient(exc) and self.request.retries < self.max_retries:
            raise self.retry(exc=exc, countdown=_retry_backoff_seconds(self.request.retries))
        profile = db.get(StyleProfile, style_profile_id)
        if profile:
            profile.status = "failed"
            profile.error_message = str(exc)
            db.commit()
    finally:
        # Only the written findings are meant to persist — never the
        # downloaded reference creator's actual video/audio.
        shutil.rmtree(storage.style_profile_dir(style_profile_id), ignore_errors=True)
        db.close()


def _check_one_channel(db, user: User, user_settings: UserSettings) -> None:
    refresh_token = decrypt_secret(user.youtube_credential.encrypted_refresh_token)
    credentials = youtube_client.credentials_from_refresh_token(refresh_token, YOUTUBE_SCOPES)

    playlist_id = youtube_client.get_uploads_playlist_id(credentials)
    if not playlist_id:
        return

    since = user_settings.last_channel_check_at or (datetime.utcnow() - timedelta(days=1))
    new_videos = youtube_client.list_recent_channel_videos(credentials, playlist_id, since)

    existing_urls = {v.source_url for v in db.query(Video).filter_by(owner_id=user.id).all()}
    for v in new_videos:
        url = f"https://www.youtube.com/watch?v={v['video_id']}"
        if not v["video_id"] or url in existing_urls:
            continue
        video = Video(
            owner_id=user.id,
            title=v.get("title", ""),
            source_type="youtube_channel_watch",
            source_url=url,
            status=VideoStatus.UPLOADED,
        )
        db.add(video)
        db.commit()
        db.refresh(video)
        job = ProcessingJob(job_type=JobType.ANALYZE_VIDEO, video_id=video.id)
        db.add(job)
        db.commit()
        import_from_url_task.delay(video.id, job.id)
        logger.info("Auto-imported new channel upload %s for user %s", url, user.id)

    user_settings.last_channel_check_at = datetime.utcnow()
    db.commit()


@celery_app.task
def check_channels_for_new_videos_task():
    """Runs on Celery Beat's schedule (see celery_app.py). For every user
    with auto_import_from_channel enabled, polls their connected channel's
    uploads playlist and imports anything published since the last check —
    the same pipeline a manual URL import triggers, just self-triggered."""
    db = SessionLocal()
    try:
        watchers = db.query(UserSettings).filter(UserSettings.auto_import_from_channel.is_(True)).all()
        for user_settings in watchers:
            user = db.get(User, user_settings.user_id)
            if not user or not user.youtube_credential:
                continue
            try:
                _check_one_channel(db, user, user_settings)
            except Exception:  # noqa: BLE001
                # One user's channel check failing (expired token, API
                # error, etc.) shouldn't stop the rest from being checked.
                logger.exception("Channel check failed for user %s", user_settings.user_id)
    finally:
        db.close()
