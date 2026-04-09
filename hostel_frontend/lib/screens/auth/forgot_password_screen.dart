import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api_calls.dart';
import '../../theme.dart';

enum ForgotPasswordStep { email, otp, reset }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  ForgotPasswordStep _currentStep = ForgotPasswordStep.email;
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMsg;
  String? _generatedOtp;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Step 1: Generate OTP on frontend and ask backend to send it via email
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = "Please enter a valid email address");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // Generate 6-digit OTP
    final random = Random();
    _generatedOtp = (random.nextInt(900000) + 100000).toString();

    final (success, error) = await ApiManager.sendForgotPasswordOtp(
      email,
      _generatedOtp!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      setState(() => _currentStep = ForgotPasswordStep.otp);
    } else {
      setState(() => _errorMsg = error ?? "Failed to send OTP");
    }
  }

  // Step 2: Verify OTP locally (frontend only verification as per request)
  void _verifyOtp() {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp == _generatedOtp) {
      setState(() {
        _currentStep = ForgotPasswordStep.reset;
        _errorMsg = null;
      });
    } else {
      setState(() => _errorMsg = "Invalid OTP. Please try again.");
    }
  }

  // Step 3: Call backend to finalize password reset
  Future<void> _resetPassword() async {
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (pass.length < 8) {
      setState(() => _errorMsg = "Password must be at least 8 characters");
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMsg = "Passwords do not match");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final (success, error) = await ApiManager.resetPassword(
      _emailController.text.trim(),
      pass,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Go back to Login
    } else {
      setState(() => _errorMsg = error ?? "Failed to reset password");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0E7FF), Color(0xFFF3E8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 48.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    if (_errorMsg != null) _buildError(),
                    _buildCurrentStep(),
                    const SizedBox(height: 24),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    String subtitle;
    IconData icon;

    switch (_currentStep) {
      case ForgotPasswordStep.email:
        title = "Forgot Password";
        subtitle = "Enter your email to receive an OTP";
        icon = Icons.lock_reset_rounded;
        break;
      case ForgotPasswordStep.otp:
        title = "Verify OTP";
        subtitle = "Enter the 6-digit code sent to your email";
        icon = Icons.mark_email_unread_outlined;
        break;
      case ForgotPasswordStep.reset:
        title = "New Password";
        subtitle = "Create a secure new password";
        icon = Icons.security_rounded;
        break;
    }

    return Column(
      children: [
        Icon(icon, size: 64, color: AppTheme.primaryColor).animate().scale(),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.accentColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMsg!,
              style: const TextStyle(color: AppTheme.accentColor),
            ),
          ),
        ],
      ),
    ).animate().shake();
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case ForgotPasswordStep.email:
        return TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ).animate().fadeIn();
      case ForgotPasswordStep.otp:
        return TextField(
          controller: _otpController,
          decoration: const InputDecoration(
            labelText: '6-Digit OTP',
            prefixIcon: Icon(Icons.pin_outlined),
            labelStyle: TextStyle(wordSpacing: 4),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ).animate().fadeIn();
      case ForgotPasswordStep.reset:
        return Column(
          children: [
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ).animate().fadeIn(),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ).animate().fadeIn(),
          ],
        );
    }
  }

  Widget _buildActions() {
    String label;
    VoidCallback? action;

    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    switch (_currentStep) {
      case ForgotPasswordStep.email:
        label = "Send OTP";
        action = _sendOtp;
        break;
      case ForgotPasswordStep.otp:
        label = "Verify OTP";
        action = _verifyOtp;
        break;
      case ForgotPasswordStep.reset:
        label = "Reset Password";
        action = _resetPassword;
        break;
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: action,
            child: Text(label, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Back to Login',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
        ),
      ],
    );
  }
}
