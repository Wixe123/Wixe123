"use client";

import { useCallback, useRef, useState } from "react";

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
      className={`flex cursor-pointer flex-col items-center justify-center gap-3 rounded-xl2 border-2 border-dashed p-12 text-center transition ${
        dragging ? "border-brand-500 bg-brand-500/5" : "border-base-600 hover:border-base-500"
      }`}
    >
      <div className="text-4xl">⬆️</div>
      <p className="text-sm text-gray-300">
        Drag & drop videos here, or <span className="text-brand-400">browse</span>
      </p>
      <p className="text-xs text-gray-500">MP4, MOV, AVI, MKV — multiple files supported</p>
      {busy && <p className="text-xs text-brand-400">Uploading…</p>}
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
