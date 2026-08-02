from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "ShortsForge"
    ENV: str = "development"
    SECRET_KEY: str = "change-me"
    # Must be set via env in any real deployment; see README for how to generate one.
    FERNET_KEY: str = ""
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    DATABASE_URL: str = "postgresql+psycopg2://shortsforge:shortsforge@postgres:5432/shortsforge"
    REDIS_URL: str = "redis://redis:6379/0"

    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    GOOGLE_REDIRECT_URI: str = "http://localhost:8000/api/auth/google/callback"
    YOUTUBE_REDIRECT_URI: str = "http://localhost:8000/api/auth/youtube/callback"

    FRONTEND_URL: str = "http://localhost:3000"

    ANTHROPIC_API_KEY: str = ""

    # Path (inside the container) to a Netscape-format cookies.txt exported
    # from a real logged-in browser session. YouTube increasingly blocks
    # unauthenticated automated requests with "Please sign in" / "confirm
    # you're not a bot" even for ordinary public videos; passing real
    # session cookies is the reliable workaround. Optional — URL import
    # just won't survive that wall without it. See README.
    YTDLP_COOKIES_FILE: str = ""

    STORAGE_ROOT: str = "/data"
    MAX_UPLOAD_BYTES: int = 5 * 1024 * 1024 * 1024  # 5 GB
    STORAGE_QUOTA_BYTES: int = 200 * 1024 * 1024 * 1024  # 200 GB, informational only

    WHISPER_MODEL_SIZE: str = "small"
    WHISPER_DEVICE: str = "cpu"  # set to "cuda" on a GPU box
    WHISPER_COMPUTE_TYPE: str = "int8"

    MAX_CLIPS_PER_VIDEO: int = 6
    DEFAULT_CLIP_MIN_SECONDS: int = 15
    DEFAULT_CLIP_MAX_SECONDS: int = 60

    CELERY_CONCURRENCY: int = 2

    # --- Daily algorithm-trends email digest ---
    # SMTP over a Gmail App Password is the path of least friction for a
    # single-user deploy: no new account/API key to sign up for, just
    # https://myaccount.google.com/apppasswords on an existing Gmail account.
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = ""  # defaults to SMTP_USERNAME if unset
    DIGEST_RECIPIENT_EMAIL: str = ""
    DIGEST_HOUR_UTC: int = 8  # convert your preferred local send time to UTC


@lru_cache
def get_settings() -> Settings:
    return Settings()
