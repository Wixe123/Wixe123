"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect } from "react";
import { setToken } from "@/lib/api";

function CallbackHandler() {
  const router = useRouter();
  const params = useSearchParams();

  useEffect(() => {
    const token = params.get("token");
    if (token) {
      setToken(token);
      router.replace("/");
    } else {
      router.replace("/login");
    }
  }, [params, router]);

  return null;
}

export default function LoginCallbackPage() {
  return (
    <div className="flex h-screen items-center justify-center text-gray-400">
      <Suspense fallback={null}>
        <CallbackHandler />
      </Suspense>
      Signing you in…
    </div>
  );
}
