import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/company_settings_provider.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/app_logo.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  String? _error;

  void _showSocialComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider sign-up is coming soon.'),
        backgroundColor: AppColors.primaryOrange,
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      setState(() {
        _error = 'You must agree to the Terms & Conditions and Privacy Policy';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _error = 'Passwords do not match';
      });
      return;
    }

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      await _authService.register(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim(),
        licenseNumber: "",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account Created Successfully! Please login.'),
          backgroundColor: AppColors.primaryOrange,
        ),
      );

      Navigator.pop(context);
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
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
          if (!isDesktop) ...[
            _buildBrandLogo(context, isOnDark: isDark),
            const SizedBox(height: 16),
          ],
          Text(
            'Create Account',
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Join ${context.watch<CompanySettingsProvider>().companyName} today and start your journey.',
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.lightText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // Full Name & Phone Number side-by-side or stacked
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width > 450) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '   Full Name',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.secondaryBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _fullNameController,
                            labelText: '',
                            hintText: 'Enter your full name',
                            prefixIcon: Icons.person_outline,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Full Name is required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '   Phone Number',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.secondaryBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _phoneController,
                            labelText: '',
                            hintText: 'e.g., +60123456789',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty)
                                return 'Phone Number is required';
                              final cleanVal = val.trim();
                              if (!RegExp(
                                r'^(\+?6?01)[0-46-9]-*[0-9]{7,8}$',
                              ).hasMatch(cleanVal)) {
                                return 'Enter a valid Malaysian phone number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '   Full Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white70
                            : AppColors.secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _fullNameController,
                      labelText: '',
                      hintText: 'Enter your full name',
                      prefixIcon: Icons.person_outline,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Full Name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '   Phone Number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white70
                            : AppColors.secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _phoneController,
                      labelText: '',
                      hintText: 'e.g., +60123456789',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return 'Phone Number is required';
                        final cleanVal = val.trim();
                        if (!RegExp(
                          r'^(\+?6?01)[0-46-9]-*[0-9]{7,8}$',
                        ).hasMatch(cleanVal)) {
                          return 'Enter a valid Malaysian phone number';
                        }
                        return null;
                      },
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // Email Address
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
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val))
                return 'Enter a valid email';
              return null;
            },
          ),

          // Password
          Text(
            '   Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          CustomTextField(
            controller: _passwordController,
            labelText: '',
            hintText: 'Create a password',
            obscureText: _obscurePassword,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: AppColors.primaryOrange,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              if (val.length < 6)
                return 'Password must be at least 6 characters';
              if (!RegExp(
                r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{6,}$',
              ).hasMatch(val)) {
                return 'Password must contain both letters and numbers';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          Text(
            '   Confirm Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          CustomTextField(
            controller: _confirmPasswordController,
            labelText: '',
            hintText: 'Confirm your password',
            obscureText: _obscureConfirmPassword,
            prefixIcon: Icons.lock_clock_outlined,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: AppColors.primaryOrange,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            validator: (val) {
              if (val == null || val.isEmpty)
                return 'Please confirm your password';
              if (val != _passwordController.text)
                return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Terms & Conditions Checkbox
          Row(
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (val) {
                  setState(() {
                    _agreeToTerms = val ?? false;
                  });
                },
                activeColor: AppColors.primaryOrange,
                checkColor: Colors.white,
                side: BorderSide(
                  color: isDark ? Colors.white54 : AppColors.secondaryBlue,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.secondaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      const TextSpan(
                        text: 'Terms & Conditions',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      const TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Error Message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Register Button
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
              onPressed: _loading ? null : _register,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Social sign-up options
          SizedBox(
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                foregroundColor: isDark
                    ? Colors.white
                    : AppColors.secondaryBlue,
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : AppColors.borderGray,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _loading
                  ? null
                  : () => _showSocialComingSoon('Google'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://www.gstatic.com/mobilesdk/160503_mobilesdk/logo/2x/google_g_normal_id_48dp.png',
                    height: 22,
                    width: 22,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata_rounded,
                      color: AppColors.primaryOrange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sign up with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : AppColors.secondaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                foregroundColor: isDark
                    ? Colors.white
                    : AppColors.secondaryBlue,
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : AppColors.borderGray,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _loading
                  ? null
                  : () => _showSocialComingSoon('Facebook'),
              icon: const Icon(
                Icons.facebook,
                color: Color(0xFF1877F2),
                size: 22,
              ),
              label: Text(
                'Sign up with Facebook',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white : AppColors.secondaryBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                foregroundColor: isDark
                    ? Colors.white
                    : AppColors.secondaryBlue,
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : AppColors.borderGray,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _loading
                  ? null
                  : () => _showSocialComingSoon('Twitter (X)'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    child: Text(
                      'X',
                      style: TextStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sign up with Twitter (X)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : AppColors.secondaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Already have account Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account? ",
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(onLoggedIn: () {}),
                    ),
                  );
                },
                child: const Text(
                  'Login',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.secondaryBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: isDesktop
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0B1220), const Color(0xFF111827)]
                      : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : null,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 40 : 24,
            vertical: isDesktop ? 32 : 20,
          ),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 550),
              padding: isDesktop ? const EdgeInsets.all(28) : EdgeInsets.zero,
              decoration: isDesktop
                  ? BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.borderGray,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.22 : 0.08,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    )
                  : null,
              child: formContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGraphic(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 54,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: isDark ? 0.3 : 0.15,
            child: Icon(
              Icons.location_city_rounded,
              size: 80,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}
