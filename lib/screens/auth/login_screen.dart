import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_textfield.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'customer/customer_responsive_shell.dart';
import 'admin/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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

  final FocusNode _emailFocusNode = FocusNode();
  List<String> _recentEmails = [];
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _emailKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSavedEmails();
    _emailFocusNode.addListener(_onEmailFocusChange);
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

  void _onEmailFocusChange() {
    if (_emailFocusNode.hasFocus) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay();
    if (_recentEmails.isEmpty) return;

    final overlayState = Overlay.of(context);
    final renderBox = _emailKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 6),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _recentEmails.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderGray),
                  itemBuilder: (context, index) {
                    final email = _recentEmails[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(
                        email,
                        style: const TextStyle(
                          color: AppColors.secondaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteEmail(email),
                      ),
                      onTap: () {
                        setState(() {
                          _emailController.text = email;
                        });
                        _emailFocusNode.unfocus();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
      _hideOverlay();
    } else {
      _showOverlay();
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
          _error = 'Your account has been disabled or suspended. Please contact support.';
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
        
        final List<String> list = prefs.getStringList('recent_login_emails') ?? [];
        list.remove(enteredEmail);
        list.insert(0, enteredEmail);
        if (list.length > 5) {
          list.removeRange(5, list.length);
        }
        await prefs.setStringList('recent_login_emails', list);
      }

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
          MaterialPageRoute(builder: (context) => const CustomerResponsiveShell()),
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
          _error = 'Your account has been disabled or suspended. Please contact support.';
          _googleLoading = false;
        });
        await _authService.logout();
        return;
      }

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
          MaterialPageRoute(builder: (context) => const CustomerResponsiveShell()),
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
    _hideOverlay();
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _emailFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.secondaryBlue, Color(0xFF07172C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.directions_car_filled_rounded,
                      size: 80,
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CARRENT Platform',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Premium Car Rental Management System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 40),
                    CompositedTransformTarget(
                      link: _layerLink,
                      child: Container(
                        key: _emailKey,
                        child: CustomTextField(
                          controller: _emailController,
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          focusNode: _emailFocusNode,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Email is required';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return 'Enter a valid email';
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      controller: _passwordController,
                      labelText: 'Password',
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
                              side: const BorderSide(color: Colors.white60),
                            ),
                            const Text(
                              'Remember Me',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
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
                            style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: AppColors.secondaryBlue,
                          backgroundColor: AppColors.primaryOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        onPressed: (_loading || _googleLoading) ? null : _login,
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.secondaryBlue,
                          side: const BorderSide(color: AppColors.borderGray, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 1,
                          shadowColor: Colors.black.withValues(alpha: 0.1),
                        ),
                        onPressed: (_loading || _googleLoading) ? null : _loginWithGoogle,
                        child: _googleLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryBlue),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://www.gstatic.com/mobilesdk/160503_mobilesdk/logo/2x/google_g_normal_id_48dp.png',
                                    height: 24,
                                    width: 24,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.g_mobiledata_rounded,
                                      color: AppColors.primaryOrange,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: AppColors.secondaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
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
                            'Sign Up',
                            style: TextStyle(
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
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
