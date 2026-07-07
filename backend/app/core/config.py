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


@lru_cache
def get_settings() -> Settings:
    return Settings()
