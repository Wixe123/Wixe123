"use client";

import * as React from "react";
import { toast } from "sonner";
import { Plus, MoreHorizontal, FolderOpen, MessageSquare, CheckCircle2, Users } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select, SelectTrigger, SelectValue, SelectContent, SelectItem,
} from "@/components/ui/select";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogTrigger,
} from "@/components/ui/dialog";
import { TEAM_MEMBERS } from "@/lib/mock-data";

const FEATURES = [
  { icon: FolderOpen, label: "Folders", desc: "Organize projects by client or campaign." },
  { icon: MessageSquare, label: "Comments", desc: "Leave feedback directly on a script or video." },
  { icon: CheckCircle2, label: "Approvals", desc: "Route drafts through client sign-off." },
  { icon: Users, label: "Client portal", desc: "Give clients view-only access to review work." },
];

export default function TeamPage() {
  const [open, setOpen] = React.useState(false);

  return (
    <div>
      <PageHeader
        title="Team"
        description="Invite teammates and manage roles across your workspace."
        actions={
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button variant="gradient"><Plus className="size-4" /> Invite member</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>Invite a teammate</DialogTitle></DialogHeader>
              <div className="space-y-4">
                <div className="space-y-1.5">
                  <Label>Email</Label>
                  <Input placeholder="teammate@company.com" />
                </div>
                <div className="space-y-1.5">
                  <Label>Role</Label>
                  <Select defaultValue="Editor">
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {["Owner", "Editor", "Reviewer", "Client (view only)"].map((r) => (
                        <SelectItem key={r} value={r}>{r}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <DialogFooter>
                <Button
                  variant="gradient"
                  onClick={() => {
                    setOpen(false);
                    toast.success("Invitation sent");
                  }}
                >
                  Send invite
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        }
      />

      <Card>
        <CardHeader>
          <CardTitle>Members</CardTitle>
          <CardDescription>{TEAM_MEMBERS.length} people have access to this workspace.</CardDescription>
        </CardHeader>
        <CardContent className="p-0">
          <div className="divide-y divide-border">
            {TEAM_MEMBERS.map((m) => (
              <div key={m.email} className="flex items-center gap-3 px-6 py-4">
                <Avatar>
                  <AvatarFallback className="text-lg">{m.avatarEmoji}</AvatarFallback>
                </Avatar>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium">{m.name}</p>
                  <p className="truncate text-xs text-muted-foreground">{m.email}</p>
                </div>
                <Badge variant="outline">{m.role}</Badge>
                <Badge variant={m.status === "Active" ? "success" : "warning"}>{m.status}</Badge>
                <Button variant="ghost" size="icon-sm"><MoreHorizontal className="size-4" /></Button>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {FEATURES.map((f) => (
          <Card key={f.label} className="p-5">
            <span className="flex size-9 items-center justify-center rounded-xl bg-primary/12 text-primary">
              <f.icon className="size-4" />
            </span>
            <p className="mt-3 font-medium">{f.label}</p>
            <p className="mt-1 text-sm text-muted-foreground">{f.desc}</p>
          </Card>
        ))}
      </div>
    </div>
  );
}
