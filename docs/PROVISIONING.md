# Shipping Hub: Backend Provisioning Handoff

**Status:** deferred by decision on 2026-07-10. All app code and the schema are
done and committed on `feature/freemium-flagship`; the app runs today in
offline/local mode with no backend. This doc is the recipe for standing up the
live backend when you want the hosted demo (e.g. closer to the Oct 1 launch).

**Why deferred:** the Dakiss-Media Supabase org's two free project slots are
used, so a dedicated third project is **$10/month**. Not worth paying months
before launch when the app already demos locally.

## Option A — dedicated project (clean, $10/mo)

1. Create the project (Supabase MCP or dashboard): org `Dakiss-Media`
   (`ctfwhbrfsququxovcvcv`), name `shipping-hub`, region `us-east-1`. Confirm
   the $10/mo cost first.
2. Apply `supabase/schema.sql` (SQL Editor, or MCP `apply_migration` named
   `schema_v2`). It is self-contained: drops v1's insecure tracking view,
   creates all tables with tombstone + tracking-token columns, adds
   `subscriptions`/`devices`, and hardens RLS (20 policies, anon revoked).
3. Copy the project URL + anon key from Project Settings > API.

## Option B — reuse "Dakiss-dev's Project" (free, shared)

Apply the same `supabase/schema.sql` to project `ddjxlfifqikwfgybvija`. It has a
`bookings` table (another app); the schema is additive (`CREATE TABLE IF NOT
EXISTS`) and won't touch it. Trade-off: Shipping Hub shares an anon key and API
surface with that app.

## Auth config (both options)

In Authentication > Sign In / Up > Email: **temporarily disable "Confirm
email"** for foundation testing. The verify-email deep-link flow ships in the
next plan; with confirmation on, mobile signups can't complete and e2e stalls.
Re-enable it the moment the deep links land.

## Wire the app

```bash
cp env.example.json env.json    # fill in SUPABASE_URL + SUPABASE_ANON_KEY
flutter run -d chrome --dart-define-from-file=env.json
```

`env.json` is gitignored. With no `env.json`, the app runs local-only (the
offline path), which is how it behaves today.

## End-to-end verification checklist

1. Onboarding → sign up (fresh email) → business setup → dashboard loads.
2. Add a customer with a +226 phone; create a shipment; add a package with a
   receiver (+223).
3. In Table Editor: `operators` has 1 row; `customers.phone_country_code` =
   `+226` (the bug this rebuild kills); `packages.receiver_phone_country_code`
   = `+223`; `packages.tracking_token` populated.
4. Settings → Sync Now → "All synced • HH:MM" appears.
5. Delete the package in-app → `packages.deleted_at` set (tombstone pushed),
   package gone from lists.
6. DevTools > Network > Offline: add another customer → Settings shows
   "1 changes pending" (no crash). Back online → Sync Now → pending clears,
   row appears.
7. Sign out → sign back in → all data returns (pull + namespace switch worked).
8. Anon read is dead:
   `curl -s "https://<REF>.supabase.co/rest/v1/packages?select=*" -H "apikey: <ANON_KEY>"`
   returns a permission-denied error (code 42501 — grants revoked), and
   `.../rest/v1/public_package_tracking?select=*` returns a 404 (view gone).

## Deploy the PWA (when ready)

`flutter build web --dart-define-from-file=env.json`, then publish `build/web`
to Cloudflare Pages. Repo stays public with bring-your-own-Supabase docs; your
instance is the live demo backend.
