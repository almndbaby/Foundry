import Link from "next/link";
import { Button } from "@/components/ui/button";
export default function NotFound() {
  return <section className="flex flex-col items-start gap-4 py-16"><p className="text-xs text-primary">404 / NOT FOUND</p><h1 className="text-2xl font-semibold">This page isn&apos;t here</h1><p className="text-sm text-muted-foreground">Head back to your workspace to find your footing.</p><Button asChild><Link href="/">Back to overview</Link></Button></section>;
}
