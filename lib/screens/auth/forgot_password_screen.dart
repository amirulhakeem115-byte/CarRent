import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/company_settings_provider.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/app_logo.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _loading = false;
  String? _error;
  String? _successMessage;

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await _authService.resetPassword(_emailController.text.trim());
      setState(() {
        _successMessage = 'A password reset link has been sent to your email.';
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg.startsWith('Exception: ') ? msg.substring(11) : msg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Widget _buildBrandLogo(BuildContext context, {required bool isOnDark}) {
    final companyName = context.watch<CompanySettingsProvider>().companyName;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppLogo(size: 36, fallbackColor: AppColors.primaryOrange),
        const SizedBox(width: 10),
        Text(
          companyName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: isOnDark ? Colors.white : AppColors.secondaryBlue,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumIllustration() {
    return Container(
      height: 180,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Icon(Icons.send_rounded, size: 24, color: AppColors.primaryOrange.withValues(alpha: 0.8)),
          ),
          Positioned(
            bottom: 15,
            left: 15,
            child: Icon(Icons.mail_outline_rounded, size: 28, color: AppColors.primaryOrange.withValues(alpha: 0.5)),
          ),
          const Icon(
            Icons.lock_reset_rounded,
            size: 72,
            color: AppColors.primaryOrange,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    Widget formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBrandLogo(context, isOnDark: isDark),
          const SizedBox(height: 24),
          _buildPremiumIllustration(),
          const SizedBox(height: 24),
          Text(
            'Forgot Password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "No worries! Enter your email address and we'll send you a link to reset your password.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.lightText,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          // Email label and field
          Text(
            '   Email Address',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          CustomTextField(
            controller: _emailController,
            labelText: '',
            hintText: 'Enter your email address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Error Message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Success Message
          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Text(
                _successMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Send Reset Link Button
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              onPressed: _loading ? null : _resetPassword,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Send Reset Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Back to Login Link
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.primaryOrange),
            label: const Text(
              'Back to Login',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          
          // Bottom Graphics & Copyright
          _buildBottomGraphic(context, isDark),
          const SizedBox(height: 16),
          Text(
            '© 2026 ${context.watch<CompanySettingsProvider>().companyName}. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF64748B) : Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.secondaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 60 : 24,
            vertical: isDesktop ? 40 : 20,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: formContent,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGraphic(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      child: Opacity(
        opacity: isDark ? 0.3 : 0.15,
        child: Icon(
          Icons.location_city_rounded,
          size: 80,
          color: isDark ? Colors.white : AppColors.secondaryBlue,
        ),
      ),
    );
  }
}
