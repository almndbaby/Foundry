import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import type { Database } from "@/types/database";

import { getSupabaseConfig, isSupabaseConfigured, supabaseCookieOptions } from "./env";

let warnedMissingConfig = false;

/**
 * Refreshes the Supabase auth session cookies on each request. Called from
 * src/proxy.ts. Performs no redirects or access control.
 */
export async function updateSession(request: NextRequest): Promise<NextResponse> {
  let response = NextResponse.next({ request });

  if (!isSupabaseConfigured()) {
    if (!warnedMissingConfig) {
      warnedMissingConfig = true;
      console.warn(
        "[supabase] Session refresh skipped: NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is not set.",
      );
    }
    return response;
  }

  const { url, publishableKey } = getSupabaseConfig();

  const supabase = createServerClient<Database>(url, publishableKey, {
    cookieOptions: supabaseCookieOptions,
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        for (const { name, value } of cookiesToSet) {
          request.cookies.set(name, value);
        }
        response = NextResponse.next({ request });
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
      },
    },
  });

  // Must run immediately after creating the client: it validates the token
  // and triggers a refresh (via setAll) when it has expired.
  await supabase.auth.getClaims();

  // Return this exact response so the refreshed cookies reach the browser.
  return response;
}
