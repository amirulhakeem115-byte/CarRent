import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // State variables
  UserModel? _user;
  bool _loading = true;
  String? _error;


  @override
  void initState() {
    super.initState();
    _loadProfileData();
    // Subscriptions and other init logic would go here.
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    // Placeholder implementation – in a real app this would fetch from Firebase.
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Simulate a delay and mock data
      await Future.delayed(const Duration(milliseconds: 500));
      // Mock user
      _user = UserModel(
        id: 'uid123',
        fullName: 'Guest User',
        email: 'user@example.com',
        phone: '',
        role: 'customer',
        createdAt: '',
        profileImage: '',
      );
      // (mock data loaded)
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load profile details. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Placeholder for verification reminder card
  Widget _buildVerificationReminderCard(bool isDark) {
    return const SizedBox.shrink();
  }


  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(child: Text(_error!)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 60.0 : 20.0,
          vertical: 24.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVerificationReminderCard(isDark),
            // Simple user info display
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, size: 36, color: AppColors.secondaryBlue),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_user?.email ?? 'No Email', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('User ID: ${_user?.id ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Additional placeholder sections could be added here.
          ],
        ),
      ),
    );
  }
}
