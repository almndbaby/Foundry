"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Blocks, LayoutDashboard, Compass, FolderKanban, BookOpen, SlidersHorizontal, ArrowUpRight, LockKeyhole } from "lucide-react";
import { cn } from "@/lib/utils";
import { siteConfig } from "@/config/site";

const navigation = [
  { label: "Overview", href: "/", icon: LayoutDashboard },
  { label: "Discovery", icon: Compass },
  { label: "Projects", icon: FolderKanban },
  { label: "Knowledge", icon: BookOpen },
];

export function WorkspaceShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return <div className="min-h-dvh lg:flex">
    <a href="#main-content" className="sr-only fixed left-4 top-4 rounded bg-card p-3 text-foreground focus:not-sr-only">Skip to content</a>
    <aside className="flex shrink-0 flex-col bg-sidebar text-sidebar-foreground lg:fixed lg:inset-y-0 lg:w-60">
      <Link href="/" className="flex items-center gap-3 px-6 py-7 text-sidebar-accent-foreground"><span className="flex size-9 items-center justify-center rounded-lg bg-primary"><Blocks className="size-5" aria-hidden="true" /></span><span className="text-2xl font-semibold tracking-tight">foundry<span className="text-primary">.</span></span></Link>
      <div className="mx-4 hidden items-center gap-3 rounded-lg border border-sidebar-accent px-3 py-3 lg:flex"><span className="flex size-8 items-center justify-center rounded bg-sidebar-accent text-xs font-semibold text-sidebar-accent-foreground">F</span><div><p className="text-sm font-medium text-sidebar-accent-foreground">Foundry workspace</p><p className="mt-1 text-[11px]">Foundation edition</p></div></div>
      <p className="mb-3 mt-8 hidden px-7 text-[10px] font-semibold tracking-[0.16em] lg:block">WORKSPACE</p>
      <nav aria-label="Main navigation" className="flex gap-1 overflow-x-auto px-3 pb-3 lg:flex-col lg:overflow-visible">
        {navigation.map(({ label, href, icon: Icon }) => href ? <Link key={label} href={href} aria-current={pathname === href ? "page" : undefined} className={cn("flex items-center gap-3 rounded-md px-3 py-2.5 text-sm transition-colors hover:bg-sidebar-accent", pathname === href && "bg-sidebar-accent text-sidebar-accent-foreground")}><Icon className="size-4 shrink-0" aria-hidden="true" />{label}<span className="ml-auto hidden size-1.5 rounded-full bg-primary lg:block" /></Link> : <span key={label} aria-disabled="true" title="Planned for a future release" className="flex cursor-not-allowed items-center gap-3 rounded-md px-3 py-2.5 text-sm opacity-55"><Icon className="size-4 shrink-0" aria-hidden="true" />{label}<LockKeyhole className="ml-auto hidden size-3 lg:block" aria-hidden="true" /><span className="sr-only"> — planned, unavailable</span></span>)}
      </nav>
      <div className="mt-auto hidden p-4 lg:block"><div className="mb-5 rounded-lg border border-sidebar-accent p-4"><p className="mb-2 text-xs font-medium text-sidebar-accent-foreground">Built with intention.</p><p className="text-xs leading-relaxed">A strong foundation for what comes next.</p><Link href="/setup" className="mt-4 flex items-center gap-2 text-xs text-sidebar-accent-foreground">Explore the foundation <ArrowUpRight className="size-3" /></Link></div><Link href="/setup" aria-current={pathname === "/setup" ? "page" : undefined} className={cn("flex items-center gap-3 rounded-md px-3 py-2.5 text-sm hover:bg-sidebar-accent", pathname === "/setup" && "bg-sidebar-accent text-sidebar-accent-foreground")}><SlidersHorizontal className="size-4" />Setup & architecture</Link><div className="mt-5 flex items-center justify-between border-t border-sidebar-accent px-3 pt-5 text-[11px]"><span>FOUNDATION</span><span>v{siteConfig.version}</span></div></div>
    </aside>
    <div className="min-w-0 flex-1 lg:ml-60"><header className="flex h-16 items-center justify-between gap-3 border-b bg-card px-5 sm:px-8"><div className="flex items-center gap-3 text-xs"><span className="text-muted-foreground">Workspace</span><span className="text-border">/</span><span>{pathname === "/setup" ? "Setup & architecture" : "Overview"}</span></div><Link href="/setup" className="flex items-center gap-2 text-xs text-muted-foreground hover:text-foreground"><span className="size-1.5 rounded-full bg-primary" />Foundation release<ArrowUpRight className="size-3.5" /></Link></header><main id="main-content" className="mx-auto max-w-7xl px-5 py-8 sm:px-8 lg:px-10 lg:py-10">{children}</main></div>
  </div>;
}
