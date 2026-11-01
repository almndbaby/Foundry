import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";

import type { Database } from "@/types/database";

import { getSupabaseConfig, supabaseCookieOptions } from "./env";

let browserClient: SupabaseClient<Database> | undefined;

/**
 * Browser Supabase client for Client Components. Uses only the public
 * publishable key, so every query is subject to Row Level Security.
 */
export function createClient(): SupabaseClient<Database> {
  if (browserClient) return browserClient;

  const { url, publishableKey } = getSupabaseConfig();

  browserClient = createBrowserClient<Database>(url, publishableKey, {
    cookieOptions: supabaseCookieOptions,
  });

  return browserClient;
}
