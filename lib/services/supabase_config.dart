/// Supabase Configuration
/// 
/// IMPORTANT: Replace these with your actual Supabase project credentials.
/// Get them from: https://supabase.com/dashboard/project/YOUR_PROJECT/settings/api
///
/// For production, consider using environment variables or a .env file.
class SupabaseConfig {
  /// Your Supabase project URL
  /// Format: https://YOUR_PROJECT_REF.supabase.co
  static const String url = 'https://bpoxslfllffldidoaoka.supabase.co';

  /// Your Supabase anon (public) key
  /// This is safe to expose in client-side code - RLS protects your data
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwb3hzbGZsbGZmbGRpZG9hb2thIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA3NzI4ODksImV4cCI6MjA4NjM0ODg4OX0.qECUk0daVkdZajKHNbBH2u-afFE2Pr24yCXs1M3gCMI';

  /// Check if Supabase is configured
  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' && anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
