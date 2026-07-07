"""Google OAuth (login) and YouTube Data API v3 (upload) integration."""
import httpx
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

from app.core.config import get_settings

settings = get_settings()

LOGIN_SCOPES = ["openid", "https://www.googleapis.com/auth/userinfo.email",
                "https://www.googleapis.com/auth/userinfo.profile"]
YOUTUBE_SCOPES = ["https://www.googleapis.com/auth/youtube.upload",
                  "https://www.googleapis.com/auth/youtube.readonly"]

CLIENT_CONFIG_TEMPLATE = {
    "web": {
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
    }
}


def _client_config() -> dict:
    cfg = dict(CLIENT_CONFIG_TEMPLATE["web"])
    cfg["client_id"] = settings.GOOGLE_CLIENT_ID
    cfg["client_secret"] = settings.GOOGLE_CLIENT_SECRET
    return {"web": cfg}


def build_auth_url(scopes: list[str], redirect_uri: str, state: str) -> str:
    flow = Flow.from_client_config(_client_config(), scopes=scopes, redirect_uri=redirect_uri)
    auth_url, _ = flow.authorization_url(
        access_type="offline",
        include_granted_scopes="true",
        prompt="consent",
        state=state,
    )
    return auth_url


def exchange_code(code: str, scopes: list[str], redirect_uri: str) -> Credentials:
    flow = Flow.from_client_config(_client_config(), scopes=scopes, redirect_uri=redirect_uri)
    flow.fetch_token(code=code)
    return flow.credentials


def fetch_userinfo(credentials: Credentials) -> dict:
    resp = httpx.get(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        headers={"Authorization": f"Bearer {credentials.token}"},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def credentials_from_refresh_token(refresh_token: str, scopes: list[str]) -> Credentials:
    creds = Credentials(
        token=None,
        refresh_token=refresh_token,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=settings.GOOGLE_CLIENT_ID,
        client_secret=settings.GOOGLE_CLIENT_SECRET,
        scopes=scopes,
    )
    creds.refresh(GoogleRequest())
    return creds


def get_my_channel(credentials: Credentials) -> dict | None:
    youtube = build("youtube", "v3", credentials=credentials)
    resp = youtube.channels().list(part="snippet", mine=True).execute()
    items = resp.get("items", [])
    if not items:
        return None
    return {"id": items[0]["id"], "title": items[0]["snippet"]["title"]}


def upload_video(
    credentials: Credentials,
    file_path: str,
    title: str,
    description: str,
    tags: list[str],
    category_id: str = "22",
    privacy_status: str = "private",
    playlist_id: str | None = None,
    thumbnail_path: str | None = None,
    publish_at: str | None = None,
) -> str:
    """Uploads a rendered clip to YouTube, returns the resulting video id."""
    youtube = build("youtube", "v3", credentials=credentials)

    status: dict = {"privacyStatus": privacy_status, "selfDeclaredMadeForKids": False}
    if publish_at:
        status["privacyStatus"] = "private"
        status["publishAt"] = publish_at

    body = {
        "snippet": {
            "title": title[:100],
            "description": description[:5000],
            "tags": tags[:500],
            "categoryId": category_id,
        },
        "status": status,
    }

    media = MediaFileUpload(file_path, chunksize=-1, resumable=True, mimetype="video/mp4")
    request = youtube.videos().insert(part="snippet,status", body=body, media_body=media)

    response = None
    while response is None:
        _status, response = request.next_chunk()
    video_id = response["id"]

    if thumbnail_path:
        youtube.thumbnails().set(videoId=video_id, media_body=MediaFileUpload(thumbnail_path)).execute()

    if playlist_id:
        youtube.playlistItems().insert(
            part="snippet",
            body={
                "snippet": {
                    "playlistId": playlist_id,
                    "resourceId": {"kind": "youtube#video", "videoId": video_id},
                }
            },
        ).execute()

    return video_id
