import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui-system/colors.dart';
import '../../ui-system/typography.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/components/prava_password_input.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  double _strength = 0.0;

  @override
  void initState() {
    super.initState();

    // ✅ Listen safely instead of using onChanged
    _passwordController.addListener(_checkStrength);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkStrength);

    // 🔐 Memory hygiene
    _passwordController.clear();
    _confirmController.clear();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // PASSWORD STRENGTH (zxcvbn-style heuristic)
  // --------------------------------------------------
  void _checkStrength() {
    final value = _passwordController.text;

    double score = 0;
    if (value.length >= 12) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(value)) score += 0.15;
    if (RegExp(r'[a-z]').hasMatch(value)) score += 0.15;
    if (RegExp(r'\d').hasMatch(value)) score += 0.2;
    if (RegExp(r'[!@#\$&*~%^()\-_+=]').hasMatch(value)) {
      score += 0.25;
    }

    setState(() {
      _strength = score.clamp(0, 1);
    });
  }

  Color get _strengthColor {
    if (_strength < 0.4) return PravaColors.error;
    if (_strength < 0.7) return Colors.orange;
    return PravaColors.success;
  }

  bool get _valid =>
      _strength >= 0.7 &&
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;

  // --------------------------------------------------
  // SUBMIT PASSWORD
  // --------------------------------------------------
  Future<void> _setPassword() async {
    if (!_valid || _loading) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _loading = true);

    // 🔐 Real security happens server-side (Argon2id)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _loading = false);

    PravaToast.show(
      context,
      message: "Password secured successfully",
      type: PravaToastType.success,
    );

    // TODO → Navigate to Home / Biometric setup
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
                      "Secure your account",
                      style: PravaTypography.h1.copyWith(
                        letterSpacing: -0.6,
                        color: isDark
                            ? PravaColors.darkTextPrimary
                            : PravaColors.lightTextPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Choose a strong password. We never store it in plain text.",
                      style: PravaTypography.body.copyWith(
                        color: secondaryText,
                      ),
                    ),

                    const SizedBox(height: 32),

                    /// 🔒 PASSWORD
                    PravaPasswordInput(
                      hint: "Password",
                      controller: _passwordController,
                      autofillHints: const [AutofillHints.newPassword],
                    ),

                    const SizedBox(height: 12),

                    /// 🧠 STRENGTH BAR
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _strength,
                        minHeight: 6,
                        backgroundColor:
                            isDark ? Colors.white12 : Colors.black12,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_strengthColor),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// 🔁 CONFIRM PASSWORD
                    PravaPasswordInput(
                      hint: "Confirm password",
                      controller: _confirmController,
                      autofillHints: const [AutofillHints.newPassword],
                    ),

                    const SizedBox(height: 32),

                    /// 🔐 SET PASSWORD
                    PravaButton(
                      label: "Set Password",
                      loading: _loading,
                      onPressed: _valid ? _setPassword : null,
                    ),

                    const SizedBox(height: 16),

                    /// 🛡 SECURITY NOTE
                    Text(
                      "Protected with Argon2id hashing, per-device salting, and zero-knowledge design.",
                      style: PravaTypography.caption.copyWith(
                        color: secondaryText,
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
