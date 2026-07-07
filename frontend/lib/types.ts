export type VideoStatus = "uploaded" | "transcribing" | "analyzing" | "analyzed" | "failed";

export type ClipStatus =
  | "pending_render"
  | "rendering"
  | "ready_for_review"
  | "approved"
  | "scheduled"
  | "uploading"
  | "uploaded"
  | "failed"
  | "rejected";

export type Visibility = "public" | "unlisted" | "private" | "draft";
export type JobStatus = "queued" | "running" | "paused" | "success" | "failed" | "cancelled";
export type JobType = "analyze_video" | "render_clip" | "upload_clip";

export interface User {
  id: string;
  email: string;
  name: string;
  avatar_url: string;
}

export interface Video {
  id: string;
  title: string;
  source_type: string;
  duration_seconds: number;
  size_bytes: number;
  status: VideoStatus;
  error_message: string;
  created_at: string;
}

export interface Clip {
  id: string;
  video_id: string;
  start_seconds: number;
  end_seconds: number;
  score: number;
  score_reasons: string[];
  status: ClipStatus;
  file_path: string;
  thumbnail_path: string;
  title: string;
  description: string;
  hashtags: string[];
  keywords: string[];
  seo_score: number;
  visibility: Visibility;
  playlist_id: string;
  scheduled_at: string | null;
  subtitle_style: Record<string, unknown>;
  youtube_video_id: string;
  error_message: string;
  created_at: string;
}

export interface ProcessingJob {
  id: string;
  job_type: JobType;
  status: JobStatus;
  video_id: string | null;
  clip_id: string | null;
  attempts: number;
  progress: number;
  error_message: string;
  created_at: string;
  updated_at: string;
}

export interface DashboardStats {
  videos_today: number;
  shorts_created_today: number;
  queue_length: number;
  processing_count: number;
  failed_count: number;
  uploaded_today: number;
  storage_used_bytes: number;
  storage_quota_bytes: number;
  api_calls_today: number;
}

export interface BrandingPreset {
  id: string;
  name: string;
  logo_path: string;
  watermark_path: string;
  intro_path: string;
  outro_path: string;
  font_family: string;
  primary_color: string;
  accent_color: string;
  is_default: boolean;
}

export interface UserSettings {
  subtitle_font: string;
  subtitle_color: string;
  subtitle_highlight_color: string;
  subtitle_stroke_color: string;
  subtitle_position: string;
  subtitle_emoji_enabled: boolean;
  subtitle_language: string;
  export_quality: string;
  clip_min_seconds: number;
  clip_max_seconds: number;
  max_clips_per_video: number;
  ai_sensitivity: number;
  default_visibility: Visibility;
  auto_upload_after_approval: boolean;
  default_branding_preset_id: string | null;
}
