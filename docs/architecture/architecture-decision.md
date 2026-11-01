# Foundry Architecture Decisions

**Status:** Working architecture decisions for the first release  
**Repository:** `almndbaby/Foundry`  
**Working branch:** `development`

This document records the decisions that govern Foundry's initial implementation. It supplements `database-proposal.md`; it does not replace it.

## 1. Product scope

Foundry is an AI-assisted business discovery and development platform.

The first usable release will support this adult-user journey:

1. Personal discovery
2. Personalised business profile
3. Business opportunity generation
4. Research and evidence-backed opportunity assessment
5. Opportunity selection
6. Business development: business model, products/services, brand, marketing, sales, launch and growth

The product architecture should allow both Adult Entrepreneur and Young Entrepreneur pathways. Build and launch the adult experience first. The young-user pathway remains design-only until jurisdiction-specific legal, privacy and safeguarding requirements have been reviewed.

Initial release constraints:

- Single-owner projects; collaboration is disabled.
- Free access only; defer subscriptions, paid credits and billing.
- Keep research sources associated with the relevant user.
- AI-inferred attributes must be labelled as inferred.
- Default AI context may use user-stated and user-confirmed attributes only. Inferred attributes require confirmation before they influence recommendations.
- Do not expose private discovery answers, conversations, opportunity details or business-plan content to guardians.
- Do not hard-code legal age thresholds, guardian-consent rules or retention periods before jurisdiction-specific review.

## 2. Technical direction

- Next.js App Router and TypeScript for the application.
- Supabase Auth and PostgreSQL for identity and data.
- Supabase Row Level Security (RLS) as a core data boundary, not as the only security control.
- GitHub is the source of truth. All schema changes are versioned migration files.
- Vercel hosts the application.
- Keep AI behind a provider-independent server-side service layer. Provider credentials and model selection stay server-side.
- Use standard PostgreSQL UUIDs initially. Do not introduce UUIDv7, partitioning or `pgvector` until there is a demonstrated need.
- Avoid new paid services or subscriptions until explicitly approved.

## 3. Data ownership and relational integrity

Every user-owned record must have an enforceable ownership path to its owner.

RLS policies must restrict reads and writes to the authenticated owner. In addition, use composite foreign keys or equivalent database constraints so a child row cannot reference a parent owned by a different user.

Do not rely only on application checks or a `user_id` column copied onto every table. The database must reject cross-user relationships even if an application bug attempts to create them.

Projects are single-owner in the first release. Do not implement project membership or collaboration yet.

## 4. RLS, privileges and protected fields

Enable and test RLS on every exposed user-data table.

Use least privilege:

- Authenticated users receive only the table and operation privileges they need.
- Server-side operations should run under the user's authenticated context wherever possible.
- Privileged database functions must be narrowly scoped, validate their inputs and have an explicit execution privilege policy.
- The Supabase service-role key must never be shipped to the browser or exposed in client-side environment variables.
- Do not use a broad service-role bypass as the default application data-access pattern.

The client must not be able to directly modify protected fields, including:

- account pathway or account status
- age-assurance and consent verification state
- staff or administrative roles
- billing or entitlement state
- AI provenance and confirmation status
- usage counters, credits or metering records

Change protected values only through validated server-side operations or database functions. Add tests proving unauthorised updates are rejected.

RLS helper functions must avoid recursive policy evaluation and must be reviewed for safe `SECURITY DEFINER` use, fixed search paths and narrowly granted execution rights.

## 5. Deletion, consent and audit records

Do not apply blanket cascading deletion from `auth.users` to every record.

Some records may need controlled deletion, anonymisation or retention for security, consent, legal or operational reasons. Implement deletion as an explicit, auditable workflow once applicable legal and retention requirements are known.

Do not assume the retention periods in the original proposal are legally approved. Treat them as unresolved decisions pending jurisdiction-specific review.

## 6. AI service boundary

AI calls must go through a server-side service layer rather than being embedded directly in page components or database policies.

The service layer should support:

- provider-independent interfaces
- server-side provider and model selection
- versioned prompts
- structured outputs validated against schemas
- tool permissions and input validation
- safety checks
- usage and cost metadata
- traceable AI-run records

The `/api/ai` placeholder remains disabled until authentication, authorisation, input validation, usage controls and safe provider-key handling are implemented.

AI-generated research must distinguish sourced evidence from model-generated interpretation. Store source metadata and evidence links with assessments where relevant.

## 7. Entitlements and usage

The first release is free-only.

Implement only the minimum server-controlled entitlement and usage tracking needed to protect the service and understand usage. Usage updates must be atomic and idempotent so retries cannot double-charge or corrupt counters.

Defer paid plans, payment processing, credit purchases and billing tables until there is a validated product and an explicit commercial decision.

## 8. Young Entrepreneur pathway

Design the data model so a young-user pathway can be added without exposing private user content to guardians.

Do not launch this pathway until legal and safeguarding review has established the requirements for each launch jurisdiction, including age thresholds, consent, guardian verification, reporting, retention and deletion.

Guardian relationships must not imply access to private discovery answers, conversations, opportunity details or business plans. Any future guardian-facing functions must be narrowly defined and separately authorised.

## 9. Migration sequence

Keep migrations small, ordered and independently reviewable. Proposed sequence:

1. `0001_foundations.sql` — required extensions, private schema, shared timestamp helper and minimal foundational privileges/functions.
2. `0002_identity.sql` — profiles, settings, auth-user bootstrap, protected fields, RLS and tests.
3. `0003_discovery.sql` — question bank, sessions, answers, profile attributes/snapshots, ownership constraints, RLS and tests.
4. `0004_ai_core.sql` — conversations, messages and AI-run metadata, ownership constraints, RLS and tests.
5. `0005_opportunities.sql` — opportunities, assessments, dimensions, research sources/evidence, ownership constraints, RLS and tests.
6. `0006_projects.sql` — single-owner projects and business-development records, ownership constraints, RLS and tests.
7. `0007_entitlements.sql` — free entitlements and server-controlled usage tracking.

Safeguarding, guardian workflows, billing, export/deletion automation and other deferred systems should be added only when their requirements are established.

Each migration must be committed to GitHub before it is applied. Test migrations and RLS behaviour against a development database first. Do not experiment on the intended production database.

## 10. Development workflow and immediate next step

- Keep all active work on the `development` branch. Keep `main` stable.
- Make database changes only through committed SQL migration files.
- Use a separate development database target (a separate Supabase project or a suitable isolated branch) before applying schema migrations.
- Confirm which existing Supabase project is intended for production and whether the older project can safely serve as development. Do not assume the Sydney project is disposable or safe to experiment on.
- Never commit secrets, database passwords, service-role keys or private environment files.
- After each migration, verify schema state, RLS policies and representative allowed/denied access cases.

**Immediate next task:** establish and verify the isolated development database target. Then prepare and test `0001_foundations.sql`. No schema migration should be applied to the production target before this is done.

## 11. Items deliberately left open

The following require evidence or specialist review before implementation:

- launch jurisdictions and jurisdiction-specific age/consent requirements
- retention periods and deletion exceptions
- young-user onboarding, guardian verification and safeguarding processes
- production/development Supabase project assignment
- AI provider, model selection and budget limits
- when semantic search or vector embeddings become justified
- paid plans, pricing and billing
