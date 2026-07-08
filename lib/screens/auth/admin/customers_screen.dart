import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart' hide Border, TextSpan, Underline;
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;

import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../services/database_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';
import '../../../widgets/app_image.dart';
import '../../../services/file_download_helper.dart' if (dart.library.html) '../../../services/file_download_web.dart' as download_helper;
import '../../../services/company_settings_provider.dart';

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

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterRole = 'All'; // 'All', 'Admin', 'Customer'
  String _filterStatus = 'All'; // 'All', 'Active', 'Disabled'
  String _filterLicense = 'All'; // 'All', 'Unprovided', 'Pending', 'Approved', 'Rejected'

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
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
      final allBookings = await _bookingService.getBookings().timeout(const Duration(seconds: 10));
      final allPayments = await _paymentService.getPayments().timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _users = allUsers;
          _bookings = allBookings;
          _payments = allPayments;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user registry records: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load user registry records. Check permissions or network.';
          _loading = false;
        });
      }
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateOnly(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(dt.toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _updateUserRoleAndStatus(String uid, String newRole, bool newIsActive, String accountStatus) async {
    final currentAdminUid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == currentAdminUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot change your own role or account status to prevent lockout!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _databaseService.updateUser(uid, {
        'role': newRole,
        'isActive': newIsActive,
        'accountStatus': accountStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile settings updated successfully'), backgroundColor: Colors.green),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: $e'), backgroundColor: Colors.redAccent),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyUserDocument(String uid, String docType, bool approve, String reason) async {
    setState(() => _loading = true);
    try {
      await _databaseService.verifyDocument(uid, docType, approve, reason: reason);
      if (mounted) {
        final docName = docType == 'license' ? 'Driving License' : 'ID/Passport';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? '$docName approved successfully!' : '$docName rejected.'),
            backgroundColor: approve ? Colors.green : Colors.redAccent,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process verification: $e'), backgroundColor: Colors.redAccent),
        );
      }
      setState(() => _loading = false);
    }
  }

  void _showSpecsDialog(UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _UserSpecsDialog(
          user: user,
          bookings: _bookings,
          payments: _payments,
          onSaveSettings: (role, isActive, accountStatus) {
            Navigator.pop(context);
            _updateUserRoleAndStatus(user.id, role, isActive, accountStatus);
          },
          onVerifyDocument: (docType, approve, reason) {
            Navigator.pop(context);
            _verifyUserDocument(user.id, docType, approve, reason);
          },
        );
      },
    );
  }

  // --- EXPORTS LOGIC ---
  void _exportExcel() {
    final filtered = _getFilteredUsers();
    var excelObj = Excel.createExcel();
    var sheet = excelObj[excelObj.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      TextCellValue('Full Name'),
      TextCellValue('Email'),
      TextCellValue('Phone'),
      TextCellValue('Role'),
      TextCellValue('Account Status'),
      TextCellValue('License Status'),
      TextCellValue('Registration Date'),
    ]);

    for (var u in filtered) {
      sheet.appendRow([
        TextCellValue(u.fullName),
        TextCellValue(u.email),
        TextCellValue(u.phone.isNotEmpty ? u.phone : 'N/A'),
        TextCellValue(u.role.toUpperCase()),
        TextCellValue(u.isActive ? 'ACTIVE' : 'DISABLED'),
        TextCellValue(u.licenseStatus.toUpperCase()),
        TextCellValue(_formatDate(u.createdAt)),
      ]);
    }

    final fileBytes = excelObj.save();
    if (fileBytes != null) {
      final companyName = CompanySettingsProvider().companyName.replaceAll(' ', '_');
      download_helper.downloadFile(
        Uint8List.fromList(fileBytes),
        '${companyName}_UserRegistry_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User Registry exported to Excel!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _exportPdf() async {
    final filtered = _getFilteredUsers();
    final pdf = pw.Document();

    List<List<String>> tableData = filtered.map((u) => [
      u.fullName,
      u.email,
      u.phone.isNotEmpty ? u.phone : 'N/A',
      u.role.toUpperCase(),
      u.isActive ? 'ACTIVE' : 'DISABLED',
      u.licenseStatus.toUpperCase(),
      _formatDateOnly(u.createdAt)
    ]).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdf_lib.PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${CompanySettingsProvider().companyName.toUpperCase()} CORPORATE USER LEDGER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: pdf_lib.PdfColor.fromInt(0xFF0F172A))),
                  pw.Text('Report Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Name', 'Email', 'Phone', 'Role', 'Account Status', 'License Status', 'Created'],
              data: tableData,
              border: pw.TableBorder.all(width: 0.5, color: pdf_lib.PdfColor.fromInt(0xFFE2E8F0)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdf_lib.PdfColors.white, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: pdf_lib.PdfColor.fromInt(0xFF0F172A)),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
          ];
        },
      ),
    );

    final fileBytes = await pdf.save();
    final companyName = CompanySettingsProvider().companyName.replaceAll(' ', '_');
    download_helper.downloadFile(
      fileBytes,
      '${companyName}_UserRegistry_Export_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User Registry exported to PDF!'), backgroundColor: Colors.green),
      );
    }
  }

  List<UserModel> _getFilteredUsers() {
    return _users.where((u) {
      // Search matches
      final matchesSearch = u.fullName.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery);

      // Role filter
      bool matchesRole = true;
      if (_filterRole != 'All') {
        matchesRole = u.role.toLowerCase() == _filterRole.toLowerCase();
      }

      // Status filter
      bool matchesStatus = true;
      if (_filterStatus != 'All') {
        final isActiveFilter = _filterStatus == 'Active';
        matchesStatus = u.isActive == isActiveFilter;
      }

      // License filter
      bool matchesLicense = true;
      if (_filterLicense != 'All') {
        matchesLicense = u.licenseStatus.toLowerCase() == _filterLicense.toLowerCase();
      }

      return matchesSearch && matchesRole && matchesStatus && matchesLicense;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingWidget(message: 'Syncing registry users...'));
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
            ElevatedButton(onPressed: _loadData, child: const Text('Retry Registry Sync')),
          ],
        ),
      );
    }

    // Statistics Calculations
    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => u.isActive).length;
    final disabledUsers = _users.where((u) => !u.isActive).length;
    final pendingLicenses = _users.where((u) => u.licenseStatus == 'pending').length;
    final approvedLicenses = _users.where((u) => u.licenseStatus == 'approved').length;

    final filteredUsers = _getFilteredUsers();
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1000;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary)),
                          Text('Audit registration credentials, manage user roles, account active statuses, and driving licenses.', style: TextStyle(fontSize: 12, color: textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildHeaderButtons(textPrimary: textPrimary),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary)),
                        Text('Audit registration credentials, manage user roles, account active statuses, and driving licenses.', style: TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildHeaderButtons(textPrimary: textPrimary),
                  ],
                ),
          const SizedBox(height: 24),

          // Statistics Grid
          GridView.count(
            crossAxisCount: isDesktop ? 5 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 2.5 : 1.6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard('Total Users', totalUsers.toString(), Icons.people_outline, Colors.indigo, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Active Users', activeUsers.toString(), Icons.check_circle_outline, Colors.teal, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Disabled Users', disabledUsers.toString(), Icons.block, Colors.redAccent, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Pending Licenses', pendingLicenses.toString(), Icons.hourglass_empty_outlined, Colors.orange, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Approved Licenses', approvedLicenses.toString(), Icons.badge_outlined, Colors.green, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
            ],
          ),
          const SizedBox(height: 24),

          // Search & Filter Bar
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search registry by user name or email...',
                            hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                            prefixIcon: Icon(Icons.search, size: 20, color: textSecondary),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildDropdownFilters(isDark: isDark, cardColor: surfaceColor, textPrimary: textPrimary, borderColor: borderColor),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search registry by user name or email...',
                          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                          prefixIcon: Icon(Icons.search, size: 20, color: textSecondary),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownFilters(isDark: isDark, cardColor: surfaceColor, textPrimary: textPrimary, borderColor: borderColor),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // User Listing Area
          filteredUsers.isEmpty
              ? Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 64, color: textSecondary),
                        const SizedBox(height: 16),
                        Text('No registered users match selected search query or filters.', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: isDesktop
                      ? _buildDesktopTable(filteredUsers, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor)
                      : _buildMobileList(filteredUsers, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButtons({required Color textPrimary}) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: textPrimary),
            foregroundColor: textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _exportExcel,
          icon: const Icon(Icons.table_view_outlined, size: 18),
          label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _exportPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildDropdownFilters({required bool isDark, required Color cardColor, required Color textPrimary, required Color borderColor}) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButton<String>(
            value: _filterRole,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            underline: const SizedBox(),
            items: ['All', 'Admin', 'Customer'].map((r) {
              return DropdownMenuItem(value: r, child: Text(r));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _filterRole = val);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButton<String>(
            value: _filterStatus,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            underline: const SizedBox(),
            items: ['All', 'Active', 'Disabled'].map((s) {
              return DropdownMenuItem(value: s, child: Text(s == 'Disabled' ? 'Disabled/Suspended' : s));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _filterStatus = val);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButton<String>(
            value: _filterLicense,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            underline: const SizedBox(),
            items: ['All', 'Unprovided', 'Pending', 'Approved', 'Rejected'].map((l) {
              return DropdownMenuItem(value: l, child: Text('License: $l'));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _filterLicense = val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(List<UserModel> users, {required bool isDark, required Color textPrimary, required Color textSecondary, required Color borderColor}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        columns: [
          DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Account', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('License Status', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
        ],
        rows: users.map((u) {
          Color licenseColor = Colors.orange;
          if (u.licenseStatus == 'approved') licenseColor = Colors.green;
          if (u.licenseStatus == 'rejected') licenseColor = Colors.red;
          if (u.licenseStatus == 'unprovided') licenseColor = Colors.grey;

          final accountStatus = u.isActive ? 'ACTIVE' : 'DISABLED';

          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.secondaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                      backgroundImage: getAppImageProvider(u.profileImage),
                      child: u.profileImage.isEmpty ? Icon(Icons.person, size: 14, color: textPrimary) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(u.fullName, style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                  ],
                ),
              ),
              DataCell(Text(u.email, style: TextStyle(color: textPrimary))),
              DataCell(Text(u.phone.isNotEmpty ? u.phone : 'N/A', style: TextStyle(color: textSecondary))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: u.role == 'admin' ? Colors.purple.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    u.role.toUpperCase(),
                    style: TextStyle(color: u.role == 'admin' ? Colors.purple : Colors.blue, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: u.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    accountStatus,
                    style: TextStyle(color: u.isActive ? Colors.green : Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: licenseColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    u.licenseStatus.toUpperCase(),
                    style: TextStyle(color: licenseColor, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataCell(
                IconButton(
                  icon: Icon(Icons.edit_note_outlined, color: textPrimary, size: 20),
                  tooltip: 'Manage Profile Details',
                  onPressed: () => _showSpecsDialog(u),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList(List<UserModel> users, {required bool isDark, required Color textPrimary, required Color textSecondary, required Color borderColor}) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (context, index) => Divider(color: borderColor, height: 1),
      itemBuilder: (context, index) {
        final u = users[index];
        Color licenseColor = Colors.orange;
        if (u.licenseStatus == 'approved') licenseColor = Colors.green;
        if (u.licenseStatus == 'rejected') licenseColor = Colors.red;
        if (u.licenseStatus == 'unprovided') licenseColor = Colors.grey;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: AppColors.secondaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
            backgroundImage: getAppImageProvider(u.profileImage),
            child: u.profileImage.isEmpty ? Icon(Icons.person, size: 14, color: textPrimary) : null,
          ),
          title: Text(u.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(u.email, style: TextStyle(fontSize: 11, color: textSecondary)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: u.role == 'admin' ? Colors.purple.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(u.role.toUpperCase(), style: TextStyle(color: u.role == 'admin' ? Colors.purple : Colors.blue, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: u.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(u.isActive ? 'ACTIVE' : 'DISABLED', style: TextStyle(color: u.isActive ? Colors.green : Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: licenseColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  u.licenseStatus.toUpperCase(),
                  style: TextStyle(color: licenseColor, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: textSecondary),
            ],
          ),
          onTap: () => _showSpecsDialog(u),
        );
      },
    );
  }
}

// --- PRIVATIZED COMPREHENSIVE SPECIFICATIONS DIALOG ---
class _UserSpecsDialog extends StatefulWidget {
  final UserModel user;
  final List<BookingModel> bookings;
  final List<PaymentModel> payments;
  final Function(String role, bool isActive, String accountStatus) onSaveSettings;
  final Function(String docType, bool approve, String reason) onVerifyDocument;

  const _UserSpecsDialog({
    required this.user,
    required this.bookings,
    required this.payments,
    required this.onSaveSettings,
    required this.onVerifyDocument,
  });

  @override
  State<_UserSpecsDialog> createState() => _UserSpecsDialogState();
}

class _UserSpecsDialogState extends State<_UserSpecsDialog> {
  late String _selectedRole;
  late String _selectedStatus;
  final TextEditingController _rejectionReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role;
    
    // Determine active account status
    final userMap = widget.user.toMap();
    final dbStatus = userMap['accountStatus'] ?? (widget.user.isActive ? 'Active' : 'Disabled');
    _selectedStatus = dbStatus;
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  void _showImageLightbox(BuildContext context, String imageSrc) {
    showDialog(
      context: context,
      builder: (context) {
        final isPdf = imageSrc.toLowerCase().contains('.pdf') || imageSrc.startsWith('data:application/pdf');
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.black54,
                elevation: 0,
                title: const Text('Driving License File', style: TextStyle(color: Colors.white)),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () {
                      final rawBase64 = imageSrc.split(',').last;
                      final bytes = base64Decode(rawBase64);
                      final ext = isPdf ? 'pdf' : 'png';
                      download_helper.downloadFile(bytes, 'license_document.$ext');
                    },
                  )
                ],
              ),
              Expanded(
                child: Container(
                  color: Colors.black87,
                  alignment: Alignment.center,
                  child: isPdf
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 80),
                            const SizedBox(height: 16),
                            const Text('PDF License Document Uploaded', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                final rawBase64 = imageSrc.split(',').last;
                                final bytes = base64Decode(rawBase64);
                                download_helper.downloadFile(bytes, 'license_document.pdf');
                              },
                              child: const Text('Download PDF'),
                            )
                          ],
                        )
                      : InteractiveViewer(
                          panEnabled: true,
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            base64Decode(imageSrc.split(',').last),
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter bookings and payments for the user
    final userBookings = widget.bookings.where((b) => b.userId == widget.user.id).toList();
    final userPayments = widget.payments.where((p) => p.userId == widget.user.id).toList();

    userBookings.sort((a, b) => b.pickUpDate.compareTo(a.pickUpDate));
    userPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardColor,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
        padding: const EdgeInsets.all(24),
        child: DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.secondaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                    backgroundImage: getAppImageProvider(widget.user.profileImage),
                    child: widget.user.profileImage.isEmpty ? Icon(Icons.person, color: textPrimary) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.user.fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                        Text(widget.user.email, style: TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Navigation Tabs
              TabBar(
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: textSecondary,
                indicatorColor: AppColors.primaryOrange,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  const Tab(text: 'Profile & Access'),
                  Tab(text: 'Bookings (${userBookings.length})'),
                  Tab(text: 'Payments (${userPayments.length})'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Profile specs & license
                    _buildProfileTab(),
                    // Tab 2: Bookings history
                    _buildBookingsTab(userBookings),
                    // Tab 3: Payments history
                    _buildPaymentsTab(userPayments),
                  ],
                ),
              ),

              Divider(height: 24, color: borderColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: borderColor),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final isActive = _selectedStatus == 'Active';
                      widget.onSaveSettings(_selectedRole, isActive, _selectedStatus);
                    },
                    child: const Text('Save Registry Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    Color idBadgeColor = Colors.orange;
    if (widget.user.idStatus == 'approved') idBadgeColor = Colors.green;
    if (widget.user.idStatus == 'rejected') idBadgeColor = Colors.red;
    if (widget.user.idStatus == 'unprovided') idBadgeColor = Colors.grey;

    Color licenseColor = Colors.orange;
    if (widget.user.licenseStatus == 'approved') licenseColor = Colors.green;
    if (widget.user.licenseStatus == 'rejected') licenseColor = Colors.red;
    if (widget.user.licenseStatus == 'unprovided') licenseColor = Colors.grey;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Access Controls row
          Text('SYSTEM ACCOUNT SECURITY CONTROLS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: textSecondary)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              final roleDropdown = DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'System Access Role',
                  labelStyle: TextStyle(color: textSecondary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                ),
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('Customer')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin Manager')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRole = val;
                    });
                  }
                },
              );
              
              final statusDropdown = DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Account Login Status',
                  labelStyle: TextStyle(color: textSecondary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active (Allow Access)')),
                  DropdownMenuItem(value: 'Disabled', child: Text('Disabled (Block Access)')),
                  DropdownMenuItem(value: 'Suspended', child: Text('Suspended (Block Access)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStatus = val;
                    });
                  }
                },
              );

              return isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        roleDropdown,
                        const SizedBox(height: 12),
                        statusDropdown,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: roleDropdown),
                        const SizedBox(width: 16),
                        Expanded(child: statusDropdown),
                      ],
                    );
            },
          ),
          const SizedBox(height: 20),

          // User details block
          Text('USER REGISTRATION PARAMETERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: textSecondary)),
          const SizedBox(height: 8),
          _buildRowDetails('Phone Number', widget.user.phone.isNotEmpty ? widget.user.phone : 'N/A'),
          _buildRowDetails('Residential Address', widget.user.address),
          _buildRowDetails('Registration Timestamp', _formatDate(widget.user.createdAt)),
          const SizedBox(height: 20),

          // ID/Passport Verification section
          Text('NATIONAL ID / PASSPORT VERIFICATION DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.user.idNumber.isNotEmpty ? '${widget.user.idType}: ${widget.user.idNumber}' : 'No ID/Passport number provided',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: idBadgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.user.idStatus.toUpperCase(),
                        style: TextStyle(color: idBadgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Uploaded on: ${widget.user.idUploadDate.isNotEmpty ? widget.user.idUploadDate : "N/A"}', style: TextStyle(color: textSecondary, fontSize: 12)),
                if (widget.user.idStatus == 'rejected' && widget.user.idRejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Rejection Reason: ${widget.user.idRejectionReason}',
                    style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
                if (widget.user.idImage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('ID Image Preview (Click to Zoom):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showImageLightbox(context, widget.user.idImage),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppImage(
                        imageSrc: widget.user.idImage,
                        height: 90,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          height: 90,
                          color: surfaceColor,
                          alignment: Alignment.center,
                          child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.user.idStatus == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              _showDocumentRejectionDialog(context, 'id');
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: const Text('Reject ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              widget.onVerifyDocument('id', true, '');
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 14),
                            label: const Text('Approve ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // License Verification section
          Text('DRIVING LICENSE VERIFICATION DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.user.licenseNumber != null ? 'License: ${widget.user.licenseNumber}' : 'No license number provided',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: licenseColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.user.licenseStatus.toUpperCase(),
                        style: TextStyle(color: licenseColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Class: ${widget.user.licenseClass} | Expiry: ${widget.user.licenseExpiry}', style: TextStyle(color: textSecondary, fontSize: 12)),
                if (widget.user.licenseUploadDate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Uploaded on: ${widget.user.licenseUploadDate}', style: TextStyle(color: textSecondary, fontSize: 11)),
                ],
                if (widget.user.licenseStatus == 'rejected' && widget.user.licenseRejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Rejection Reason: ${widget.user.licenseRejectionReason}',
                    style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
                if (widget.user.licenseImage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('License Image Preview (Click to Zoom):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showImageLightbox(context, widget.user.licenseImage),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppImage(
                        imageSrc: widget.user.licenseImage,
                        height: 90,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          height: 90,
                          color: surfaceColor,
                          alignment: Alignment.center,
                          child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.user.licenseStatus == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              _showDocumentRejectionDialog(context, 'license');
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: const Text('Reject License', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              widget.onVerifyDocument('license', true, '');
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 14),
                            label: const Text('Approve License', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDocumentRejectionDialog(BuildContext context, String docType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final docName = docType == 'license' ? 'License' : 'ID/Passport';
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('$docName Rejection Reason', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
          content: TextField(
            controller: _rejectionReasonController,
            style: TextStyle(color: textPrimary),
            decoration: const InputDecoration(
              labelText: 'Rejection Reason',
              hintText: 'e.g. Photo blurry or document expired',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                final reason = _rejectionReasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a rejection reason.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                widget.onVerifyDocument(docType, false, reason);
              },
              child: const Text('Submit Rejection'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRowDetails(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsTab(List<BookingModel> bookings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_outlined, size: 48, color: textSecondary),
            const SizedBox(height: 12),
            Text('No booking reservations registered for this user.', style: TextStyle(color: textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        Color statusColor = Colors.orange;
        if (['approved', 'active', 'ongoing'].contains(b.status.toLowerCase())) statusColor = Colors.blue;
        if (b.status.toLowerCase() == 'completed') statusColor = Colors.green;
        if (['cancelled', 'rejected'].contains(b.status.toLowerCase())) statusColor = Colors.red;

        final startStr = DateFormat('dd MMM yy').format(b.pickUpDate);
        final endStr = b.isOpenRental ? 'Open Rental' : (b.returnDate != null ? DateFormat('dd MMM yy').format(b.returnDate!) : "");

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          color: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
          elevation: 0,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(b.vehicleName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                Text('RM ${b.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryOrange, fontSize: 12)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Duration: $startStr - $endStr', style: TextStyle(fontSize: 11, color: textSecondary)),
                Text('Ref ID: #${b.id.substring(0, b.id.length > 8 ? 8 : b.id.length).toUpperCase()}', style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(b.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab(List<PaymentModel> payments) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_outlined, size: 48, color: textSecondary),
            const SizedBox(height: 12),
            Text('No payment transaction history found for this user.', style: TextStyle(color: textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final p = payments[index];
        Color statusColor = Colors.orange;
        if (p.status.toLowerCase() == 'paid') statusColor = Colors.green;
        if (['failed', 'rejected'].contains(p.status.toLowerCase())) statusColor = Colors.redAccent;
        if (p.status.toLowerCase() == 'refunded') statusColor = Colors.purple;

        final payDate = DateFormat('dd MMM yy, hh:mm a').format(p.paymentDate);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          color: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
          elevation: 0,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('RM ${p.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                Text(p.paymentMethod.toUpperCase(), style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Settled Date: $payDate', style: TextStyle(fontSize: 11, color: textSecondary)),
                Text('Tx Ref: #${p.id.substring(0, p.id.length > 8 ? 8 : p.id.length).toUpperCase()}', style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(p.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}
