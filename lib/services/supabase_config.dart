/// Supabase Configuration
/// 
/// IMPORTANT: Replace these with your actual Supabase project credentials.
/// Get them from: https://supabase.com/dashboard/project/YOUR_PROJECT/settings/api
///
/// For production, consider using environment variables or a .env file.
class SupabaseConfig {
  /// Your Supabase project URL
  /// Format: https://YOUR_PROJECT_REF.supabase.co
  static const String url = 'YOUR_SUPABASE_URL';

  /// Your Supabase anon (public) key
  /// This is safe to expose in client-side code - RLS protects your data
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';

  /// Check if Supabase is configured
  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' && anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
