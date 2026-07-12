import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser, updateUserPassword } from "@/lib/server/auth";

export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { currentPassword, newPassword } = await req.json().catch(() => ({}));
  if (!currentPassword || !newPassword) {
    return NextResponse.json({ error: "Both passwords are required" }, { status: 400 });
  }
  if (newPassword.length < 8) {
    return NextResponse.json({ error: "New password must be at least 8 characters" }, { status: 400 });
  }

  try {
    updateUserPassword(user.id, currentPassword, newPassword);
    return NextResponse.json({ ok: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Could not update password";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
