import { Skeleton } from "@/components/ui/skeleton";
export default function Loading() {
  return <div role="status" aria-label="Loading workspace" className="flex flex-col gap-6"><Skeleton className="h-9 w-64 max-w-full" /><Skeleton className="h-5 w-80 max-w-full" /><Skeleton className="h-72 w-full" /><div className="grid gap-4 md:grid-cols-3">{[0, 1, 2].map((key) => <Skeleton key={key} className="h-48" />)}</div><span className="sr-only">Loading workspace…</span></div>;
}
