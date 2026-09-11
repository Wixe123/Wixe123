"""Google OAuth (login) and YouTube Data API v3 (upload) integration."""
from datetime import datetime

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
                  "https://www.googleapis.com/auth/youtube.readonly",
                  "https://www.googleapis.com/auth/yt-analytics.readonly",
                  # Posting/replying to comments needs force-ssl (readonly only
                  # covers listing); accounts connected before this was added
                  # need to reconnect once to grant it, same as analytics below.
                  "https://www.googleapis.com/auth/youtube.force-ssl"]

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


def get_uploads_playlist_id(credentials: Credentials) -> str | None:
    """Every channel has a hidden "uploads" playlist containing all its
    videos — listing that playlist is far cheaper (quota-wise) than
    search.list for periodically checking "what's new on my channel"."""
    youtube = build("youtube", "v3", credentials=credentials)
    resp = youtube.channels().list(part="contentDetails", mine=True).execute()
    items = resp.get("items", [])
    if not items:
        return None
    return items[0]["contentDetails"]["relatedPlaylists"]["uploads"]


def list_recent_channel_videos(credentials: Credentials, playlist_id: str, published_after: datetime) -> list[dict]:
    """Videos in the uploads playlist published after `published_after`
    (a naive UTC datetime, matching this app's convention elsewhere). The
    playlist is newest-first by default, so this can stop as soon as it
    hits something older than the cutoff."""
    youtube = build("youtube", "v3", credentials=credentials)
    resp = youtube.playlistItems().list(part="snippet", playlistId=playlist_id, maxResults=25).execute()

    videos = []
    for item in resp.get("items", []):
        snippet = item.get("snippet", {})
        published_raw = snippet.get("publishedAt")
        if not published_raw:
            continue
        published_at = datetime.fromisoformat(published_raw.replace("Z", "+00:00")).replace(tzinfo=None)
        if published_at <= published_after:
            break
        videos.append(
            {
                "video_id": snippet.get("resourceId", {}).get("videoId", ""),
                "title": snippet.get("title", ""),
                "published_at": published_at,
            }
        )
    return videos


def get_video_titles(credentials: Credentials, video_ids: list[str]) -> dict[str, dict]:
    """Batch-fetches title/thumbnail for a set of video IDs, keyed by id.
    The Analytics API only ever returns bare video IDs in its rows — this
    is the Data API call needed to turn those into something displayable."""
    if not video_ids:
        return {}
    youtube = build("youtube", "v3", credentials=credentials)
    out: dict[str, dict] = {}
    # videos().list caps at 50 ids per call.
    for i in range(0, len(video_ids), 50):
        batch = video_ids[i : i + 50]
        resp = youtube.videos().list(part="snippet", id=",".join(batch)).execute()
        for item in resp.get("items", []):
            snippet = item.get("snippet", {})
            thumbnails = snippet.get("thumbnails", {})
            thumb = thumbnails.get("medium") or thumbnails.get("default") or {}
            out[item["id"]] = {"title": snippet.get("title", ""), "thumbnail": thumb.get("url", "")}
    return out


def list_recent_comments(credentials: Credentials, max_results: int = 25) -> list[dict]:
    """Most recent top-level comment threads across the whole channel (any
    video), newest first — the Data API's channel-wide comment feed, not a
    per-video one. Each item includes enough to display + reply to it."""
    channel = get_my_channel(credentials)
    if not channel:
        return []

    youtube = build("youtube", "v3", credentials=credentials)
    resp = youtube.commentThreads().list(
        part="snippet",
        allThreadsRelatedToChannelId=channel["id"],
        order="time",
        maxResults=max_results,
        textFormat="plainText",
    ).execute()

    comments = []
    for item in resp.get("items", []):
        top = item["snippet"]["topLevelComment"]["snippet"]
        comments.append(
            {
                "comment_id": item["snippet"]["topLevelComment"]["id"],
                "thread_id": item["id"],
                "video_id": item["snippet"].get("videoId", ""),
                "author": top.get("authorDisplayName", ""),
                "author_avatar": top.get("authorProfileImageUrl", ""),
                "text": top.get("textDisplay", ""),
                "like_count": top.get("likeCount", 0),
                "published_at": top.get("publishedAt", ""),
                "reply_count": item["snippet"].get("totalReplyCount", 0),
                "can_reply": item["snippet"].get("canReply", True),
            }
        )
    return comments


def reply_to_comment(credentials: Credentials, parent_comment_id: str, text: str) -> dict:
    """Posts a reply under an existing top-level comment (or another reply),
    as the channel owner. Returns the new reply's id + text."""
    youtube = build("youtube", "v3", credentials=credentials)
    resp = youtube.comments().insert(
        part="snippet",
        body={"snippet": {"parentId": parent_comment_id, "textOriginal": text}},
    ).execute()
    return {"comment_id": resp["id"], "text": resp["snippet"].get("textDisplay", text)}


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
