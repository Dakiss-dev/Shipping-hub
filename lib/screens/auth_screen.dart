import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import 'verify_email_screen.dart';

/// Redesigned auth screen — inspired by Stripe's clean, confidence-building signup.
/// Key UX decisions:
///  - Sign Up is the default (new users are the priority)
///  - Business name is collected up-front (progressive profiling step 1)
///  - Password requirements shown inline (not after failure)
///  - Social proof ("Trusted by diaspora operators worldwide")
///  - "Use Offline" is visible but secondary
class AuthScreen extends StatefulWidget {
  /// If true, show sign-up mode first; if false, show sign-in.
  final bool startWithSignUp;
  /// Called when auth completes successfully (signup or signin).
  final VoidCallback? onAuthComplete;

  const AuthScreen({
    super.key,
    this.startWithSignUp = true,
    this.onAuthComplete,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late bool _isSignUp;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _showVerification = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();
  String? _errorMessage;
  String? _successMessage;

  // Password strength
  bool get _hasMinLength => _passwordController.text.length >= 6;
  bool get _hasUpperCase =>
      _passwordController.text.contains(RegExp(r'[A-Z]'));

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.startWithSignUp;
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final provider = context.read<AppProvider>();
    String? error;

    if (_isSignUp) {
      error = await provider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        businessName: _businessNameController.text.trim().isNotEmpty
            ? _businessNameController.text.trim()
            : null,
      );
    } else {
      error = await provider.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = _parseError(error!));
    } else {
      // Check if email needs verification (signup flow)
      final prov = context.read<AppProvider>();
      if (_isSignUp && !prov.isEmailConfirmed) {
        // Show verification screen
        setState(() => _showVerification = true);
      } else {
        // Fully authenticated — proceed
        if (widget.onAuthComplete != null) {
          widget.onAuthComplete!();
        } else {
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    final provider = context.read<AppProvider>();
    final success = await provider.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (success) {
      // Google users are auto-confirmed — skip verification
      if (widget.onAuthComplete != null) {
        widget.onAuthComplete!();
      } else {
        Navigator.pop(context);
      }
    }
    // If not success, the OAuth popup was likely cancelled — no error needed
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() =>
          _errorMessage = 'Enter your email above, then tap Forgot Password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final provider = context.read<AppProvider>();
    final error = await provider.resetPassword(email);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (error != null) {
        _errorMessage = error;
      } else {
        _successMessage = 'Password reset link sent to $email';
      }
    });
  }

  String _parseError(String error) {
    if (error.contains('invalid_credentials') ||
        error.contains('Invalid login')) {
      return 'Invalid email or password. Please try again.';
    }
    if (error.contains('email_exists') ||
        error.contains('already registered')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (error.contains('weak_password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (error.contains('invalid_email')) {
      return 'Please enter a valid email address.';
    }
    if (error.contains('not configured')) {
      return 'Cloud sync is not configured yet.';
    }
    if (error.contains('Email not confirmed')) {
      return 'Please check your email and confirm your account, then sign in.';
    }
    return error.length > 120 ? '${error.substring(0, 120)}...' : error;
  }

  @override
  Widget build(BuildContext context) {
    // Show verification screen if needed
    if (_showVerification) {
      return VerifyEmailScreen(
        email: _emailController.text.trim(),
        onVerified: () {
          // Email confirmed — proceed to next step
          if (widget.onAuthComplete != null) {
            widget.onAuthComplete!();
          } else {
            Navigator.pop(context);
          }
        },
        onChangeAccount: () async {
          // Sign out and go back to auth form
          final provider = context.read<AppProvider>();
          await provider.signOut();
          setState(() {
            _showVerification = false;
            _emailController.clear();
            _passwordController.clear();
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Logo + brand
                _buildLogo(),
                const SizedBox(height: 8),

                // Social proof (Shopify pattern)
                Text(
                  'Trusted by diaspora shipping operators',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 28),

                // Tab switcher (Sign Up / Sign In)
                _buildTabSwitcher(),
                const SizedBox(height: 20),

                // Form card
                _buildFormCard(),
                const SizedBox(height: 16),

                // Use offline (secondary action)
                TextButton.icon(
                  onPressed: () {
                    if (widget.onAuthComplete != null) {
                      widget.onAuthComplete!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 18,
                  ),
                  label: Text(
                    'Continue without account',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping_rounded,
            color: AppColors.navy,
            size: 38,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Shipping Hub',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// Pill-style tab switcher (inspired by Notion's clean toggle)
  Widget _buildTabSwitcher() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton('Create Account',
                isActive: _isSignUp,
                onTap: () {
                  setState(() {
                    _isSignUp = true;
                    _errorMessage = null;
                    _successMessage = null;
                  });
                }),
          ),
          Expanded(
            child: _tabButton('Sign In',
                isActive: !_isSignUp,
                onTap: () {
                  setState(() {
                    _isSignUp = false;
                    _errorMessage = null;
                    _successMessage = null;
                  });
                }),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label,
      {required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? AppColors.navy
                : Colors.white.withValues(alpha: 0.5),
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Business name (sign-up only)
            if (_isSignUp) ...[
              _buildField(
                controller: _businessNameController,
                label: 'Business Name',
                hint: 'e.g., SD Express, Afrik Cargo',
                icon: Icons.store_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
            ],

            // Email
            _buildField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password
            _buildField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),

            // Password strength indicators (sign-up only — inline guidance)
            if (_isSignUp && _passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _strengthChip('6+ chars', _hasMinLength),
                  const SizedBox(width: 8),
                  _strengthChip('Uppercase', _hasUpperCase),
                ],
              ),
            ],

            // Forgot password (sign-in only)
            if (!_isSignUp) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _forgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _messageBox(
                _errorMessage!,
                icon: Icons.error_outline_rounded,
                color: AppColors.danger,
              ),
            ],

            // Success message
            if (_successMessage != null) ...[
              const SizedBox(height: 14),
              _messageBox(
                _successMessage!,
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
            ],

            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.navy.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isSignUp
                                ? Icons.arrow_forward_rounded
                                : Icons.login_rounded,
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),

            // Divider with "or"
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 18),

            // Google Sign-In button
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: Colors.white,
                ),
                child: _isGoogleLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google "G" logo using text (no image dependency)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'G',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Security badge (builds trust — Stripe pattern)
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded,
                    size: 13,
                    color:
                        AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  'Secured with end-to-end encryption',
                  style: TextStyle(
                    color:
                        AppColors.textSecondary.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _strengthChip(String label, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? AppColors.success.withValues(alpha: 0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: met
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: met ? AppColors.success : Colors.grey.shade400,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: met ? AppColors.success : Colors.grey.shade500,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBox(String message,
      {required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
