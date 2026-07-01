import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/maintenance_job_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/maintenance_service.dart';
import '../../../widgets/loading_widget.dart';

class VehicleMaintenanceView extends StatefulWidget {
  const VehicleMaintenanceView({super.key});

  @override
  State<VehicleMaintenanceView> createState() => _VehicleMaintenanceViewState();
}

class _VehicleMaintenanceViewState extends State<VehicleMaintenanceView> {
  final MaintenanceService _maintenanceService = MaintenanceService();
  final VehicleService _vehicleService = VehicleService();

  List<MaintenanceJobModel> _jobs = [];
  List<VehicleModel> _vehicles = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'All';
  String _selectedVehicleFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
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
      _jobs = await _maintenanceService.getMaintenanceJobs().timeout(const Duration(seconds: 10));
      _vehicles = await _vehicleService.getVehicles().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error loading maintenance data: $e');
      setState(() => _error = 'Failed to load maintenance records. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteJob(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to remove this maintenance record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _maintenanceService.deleteMaintenanceJob(id);
      _loadData();
    }
  }

  Future<void> _updateStatus(String jobId, String status) async {
    await _maintenanceService.updateMaintenanceJob(jobId, {'status': status});
    _loadData();
  }

  void _showAddEditJobDialog({MaintenanceJobModel? job}) {
    if (_vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot schedule maintenance. Fleet is empty.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final isEdit = job != null;
    VehicleModel selectedVehicle = isEdit
        ? _vehicles.firstWhere((v) => v.id == job.vehicleId, orElse: () => _vehicles.first)
        : _vehicles.first;
    final titleController = TextEditingController(text: job?.title);
    final descriptionController = TextEditingController(text: job?.description);
    final costController = TextEditingController(text: job != null ? job.cost.toString() : '');
    DateTime startDate = job != null ? (DateTime.tryParse(job.startDate) ?? DateTime.now()) : DateTime.now();
    DateTime endDate = job != null ? (DateTime.tryParse(job.endDate) ?? DateTime.now()) : DateTime.now();
    String status = job?.status ?? 'Scheduled';
    bool showToCustomer = job?.showToCustomer ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                isEdit ? 'Edit Maintenance Record' : 'Schedule Maintenance',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
              ),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<VehicleModel>(
                        initialValue: selectedVehicle,
                        decoration: const InputDecoration(labelText: 'Select Vehicle'),
                        items: _vehicles.map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text('${v.brand} ${v.model} (${v.plateNumber})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedVehicle = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Service / Repair Title', hintText: 'e.g., Oil Change, Tyre Alignment'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description / Notes', hintText: 'Explain issue or service details...'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Est. Cost (RM)', hintText: 'e.g., 250.00'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    startDate = picked;
                                    if (endDate.isBefore(startDate)) endDate = startDate;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Start Date', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(DateFormat('yyyy-MM-dd').format(startDate), style: const TextStyle(fontSize: 11)),
                                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) setDialogState(() => endDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('End Date', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(DateFormat('yyyy-MM-dd').format(endDate), style: const TextStyle(fontSize: 11)),
                                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: ['Scheduled', 'In Progress', 'Completed', 'Cancelled'].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => status = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Show to Customers', style: TextStyle(fontSize: 14)),
                        subtitle: const Text('Allow customers to view this record in vehicle details', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        value: showToCustomer,
                        activeThumbColor: AppColors.primaryOrange,
                        onChanged: (val) => setDialogState(() => showToCustomer = val),
                      ),
                    ],
                  ),
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
                    if (titleController.text.trim().isEmpty) return;
                    final cost = double.tryParse(costController.text.trim()) ?? 0.0;
                    if (isEdit) {
                      await _maintenanceService.updateMaintenanceJob(job.id, {
                        'vehicleId': selectedVehicle.id,
                        'vehicleName': '${selectedVehicle.brand} ${selectedVehicle.model}',
                        'title': titleController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'cost': cost,
                        'startDate': DateFormat('yyyy-MM-dd').format(startDate),
                        'endDate': DateFormat('yyyy-MM-dd').format(endDate),
                        'status': status,
                        'showToCustomer': showToCustomer,
                      });
                    } else {
                      await _maintenanceService.addMaintenanceJob(MaintenanceJobModel(
                        id: '',
                        vehicleId: selectedVehicle.id,
                        vehicleName: '${selectedVehicle.brand} ${selectedVehicle.model}',
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        cost: cost,
                        startDate: DateFormat('yyyy-MM-dd').format(startDate),
                        endDate: DateFormat('yyyy-MM-dd').format(endDate),
                        status: status,
                        showToCustomer: showToCustomer,
                        createdAt: DateTime.now().toIso8601String(),
                        updatedAt: DateTime.now().toIso8601String(),
                      ));
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadData();
                  },
                  child: Text(isEdit ? 'Save' : 'Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    if (_loading) {
      return const Center(child: LoadingWidget(message: 'Syncing maintenance log...'));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final totalJobs = _jobs.length;
    final activeJobs = _jobs.where((j) => j.status == 'In Progress' || j.status == 'Scheduled').length;
    final completedJobs = _jobs.where((j) => j.status == 'Completed').length;
    double totalCost = 0.0;
    for (var j in _jobs) { totalCost += j.cost; }

    final filteredJobs = _jobs.where((job) {
      final matchesStatus = _selectedFilter == 'All' || job.status.toLowerCase() == _selectedFilter.toLowerCase();
      final matchesVehicle = _selectedVehicleFilter == 'All' || job.vehicleId == _selectedVehicleFilter;
      final matchesSearch = job.vehicleName.toLowerCase().contains(_searchQuery) ||
          job.title.toLowerCase().contains(_searchQuery) ||
          job.description.toLowerCase().contains(_searchQuery);
      return matchesStatus && matchesVehicle && matchesSearch;
    }).toList();

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vehicle Maintenance Log', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary)),
                        Text('Track fleet repairs, scheduled tune-ups, and cost reports.', style: TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showAddEditJobDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Schedule Service', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vehicle Maintenance Log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary)),
                    Text('Track fleet repairs, scheduled tune-ups, and cost reports.', style: TextStyle(fontSize: 12, color: textSecondary)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showAddEditJobDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Schedule Service', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 24),

          // Stats Grid
          GridView.count(
            crossAxisCount: isDesktop ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 2.2 : 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard('Total Service Jobs', totalJobs.toString(), Icons.build, Colors.indigo, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary),
              _buildStatCard('Active Jobs', activeJobs.toString(), Icons.hourglass_empty, Colors.orange, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary),
              _buildStatCard('Completed Jobs', completedJobs.toString(), Icons.check_circle_outline, Colors.green, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary),
              _buildStatCard('Total Cost', 'RM ${totalCost.toStringAsFixed(2)}', Icons.monetization_on_outlined, Colors.redAccent, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary),
            ],
          ),
          const SizedBox(height: 24),

          // Filters & Search
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
                            hintText: 'Search by vehicle, service title, or notes...',
                            hintStyle: TextStyle(color: textSecondary),
                            prefixIcon: Icon(Icons.search, size: 20, color: textSecondary),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildStatusDropdown(isDark: isDark, cardColor: surfaceColor, textPrimary: textPrimary, borderColor: borderColor),
                      const SizedBox(width: 16),
                      _buildVehicleDropdown(isDark: isDark, cardColor: surfaceColor, textPrimary: textPrimary, borderColor: borderColor),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search vehicle, title, or notes...',
                          hintStyle: TextStyle(color: textSecondary),
                          prefixIcon: Icon(Icons.search, size: 20, color: textSecondary),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildStatusDropdown(isDark: isDark, cardColor: surfaceColor, textPrimary: textPrimary, borderColor: borderColor)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildVehicleDropdown(isDark: isDark, cardColor: surfaceColor, textPrimary: textPrimary, borderColor: borderColor)),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // List / Table — natural scroll, no Expanded
          filteredJobs.isEmpty
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
                        Icon(Icons.build_circle_outlined, size: 64, color: textSecondary),
                        const SizedBox(height: 16),
                        Text('No service logs found matching filters.', style: TextStyle(color: textSecondary)),
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
                      ? _buildDesktopTable(filteredJobs, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor)
                      : _buildMobileList(filteredJobs, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {
    required bool isDark, required Color cardColor, required Color textPrimary, required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade100),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<MaintenanceJobModel> jobs, {
    required bool isDark, required Color textPrimary, required Color textSecondary, required Color borderColor,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        dividerThickness: 1,
        columns: [
          DataColumn(label: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Cost (RM)', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('End Date', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
        ],
        rows: jobs.map((job) {
          Color statusColor = Colors.orange;
          if (job.status == 'In Progress') statusColor = Colors.blue;
          if (job.status == 'Completed') statusColor = Colors.green;
          if (job.status == 'Cancelled') statusColor = Colors.redAccent;

          return DataRow(
            cells: [
              DataCell(Text(job.vehicleName, style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary))),
              DataCell(Text(job.title, style: TextStyle(color: textPrimary))),
              DataCell(Text('RM ${job.cost.toStringAsFixed(2)}', style: TextStyle(color: textPrimary))),
              DataCell(Text(job.startDate, style: TextStyle(color: textSecondary))),
              DataCell(Text(job.endDate, style: TextStyle(color: textSecondary))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(job.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
              DataCell(Text(job.description.isNotEmpty ? job.description : 'N/A', style: TextStyle(color: textSecondary), overflow: TextOverflow.ellipsis)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: ['Scheduled', 'In Progress', 'Completed', 'Cancelled'].contains(job.status) ? job.status : 'Scheduled',
                      underline: const SizedBox(),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: textPrimary, fontSize: 12),
                      icon: Icon(Icons.edit_note, size: 18, color: AppColors.primaryOrange),
                      items: ['Scheduled', 'In Progress', 'Completed', 'Cancelled'].map((s) {
                        return DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12, color: textPrimary)));
                      }).toList(),
                      onChanged: (val) { if (val != null) _updateStatus(job.id, val); },
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: AppColors.secondaryBlue, size: 18),
                      onPressed: () => _showAddEditJobDialog(job: job),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      onPressed: () => _deleteJob(job.id),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList(List<MaintenanceJobModel> jobs, {
    required bool isDark, required Color cardColor, required Color textPrimary, required Color textSecondary, required Color borderColor,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: borderColor),
      itemBuilder: (context, index) {
        final job = jobs[index];
        Color statusColor = Colors.orange;
        if (job.status == 'In Progress') statusColor = Colors.blue;
        if (job.status == 'Completed') statusColor = Colors.green;
        if (job.status == 'Cancelled') statusColor = Colors.redAccent;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(job.vehicleName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(job.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Title: ${job.title}', style: TextStyle(fontSize: 13, color: textPrimary)),
              Text('Cost: RM ${job.cost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
              Text('${job.startDate} → ${job.endDate}', style: TextStyle(fontSize: 12, color: textSecondary)),
              if (job.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(job.description, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: textSecondary)),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Status: ', style: TextStyle(fontSize: 12, color: textSecondary)),
                  DropdownButton<String>(
                    value: ['Scheduled', 'In Progress', 'Completed', 'Cancelled'].contains(job.status) ? job.status : 'Scheduled',
                    underline: const SizedBox(),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: textPrimary, fontSize: 12),
                    items: ['Scheduled', 'In Progress', 'Completed', 'Cancelled'].map((s) {
                      return DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12, color: textPrimary)));
                    }).toList(),
                    onChanged: (val) { if (val != null) _updateStatus(job.id, val); },
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: AppColors.secondaryBlue, size: 20),
                    onPressed: () => _showAddEditJobDialog(job: job),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _deleteJob(job.id),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusDropdown({required bool isDark, required Color cardColor, required Color textPrimary, required Color borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButton<String>(
        value: _selectedFilter,
        underline: const SizedBox(),
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
        items: ['All', 'Scheduled', 'In Progress', 'Completed', 'Cancelled'].map((s) {
          return DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: textPrimary, fontSize: 13)));
        }).toList(),
        onChanged: (val) { if (val != null) setState(() => _selectedFilter = val); },
      ),
    );
  }

  Widget _buildVehicleDropdown({required bool isDark, required Color cardColor, required Color textPrimary, required Color borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButton<String>(
        value: _selectedVehicleFilter,
        underline: const SizedBox(),
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(color: textPrimary, fontSize: 13),
        items: [
          DropdownMenuItem(value: 'All', child: Text('All Vehicles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary))),
          ..._vehicles.map((v) => DropdownMenuItem(
            value: v.id,
            child: Text('${v.brand} ${v.model}', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: textPrimary)),
          )),
        ],
        onChanged: (val) { if (val != null) setState(() => _selectedVehicleFilter = val); },
      ),
    );
  }
}
