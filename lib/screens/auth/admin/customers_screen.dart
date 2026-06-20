import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';
import '../../../services/notification_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    final allUsers = await _databaseService.getUsers();
    // Filter to only display customers
    _users = allUsers.where((u) => u.role == 'customer').toList();
    setState(() => _loading = false);
  }

  Future<void> _toggleLicenseVerification(UserModel user, bool isVerified) async {
    await _databaseService.verifyLicense(user.id, isVerified);
    
    // Notify customer
    final title = isVerified ? 'License Verified!' : 'License Verification Rejected';
    final msg = isVerified
        ? 'Your driving license has been approved. You are now authorized to book rentals!'
        : 'Your driving license was rejected. Please re-upload a clear card photo.';
    
    await _notificationService.createNotification(
      userId: user.id,
      title: title,
      message: msg,
      type: 'approval',
    );

    _loadCustomers();
  }

  void _showLicenseVerificationDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('License Verification for ${user.fullName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('License Number: ${user.licenseNumber ?? "Not Submitted"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                user.licenseImage.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          user.licenseImage,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 180,
                            color: Colors.grey[200],
                            child: const Icon(Icons.badge, size: 64, color: Colors.grey),
                          ),
                        ),
                      )
                    : Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('No driving license card photo uploaded', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        ),
                      ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            if (user.licenseImage.isNotEmpty) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  _toggleLicenseVerification(user, false);
                },
                child: const Text('Reject'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  _toggleLicenseVerification(user, true);
                },
                child: const Text('Approve'),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Manage Customers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No customer accounts found', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1A237E).withValues(alpha: 0.1),
                          backgroundImage: user.profileImage.isNotEmpty ? NetworkImage(user.profileImage) : null,
                          child: user.profileImage.isEmpty ? const Icon(Icons.person, color: Color(0xFF1A237E)) : null,
                        ),
                        title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.email, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('Phone: ${user.phone}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: user.isVerified
                                ? Colors.green.withValues(alpha: 0.1)
                                : (user.licenseImage.isNotEmpty ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.isVerified
                                ? 'VERIFIED'
                                : (user.licenseImage.isNotEmpty ? 'PENDING' : 'NO UPLOAD'),
                            style: TextStyle(
                              color: user.isVerified
                                  ? Colors.green
                                  : (user.licenseImage.isNotEmpty ? Colors.orange : Colors.grey),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () => _showLicenseVerificationDialog(user),
                      ),
                    );
                  },
                ),
    );
  }
}
