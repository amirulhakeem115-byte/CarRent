import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/company_settings_provider.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/app_logo.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'customer/customer_responsive_shell.dart';
import 'admin/dashboard_screen.dart';
import '../../services/booking_lifecycle_manager.dart';
import '../../services/user_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required Null Function() onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _error;

  List<String> _recentEmails = [];

  @override
  void initState() {
    super.initState();
    _loadSavedEmails();
  }

  Future<void> _loadSavedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString('last_login_email') ?? '';
    final list = prefs.getStringList('recent_login_emails') ?? [];
    if (mounted) {
      setState(() {
        _recentEmails = list;
        if (lastEmail.isNotEmpty && _emailController.text.isEmpty) {
          _emailController.text = lastEmail;
        }
      });
    }
  }

  Future<void> _deleteEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentEmails.remove(email);
    });
    await prefs.setStringList('recent_login_emails', _recentEmails);

    final lastEmail = prefs.getString('last_login_email') ?? '';
    if (lastEmail == email) {
      await prefs.remove('last_login_email');
    }

    if (_recentEmails.isEmpty) {
      setState(() {});
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userCreds = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCreds.user!.uid;
      final userModel = await _databaseService.getUser(uid);
      if (userModel != null) {
        UserSession().forceSetRole(userModel.role);
      }
      if (!mounted) return;

      if (userModel == null) {
        setState(() {
          _error = 'User profile not found. Please contact support.';
          _loading = false;
        });
        return;
      }

      if (!userModel.isActive) {
        setState(() {
          _error =
              'Your account has been disabled or suspended. Please contact support.';
          _loading = false;
        });
        await _authService.logout();
        return;
      }

      // Save email locally
      final String enteredEmail = _emailController.text.trim();
      if (enteredEmail.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_login_email', enteredEmail);

        final List<String> list =
            prefs.getStringList('recent_login_emails') ?? [];
        list.remove(enteredEmail);
        list.insert(0, enteredEmail);
        if (list.length > 5) {
          list.removeRange(5, list.length);
        }
        await prefs.setStringList('recent_login_emails', list);
      }

      if (!mounted) return;

      // Trigger booking lifecycle check on login
      await BookingLifecycleManager().checkAndProcessLifecycle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${userModel.fullName}!'),
          backgroundColor: AppColors.primaryOrange,
        ),
      );

      // Route based on role
      if (userModel.role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerResponsiveShell(),
          ),
        );
      }
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

  Future<void> _loginWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final userCreds = await _authService.signInWithGoogle();

      final uid = userCreds.user!.uid;
      final userModel = await _databaseService.getUser(uid);
      if (userModel != null) {
        UserSession().forceSetRole(userModel.role);
      }
      if (!mounted) return;

      if (userModel == null) {
        setState(() {
          _error = 'Failed to load user profile. Please contact support.';
          _googleLoading = false;
        });
        return;
      }

      if (!userModel.isActive) {
        setState(() {
          _error =
              'Your account has been disabled or suspended. Please contact support.';
          _googleLoading = false;
        });
        await _authService.logout();
        return;
      }

      // Trigger booking lifecycle check on login
      await BookingLifecycleManager().checkAndProcessLifecycle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${userModel.fullName}!'),
          backgroundColor: AppColors.primaryOrange,
        ),
      );

      // Route based on role
      if (userModel.role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerResponsiveShell(),
          ),
        );
      }
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg.startsWith('Exception: ') ? msg.substring(11) : msg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _googleLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildBrandLogo(BuildContext context, {required bool isOnDark}) {
    final companyName = context.watch<CompanySettingsProvider>().companyName;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppLogo(size: 40, fallbackColor: AppColors.primaryOrange),
        const SizedBox(width: 12),
        Text(
          companyName,
          style: TextStyle(
            fontSize: 26,
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
          Text(
            'Welcome Back!',
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to continue to your account',
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.lightText,
              fontWeight: FontWeight.w500,
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
            hintText: 'Enter your email',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          if (_recentEmails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent accounts',
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.lightText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentEmails.map((email) {
                final bool isSelected = _emailController.text.trim() == email;
                return InputChip(
                  label: Text(email),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _emailController.text = email;
                    });
                  },
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _deleteEmail(email),
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  selectedColor: AppColors.primaryOrange.withValues(
                    alpha: 0.15,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : (isDark
                              ? const Color(0xFF334155)
                              : Colors.grey[300]!),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : (isDark ? Colors.white70 : AppColors.secondaryBlue),
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),

          // Password label and field
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
            hintText: 'Enter your password',
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
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Forgot Password / Remember me Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (val) {
                      setState(() {
                        _rememberMe = val ?? false;
                      });
                    },
                    activeColor: AppColors.primaryOrange,
                    checkColor: Colors.white,
                    side: BorderSide(
                      color: isDark ? Colors.white54 : AppColors.secondaryBlue,
                    ),
                  ),
                  Text(
                    'Remember Me',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.secondaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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

          // Login Button
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
              onPressed: (_loading || _googleLoading) ? null : _login,
              icon: const Icon(Icons.login_rounded, size: 20),
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
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDark
                      ? const Color(0xFF334155)
                      : AppColors.borderGray,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR CONTINUE WITH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF64748B) : Colors.grey[500],
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isDark
                      ? const Color(0xFF334155)
                      : AppColors.borderGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Google Sign In Button
          SizedBox(
            height: 54,
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
                elevation: isDark ? 0 : 1,
              ),
              onPressed: (_loading || _googleLoading) ? null : _loginWithGoogle,
              child: _googleLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryOrange,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://www.gstatic.com/mobilesdk/160503_mobilesdk/logo/2x/google_g_normal_id_48dp.png',
                          height: 24,
                          width: 24,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.g_mobiledata_rounded,
                                color: AppColors.primaryOrange,
                                size: 28,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark
                                ? Colors.white
                                : AppColors.secondaryBlue,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 32),

          // Register Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Register',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Copyright
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
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const RegisterScreen()),
            );
          },
        ),
      ),
      body: isDesktop
          ? Row(
              children: [
                // Left half: Branding
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.secondaryBlue, Color(0xFF0F172A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildBrandLogo(context, isOnDark: true),
                            const SizedBox(height: 8),
                            const Text(
                              'Drive Your Journey',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Security / minimal premium illustration in vector-style
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                size: 120,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Right half: Login Form
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 60,
                        vertical: 40,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: formContent,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Curved Top Banner
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipPath(
                        clipper: HeaderCurveClipper(),
                        child: Container(
                          height: 240,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.secondaryBlue,
                                Color(0xFF0F172A),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildBrandLogo(context, isOnDark: true),
                                const SizedBox(height: 4),
                                const Text(
                                  'Drive Your Journey',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                              border: isDark
                                  ? Border.all(
                                      color: const Color(0xFF334155),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 40,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: formContent,
                  ),
                ],
              ),
            ),
    );
  }
}

class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 10,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
