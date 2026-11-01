import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, ArrowUpRight, Database, Sparkles } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";

export const metadata: Metadata = { title: "Setup & architecture" };
const layers = [
  ["src/app", "Routes, layouts, loading and error boundaries, and server API endpoints."],
  ["src/components", "Reusable workspace layouts and shadcn/ui primitives."],
  ["src/features", "Feature-owned components and business logic, isolated by domain."],
  ["src/server", "Server-only infrastructure and HTTP helpers. Future service adapters belong here."],
  ["src/types", "Shared TypeScript contracts across feature and server boundaries."],
  ["src/lib · src/config", "Small reusable utilities and public application configuration."],
];
export default function SetupPage() {
  return <div className="flex max-w-4xl flex-col gap-8"><div><Button variant="ghost" asChild><Link href="/"><ArrowLeft data-icon="inline-start" />Overview</Link></Button><h1 className="mt-5 text-3xl font-semibold tracking-tight">A foundation built to grow</h1><p className="mt-3 text-sm leading-6 text-muted-foreground">A working application shell. Clear boundaries. No external services connected.</p></div>
    <Card className="shadow-none"><CardHeader><CardTitle><h2>Application architecture</h2></CardTitle><CardDescription>Each layer has a clear responsibility.</CardDescription></CardHeader><CardContent><dl className="flex flex-col gap-5">{layers.map(([path, description]) => <div key={path} className="grid gap-2 sm:grid-cols-[160px_1fr]"><dt className="font-mono text-xs text-primary">{path}</dt><dd className="text-sm leading-6 text-muted-foreground">{description}</dd></div>)}</dl></CardContent></Card>
    <section id="integrations" className="flex scroll-mt-8 flex-col gap-4"><h2 className="text-lg font-semibold">Connect deliberately</h2><p className="text-sm leading-6 text-muted-foreground">These are future setup requirements, not active connections. Adding credentials alone will not enable a feature.</p><div className="grid gap-4 sm:grid-cols-2">{[{ title: "Supabase", icon: Database, text: "Provision a project, implement server and browser clients, configure authentication, then add reviewed migrations and row-level security policies.", url: "https://supabase.com/docs" }, { title: "OpenAI", icon: Sparkles, text: "Add a server-only provider adapter, authentication, request validation, rate limits, usage budgets, and timeouts before enabling AI requests.", url: "https://platform.openai.com/docs" }].map(({ title, icon: Icon, text, url }) => <Card key={title} className="shadow-none"><CardHeader><Icon className="mb-2 size-5 text-primary" /><CardTitle><h3>{title}</h3></CardTitle><CardDescription><Badge variant="outline">Not connected</Badge></CardDescription></CardHeader><CardContent className="flex flex-col gap-4"><p className="text-sm leading-6 text-muted-foreground">{text}</p><a href={url} target="_blank" rel="noreferrer" className="flex items-center gap-2 text-xs text-primary">Official documentation<ArrowUpRight className="size-3" /><span className="sr-only"> (opens in new tab)</span></a></CardContent></Card>)}</div></section>
    <section className="rounded-xl border bg-card p-6"><h2 className="font-semibold">Ready for development, not production use</h2><p className="mt-3 text-sm leading-7 text-muted-foreground">The workspace is public and contains no business data. Product features, user accounts, persistence, and AI generation are intentionally unavailable. The reserved AI endpoint returns a structured 503 response without reading your request or calling a provider.</p><p className="mt-3 text-sm leading-7 text-muted-foreground">See the repository README for installation, verification commands, environment conventions, and the production-readiness checklist.</p></section>
  </div>;
}
