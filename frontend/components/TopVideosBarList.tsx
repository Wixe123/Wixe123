import type { TopVideo } from "@/lib/types";

export default function TopVideosBarList({ videos }: { videos: TopVideo[] }) {
  if (videos.length === 0) {
    return <p className="text-sm text-gray-500">No channel data for this period yet.</p>;
  }
  const maxViews = Math.max(...videos.map((v) => v.views), 1);

  return (
    <div className="space-y-3">
      {videos.map((v) => (
        <a
          key={v.video_id}
          href={`https://youtube.com/watch?v=${v.video_id}`}
          target="_blank"
          rel="noreferrer"
          className="group block"
        >
          <div className="mb-1 flex items-center justify-between gap-3">
            <span className="truncate text-sm text-gray-300 group-hover:text-brand-300">{v.title}</span>
            <span className="shrink-0 text-xs font-medium text-gray-400">{v.views.toLocaleString()} views</span>
          </div>
          <div className="h-1.5 w-full overflow-hidden rounded-full bg-white/5">
            <div
              className="h-full rounded-full bg-brand-400 transition-all"
              style={{ width: `${Math.max(2, (v.views / maxViews) * 100)}%` }}
            />
          </div>
        </a>
      ))}
    </div>
  );
}
