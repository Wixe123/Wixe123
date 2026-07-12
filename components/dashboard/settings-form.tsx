"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter,
} from "@/components/ui/dialog";

const NOTIFICATIONS = [
  { label: "Render complete", desc: "When a video finishes rendering.", defaultOn: true },
  { label: "Weekly performance digest", desc: "A summary of your account every Monday.", defaultOn: true },
  { label: "New feature announcements", desc: "Occasional product updates.", defaultOn: false },
  { label: "Credit balance low", desc: "When you have fewer than 5 credits left.", defaultOn: true },
];

type SessionUser = { name: string; email: string; initials: string };
type ApiKeyStatus = { name: string; env: string; connected: boolean };

export function SettingsForm({ user, apiKeys }: { user: SessionUser; apiKeys: ApiKeyStatus[] }) {
  const router = useRouter();
  const [name, setName] = React.useState(user.name);
  const [savingProfile, setSavingProfile] = React.useState(false);

  const [currentPassword, setCurrentPassword] = React.useState("");
  const [newPassword, setNewPassword] = React.useState("");
  const [savingPassword, setSavingPassword] = React.useState(false);

  const [deleteOpen, setDeleteOpen] = React.useState(false);
  const [deleting, setDeleting] = React.useState(false);

  async function saveProfile() {
    setSavingProfile(true);
    try {
      const res = await fetch("/api/auth/profile", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      toast.success("Profile saved");
      router.refresh();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Could not save profile");
    } finally {
      setSavingProfile(false);
    }
  }

  async function updatePassword() {
    setSavingPassword(true);
    try {
      const res = await fetch("/api/auth/password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ currentPassword, newPassword }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      toast.success("Password updated");
      setCurrentPassword("");
      setNewPassword("");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Could not update password");
    } finally {
      setSavingPassword(false);
    }
  }

  async function deleteAccount() {
    setDeleting(true);
    try {
      await fetch("/api/auth/delete", { method: "POST" });
      toast.success("Account deleted");
      router.push("/");
      router.refresh();
    } finally {
      setDeleting(false);
    }
  }

  return (
    <Tabs defaultValue="profile">
      <TabsList>
        <TabsTrigger value="profile">Profile</TabsTrigger>
        <TabsTrigger value="notifications">Notifications</TabsTrigger>
        <TabsTrigger value="security">Security</TabsTrigger>
        <TabsTrigger value="api">API keys</TabsTrigger>
      </TabsList>

      <TabsContent value="profile">
        <Card>
          <CardHeader>
            <CardTitle>Profile</CardTitle>
            <CardDescription>This information is stored in your account.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="flex items-center gap-4">
              <Avatar className="size-16">
                <AvatarFallback className="bg-[linear-gradient(135deg,var(--gradient-1),var(--gradient-2))] text-xl text-white">
                  {user.initials}
                </AvatarFallback>
              </Avatar>
            </div>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label>Full name</Label>
                <Input value={name} onChange={(e) => setName(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label>Email</Label>
                <Input value={user.email} type="email" disabled />
              </div>
            </div>
            <Button variant="gradient" onClick={saveProfile} disabled={savingProfile || !name.trim()}>
              {savingProfile ? "Saving…" : "Save changes"}
            </Button>
          </CardContent>
        </Card>
      </TabsContent>

      <TabsContent value="notifications">
        <Card>
          <CardHeader>
            <CardTitle>Notifications</CardTitle>
            <CardDescription>
              UI-only for now — wiring these up needs an email/push provider (e.g. Resend, Postmark).
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-1">
            {NOTIFICATIONS.map((n, i) => (
              <div key={n.label}>
                <div className="flex items-center justify-between py-3">
                  <div>
                    <p className="text-sm font-medium">{n.label}</p>
                    <p className="text-xs text-muted-foreground">{n.desc}</p>
                  </div>
                  <Switch defaultChecked={n.defaultOn} />
                </div>
                {i < NOTIFICATIONS.length - 1 && <Separator />}
              </div>
            ))}
          </CardContent>
        </Card>
      </TabsContent>

      <TabsContent value="security">
        <Card>
          <CardHeader>
            <CardTitle>Security</CardTitle>
            <CardDescription>Change your real account password.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-1.5">
              <Label>Current password</Label>
              <Input
                type="password"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                placeholder="••••••••"
              />
            </div>
            <div className="space-y-1.5">
              <Label>New password</Label>
              <Input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                placeholder="At least 8 characters"
              />
            </div>
            <Button
              variant="gradient"
              onClick={updatePassword}
              disabled={savingPassword || !currentPassword || newPassword.length < 8}
            >
              {savingPassword ? "Updating…" : "Update password"}
            </Button>
          </CardContent>
        </Card>

        <Card className="mt-6 border-destructive/30">
          <CardHeader>
            <CardTitle className="text-destructive">Danger zone</CardTitle>
            <CardDescription>
              Deleting your account permanently removes it, your sessions, and every generated project
              (including rendered video files) from the database.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button variant="destructive" onClick={() => setDeleteOpen(true)}>
              Delete account
            </Button>
          </CardContent>
        </Card>
      </TabsContent>

      <TabsContent value="api">
        <Card>
          <CardHeader>
            <CardTitle>API keys</CardTitle>
            <CardDescription>
              Read from server environment variables (see .env.example) — not editable from the UI since
              they&apos;re shared server secrets, not per-user data.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            {apiKeys.map((k) => (
              <div key={k.name} className="flex items-center justify-between rounded-xl border border-border p-3">
                <div>
                  <p className="text-sm font-medium">{k.name}</p>
                  <p className="font-mono text-xs text-muted-foreground">{k.env}</p>
                </div>
                <Badge variant={k.connected ? "success" : "secondary"}>
                  {k.connected ? "Connected" : "Using mock fallback"}
                </Badge>
              </div>
            ))}
          </CardContent>
        </Card>
      </TabsContent>

      <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete your account?</DialogTitle>
            <DialogDescription>
              This permanently deletes your account and every project you&apos;ve created. This cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteOpen(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={deleteAccount} disabled={deleting}>
              {deleting ? "Deleting…" : "Yes, delete my account"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Tabs>
  );
}
