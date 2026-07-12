import { NextRequest, NextResponse } from "next/server";
import { verifyCredentials, createSession, setSessionCookie } from "@/lib/server/auth";

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const email = (body.email ?? "").trim();
  const password = body.password ?? "";

  if (!email || !password) {
    return NextResponse.json({ error: "Email and password are required" }, { status: 400 });
  }

  const user = verifyCredentials(email, password);
  if (!user) {
    return NextResponse.json({ error: "Invalid email or password" }, { status: 401 });
  }

  const { token, expiresAt } = createSession(user.id);
  await setSessionCookie(token, expiresAt);
  return NextResponse.json({ user });
}
