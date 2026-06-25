import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../services/database_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';
import '../../../widgets/app_image.dart';

class CustomersView extends StatefulWidget {
  const CustomersView({super.key});

  @override
  State<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<CustomersView> {
  final DatabaseService _databaseService = DatabaseService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  List<UserModel> _users = [];
  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _subTab = 'Registry'; // 'Registry' or 'Verification'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final allUsers = await _databaseService.getUsers().timeout(const Duration(seconds: 10));
      _users = allUsers.where((u) => u.role == 'customer').toList();
      _bookings = await _bookingService.getBookings().timeout(const Duration(seconds: 10));
      _payments = await _paymentService.getPayments().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error loading customer registry details: $e');
      setState(() {
        _error = 'Failed to load customer registry records. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleLicenseVerification(UserModel user, bool isVerified) async {
    if (isVerified) {
      await _approveUserLicense(user);
    } else {
      await _rejectUserLicense(user);
    }
  }

  Future<void> _approveUserLicense(UserModel user) async {
    setState(() => _loading = true);
    try {
      await _databaseService.verifyLicense(user.id, true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approved license for ${user.fullName}'), backgroundColor: Colors.green),
        );
      }
      _loadData();
    } catch (e) {
      debugPrint('Error approving license: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve license: $e'), backgroundColor: Colors.redAccent),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectUserLicense(UserModel user) async {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reject Driving License', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Specify the reason for rejecting ${user.fullName}\'s driving license:'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  hintText: 'e.g., Image is blurry, License expired',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please specify a rejection reason.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                setState(() => _loading = true);
                try {
                  await _databaseService.verifyLicense(user.id, false, reason: reason);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Rejected license for ${user.fullName}'), backgroundColor: Colors.redAccent),
                    );
                  }
                  _loadData();
                } catch (e) {
                  debugPrint('Error rejecting license: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to reject license: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                  setState(() => _loading = false);
                }
              },
              child: const Text('Submit Rejection'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomerDetailsDialog(UserModel user) {
    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phone);
    final addressController = TextEditingController(text: user.address);
    bool isActive = user.isActive;

    // Calculate customer metrics
    final totalUserBookings = _bookings.where((b) => b.userId == user.id).length;
    double totalUserPayments = 0.0;
    for (var p in _payments) {
      if (p.userId == user.id && p.status == 'paid') {
        totalUserPayments += p.amount;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Customer Specifications & Status', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.1),
                      backgroundImage: getAppImageProvider(user.profileImage),
                      child: user.profileImage.isEmpty ? const Icon(Icons.person, size: 36, color: AppColors.secondaryBlue) : null,
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                    TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
                    TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Residential Address')),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildStatRow('Total Bookings Made', '$totalUserBookings reservation(s)'),
                    _buildStatRow('Total Payments Cleared', 'RM ${totalUserPayments.toStringAsFixed(2)}'),
                    _buildStatRow('License Status', user.isVerified ? 'VERIFIED' : 'PENDING APPROVAL',
                        color: user.isVerified ? Colors.green : Colors.orange),

                    if (user.licenseImage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Uploaded License Image:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppImage(
                          imageSrc: user.licenseImage,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            height: 120,
                            color: Colors.grey[100],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                            onPressed: () {
                              Navigator.pop(context);
                              _toggleLicenseVerification(user, false);
                            },
                            child: const Text('Reject License'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.pop(context);
                              _toggleLicenseVerification(user, true);
                            },
                            child: const Text('Approve License'),
                          ),
                        ],
                      ),
                    ],

                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Account Active:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryBlue)),
                        Switch(
                          value: isActive,
                          activeThumbColor: Colors.green,
                          onChanged: (val) {
                            setDialogState(() {
                              isActive = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await _databaseService.updateUser(user.id, {
                      'fullName': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'address': addressController.text.trim(),
                      'isActive': isActive,
                    });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadData();
                  },
                  child: const Text('Save Details'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? AppColors.secondaryBlue)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingWidget(message: 'Loading customer database...'));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16, color: AppColors.secondaryBlue, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    // Calculations
    final totalCustomers = _users.length;
    final activeCustomers = _users.where((u) => u.isActive).length;
    final blockedCustomers = _users.where((u) => !u.isActive).length;

    // Filters application
    final filteredUsers = _users.where((u) {
      final matchesSearch = u.fullName.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery) ||
          u.phone.toLowerCase().contains(_searchQuery);
      return matchesSearch;
    }).toList();

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer Registry', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
                  Text('Audit customer profiles, edit records, toggle accounts, and verify licenses.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              // Tab Switcher
              Row(
                children: [
                  _buildTabButton('Registry', _subTab == 'Registry', () {
                    setState(() => _subTab = 'Registry');
                  }),
                  const SizedBox(width: 12),
                  _buildTabButton('License Verification', _subTab == 'Verification', () {
                    setState(() => _subTab = 'Verification');
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_subTab == 'Registry') ...[
            // Statistics Grid
            GridView.count(
              crossAxisCount: isDesktop ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              childAspectRatio: isDesktop ? 2.5 : 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard('Total Customers', totalCustomers.toString(), Icons.people_outline, Colors.indigo),
                _buildStatCard('Active Accounts', activeCustomers.toString(), Icons.check_circle_outline, Colors.green),
                _buildStatCard('Blocked Accounts', blockedCustomers.toString(), Icons.block, Colors.redAccent),
              ],
            ),
            const SizedBox(height: 24),

            // Search Box Card
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search customers by name, email, or phone number...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // List / Table container
            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No customers found in database.', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      child: isDesktop ? _buildDesktopTable(filteredUsers) : _buildMobileList(filteredUsers),
                    ),
            ),
          ] else ...[
            // License Verification View
            Expanded(
              child: _buildLicenseVerificationView(filteredUsers),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.secondaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.secondaryBlue : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.secondaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseVerificationView(List<UserModel> users) {
    final usersWithLicense = users.where((u) => u.licenseImage.isNotEmpty).toList();

    if (usersWithLicense.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No driving licenses submitted for verification yet.', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: usersWithLicense.length,
      itemBuilder: (context, index) {
        final u = usersWithLicense[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[100]!)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Flex(
              direction: MediaQuery.of(context).size.width > 900 ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Customer details
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
                      const SizedBox(height: 4),
                      Text('Email: ${u.email}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('License Number: ${u.licenseNumber ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('License Class: ${u.licenseClass}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('Expiry: ${u.licenseExpiry}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: u.licenseStatus == 'approved'
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : u.licenseStatus == 'rejected'
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              u.licenseStatus.toUpperCase(),
                              style: TextStyle(
                                color: u.licenseStatus == 'approved'
                                    ? Colors.green
                                    : u.licenseStatus == 'rejected'
                                        ? Colors.red
                                        : Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (u.licenseStatus == 'rejected' && u.licenseRejectionReason.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Rejection Reason: ${u.licenseRejectionReason}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24, height: 16),
                // Middle: License Image Preview
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('License Image Preview:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppImage(
                          imageSrc: u.licenseImage,
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            height: 130,
                            color: Colors.grey[100],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24, height: 16),
                // Right: Action Buttons
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: u.licenseStatus == 'approved' ? null : () => _approveUserLicense(u),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: u.licenseStatus == 'rejected' ? null : () => _rejectUserLicense(u),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<UserModel> users) {
    return ListView(
      children: [
        DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('License Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: users.map((u) {
            Color statusColor = Colors.orange;
            if (u.licenseStatus == 'approved') statusColor = Colors.green;
            if (u.licenseStatus == 'rejected') statusColor = Colors.red;
            if (u.licenseStatus == 'unprovided') statusColor = Colors.grey;

            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.1),
                        backgroundImage: getAppImageProvider(u.profileImage),
                        child: u.profileImage.isEmpty ? const Icon(Icons.person, size: 14, color: AppColors.secondaryBlue) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                DataCell(Text(u.email)),
                DataCell(Text(u.phone.isNotEmpty ? u.phone : 'N/A')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      u.licenseStatus.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: u.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      u.isActive ? 'ACTIVE' : 'BLOCKED',
                      style: TextStyle(color: u.isActive ? Colors.green : Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: AppColors.secondaryBlue, size: 18),
                    onPressed: () => _showCustomerDetailsDialog(u),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<UserModel> users) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        Color statusColor = Colors.orange;
        if (u.licenseStatus == 'approved') statusColor = Colors.green;
        if (u.licenseStatus == 'rejected') statusColor = Colors.red;
        if (u.licenseStatus == 'unprovided') statusColor = Colors.grey;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.1),
              backgroundImage: getAppImageProvider(u.profileImage),
              child: u.profileImage.isEmpty ? const Icon(Icons.person, color: AppColors.secondaryBlue) : null,
            ),
            title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(u.email, style: const TextStyle(fontSize: 12)),
                Text(u.phone.isNotEmpty ? u.phone : 'No phone number', style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    u.licenseStatus.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, size: 16),
              ],
            ),
            onTap: () => _showCustomerDetailsDialog(u),
          ),
        );
      },
    );
  }
}
