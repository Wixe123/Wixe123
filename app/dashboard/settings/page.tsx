import { redirect } from "next/navigation";
import { PageHeader } from "@/components/dashboard/page-header";
import { getCurrentUser, initials } from "@/lib/server/auth";
import { hasProviderKey } from "@/lib/ai/engine";
import { SettingsForm } from "@/components/dashboard/settings-form";

const PROVIDER_ENV_VARS = [
  { name: "OpenAI", env: "OPENAI_API_KEY" },
  { name: "ElevenLabs", env: "ELEVENLABS_API_KEY" },
  { name: "HeyGen", env: "HEYGEN_API_KEY" },
  { name: "Runway", env: "RUNWAY_API_KEY" },
];

export default async function SettingsPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/sign-in");

  const apiKeys = PROVIDER_ENV_VARS.map((p) => ({ ...p, connected: hasProviderKey(p.env) }));

  return (
    <div>
      <PageHeader title="Settings" description="Manage your profile, notifications, and account security." />
      <SettingsForm
        user={{ name: user.name, email: user.email, initials: initials(user.name) }}
        apiKeys={apiKeys}
      />
    </div>
  );
}
