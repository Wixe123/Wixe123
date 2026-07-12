// Maps the Tailwind gradient utility classes used across lib/mock-data.ts
// avatars/thumbnails to real hex pairs, so the server-side ffmpeg renderer
// can paint the same gradient into an actual video/image file.
export const GRADIENT_HEX: Record<string, [string, string]> = {
  "from-violet-500 to-fuchsia-500": ["0x8b5cf6", "0xd946ef"],
  "from-sky-500 to-indigo-500": ["0x0ea5e9", "0x6366f1"],
  "from-rose-500 to-orange-400": ["0xf43f5e", "0xfb923c"],
  "from-emerald-500 to-teal-400": ["0x10b981", "0x2dd4bf"],
  "from-amber-400 to-rose-500": ["0xfbbf24", "0xf43f5e"],
  "from-indigo-500 to-purple-500": ["0x6366f1", "0xa855f7"],
  "from-pink-500 to-rose-400": ["0xec4899", "0xfb7185"],
  "from-teal-400 to-cyan-500": ["0x2dd4bf", "0x06b6d4"],
};

export function gradientToHex(gradientClass: string): [string, string] {
  return GRADIENT_HEX[gradientClass] ?? ["0x8b5cf6", "0xd946ef"];
}
