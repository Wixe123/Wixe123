"use client";

import { useCallback, useRef, useState } from "react";
import { IconUploadCloud } from "@/components/icons";

const ACCEPTED = [".mp4", ".mov", ".avi", ".mkv"];

export default function UploadDropzone({
  onFiles,
  busy,
}: {
  onFiles: (files: File[]) => void;
  busy: boolean;
}) {
  const [dragging, setDragging] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFiles = useCallback(
    (fileList: FileList | null) => {
      if (!fileList) return;
      const files = Array.from(fileList).filter((f) =>
        ACCEPTED.some((ext) => f.name.toLowerCase().endsWith(ext))
      );
      if (files.length) onFiles(files);
    },
    [onFiles]
  );

  return (
    <div
      onDragOver={(e) => {
        e.preventDefault();
        setDragging(true);
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragging(false);
        handleFiles(e.dataTransfer.files);
      }}
      onClick={() => inputRef.current?.click()}
      className={`flex cursor-pointer flex-col items-center justify-center gap-3 rounded-xl2 border-2 border-dashed p-8 text-center transition sm:p-12 ${
        dragging ? "border-brand-500 bg-brand-500/5" : "border-white/10 hover:border-white/20 hover:bg-white/[0.02]"
      }`}
    >
      <span className="icon-chip h-14 w-14 bg-brand-500/15 text-brand-400">
        <IconUploadCloud className="h-6 w-6" />
      </span>
      <p className="text-sm text-gray-300">
        Drag & drop videos here, or <span className="font-medium text-brand-400">browse</span>
      </p>
      <p className="text-xs text-gray-500">MP4, MOV, AVI, MKV — multiple files supported</p>
      {busy && (
        <p className="flex items-center gap-2 text-xs text-brand-400">
          <span className="h-3 w-3 animate-spin rounded-full border-2 border-brand-500/50 border-t-brand-400" />
          Uploading…
        </p>
      )}
      <input
        ref={inputRef}
        type="file"
        multiple
        accept={ACCEPTED.join(",")}
        className="hidden"
        onChange={(e) => handleFiles(e.target.files)}
      />
    </div>
  );
}
