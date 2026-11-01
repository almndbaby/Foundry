import "server-only";

import { createServerClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import { cookies } from "next/headers";

import type { Database } from "@/types/database";

import { getSupabaseConfig, supabaseCookieOptions } from "./env";

/**
 * Server Supabase client for Server Components, Server Actions and Route
 * Handlers. Acts as the signed-in user (via session cookies) with the
 * publishable key, so RLS applies.
 *
 * Create a new client per request; never store it in module scope, because
 * it is bound to the current request's cookies.
 */
export async function createClient(): Promise<SupabaseClient<Database>> {
  const { url, publishableKey } = getSupabaseConfig();
  const cookieStore = await cookies();

  return createServerClient<Database>(url, publishableKey, {
    cookieOptions: supabaseCookieOptions,
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Server Components cannot set cookies; src/proxy.ts refreshes the
          // session on each request instead.
        }
      },
    },
  });
}
