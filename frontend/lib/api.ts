import type {
  AnalyticsOverview,
  BrandingPreset,
  Clip,
  ClipPerformance,
  DashboardStats,
  ProcessingJob,
  StyleProfile,
  TopVideo,
  TrendingClip,
  TrendPoint,
  User,
  UserSettings,
  Video,
  WatchedChannel,
  WatchedChannelDetail,
  YouTubeComment,
} from "./types";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
const TOKEN_KEY = "shortsforge_token";

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const headers = new Headers(options.headers);
  if (token) headers.set("Authorization", `Bearer ${token}`);
  if (!(options.body instanceof FormData) && options.body) {
    headers.set("Content-Type", "application/json");
  }

  const res = await fetch(`${API_URL}${path}`, { ...options, headers });
  if (!res.ok) {
    let detail = res.statusText;
    try {
      const data = await res.json();
      detail = data.detail || detail;
    } catch {
      // ignore
    }
    throw new Error(detail);
  }
  if (res.status === 204) return undefined as T;
  return res.json();
}

export const api = {
  apiUrl: API_URL,

  googleLoginUrl: async () => request<{ auth_url: string }>("/api/auth/google/login"),
  me: () => request<User>("/api/auth/me"),
  youtubeConnectUrl: () => request<{ auth_url: string }>("/api/auth/youtube/connect"),
  youtubeStatus: () =>
    request<{ connected: boolean; channel_title?: string; channel_id?: string }>(
      "/api/auth/youtube/status"
    ),

  listVideos: () => request<Video[]>("/api/videos"),
  getVideo: (id: string) => request<Video>(`/api/videos/${id}`),
  getVideoClips: (id: string) => request<Clip[]>(`/api/videos/${id}/clips`),
  deleteVideo: (id: string) => request<{ ok: boolean }>(`/api/videos/${id}`, { method: "DELETE" }),
  importFromUrl: (url: string) =>
    request<Video>("/api/videos/import", { method: "POST", body: JSON.stringify({ url }) }),
  uploadVideo: (file: File) => {
    const form = new FormData();
    form.append("file", file);
    return request<Video>("/api/videos", { method: "POST", body: form });
  },

  listClips: (status?: string) =>
    request<Clip[]>(`/api/clips${status ? `?status=${status}` : ""}`),
  getClip: (id: string) => request<Clip>(`/api/clips/${id}`),
  updateClip: (id: string, payload: Partial<Clip>) =>
    request<Clip>(`/api/clips/${id}`, { method: "PATCH", body: JSON.stringify(payload) }),
  approveClip: (id: string) => request<Clip>(`/api/clips/${id}/approve`, { method: "POST" }),
  rejectClip: (id: string) => request<Clip>(`/api/clips/${id}/reject`, { method: "POST" }),
  uploadClip: (id: string) => request<Clip>(`/api/clips/${id}/upload`, { method: "POST" }),
  retryRender: (id: string) => request<Clip>(`/api/clips/${id}/retry-render`, { method: "POST" }),
  clipVideoUrl: (id: string) => `${API_URL}/api/clips/${id}/video?token=${getToken()}`,
  clipDownloadUrl: (id: string) => `${API_URL}/api/clips/${id}/video?download=true&token=${getToken()}`,
  clipThumbnailUrl: (id: string) => `${API_URL}/api/clips/${id}/thumbnail?token=${getToken()}`,

  listJobs: (status?: string) => request<ProcessingJob[]>(`/api/jobs${status ? `?status=${status}` : ""}`),
  cancelJob: (id: string) => request<ProcessingJob>(`/api/jobs/${id}/cancel`, { method: "POST" }),
  pauseJob: (id: string) => request<ProcessingJob>(`/api/jobs/${id}/pause`, { method: "POST" }),
  retryJob: (id: string) => request<ProcessingJob>(`/api/jobs/${id}/retry`, { method: "POST" }),

  dashboardStats: () => request<DashboardStats>("/api/dashboard/stats"),

  analyticsOverview: (days = 28) => request<AnalyticsOverview>(`/api/analytics/overview?days=${days}`),
  analyticsClips: (days = 28) => request<ClipPerformance[]>(`/api/analytics/clips?days=${days}`),
  analyticsTrend: (days = 28) => request<TrendPoint[]>(`/api/analytics/trend?days=${days}`),
  analyticsTopVideos: (days = 28) => request<TopVideo[]>(`/api/analytics/top-videos?days=${days}`),
  analyticsComments: (maxResults = 25) =>
    request<YouTubeComment[]>(`/api/analytics/comments?max_results=${maxResults}`),
  replyToComment: (commentId: string, text: string) =>
    request<{ comment_id: string; text: string }>(`/api/analytics/comments/${commentId}/reply`, {
      method: "POST",
      body: JSON.stringify({ text }),
    }),

  listBrandingPresets: () => request<BrandingPreset[]>("/api/branding"),
  createBrandingPreset: (payload: Partial<BrandingPreset>) =>
    request<BrandingPreset>("/api/branding", { method: "POST", body: JSON.stringify(payload) }),
  updateBrandingPreset: (id: string, payload: Partial<BrandingPreset>) =>
    request<BrandingPreset>(`/api/branding/${id}`, { method: "PATCH", body: JSON.stringify(payload) }),
  deleteBrandingPreset: (id: string) =>
    request<{ ok: boolean }>(`/api/branding/${id}`, { method: "DELETE" }),
  uploadBrandingAsset: (kind: string, file: File) => {
    const form = new FormData();
    form.append("file", file);
    return request<{ path: string }>(`/api/branding/assets/${kind}`, { method: "POST", body: form });
  },

  getSettings: () => request<UserSettings>("/api/settings"),
  updateSettings: (payload: Partial<UserSettings>) =>
    request<UserSettings>("/api/settings", { method: "PUT", body: JSON.stringify(payload) }),

  generateFacelessVideo: () =>
    request<{ status: string; job_id: string }>("/api/faceless/generate", { method: "POST" }),

  listStyleProfiles: () => request<StyleProfile[]>("/api/style-profiles"),
  createStyleProfile: (source_url: string, creator_label: string) =>
    request<StyleProfile>("/api/style-profiles", {
      method: "POST",
      body: JSON.stringify({ source_url, creator_label }),
    }),
  getStyleProfile: (id: string) => request<StyleProfile>(`/api/style-profiles/${id}`),
  deleteStyleProfile: (id: string) =>
    request<{ ok: boolean }>(`/api/style-profiles/${id}`, { method: "DELETE" }),

  listWatchedChannels: () => request<WatchedChannel[]>("/api/watched-channels"),
  createWatchedChannel: (channel_url: string, label: string) =>
    request<WatchedChannel>("/api/watched-channels", {
      method: "POST",
      body: JSON.stringify({ channel_url, label }),
    }),
  deleteWatchedChannel: (id: string) =>
    request<{ ok: boolean }>(`/api/watched-channels/${id}`, { method: "DELETE" }),
  analyzeWatchedChannel: (id: string) =>
    request<StyleProfile>(`/api/watched-channels/${id}/analyze`, { method: "POST" }),

  listTrending: () => request<TrendingClip[]>("/api/trending"),
  refreshTrending: () => request<{ status: string }>("/api/trending/refresh", { method: "POST" }),
  getTrendingChannel: (id: string) => request<WatchedChannelDetail>(`/api/trending/channels/${id}`),
};
