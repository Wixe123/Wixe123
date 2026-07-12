import {
  LayoutDashboard,
  FilePlus2,
  FolderOpen,
  ScrollText,
  Users,
  Mic,
  Clapperboard,
  Sparkles,
  Image as ImageIcon,
  PenSquare,
  SplitSquareHorizontal,
  Palette,
  UsersRound,
  Plug,
  CreditCard,
  Settings,
  type LucideIcon,
} from "lucide-react";

export type NavItem = {
  label: string;
  href: string;
  icon: LucideIcon;
  badge?: string;
};

export type NavGroup = {
  title: string;
  items: NavItem[];
};

export const NAV_GROUPS: NavGroup[] = [
  {
    title: "Overview",
    items: [
      { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
      { label: "New Project", href: "/dashboard/projects/new", icon: FilePlus2, badge: "New" },
      { label: "Projects", href: "/dashboard/projects", icon: FolderOpen },
    ],
  },
  {
    title: "Create",
    items: [
      { label: "Scripts", href: "/dashboard/scripts", icon: ScrollText },
      { label: "Avatars", href: "/dashboard/avatars", icon: Users },
      { label: "Voices", href: "/dashboard/voices", icon: Mic },
      { label: "Video Studio", href: "/dashboard/studio", icon: Clapperboard },
      { label: "Thumbnails", href: "/dashboard/thumbnails", icon: ImageIcon },
      { label: "Copywriter", href: "/dashboard/copywriter", icon: PenSquare },
      { label: "A/B Testing", href: "/dashboard/ab-testing", icon: SplitSquareHorizontal },
    ],
  },
  {
    title: "Optimize",
    items: [{ label: "Viral Optimizer", href: "/dashboard/optimizer", icon: Sparkles }],
  },
  {
    title: "Manage",
    items: [
      { label: "Brand Kit", href: "/dashboard/brand-kit", icon: Palette },
      { label: "Team", href: "/dashboard/team", icon: UsersRound },
      { label: "Integrations", href: "/dashboard/integrations", icon: Plug },
      { label: "Billing", href: "/dashboard/billing", icon: CreditCard },
      { label: "Settings", href: "/dashboard/settings", icon: Settings },
    ],
  },
];
