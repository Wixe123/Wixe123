import { NextRequest, NextResponse } from "next/server";
import { createUser, createSession, setSessionCookie } from "@/lib/server/auth";

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const name = (body.name ?? "").trim();
  const email = (body.email ?? "").trim();
  const password = body.password ?? "";

  if (!name || !email || !password) {
    return NextResponse.json({ error: "Name, email, and password are required" }, { status: 400 });
  }
  if (password.length < 8) {
    return NextResponse.json({ error: "Password must be at least 8 characters" }, { status: 400 });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ error: "Enter a valid email address" }, { status: 400 });
  }

  try {
    const user = createUser(name, email, password);
    const { token, expiresAt } = createSession(user.id);
    await setSessionCookie(token, expiresAt);
    return NextResponse.json({ user });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Could not create account";
    return NextResponse.json({ error: message }, { status: 409 });
  }
}
