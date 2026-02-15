import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

/// Beautiful email verification pending screen.
/// Inspired by Linear/Notion: clean, animated, non-stressful.
///
/// Uses TWO detection strategies:
///  1. Supabase onAuthStateChange listener — fires instantly when the user
///     clicks the verification link in the SAME browser (Supabase magic link
///     redirects back and refreshes the session).
///  2. Polling fallback (every 4s) — catches the case where the user verifies
///     in a DIFFERENT tab/browser/device.
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;
  final VoidCallback onChangeAccount;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onVerified,
    required this.onChangeAccount,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollingTimer;
  StreamSubscription<AuthState>? _authSubscription;
  bool _resending = false;
  bool _resent = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  late AnimationController _pulseController;
  bool _verified = false; // guard against double-fire

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Strategy 1: Listen to Supabase auth state changes
    // This fires when the confirmation link redirects back to the app
    _listenAuthState();

    // Strategy 2: Poll for confirmation every 4 seconds as a fallback
    // Handles the case where user clicks in another tab/device
    _startPolling();
  }

  void _listenAuthState() {
    try {
      final supabase = Supabase.instance.client;
      _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;

        // If the user's session is refreshed or signed in, check confirmation
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.userUpdated) {
          if (session?.user.emailConfirmedAt != null && !_verified) {
            _onVerified();
          }
        }
      });
    } catch (_) {
      // Supabase not initialized — rely on polling only
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_verified) return;
      final provider = context.read<AppProvider>();
      final confirmed = await provider.checkEmailConfirmation();
      if (confirmed && mounted && !_verified) {
        _onVerified();
      }
    });
  }

  void _onVerified() {
    if (_verified) return; // prevent double-fire
    _verified = true;
    _pollingTimer?.cancel();
    _authSubscription?.cancel();

    // Small celebration haptic
    HapticFeedback.mediumImpact();

    // Brief success animation before proceeding
    if (mounted) {
      setState(() {});
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onVerified();
      });
    }
  }

  Future<void> _resendEmail() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _resending = true;
      _resent = false;
    });

    final provider = context.read<AppProvider>();
    final error = await provider.resendConfirmation(widget.email);

    if (!mounted) return;

    setState(() {
      _resending = false;
      _resent = error == null;
      _resendCooldown = 60;
    });

    // Start cooldown timer
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel();
          _resent = false;
        }
      });
    });

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    _authSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated email icon (or success checkmark)
                _verified ? _buildSuccessIcon() : _buildAnimatedIcon(),
                const SizedBox(height: 36),

                // Title
                Text(
                  _verified ? 'Email verified!' : 'Check your email',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle with email
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: _verified
                            ? 'Welcome aboard! Redirecting you now...'
                            : 'We sent a verification link to\n',
                      ),
                      if (!_verified)
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),

                if (!_verified) ...[
                  const SizedBox(height: 28),

                  // PROMINENT spam/junk warning — #1 user complaint
                  _buildSpamWarning(),
                  const SizedBox(height: 20),

                  // Status card
                  _buildStatusCard(),
                  const SizedBox(height: 24),

                  // Resend button
                  _buildResendButton(),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Change account
                  TextButton(
                    onPressed: widget.onChangeAccount,
                    child: Text(
                      'Use a different account',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Additional email tips
                  _buildEmailTips(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        final glow = 0.2 + (_pulseController.value * 0.15);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: glow),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: AppColors.navy,
                  size: 40,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Big, unmissable spam-folder warning — the #1 pain point
  Widget _buildSpamWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF9800),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check your Spam / Junk folder!',
                  style: TextStyle(
                    color: Color(0xFFFF9800),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verification emails often land in spam. If you find it there, tap the link and mark it "Not Spam" to get future emails in your inbox.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Waiting indicator
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.gold.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Waiting for verification...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Click the link in the email. This page updates automatically — no need to come back here manually.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendButton() {
    if (_resent && _resendCooldown > 0) {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text(
              'Email sent! Resend in ${_resendCooldown}s',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _resending || _resendCooldown > 0 ? null : _resendEmail,
        icon: _resending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.refresh_rounded, size: 18),
        label: Text(
          _resendCooldown > 0
              ? 'Resend in ${_resendCooldown}s'
              : 'Resend verification email',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailTips() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Still nothing?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _tipRow(Icons.schedule_rounded, 'Wait 1-2 min, then resend'),
          _tipRow(Icons.alternate_email_rounded,
              'Verify that ${widget.email} is correct'),
          _tipRow(Icons.search_rounded,
              'Search your inbox for "Shipping Hub" or "verify"'),
          _tipRow(Icons.devices_other_rounded,
              'You can click the link on any device or tab'),
        ],
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 14, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
