"use client";
import { Button } from "@/components/ui/button";
export default function ErrorBoundary({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <section role="alert" className="flex flex-col items-start gap-4 py-16"><h1 className="text-2xl font-semibold">Something went wrong</h1><p className="text-sm text-muted-foreground">We couldn&apos;t load this part of the workspace. Please try again.</p><Button onClick={reset}>Try again</Button></section>;
}
