import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // 👈 for kDebugMode

import '../../ui-system/colors.dart';
import '../../ui-system/typography.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/components/prava_input.dart';
import '../../ui-system/components/prava_password_input.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import '../home/home_shell.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;

  late final AnimationController _lockController;

  @override
  void initState() {
    super.initState();
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.clear();
    _passwordController.clear();
    _emailController.dispose();
    _passwordController.dispose();
    _lockController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      PravaToast.show(
        context,
        message: "Username / email and password are required",
        type: PravaToastType.warning,
      );
      return;
    }

    setState(() => _loading = true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _loading = false);

    PravaToast.show(
      context,
      message: "Welcome back",
      type: PravaToastType.success,
    );
  }

  /// 🧪 DEV MODE LOGIN (DEBUG ONLY)
  void _devLogin() {
    HapticFeedback.selectionClick();

    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(
        builder: (_) => const HomeShell(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryText =
        isDark ? PravaColors.darkTextPrimary : PravaColors.lightTextPrimary;
    final secondaryText =
        isDark ? PravaColors.darkTextSecondary : PravaColors.lightTextSecondary;
    final tertiaryText =
        isDark ? PravaColors.darkTextTertiary : PravaColors.lightTextTertiary;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Stack(
            children: [
              /// ================= CENTER CONTENT =================
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Prava",
                          style: PravaTypography.h1.copyWith(
                            letterSpacing: -0.8,
                            color: primaryText,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Conversations that flow",
                          style: PravaTypography.body.copyWith(
                            color: secondaryText,
                            letterSpacing: 0.2,
                          ),
                        ),

                        const SizedBox(height: 40),

                        PravaInput(
                          hint: "Email or username",
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                        ),

                        const SizedBox(height: 16),

                        PravaPasswordInput(
                          hint: "Password",
                          controller: _passwordController,
                          autofillHints: const [AutofillHints.password],
                        ),

                        const SizedBox(height: 32),

                        PravaButton(
                          label: "Sign In",
                          loading: _loading,
                          onPressed: _loading ? null : _onLogin,
                        ),

                        const SizedBox(height: 24),

                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              style: PravaTypography.body.copyWith(
                                color: secondaryText,
                              ),
                              children: [
                                const TextSpan(text: "New here? "),
                                TextSpan(
                                  text: "Create account",
                                  style: TextStyle(
                                    color: PravaColors.accentPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        /// 🧪 DEV MODE LOGIN (DEBUG ONLY)
                        if (kDebugMode) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: GestureDetector(
                              onTap: _devLogin,
                              child: Text(
                                "Dev login → Home",
                                style: PravaTypography.caption.copyWith(
                                  color: PravaColors.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              /// ================= BOTTOM SECURITY FOOTER =================
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Center(
                  child: FadeTransition(
                    opacity: Tween(begin: 0.35, end: 0.9).animate(
                      CurvedAnimation(
                        parent: _lockController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: tertiaryText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "End-to-end encrypted",
                          style: PravaTypography.caption.copyWith(
                            color: tertiaryText,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
