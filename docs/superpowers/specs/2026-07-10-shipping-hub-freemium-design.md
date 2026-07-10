# Shipping Hub: Freemium Flagship Design

**Date:** 2026-07-10
**Status:** Approved by Ali (sections reviewed and signed off individually)
**Strategic frame:** Portfolio flagship under the Contract Engine lock. Built launch-ready, demo-perfect, and public. Stripe stays in test mode; flipping to live keys after 2026-10-01 is the business launch. No marketing, support channel, or paid acquisition before then.

## Goal

Take the Feb 2026 MVP to a finished freemium product: a generous free plan that never blocks the daily intake-and-get-paid workflow, and a Pro plan that sells scale and professionalism. Primary surfaces: installable PWA (hosted on Cloudflare Pages) and a working Android APK. Visual direction: refine the existing navy + gold identity.

## Current-state summary (from the 2026-07-10 audit)

Working MVP core: package intake with air/sea pricing, shipment lifecycle, customers, WhatsApp receipts, offline-first Hive storage with a Supabase sync queue, partial FR/EN, PWA shell. Critical defects to resolve:

- Sync loses data silently: swallowed exceptions dequeue failed writes; `fullSync` never flushes before pulling (`_isSyncing` guard ordering); blind last-write-wins merge; deletions never propagate; Hive bleeds across accounts on shared devices.
- Security: `public_package_tracking` view bypasses RLS and exposes all tenants' data to anon; `operators` update policy has no column restrictions.
- Faked features: photos never upload (local path stored as `photo_url`); dashboard pull-to-refresh is a no-op; WhatsApp "Send to Both" second message rarely sends; false "end-to-end encryption" claim.
- Broken auth: Google Sign-In cannot complete on Android (unregistered deep link); verify-email waits forever on mobile; password reset link is a dead end; no account deletion; "Continue without account" is an infinite loop; setup wizard re-runs every sign-in; OAuth users never get an operator profile row.
- Data corruption: customer `phoneCountryCode` resets to `+1` through one sync round-trip; contact import drops country codes.
- FR localization missing across the entire entry flow and receipts.
- Hygiene: nine files over the 400-line rule, one smoke test, duplicated contact picker, dead code, four unused dependencies.

## Tier design

| Capability | Free | Pro |
|---|---|---|
| Packages, customers | Unlimited | Unlimited |
| Active shipments | 3 at a time | Unlimited |
| Cloud backup + sync | Yes, 1 registered device (transferable) | Multi-device |
| WhatsApp receipts | Yes, small "via Shipping Hub" footer | Business name + logo, no footer |
| Package photos | Yes | Yes |
| Customer tracking links | No | Yes |
| Exports (CSV, PDF manifest) | No | Yes |
| Analytics | No | Yes |

On-ramp funnel: local-only mode works forever without an account; signing up migrates local data to the cloud and adds backup; Pro adds scale and professionalism.

## Section 1: Backend architecture

Fresh Supabase project with schema v2:

- **`subscriptions` table** (new): `operator_id` FK, `plan` (`free`/`pro`), `status`, `current_period_end`, `stripe_customer_id`, `stripe_subscription_id`. RLS: operator can SELECT own row only. All writes via service-role (Stripe webhook Edge Function). Plan data never lives on a client-writable row.
- **`operators` update policy** rewritten with explicit column allowances and a `WITH CHECK` clause.
- **Tracking**: drop `public_package_tracking`. Add unguessable `tracking_token` (UUID) per package. Public lookup via rate-limited `track` Edge Function returning only status, destination, and ETA. No payment status, no PII, no enumeration surface.
- **Tombstones**: `deleted_at` on packages, shipments, customers so deletions propagate.
- **`reference_number`**: unique index plus insert-retry on collision; remains the human-facing id, tracking uses the token.
- **Storage**: `package-photos` bucket with per-operator folder RLS.
- **`devices` table** (new): `operator_id`, `device_id`, `label`, `last_seen_at`. A trigger enforces the free-plan single-device rule on registration; Settings lets a free operator transfer (deregister old, register new).
- **Edge Functions**: `stripe-checkout`, `stripe-webhook`, `track`, `delete-account`.
- **Hosting**: `flutter build web` on Cloudflare Pages. Repo stays public with bring-your-own-Supabase docs; Ali's instance is the live demo backend.

## Section 2: Sync engine v2

- `SupabaseService` CRUD methods throw on failure instead of swallowing. Queue entries are removed only on confirmed success; failures retry with backoff and surface to the UI.
- `fullSync` flushes the pending queue before pulling (fix the `_isSyncing` guard ordering bug).
- Merge by `updated_at`: cloud replaces local only when newer; records with queued local edits win until flushed.
- Soft-delete tombstones sync both directions; local hard-delete after tombstone acknowledgment.
- Hive boxes namespaced per account id; queue entries stamped with the owning user; sign-out cannot leak data or queued writes into another account.
- Sync status UI: pending-changes count, last-synced timestamp, error banner with retry (Settings + subtle dashboard indicator).
- Server-side rejections (plan limits) map to an explicit "limit reached" state, never silent divergence.
- `isOnline` reports actual connectivity, not auth state.
- Fix customer `phoneCountryCode` end to end: push includes it, pull preserves it, contact import parses it.

## Section 3: Entitlements and gating

- `PlanService` reads the subscription on login, caches in Hive, exposes `plan` via `AppProvider` (`isPro` getter).
- Client-side gates are UX: friendly upgrade sheet when a free operator hits a Pro boundary (4th active shipment, second device, Pro toggles). Never a dead button.
- Server-side gates are law: Postgres trigger rejects the 4th active-shipment insert for free accounts; device registration check enforces the one-device rule; sync rejection handling renders these as in-app limit states.
- "Continue without account" becomes a real persistent local-only mode; later sign-up migrates local data to the cloud.
- Demo posture: Stripe test mode means any demo viewer can "upgrade" with a test card. That is a feature of the demo.

## Section 4: Feature build-out

All plans:

1. **Photo upload** (fixes the biggest faked feature): compress on device, upload to `package-photos`, offline-queued, real thumbnails, `photo_url` becomes a storage URL.
2. **Ride-along fixes**: "Send to Both" reworked (sequential send that actually completes), pull-to-refresh triggers real sync, payment toggle gets undo snackbar.

Pro-gated:

3. **Customer tracking links**: receipt includes `…/track/<token>`; public page shows a clean status timeline. Flagship demo moment.
4. **Exports**: CSV (packages, customers) and PDF shipment manifest.
5. **Analytics**: revenue by month, outstanding payments, top customers, air/sea mix.
6. **Receipt branding**: free footer "via Shipping Hub"; Pro replaces with business name + logo.

Supporting:

7. **Billing screen**: current plan, Stripe Checkout upgrade (test mode), manage subscription.

## Section 5: Auth repairs

- Register `io.supabase.shippinghub://login-callback` in AndroidManifest; Google Sign-In and verify-email complete via deep link; UI stops treating browser launch as success.
- Web verification works via configured redirect URL and the existing auth-state listener.
- Password reset: `redirectTo` plus in-app new-password screen on the recovery event.
- Account deletion via `delete-account` Edge Function (service role, cascading).
- Sign-out warns on unsynced changes, then clears account-namespaced local state.
- OAuth users get operator profiles; setup wizard runs once (respect `business_setup_done`); remove the false "end-to-end encryption" claim.

## Section 6: UI and UX polish

- Navy + gold refined into a small design system: type scale, spacing tokens, consistent radii/elevation, subtle motion.
- Dark mode (seeded from the unused `cardBgDark`).
- Guided empty states, skeleton loading, human error states with actions, everywhere.
- Complete FR coverage: entry flow, dialogs, receipts (receipt language follows operator setting).
- Structure: split all files over 400 lines; single shared contact-picker widget; delete dead code (`ContactService.pickContact`, `_isCustomWeight`); drop unused deps (`http`, `intl`, `path_provider`, `path`).
- PWA polish: icons, splash, theme color, install prompt.

## Section 7: Testing and quality

- Unit tests: sync merge (timestamp wins, retry, tombstones, rejection handling) against a fake Supabase client; pricing calculators; receipt generation; entitlement gates.
- Widget tests: intake flow, paywall prompts.
- CI: GitHub Actions running `flutter analyze` + tests on PR.
- All work on `feature/freemium-flagship`, merged by PR.

## Error handling principles

- No swallowed exceptions in the data path; every failure either retries visibly or surfaces with an action.
- Offline is a first-class state, not an error.
- Money-adjacent actions (payment toggle, deletes) are confirmable or undoable.

## Out of scope (explicitly)

- Team seats / staff accounts (requires schema and RLS rework; future business phase).
- WhatsApp Business API automation, SMS credits.
- iOS as a supported target (not blocked, just untested).
- Live Stripe keys, pricing page marketing, support channels (post 2026-10-01).

## Success criteria

- A stranger can open the hosted PWA, onboard in French or English, intake a package with a real photo, get a WhatsApp receipt with a working tracking link (after test-mode upgrade), and install the app, without hitting a broken path.
- The Android APK completes Google Sign-In, email verification, and photo capture on device.
- Free plan limits enforce server-side and present friendly upgrade UX client-side.
- `flutter analyze` clean; test suite green in CI; no file over 400 lines.
