import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui-system/colors.dart';
import '../../ui-system/typography.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/components/prava_input.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import 'email_otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _checkingUsername = false;
  bool _usernameAvailable = false;
  bool _loading = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _usernameController.addListener(() {
      _checkUsername(_usernameController.text);
    });

    _emailController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // USERNAME AVAILABILITY CHECK (DEBOUNCED)
  // --------------------------------------------------
  void _checkUsername(String value) {
    _debounce?.cancel();

    final username = value.trim();

    if (username.length < 3) {
      setState(() {
        _usernameAvailable = false;
        _checkingUsername = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _checkingUsername = true);

      // 🔐 BACKEND PLACEHOLDER
      await Future.delayed(const Duration(milliseconds: 700));

      const reserved = ['admin', 'support', 'prava'];
      final available = !reserved.contains(username.toLowerCase());

      if (!mounted) return;

      setState(() {
        _usernameAvailable = available;
        _checkingUsername = false;
      });
    });
  }

  bool get _canSendOtp =>
      _usernameAvailable &&
      _emailController.text.trim().isNotEmpty &&
      !_loading;

  // --------------------------------------------------
  // SEND OTP
  // --------------------------------------------------
  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _loading = true);

    final email = '${_emailController.text.trim()}@gmail.com';

    // 🔐 BACKEND PLACEHOLDER
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _loading = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmailOtpScreen(email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final secondaryText = isDark
        ? PravaColors.darkTextSecondary
        : PravaColors.lightTextSecondary;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 🏷 TITLE
                    Text(
                      "Create your account",
                      style: PravaTypography.h1.copyWith(
                        letterSpacing: -0.6,
                        color: isDark
                            ? PravaColors.darkTextPrimary
                            : PravaColors.lightTextPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Choose a unique username and verify your email",
                      style: PravaTypography.body.copyWith(
                        color: secondaryText,
                      ),
                    ),

                    const SizedBox(height: 40),

                    /// 👤 USERNAME ROW (@ fixed visually)
                    Row(
                      children: [
                        Text(
                          "@",
                          style: PravaTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: PravaInput(
                            hint: "username",
                            controller: _usernameController,
                            suffixIcon: _checkingUsername
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : _usernameController.text.isEmpty
                                    ? null
                                    : Icon(
                                        _usernameAvailable
                                            ? Icons.check_circle_outline
                                            : Icons.error_outline,
                                        size: 18,
                                        color: _usernameAvailable
                                            ? PravaColors.success
                                            : PravaColors.error,
                                      ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// ✉️ EMAIL (gmail only)
                    PravaInput(
                      hint: "email",
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          "@gmail.com",
                          style: PravaTypography.body.copyWith(
                            color: secondaryText,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    /// 🚀 SEND OTP
                    PravaButton(
                      label: "Send OTP",
                      loading: _loading,
                      onPressed: _canSendOtp ? _sendOtp : null,
                    ),

                    const SizedBox(height: 24),

                    /// 🔁 BACK
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          "Back to sign in",
                          style: PravaTypography.body.copyWith(
                            color: PravaColors.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
