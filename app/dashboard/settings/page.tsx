"use client";

import * as React from "react";
import { toast } from "sonner";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";

const NOTIFICATIONS = [
  { label: "Render complete", desc: "When a video finishes rendering.", defaultOn: true },
  { label: "Weekly performance digest", desc: "A summary of your account every Monday.", defaultOn: true },
  { label: "New feature announcements", desc: "Occasional product updates.", defaultOn: false },
  { label: "Credit balance low", desc: "When you have fewer than 5 credits left.", defaultOn: true },
];

const API_KEYS = [
  { name: "OpenAI", masked: "sk-••••••••7f2a", connected: true },
  { name: "ElevenLabs", masked: "el-••••••••91cd", connected: true },
  { name: "HeyGen", masked: "—", connected: false },
  { name: "Runway", masked: "—", connected: false },
];

export default function SettingsPage() {
  return (
    <div>
      <PageHeader title="Settings" description="Manage your profile, notifications, and account security." />

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
              <CardDescription>This information is visible to your team.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-5">
              <div className="flex items-center gap-4">
                <Avatar className="size-16">
                  <AvatarFallback className="bg-[linear-gradient(135deg,var(--gradient-1),var(--gradient-2))] text-xl text-white">
                    LL
                  </AvatarFallback>
                </Avatar>
                <Button variant="outline" size="sm" onClick={() => toast.success("Avatar updated")}>
                  Change avatar
                </Button>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <Label>Full name</Label>
                  <Input defaultValue="Love Lindberg" />
                </div>
                <div className="space-y-1.5">
                  <Label>Email</Label>
                  <Input defaultValue="love.lindberg10@gmail.com" type="email" />
                </div>
                <div className="space-y-1.5">
                  <Label>Company</Label>
                  <Input defaultValue="Loop Skincare" />
                </div>
                <div className="space-y-1.5">
                  <Label>Timezone</Label>
                  <Input defaultValue="Europe/Stockholm" />
                </div>
              </div>
              <Button variant="gradient" onClick={() => toast.success("Profile saved")}>Save changes</Button>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="notifications">
          <Card>
            <CardHeader>
              <CardTitle>Notifications</CardTitle>
              <CardDescription>Choose what you want to hear about.</CardDescription>
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
              <CardDescription>Update your password and manage sessions.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-1.5">
                <Label>Current password</Label>
                <Input type="password" placeholder="••••••••" />
              </div>
              <div className="space-y-1.5">
                <Label>New password</Label>
                <Input type="password" placeholder="••••••••" />
              </div>
              <Button variant="gradient" onClick={() => toast.success("Password updated")}>Update password</Button>
              <Separator className="my-2" />
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium">Two-factor authentication</p>
                  <p className="text-xs text-muted-foreground">Add an extra layer of security.</p>
                </div>
                <Switch />
              </div>
            </CardContent>
          </Card>

          <Card className="mt-6 border-destructive/30">
            <CardHeader>
              <CardTitle className="text-destructive">Danger zone</CardTitle>
              <CardDescription>Deleting your account is permanent and cannot be undone.</CardDescription>
            </CardHeader>
            <CardContent>
              <Button variant="destructive" onClick={() => toast.error("This is a demo — account not deleted")}>
                Delete account
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="api">
          <Card>
            <CardHeader>
              <CardTitle>API keys</CardTitle>
              <CardDescription>Provider keys used for script, voice, and video generation.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-2">
              {API_KEYS.map((k) => (
                <div key={k.name} className="flex items-center justify-between rounded-xl border border-border p-3">
                  <div>
                    <p className="text-sm font-medium">{k.name}</p>
                    <p className="font-mono text-xs text-muted-foreground">{k.masked}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge variant={k.connected ? "success" : "secondary"}>
                      {k.connected ? "Connected" : "Not connected"}
                    </Badge>
                    <Button variant="outline" size="sm">{k.connected ? "Rotate" : "Connect"}</Button>
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
