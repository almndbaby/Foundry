export type SupabasePublicConfig = {
  url: string;
  publishableKey: string;
};

export class SupabaseConfigError extends Error {
  constructor(missing: readonly string[]) {
    super(
      `Supabase is not configured. Missing environment variable(s): ${missing.join(", ")}. ` +
        "Connect the Supabase integration in the Vercel project (Settings → Integrations) " +
        "or add them to .env.local for local development.",
    );
    this.name = "SupabaseConfigError";
  }
}

function readPublicConfig() {
  // Each variable must be referenced statically so Next.js can inline
  // NEXT_PUBLIC_ values into the browser bundle.
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?.trim();

  const missing: string[] = [];
  if (!url) missing.push("NEXT_PUBLIC_SUPABASE_URL");
  if (!publishableKey) missing.push("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY");

  return { url, publishableKey, missing };
}

export function isSupabaseConfigured(): boolean {
  return readPublicConfig().missing.length === 0;
}

export function getSupabaseConfig(): SupabasePublicConfig {
  const { url, publishableKey, missing } = readPublicConfig();

  if (!url || !publishableKey) {
    throw new SupabaseConfigError(missing);
  }

  try {
    new URL(url);
  } catch {
    throw new Error("NEXT_PUBLIC_SUPABASE_URL is not a valid URL.");
  }

  return { url, publishableKey };
}

export const supabaseCookieOptions = {
  secure: process.env.NODE_ENV === "production",
} as const;
