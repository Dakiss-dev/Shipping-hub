/// Supabase Configuration
///
/// Credentials come from --dart-define at build time:
///   flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
///
/// Get them from: https://supabase.com/dashboard/project/YOUR_PROJECT/settings/api
/// Apply supabase/schema.sql to a fresh project before first run.
class SupabaseConfig {
  /// Your Supabase project URL
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Your Supabase anon (public) key. Safe for client-side use when RLS is on.
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Check if Supabase is configured
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Base URL used for customer tracking links on receipts. Set this to the
  /// deployed PWA origin (e.g. https://track.dakissmedia.com) at build time;
  /// when unset it falls back to the running app's own origin so the link
  /// works in local/dev.
  static const String _trackingBaseUrl =
      String.fromEnvironment('TRACKING_BASE_URL');

  static String trackingBaseUrl(Uri appBase) =>
      _trackingBaseUrl.isNotEmpty ? _trackingBaseUrl : appBase.origin;
}
