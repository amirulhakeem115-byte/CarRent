import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../l10n/app_translations.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/company_settings_provider.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/app_logo.dart';
import '../home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'customer/customer_responsive_shell.dart';
import 'admin/dashboard_screen.dart';
import 'employee/employee_dashboard_screen.dart';
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
  final _emailFocusNode = FocusNode();

  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _error;

  List<String> _recentEmails = [];
  bool _showEmailSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmails();
  }

  bool _isValidStoredEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    if (email.contains('*')) return false;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _loadSavedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString('last_login_email') ?? '';
    final storedList = prefs.getStringList('recent_login_emails') ?? [];
    final normalized = storedList
        .map((e) => e.trim().toLowerCase())
        .where(_isValidStoredEmail)
        .toSet()
        .toList();

    if (normalized.length != storedList.length) {
      await prefs.setStringList('recent_login_emails', normalized);
    }

    if (mounted) {
      setState(() {
        _recentEmails = List<String>.from(normalized);
        if (lastEmail.isNotEmpty && _emailController.text.isEmpty) {
          _emailController.text = lastEmail;
        }
      });
    }
  }

  Future<void> _deleteEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final updatedEmails = _recentEmails.where((e) => e != email).toList();

    setState(() {
      _recentEmails = updatedEmails;
      _showEmailSuggestions = true;
    });
    await prefs.setStringList('recent_login_emails', updatedEmails);

    final lastEmail = prefs.getString('last_login_email') ?? '';
    if (lastEmail == email) {
      await prefs.remove('last_login_email');
      if (_emailController.text.trim().toLowerCase() == email.toLowerCase()) {
        setState(() {
          _emailController.clear();
        });
      }
    }
  }

  String _maskEmailForDisplay(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final local = parts[0];
    final domain = parts[1];

    if (local.isEmpty) return '***@$domain';
    if (local.length == 1) return '${local[0]}***@$domain';
    if (local.length == 2) return '${local[0]}*@$domain';

    return '${local.substring(0, 2)}***@$domain';
  }

  void _selectEmail(String email) {
    if (!_isValidStoredEmail(email)) {
      return;
    }

    final current = _emailController.text.trim();
    if (current.isEmpty) {
      _emailController.value = TextEditingValue(
        text: email,
        selection: TextSelection.collapsed(offset: email.length),
      );
    }

    setState(() {
      _showEmailSuggestions = false;
      _error = null;
    });
    FocusScope.of(context).requestFocus(_emailFocusNode);
  }

  // Closes only the suggestions dropdown.
  void _closeSuggestions() {
    setState(() {
      _showEmailSuggestions = false;
      _error = null;
    });
  }

  Future<void> _clearRememberedAccounts() async {
    setState(() {
      _recentEmails = [];
      _showEmailSuggestions = true;
      _emailController.clear();
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_login_emails', <String>[]);
    await prefs.remove('recent_login_emails');
    await prefs.remove('last_login_email');

    if (!mounted) return;
    FocusScope.of(context).requestFocus(_emailFocusNode);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _showEmailSuggestions = false;
    });

    try {
      final userCreds = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCreds.user!.uid;
      final userModel = await _databaseService.getUser(uid);
      if (userModel != null) {
        UserSession().forceSetUser(userModel);
      }
      if (!mounted) return;

      if (userModel == null) {
        setState(() {
          _error = 'User profile not found. Please contact support.'.tr(context);
          _loading = false;
        });
        return;
      }

      final String accountStatus =
          (userModel.toMap()['accountStatus'] ?? 'Active').toString().trim();
      if (accountStatus.toLowerCase() == 'suspended') {
        setState(() {
          _error = 'Your account has been suspended. Please contact support.'.tr(context);
          _loading = false;
        });
        await _authService.logout();
        return;
      }

      if (!userModel.isActive && accountStatus.toLowerCase() != 'disabled') {
        setState(() {
          _error =
              'Your account has been disabled or suspended. Please contact support.'.tr(context);
          _loading = false;
        });
        await _authService.logout();
        return;
      }

      if (accountStatus.toLowerCase() == 'disabled') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your account is disabled. Some features are currently unavailable.'.tr(context),
            ),
            backgroundColor: Colors.orange,
          ),
        );
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
        setState(() {
          _recentEmails = list;
        });
      }

      if (!mounted) return;

      // Trigger booking lifecycle check on login
      await BookingLifecycleManager().checkAndProcessLifecycle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${"Welcome back, ".tr(context)}${userModel.fullName}!'),
          backgroundColor: AppColors.primaryOrange,
        ),
      );

      // Route based on role
      final normalizedRole = userModel.normalizedRole;
      if (normalizedRole == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else if (normalizedRole == 'employee') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const EmployeeDashboardScreen(),
          ),
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
      _showEmailSuggestions = false;
    });

    try {
      final userCreds = await _authService.signInWithGoogle();

      final uid = userCreds.user!.uid;
      final userModel = await _databaseService.getUser(uid);
      if (userModel != null) {
        UserSession().forceSetUser(userModel);
      }
      if (!mounted) return;

      if (userModel == null) {
        setState(() {
          _error = 'Failed to load user profile. Please contact support.'.tr(context);
          _googleLoading = false;
        });
        return;
      }

      final String accountStatus =
          (userModel.toMap()['accountStatus'] ?? 'Active').toString().trim();
      if (accountStatus.toLowerCase() == 'suspended') {
        setState(() {
          _error = 'Your account has been suspended. Please contact support.'.tr(context);
          _googleLoading = false;
        });
        await _authService.logout();
        return;
      }

      if (!userModel.isActive && accountStatus.toLowerCase() != 'disabled') {
        setState(() {
          _error =
              'Your account has been disabled or suspended. Please contact support.'.tr(context);
          _googleLoading = false;
        });
        await _authService.logout();
        return;
      }

      if (accountStatus.toLowerCase() == 'disabled') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your account is disabled. Some features are currently unavailable.'.tr(context),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Trigger booking lifecycle check on login
      await BookingLifecycleManager().checkAndProcessLifecycle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${"Welcome back, ".tr(context)}${userModel.fullName}!'),
          backgroundColor: AppColors.primaryOrange,
        ),
      );

      // Route based on role
      final normalizedRole = userModel.normalizedRole;
      if (normalizedRole == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else if (normalizedRole == 'employee') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const EmployeeDashboardScreen(),
          ),
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
    _emailFocusNode.dispose();
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
            'Welcome Back!'.tr(context),
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to continue to your account'.tr(context),
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
            '   ${"Email Address".tr(context)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              CustomTextField(
                controller: _emailController,
                labelText: '',
                hintText: 'Enter your email'.tr(context),
                prefixIcon: Icons.email_outlined,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                onTap: () {
                  setState(() {
                    _showEmailSuggestions = _recentEmails.isNotEmpty;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    _showEmailSuggestions = false;
                    _error = null;
                  });
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Email is required'.tr(context);
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) {
                    return 'Enter a valid email'.tr(context);
                  }
                  return null;
                },
              ),
              // ✅ UPDATED: Email suggestions dropdown with improved Close button
              if (_showEmailSuggestions)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey[300]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Recent accounts'.tr(context),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white54
                                    : AppColors.lightText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed:
                                  _closeSuggestions, // ✅ UPDATED: Uses new method
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(40, 30),
                              ),
                              child: Text(
                                'Close'.tr(context),
                                style: const TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (_recentEmails.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          child: Text(
                            'No saved accounts'.tr(context),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        )
                      else
                        ..._recentEmails.map((email) {
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              onTap: () => _selectEmail(email),
                              onLongPress: () => _deleteEmail(email),
                              leading: Icon(
                                Icons.history,
                                size: 18,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[500],
                              ),
                              title: Text(
                                _maskEmailForDisplay(email),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.secondaryBlue,
                                  fontSize: 14,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
                              dense: true,
                              trailing: IconButton(
                                onPressed: () => _deleteEmail(email),
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey[400],
                                ),
                                tooltip: 'Remove account'.tr(context),
                                splashRadius: 18,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                            ),
                          );
                        }),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Long press email to remove'.tr(context),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                        ),
                      ),
                      // Dedicated clear-all button at the bottom
                      const Divider(height: 1),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: _clearRememberedAccounts,
                          leading: Icon(
                            Icons.cancel_outlined,
                            size: 18,
                            color: isDark ? Colors.white54 : Colors.grey[500],
                          ),
                          title: Text(
                            'Clear remembered accounts'.tr(context),
                            style: const TextStyle(
                              color: AppColors.primaryOrange,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Password label and field
          Text(
            '   ${"Password".tr(context)}',
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
            hintText: 'Enter your password'.tr(context),
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
            onChanged: (_) {
              setState(() {
                _error = null;
              });
            },
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required'.tr(context);
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Forgot Password / Remember me row with adaptive layout for long text.
          LayoutBuilder(
            builder: (context, constraints) {
              final hasLargeText =
                  MediaQuery.of(context).textScaler.scale(1.0) > 1.15;
              final stacked = constraints.maxWidth < 360 || hasLargeText;

              final remember = Row(
                mainAxisSize: MainAxisSize.min,
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
                  Flexible(
                    child: Text(
                      'Remember Me'.tr(context),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : AppColors.secondaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );

              final forgot = TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: Text(
                  'Forgot Password?'.tr(context),
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [remember, forgot],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: remember),
                  forgot,
                ],
              );
            },
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
                _error!.tr(context),
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
                  : Text(
                      'Login'.tr(context),
                      style: const TextStyle(
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
                  'OR CONTINUE WITH'.tr(context),
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
                        const Icon(
                          Icons.g_mobiledata_rounded,
                          color: AppColors.primaryOrange,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Google'.tr(context),
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
                "Don't have an account? ".tr(context),
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
                child: Text(
                  'Register'.tr(context),
                  style: const TextStyle(
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
            '${"© 2026 ".tr(context)}${context.watch<CompanySettingsProvider>().companyName}${" . All rights reserved.".tr(context)}',
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      },
      child: Scaffold(
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
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
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
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewPadding.bottom + 24,
                ),
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
