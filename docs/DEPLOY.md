# Deploying Shipping Hub to Cloudflare Pages (GitHub auto-deploy)

The app is a Flutter web PWA. Cloudflare Pages builds it from the GitHub repo on
every push to `main`, using a pinned Flutter version.

## One-time setup (you, in the Cloudflare dashboard)

1. **Cloudflare dashboard → Workers & Pages → Create → Pages → Connect to Git.**
2. Pick the **`Dakiss-dev/Shipping-hub`** repo, production branch **`main`**.
3. **Build settings:**
   - Framework preset: **None**
   - Build command: `bash scripts/cf-pages-build.sh`
   - Build output directory: `build/web`
   - Root directory: `/` (leave default)
4. **Environment variables** (add under Settings → Environment variables, for
   both **Production** and **Preview**). The values are the two lines in your
   local `env.json`:
   - `SUPABASE_URL` = `https://bpoxslfllffldidoaoka.supabase.co`
   - `SUPABASE_ANON_KEY` = *(the anon key from env.json — safe to expose; it
     already ships inside the client bundle)*
5. Save and deploy. First build takes a few minutes (it downloads Flutter 3.44.0).

You get a `https://<project>.pages.dev` URL. Every merge to `main` redeploys;
every PR gets a preview URL.

## What each file does
- `scripts/cf-pages-build.sh` — installs the pinned Flutter and runs
  `flutter build web --release` with the Supabase keys from the env vars above.
- `web/_redirects` — SPA fallback so deep links (tracking links) resolve to the
  app shell.

## Tracking links
On the web build, the customer tracking link auto-uses the deployed origin, so
`https://<project>.pages.dev/?t=<token>` just works — no extra config. Only set
`TRACKING_BASE_URL` if you later want the links on a custom domain.

## Notes for launch (held to 2026-10-01)
- The `*.pages.dev` URL is obscure and not indexed; fine for demos under the lock.
- Before real users: turn Supabase email confirmation back ON.
- Custom domain: add it in Pages → Custom domains when you're ready to go public.
