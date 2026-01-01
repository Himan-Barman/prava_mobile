import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui-system/colors.dart';
import '../../ui-system/typography.dart';
import '../../ui-system/components/prava_button.dart';
import '../../ui-system/feedback/prava_toast.dart';
import '../../ui-system/feedback/toast_type.dart';
import 'set_password_screen.dart';

class EmailOtpScreen extends StatefulWidget {
  final String email;

  const EmailOtpScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());

  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.clear();
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  // --------------------------
  // TIMER
  // --------------------------
  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  // --------------------------
  // OTP HANDLING
  // --------------------------
  void _onChanged(String value, int index) {
    if (value.length > 1) {
      // Paste-aware
      final chars = value.split('');
      for (int i = 0; i < chars.length && i < 6; i++) {
        _controllers[i].text = chars[i];
      }
      _nodes.last.requestFocus();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
  }

  String get _otp =>
      _controllers.map((c) => c.text).join();

  bool get _complete =>
      _otp.length == 6 && !_otp.contains('');

  // --------------------------
  // VERIFY OTP
  // --------------------------
  Future<void> _verifyOtp() async {
    if (!_complete || _loading) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _loading = true);

    // 🔐 BACKEND FLOW (placeholder)
    // POST /auth/verify-otp
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _loading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const SetPasswordScreen(),
      ),
    );
  }

  // --------------------------
  // RESEND OTP
  // --------------------------
  Future<void> _resendOtp() async {
    HapticFeedback.selectionClick();
    _startTimer();

    PravaToast.show(
      context,
      message: "OTP sent again to ${widget.email}",
      type: PravaToastType.info,
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
                      "Verify your email",
                      style: PravaTypography.h1.copyWith(
                        letterSpacing: -0.6,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Enter the 6-digit code sent to ${widget.email}",
                      style: PravaTypography.body.copyWith(
                        color: secondaryText,
                      ),
                    ),

                    const SizedBox(height: 32),

                    /// 🔢 OTP INPUTS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        return SizedBox(
                          width: 48,
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _nodes[i],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: PravaTypography.h2,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              counterText: "",
                            ),
                            onChanged: (v) => _onChanged(v, i),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 32),

                    /// ✅ VERIFY
                    PravaButton(
                      label: "Verify",
                      loading: _loading,
                      onPressed: _complete ? _verifyOtp : null,
                    ),

                    const SizedBox(height: 16),

                    /// 🔁 RESEND
                    Center(
                      child: _secondsLeft > 0
                          ? Text(
                              "Resend in $_secondsLeft s",
                              style: PravaTypography.caption.copyWith(
                                color: secondaryText,
                              ),
                            )
                          : GestureDetector(
                              onTap: _resendOtp,
                              child: Text(
                                "Resend OTP",
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
