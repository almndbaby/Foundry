"use client";
export default function GlobalError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <html lang="en"><body style={{ fontFamily: "sans-serif", padding: "3rem" }}><h1>Foundry couldn&apos;t load</h1><p>Please retry. If this continues, refresh the page.</p><button onClick={reset}>Try again</button></body></html>;
}
