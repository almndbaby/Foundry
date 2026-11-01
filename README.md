# Foundry

AI-powered business discovery and development platform.

This repository contains the **application foundation**: a production-grade Next.js setup, a reusable component system, and clearly defined extension points for Supabase and OpenAI. It intentionally contains no product features, sample business data, database tables, or live external connections.

## Tech stack

- [Next.js 16](https://nextjs.org) (App Router, Turbopack)
- React 19 and TypeScript (strict mode)
- Tailwind CSS v4 with semantic design tokens
- [shadcn/ui](https://ui.shadcn.com) components (Radix primitives, `lucide-react` icons)
- ESLint (`eslint-config-next`)

## Getting started

Requirements: Node.js 22 or later and npm.

```bash
npm install
cp .env.example .env.local   # optional; the foundation needs no variables yet
npm run dev                  # http://localhost:3000
```

### Scripts

| Script              | Purpose                                   |
| ------------------- | ----------------------------------------- |
| `npm run dev`       | Start the development server              |
| `npm run build`     | Create a production build                 |
| `npm run start`     | Serve the production build                |
| `npm run lint`      | Lint with zero warnings allowed           |
| `npm run typecheck` | Type-check without emitting               |

Run `npm run typecheck && npm run lint && npm run build` before opening a pull request.

## Architecture

```
src/
├── app/                    # Routes only: layouts, pages, route handlers, boundaries
│   ├── api/ai/route.ts     # Server-only AI endpoint (currently returns 503)
│   ├── setup/              # Integration readiness page
│   ├── error.tsx           # Route-level error boundary
│   ├── global-error.tsx    # Root error boundary
│   ├── loading.tsx         # Route-level loading skeleton
│   └── not-found.tsx       # 404 page
├── components/
│   ├── ui/                 # shadcn/ui primitives (generated, lightly customised)
│   └── layout/             # App-wide layout (workspace shell, navigation)
├── features/               # Feature modules, each self-contained
│   └── overview/components/
├── server/                 # Server-only code (guarded with `server-only`)
│   └── http/errors.ts      # Consistent JSON error responses
├── lib/                    # Framework-agnostic utilities
├── config/                 # Static app configuration (site metadata, navigation)
└── types/                  # Shared TypeScript types and API contracts
```

### Conventions

- **Routes stay thin.** Files in `src/app` compose feature components and call server modules; they should not hold business logic.
- **Features are independent.** Each feature lives in `src/features/<name>/` with its own `components/`, and, as needed, `actions/`, `queries/`, `schemas/`, and `types.ts`. Features should import from `components`, `lib`, `config`, `types`, and `server`, and avoid importing from each other.
- **Server code is fenced.** Anything that touches secrets, databases, or third-party APIs belongs in `src/server/` and starts with `import "server-only"`, so accidentally importing it into a client component fails the build.
- **Shared contracts live in `src/types`.** API responses use the `ApiErrorResponse` shape from `src/types/api.ts`.
- **UI uses semantic tokens.** Colours come from CSS variables in `src/app/globals.css` (`bg-background`, `text-muted-foreground`, and so on), not raw palette values.

### Error handling and loading states

- `app/error.tsx` catches errors inside a route segment and offers a retry, without exposing error details.
- `app/global-error.tsx` catches failures in the root layout.
- `app/not-found.tsx` handles unknown routes.
- `app/loading.tsx` shows skeletons while segments stream in.
- API routes return `{ error: { code, message } }` with an appropriate HTTP status and `Cache-Control: no-store`, through `errorResponse()` in `src/server/http/errors.ts`.

### Security

- No secrets are committed. `.env*` files are ignored; only `.env.example` is tracked.
- Server-only variables (for example `OPENAI_API_KEY`) must **never** use the `NEXT_PUBLIC_` prefix. Next.js inlines `NEXT_PUBLIC_` variables into the browser bundle.
- `next.config.ts` sets baseline security headers (`X-Content-Type-Options`, `Referrer-Policy`, `Strict-Transport-Security`, `Permissions-Policy`) and disables the `X-Powered-By` header. Add `X-Frame-Options: SAMEORIGIN` once authenticated or state-changing UI ships.

## Integration readiness

### Supabase (connected: application client only)

The app connects to Supabase with `@supabase/supabase-js` and `@supabase/ssr`, using only `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (provided by the Vercel Supabase integration). No tables, auth screens or business logic exist yet.

| File | Purpose |
| --- | --- |
| `src/lib/supabase/env.ts` | Reads and validates the public config; throws `SupabaseConfigError` naming any missing variable. |
| `src/lib/supabase/client.ts` | Browser client (singleton) for Client Components. |
| `src/lib/supabase/server.ts` | Per-request server client (`server-only`) for Server Components, Server Actions and Route Handlers. |
| `src/lib/supabase/proxy.ts` | `updateSession()`: refreshes auth cookies; skips with a warning if config is missing. |
| `src/proxy.ts` | Next.js 16 proxy that runs `updateSession()` on page requests. No redirects. |
| `src/types/database.ts` | Placeholder `Database` type; replace with generated types once a schema exists. |

The publishable key is only safe with Row Level Security enabled on every table. Never use the service-role or secret key in these clients. Manage future schema changes as versioned SQL migrations.

### OpenAI (server-side only)

1. Set `OPENAI_API_KEY` in the server environment. Never expose it to the client.
2. Put the provider client in `src/server/ai/`, guarded with `import "server-only"`.
3. Extend `src/app/api/ai/route.ts`: authenticate the caller, validate input (for example with Zod), rate-limit, then call the provider. The browser only ever talks to `/api/ai`.

## Outstanding setup requirements

- [x] Connect the Supabase project and add application clients.
- [ ] Define the initial schema and RLS policies; generate `src/types/database.ts`.
- [ ] Implement authentication (Supabase Auth) and protect routes.
- [ ] Provision `OPENAI_API_KEY` in Vercel project environments.
- [ ] Add input validation (Zod) and rate limiting to `/api/ai` before enabling it.
- [ ] Add automated tests (for example Vitest and Playwright) and CI checks.
- [ ] Tighten a Content Security Policy once external origins are known.

## Branching

Feature work happens on `development` (or feature branches off it). `main` is updated through pull requests only.
