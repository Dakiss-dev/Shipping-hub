import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Supabase service layer for auth and the operator profile.
/// Entity CRUD lives in SupabaseBackend (lib/services/sync/supabase_backend.dart).
class SupabaseService {
  static SupabaseService? _instance;
  SupabaseClient? _client;
  bool _initialized = false;

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  bool get isInitialized => _initialized;
  bool get isConfigured => SupabaseConfig.isConfigured;
  SupabaseClient? get client => _client;

  String? get currentUserId => _client?.auth.currentUser?.id;
  bool get isAuthenticated => _client?.auth.currentUser != null;

  /// Initialize Supabase - call once at app startup
  Future<bool> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint('[Supabase] Not configured - running in offline mode');
      }
      return false;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _client = Supabase.instance.client;
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[Supabase] Initialized successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Supabase] Init failed: $e');
      }
      return false;
    }
  }

  // ==================== AUTH ====================

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? businessName,
  }) async {
    final bName = businessName ?? 'My Shipping Business';
    final response = await _client!.auth.signUp(
      email: email,
      password: password,
      data: {'business_name': bName},
    );

    // Create operator profile from the app (Supabase blocks triggers on auth.users)
    if (response.user != null) {
      // Small delay to let Supabase session fully establish (RLS needs auth.uid())
      await Future.delayed(const Duration(milliseconds: 500));
      await _ensureOperatorProfile(
        userId: response.user!.id,
        email: email,
        businessName: bName,
      );
    }

    return response;
  }

  /// Ensure operator profile exists — creates it app-side since DB trigger is disabled
  Future<void> _ensureOperatorProfile({
    required String userId,
    required String email,
    required String businessName,
  }) async {
    // Retry up to 3 times — RLS auth session may take a moment after signup
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        // Check if profile already exists
        final existing = await _client!
            .from('operators')
            .select('id')
            .eq('id', userId)
            .maybeSingle();

        if (existing == null) {
          await _client!.from('operators').insert({
            'id': userId,
            'email': email,
            'business_name': businessName,
          });
        }
        // Success — exit retry loop
        if (kDebugMode) debugPrint('[Supabase] Operator profile ensured (attempt $attempt)');
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Supabase] Ensure operator profile attempt $attempt failed: $e');
        }
        if (attempt < 3) {
          // Wait longer each retry to give RLS session time to propagate
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client!.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Safety net: ensure operator profile exists on login too
    // Pull existing business name from Supabase instead of hardcoding default
    if (response.user != null) {
      String existingName = 'My Shipping Business';
      try {
        final profile = await _client!
            .from('operators')
            .select('business_name')
            .eq('id', response.user!.id)
            .maybeSingle();
        if (profile != null && profile['business_name'] != null) {
          existingName = profile['business_name'] as String;
        }
      } catch (_) {
        // If fetch fails, fall back to default
      }
      await _ensureOperatorProfile(
        userId: response.user!.id,
        email: email,
        businessName: existingName,
      );
    }

    return response;
  }

  /// Sign in with Google OAuth (web: popup, mobile: redirect)
  Future<bool> signInWithGoogle() async {
    if (_client == null) return false;
    try {
      final result = await _client!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.shippinghub://login-callback/',
      );
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Google sign-in error: $e');
      return false;
    }
  }

  /// Check if current user's email is confirmed
  bool get isEmailConfirmed {
    final user = _client?.auth.currentUser;
    if (user == null) return false;
    // Google OAuth users are always confirmed
    final provider = user.appMetadata['provider'] as String?;
    if (provider == 'google') return true;
    return user.emailConfirmedAt != null;
  }

  /// Resend confirmation email
  Future<void> resendConfirmationEmail(String email) async {
    await _client!.auth.resend(type: OtpType.signup, email: email);
  }

  /// Refresh the current session to pick up email confirmation changes
  Future<void> refreshSession() async {
    try {
      await _client!.auth.refreshSession();
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Refresh session error: $e');
    }
  }

  Future<void> signOut() async {
    await _client!.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client!.auth.resetPasswordForEmail(email);
  }

  // ==================== OPERATOR PROFILE ====================

  Future<Map<String, dynamic>?> getOperatorProfile() async {
    if (!isAuthenticated) return null;
    try {
      final response = await _client!
          .from('operators')
          .select()
          .eq('id', currentUserId!)
          .maybeSingle();
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('[Supabase] Get profile error: $e');
      return null;
    }
  }

  Future<void> updateOperatorProfile(Map<String, dynamic> data) async {
    if (!isAuthenticated) return;
    await _client!
        .from('operators')
        .update(data)
        .eq('id', currentUserId!);
  }

  // ==================== STORAGE ====================

  /// Uploads a package photo to the `package-photos` bucket under the
  /// operator's own folder (`{operatorId}/{packageId}.jpg`) and returns the
  /// public URL. `uploadBinary` works on both web and mobile. Throws on
  /// failure so the caller can fall back to the local path.
  Future<String> uploadPackagePhoto({
    required String operatorId,
    required String packageId,
    required Uint8List bytes,
  }) async {
    final path = '$operatorId/$packageId.jpg';
    await _client!.storage.from('package-photos').uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _client!.storage.from('package-photos').getPublicUrl(path);
  }
}
