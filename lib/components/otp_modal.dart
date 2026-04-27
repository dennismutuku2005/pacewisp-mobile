import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../theme/colors.dart';
import '../services/api_service.dart';

class OtpModal extends StatefulWidget {
  final String phoneNumber;
  final String? actionType;
  final Function(String code) onVerify;
  final VoidCallback? onResend;
  final bool isLoading;

  const OtpModal({
    super.key,
    required this.phoneNumber,
    this.actionType,
    required this.onVerify,
    this.onResend,
    this.isLoading = false,
  });

  @override
  State<OtpModal> createState() => _OtpModalState();
}

class _OtpModalState extends State<OtpModal> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  int _timer = 0;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    // Start focusing first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    setState(() => _timer = 60);
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timer == 0) {
        t.cancel();
      } else {
        setState(() => _timer--);
      }
    });
  }

  void _onInput(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    
    // Check if full OTP is entered
    String code = _controllers.map((c) => c.text).join();
    if (code.length == 6) {
      widget.onVerify(code);
    }
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: 32,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: PaceColors.getBackground(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: PaceColors.getBorder(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PaceColors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: PaceColors.purple, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'TWO-STEP VERIFICATION',
            style: GoogleFonts.figtree(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: PaceColors.purple,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Verify your identity via WhatsApp code sent to ${widget.phoneNumber.length >= 9 ? widget.phoneNumber.replaceRange(4, 9, '****') : widget.phoneNumber}",
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(
              fontSize: 10,
              color: PaceColors.getDimText(isDark),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) => _buildOtpField(index, isDark)),
          ),
          const SizedBox(height: 32),
          if (widget.isLoading)
            const CircularProgressIndicator(color: PaceColors.purple)
          else ...[
            TextButton(
              onPressed: (_timer > 0 || widget.isLoading) ? null : () async {
                if (widget.actionType != null) {
                   final api = ApiService();
                   await api.resendOtp(widget.actionType!);
                }
                _startTimer();
                widget.onResend?.call();
              },
              child: Text(
                _timer > 0 ? "RESEND IN ${_timer}S" : "DIDN'T RECEIVE CODE? RESEND",
                style: GoogleFonts.figtree(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: (_timer > 0 || widget.isLoading) ? PaceColors.getDimText(isDark) : PaceColors.purple,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                   String code = _controllers.map((c) => c.text).join();
                   if (code.length == 6) widget.onVerify(code);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'VERIFY IDENTITY',
                  style: GoogleFonts.figtree(fontWeight: FontWeight.w600, letterSpacing: 1.5, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpField(int index, bool isDark) {
    return Container(
      width: 45,
      height: 56,
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focusNodes[index].hasFocus ? PaceColors.purple : PaceColors.getBorder(isDark),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: PaceColors.purple,
        ),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) => _onInput(index, v),
      ),
    );
  }
}
