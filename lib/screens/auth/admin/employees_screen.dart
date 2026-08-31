import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_model.dart';
import '../../../services/employee_service.dart';
import '../../../services/database_service.dart';
import '../../../constants/colors.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../l10n/app_translations.dart';

class EmployeesView extends StatefulWidget {
  const EmployeesView({super.key});

  @override
  State<EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<EmployeesView> {
  final EmployeeService _employeeService = EmployeeService();
  final DatabaseService _databaseService = DatabaseService();

  List<UserModel> _allUsers = [];
  bool _loading = true;
  String? _error;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'All'; // 'All', 'Active', 'Inactive'
  String _filterRole = 'All'; // 'All', 'Employee', 'Admin'

  StreamSubscription? _usersSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToLiveData();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _subscribeToLiveData() {
    _usersSubscription?.cancel();
    _usersSubscription = _databaseService.getUsersStream().listen((uList) {
      if (mounted) {
        setState(() {
          _allUsers = uList;
          _loading = false;
        });
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_allUsers.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final users = await _databaseService.getUsers(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _allUsers = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[EmployeesView] Error loading users: $e');
      if (mounted && _allUsers.isEmpty) {
        setState(() {
          _error = 'Failed to load employee records. Please check connection.';
          _loading = false;
        });
      }
    }
  }

  List<UserModel> _getEmployees() {
    return _allUsers.where((u) {
      // Must be employee or admin if role filter is set
      final roleLower = u.normalizedRole;
      final isStaff = roleLower == 'employee' || roleLower == 'admin';
      if (!isStaff) return false;

      // Search query filter
      final empId = u.employeeId.toLowerCase();
      final matchesSearch = u.fullName.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery) ||
          u.phone.toLowerCase().contains(_searchQuery) ||
          empId.contains(_searchQuery);

      // Status filter
      bool matchesStatus = true;
      if (_filterStatus == 'Active') {
        matchesStatus = u.isActive && u.accountStatus.toLowerCase() != 'disabled';
      } else if (_filterStatus == 'Inactive') {
        matchesStatus = !u.isActive || u.accountStatus.toLowerCase() == 'disabled' || u.accountStatus.toLowerCase() == 'suspended';
      }

      // Role filter
      bool matchesRole = true;
      if (_filterRole != 'All') {
        matchesRole = u.normalizedRole == _filterRole.toLowerCase();
      }

      return matchesSearch && matchesStatus && matchesRole;
    }).toList();
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

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddEmployeeDialog(
        onEmployeeAdded: () {
          _loadData();
        },
      ),
    );
  }

  void _showEditEmployeeDialog(UserModel employee) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditEmployeeDialog(
        employee: employee,
        onEmployeeUpdated: () {
          _loadData();
        },
      ),
    );
  }

  void _showEmployeeDetailsDialog(UserModel employee) {
    showDialog(
      context: context,
      builder: (context) => _EmployeeDetailsDialog(employee: employee),
    );
  }

  Future<void> _toggleEmployeeStatus(UserModel employee) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (employee.id == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot change your own account status to prevent lockout!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newIsActive = !employee.isActive;
    final newAccountStatus = newIsActive ? 'Active' : 'Disabled';
    final actionName = newIsActive ? 'Activate' : 'Deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionName Employee Account'),
        content: Text(
          'Are you sure you want to $actionName account for ${employee.fullName}? '
          '${newIsActive ? "They will be able to log in to the system." : "They will be blocked from logging in."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newIsActive ? Colors.green : Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionName),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _employeeService.toggleEmployeeStatus(
          employee.id,
          newIsActive,
          newAccountStatus,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Employee ${employee.fullName} $actionName d successfully'),
              backgroundColor: newIsActive ? Colors.green : Colors.orange,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteEmployee(UserModel employee) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (employee.id == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your own admin account!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee Record'),
        content: Text(
          'Are you sure you want to delete ${employee.fullName} (${employee.email})?\n\n'
          'This will remove their profile record from the system database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Safely'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _employeeService.deleteEmployee(employee.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Employee ${employee.fullName} record deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete employee: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: LoadingWidget(message: 'Loading employee records...'.tr(context)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!.tr(context),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: Text('Retry Loading'.tr(context)),
            ),
          ],
        ),
      );
    }

    final employees = _getEmployees();
    final totalEmployees = _allUsers.where((u) => u.isEmployee || u.normalizedRole == 'employee').length;
    final activeEmployees = _allUsers.where((u) => (u.isEmployee || u.normalizedRole == 'employee') && u.isActive).length;
    final inactiveEmployees = totalEmployees - activeEmployees;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1000;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee Management'.tr(context),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Manage staff accounts, credentials, role assignments, and active statuses.'.tr(context),
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddEmployeeDialog,
                icon: const Icon(Icons.person_add_rounded, size: 20),
                label: Text('Add Employee'.tr(context)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stat Cards Grid
          GridView.count(
            crossAxisCount: isDesktop ? 3 : 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 3.0 : 2.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                'Total Employees',
                totalEmployees.toString(),
                Icons.badge_outlined,
                Colors.indigo,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Active Staff',
                activeEmployees.toString(),
                Icons.check_circle_outline_rounded,
                Colors.teal,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Inactive Staff',
                inactiveEmployees.toString(),
                Icons.pause_circle_outline_rounded,
                Colors.orange,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search & Filter Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search employees by name, email, phone, or ID...'.tr(context),
                            hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                            prefixIcon: Icon(Icons.search, color: textSecondary),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildFilters(isDark: isDark, textPrimary: textPrimary),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search employees by name, email, phone, or ID...'.tr(context),
                          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                          prefixIcon: Icon(Icons.search, color: textSecondary),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFilters(isDark: isDark, textPrimary: textPrimary),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Employee Listing Table / Cards
          employees.isEmpty
              ? Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No employee records match the search query or filter criteria.'.tr(context),
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
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
                      ? _buildDesktopTable(employees, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor)
                      : _buildMobileList(employees, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              Text(
                label.tr(context),
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters({required bool isDark, required Color textPrimary}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterStatus,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              items: [
                DropdownMenuItem(value: 'All', child: Text('Status: All'.tr(context))),
                DropdownMenuItem(value: 'Active', child: Text('Status: Active'.tr(context))),
                DropdownMenuItem(value: 'Inactive', child: Text('Status: Inactive'.tr(context))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _filterStatus = val);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Role Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterRole,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              items: [
                DropdownMenuItem(value: 'All', child: Text('Role: All'.tr(context))),
                DropdownMenuItem(value: 'Employee', child: Text('Role: Employee'.tr(context))),
                DropdownMenuItem(value: 'Admin', child: Text('Role: Admin'.tr(context))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _filterRole = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(
    List<UserModel> employees, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return DataTable(
      columnSpacing: 20,
      headingRowHeight: 52,
      dataRowMaxHeight: 64,
      columns: [
        DataColumn(label: Text('Employee'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
        DataColumn(label: Text('ID'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
        DataColumn(label: Text('Contact'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
        DataColumn(label: Text('Role'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
        DataColumn(label: Text('Status'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
        DataColumn(label: Text('Created Date'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
        DataColumn(label: Text('Actions'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
      ],
      rows: employees.map((emp) {
        final isActive = emp.isActive && emp.accountStatus.toLowerCase() != 'disabled';
        final empIdDisplay = emp.employeeId.isNotEmpty ? emp.employeeId : 'EMP-${emp.id.substring(0, 5).toUpperCase()}';

        return DataRow(
          cells: [
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
                    child: Text(
                      emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        emp.fullName,
                        style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      Text(
                        emp.email,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  empIdDisplay,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            DataCell(
              Text(
                emp.phone.isNotEmpty ? emp.phone : 'N/A',
                style: TextStyle(color: textPrimary),
              ),
            ),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: emp.isAdmin ? Colors.purple.withValues(alpha: 0.15) : AppColors.primaryOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  emp.normalizedRole.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: emp.isAdmin ? Colors.purple : AppColors.primaryOrange,
                  ),
                ),
              ),
            ),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.teal.withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.teal : Colors.redAccent,
                  ),
                ),
              ),
            ),
            DataCell(
              Text(
                _formatDate(emp.createdAt),
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    tooltip: 'View Details',
                    onPressed: () => _showEmployeeDetailsDialog(emp),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit Information',
                    onPressed: () => _showEditEmployeeDialog(emp),
                  ),
                  IconButton(
                    icon: Icon(
                      isActive ? Icons.block_outlined : Icons.check_circle_outline,
                      color: isActive ? Colors.orange : Colors.teal,
                      size: 20,
                    ),
                    tooltip: isActive ? 'Deactivate Account' : 'Activate Account',
                    onPressed: () => _toggleEmployeeStatus(emp),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete Record Safely',
                    onPressed: () => _deleteEmployee(emp),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMobileList(
    List<UserModel> employees, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: borderColor),
      itemBuilder: (context, index) {
        final emp = employees[index];
        final isActive = emp.isActive && emp.accountStatus.toLowerCase() != 'disabled';
        final empIdDisplay = emp.employeeId.isNotEmpty ? emp.employeeId : 'EMP-${emp.id.substring(0, 5).toUpperCase()}';

        return Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
              child: Text(
                emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    emp.fullName,
                    style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.teal.withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.teal : Colors.redAccent),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${emp.email} • ID: $empIdDisplay', style: TextStyle(fontSize: 12, color: textSecondary)),
                Text('Role: ${emp.normalizedRole.toUpperCase()} • Phone: ${emp.phone.isNotEmpty ? emp.phone : "N/A"}', style: TextStyle(fontSize: 12, color: textSecondary)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'view') _showEmployeeDetailsDialog(emp);
                if (val == 'edit') _showEditEmployeeDialog(emp);
                if (val == 'toggle') _toggleEmployeeStatus(emp);
                if (val == 'delete') _deleteEmployee(emp);
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'view', child: Text('View Details'.tr(context))),
                PopupMenuItem(value: 'edit', child: Text('Edit Employee'.tr(context))),
                PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate'.tr(context) : 'Activate'.tr(context))),
                PopupMenuItem(value: 'delete', child: Text('Delete Record'.tr(context), style: const TextStyle(color: Colors.redAccent))),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ADD EMPLOYEE DIALOG
// ─────────────────────────────────────────────────────────────
class _AddEmployeeDialog extends StatefulWidget {
  final VoidCallback onEmployeeAdded;
  const _AddEmployeeDialog({required this.onEmployeeAdded});

  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _empIdController = TextEditingController();
  final _passwordController = TextEditingController();

  final EmployeeService _employeeService = EmployeeService();
  bool _loading = false;
  bool _obscurePassword = true;
  String _role = 'employee';
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _empIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _employeeService.createEmployee(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim(),
        employeeId: _empIdController.text.trim(),
        role: _role,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee ${_nameController.text.trim()} added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onEmployeeAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.person_add_rounded, color: AppColors.primaryOrange),
          const SizedBox(width: 10),
          Text('Add New Employee'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!.tr(context),
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                CustomTextField(
                  controller: _nameController,
                  labelText: 'Full Name'.tr(context),
                  hintText: 'e.g. Ahmad Razak',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required'.tr(context) : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email Address'.tr(context),
                  hintText: 'e.g. ahmad.employee@carrent.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required'.tr(context);
                    if (!v.contains('@')) return 'Enter valid email'.tr(context);
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number'.tr(context),
                  hintText: 'e.g. +60123456789',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _empIdController,
                  labelText: 'Employee ID (Optional)'.tr(context),
                  hintText: 'e.g. EMP-108',
                  prefixIcon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Initial Password'.tr(context),
                  hintText: 'At least 6 characters'.tr(context),
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters'.tr(context) : null,
                ),
                const SizedBox(height: 14),

                // Role Dropdown
                Text('  ${"Role Assignment".tr(context)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.security_outlined),
                    fillColor: isDark ? const Color(0xFF1E293B) : AppColors.lightGray,
                  ),
                  items: [
                    DropdownMenuItem(value: 'employee', child: Text('Employee'.tr(context))),
                    DropdownMenuItem(value: 'admin', child: Text('Admin'.tr(context))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _role = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text('Cancel'.tr(context)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Create Account'.tr(context)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EDIT EMPLOYEE DIALOG
// ─────────────────────────────────────────────────────────────
class _EditEmployeeDialog extends StatefulWidget {
  final UserModel employee;
  final VoidCallback onEmployeeUpdated;
  const _EditEmployeeDialog({required this.employee, required this.onEmployeeUpdated});

  @override
  State<_EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<_EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _empIdController;

  late String _role;
  late bool _isActive;

  final EmployeeService _employeeService = EmployeeService();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.fullName);
    _phoneController = TextEditingController(text: widget.employee.phone);
    _empIdController = TextEditingController(text: widget.employee.employeeId);
    _role = widget.employee.normalizedRole;
    _isActive = widget.employee.isActive && widget.employee.accountStatus.toLowerCase() != 'disabled';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _empIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await _employeeService.updateEmployee(widget.employee.id, {
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'employeeId': _empIdController.text.trim().toUpperCase(),
        'role': _role,
        'isActive': _isActive,
        'accountStatus': _isActive ? 'Active' : 'Disabled',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onEmployeeUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_outlined, color: AppColors.primaryOrange),
          const SizedBox(width: 10),
          Text('Edit Employee'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${"Email:".tr(context)} ${widget.employee.email}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _nameController,
                  labelText: 'Full Name'.tr(context),
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required'.tr(context) : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number'.tr(context),
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _empIdController,
                  labelText: 'Employee ID'.tr(context),
                  prefixIcon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),

                Text('  ${"Role Assignment".tr(context)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.security_outlined),
                    fillColor: isDark ? const Color(0xFF1E293B) : AppColors.lightGray,
                  ),
                  items: [
                    DropdownMenuItem(value: 'employee', child: Text('Employee'.tr(context))),
                    DropdownMenuItem(value: 'admin', child: Text('Admin'.tr(context))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _role = val);
                  },
                ),
                const SizedBox(height: 14),

                SwitchListTile(
                  title: Text('Active Account'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(_isActive ? 'Allowed to access system'.tr(context) : 'Blocked from accessing system'.tr(context), style: const TextStyle(fontSize: 12)),
                  value: _isActive,
                  activeThumbColor: Colors.teal,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text('Cancel'.tr(context)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Save Changes'.tr(context)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EMPLOYEE DETAILS DIALOG
// ─────────────────────────────────────────────────────────────
class _EmployeeDetailsDialog extends StatelessWidget {
  final UserModel employee;
  const _EmployeeDetailsDialog({required this.employee});

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;
    final textSecondary = isDark ? Colors.white70 : Colors.grey[700];

    final isActive = employee.isActive && employee.accountStatus.toLowerCase() != 'disabled';
    final empIdDisplay = employee.employeeId.isNotEmpty ? employee.employeeId : 'EMP-${employee.id.substring(0, 5).toUpperCase()}';

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.2),
            child: Text(
              employee.fullName.isNotEmpty ? employee.fullName[0].toUpperCase() : 'E',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(employee.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            _buildDetailRow('Employee ID'.tr(context), empIdDisplay, textPrimary, textSecondary),
            _buildDetailRow('Role'.tr(context), employee.normalizedRole.toUpperCase().tr(context), textPrimary, textSecondary),
            _buildDetailRow('Status'.tr(context), isActive ? 'ACTIVE'.tr(context) : 'INACTIVE'.tr(context), isActive ? Colors.teal : Colors.redAccent, textSecondary),
            _buildDetailRow('Phone Number'.tr(context), employee.phone.isNotEmpty ? employee.phone : 'N/A', textPrimary, textSecondary),
            _buildDetailRow('Registration Date'.tr(context), _formatDate(employee.createdAt), textPrimary, textSecondary),
            _buildDetailRow('Account Status'.tr(context), employee.accountStatus.isNotEmpty ? employee.accountStatus.tr(context) : (isActive ? 'Active'.tr(context) : 'Disabled'.tr(context)), textPrimary, textSecondary),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryBlue, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context),
          child: Text('Close'.tr(context)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor, Color? labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: labelColor, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 13, color: valueColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
