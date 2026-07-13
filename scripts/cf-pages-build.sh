#!/usr/bin/env bash
# Cloudflare Pages build for the Shipping Hub Flutter web PWA.
#
# The Pages build image doesn't ship Flutter, so we install a PINNED version
# (reproducible builds) and compile the web release. Set this as the Pages
# "Build command":  bash scripts/cf-pages-build.sh
# and the "Build output directory" to:  build/web
#
# Required Pages environment variables (Settings > Environment variables):
#   SUPABASE_URL        e.g. https://bpoxslfllffldidoaoka.supabase.co
#   SUPABASE_ANON_KEY   the anon/publishable key (safe to expose in a client bundle)
# Optional:
#   TRACKING_BASE_URL   only if you want tracking links to point at a custom
#                       domain; on web it otherwise derives from the deployed
#                       origin automatically, so you can usually leave it unset.
set -euo pipefail

FLUTTER_VERSION="3.44.0"
FLUTTER_DIR="$HOME/.flutter-$FLUTTER_VERSION"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "==> Installing Flutter $FLUTTER_VERSION"
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

# Avoid "dubious ownership" git errors in the CI checkout.
git config --global --add safe.directory "$FLUTTER_DIR" || true

flutter --version
flutter pub get

echo "==> Building web release"
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:?set SUPABASE_URL in Cloudflare Pages env vars}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:?set SUPABASE_ANON_KEY in Cloudflare Pages env vars}" \
  ${TRACKING_BASE_URL:+--dart-define=TRACKING_BASE_URL="$TRACKING_BASE_URL"}

echo "==> Done. Output in build/web"
