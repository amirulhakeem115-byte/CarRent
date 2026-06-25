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
  String _selectedFilter = 'All'; // 'All', 'Pending', 'In Progress', 'Completed'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
      _jobs = await _maintenanceService.getMaintenanceJobs().timeout(const Duration(seconds: 10));
      _vehicles = await _vehicleService.getVehicles().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error loading maintenance data: $e');
      setState(() {
        _error = 'Failed to load maintenance records. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
    try {
      final job = _jobs.firstWhere((j) => j.id == jobId);
      if (status == 'Completed') {
        await _vehicleService.updateVehicleStatus(job.vehicleId, 'available');
      } else if (status == 'In Progress') {
        await _vehicleService.updateVehicleStatus(job.vehicleId, 'maintenance');
      } else if (status == 'Pending') {
        await _vehicleService.updateVehicleStatus(job.vehicleId, 'available');
      }
    } catch (e) {
      debugPrint('Error updating vehicle status on maintenance status change: $e');
    }
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
    final typeController = TextEditingController(text: job?.serviceType);
    final costController = TextEditingController(text: job != null ? job.cost.toString() : '');
    final notesController = TextEditingController(text: job?.notes);
    DateTime selectedDate = job != null
        ? (DateTime.tryParse(job.date) ?? DateTime.now())
        : DateTime.now();
    bool showToCustomer = job?.showToCustomer ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(isEdit ? 'Edit Maintenance Record' : 'Schedule Maintenance', 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<VehicleModel>(
                      initialValue: selectedVehicle,
                      decoration: const InputDecoration(labelText: 'Select Vehicle'),
                      items: _vehicles.map((v) {
                        return DropdownMenuItem(
                          value: v,
                          child: Text('${v.brand} ${v.model} (${v.plateNumber})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedVehicle = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(labelText: 'Service / Repair Type', hintText: 'e.g., Oil Change, Tyre Alignment'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Est. Cost (RM)', hintText: 'e.g., 250.00'),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Service Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes / Remarks', hintText: 'Optional special remarks...'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Show to Customer', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Allow customers to view this maintenance record in vehicle details', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      value: showToCustomer,
                      activeThumbColor: AppColors.primaryOrange,
                      onChanged: (val) {
                        setDialogState(() {
                          showToCustomer = val;
                        });
                      },
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
                    if (typeController.text.trim().isEmpty) return;
                    final cost = double.tryParse(costController.text.trim()) ?? 0.0;
                    
                    if (isEdit) {
                      final updatedData = {
                        'vehicleId': selectedVehicle.id,
                        'vehicleName': '${selectedVehicle.brand} ${selectedVehicle.model}',
                        'serviceType': typeController.text.trim(),
                        'cost': cost,
                        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                        'notes': notesController.text.trim(),
                        'showToCustomer': showToCustomer,
                      };
                      await _maintenanceService.updateMaintenanceJob(job.id, updatedData);
                    } else {
                      final newJob = MaintenanceJobModel(
                        id: '',
                        vehicleId: selectedVehicle.id,
                        vehicleName: '${selectedVehicle.brand} ${selectedVehicle.model}',
                        serviceType: typeController.text.trim(),
                        cost: cost,
                        date: DateFormat('yyyy-MM-dd').format(selectedDate),
                        notes: notesController.text.trim(),
                        status: 'Pending',
                        showToCustomer: showToCustomer,
                      );
                      await _maintenanceService.addMaintenanceJob(newJob);
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

    // Calculations
    final totalJobs = _jobs.length;
    final activeJobs = _jobs.where((j) => j.status == 'In Progress').length;
    final completedJobs = _jobs.where((j) => j.status == 'Completed').length;
    double totalCost = 0.0;
    for (var j in _jobs) {
      totalCost += j.cost;
    }

    // Filters
    final filteredJobs = _jobs.where((job) {
      final matchesStatus = _selectedFilter == 'All' || job.status.toLowerCase() == _selectedFilter.toLowerCase();
      final matchesSearch = job.vehicleName.toLowerCase().contains(_searchQuery) ||
          job.serviceType.toLowerCase().contains(_searchQuery) ||
          job.notes.toLowerCase().contains(_searchQuery);
      return matchesStatus && matchesSearch;
    }).toList();

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title + Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Maintenance Log',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                  ),
                  Text(
                    'Track fleet repairs, scheduled tune-ups, and cost reports.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
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
              _buildStatCard('Total Service Jobs', totalJobs.toString(), Icons.build, Colors.indigo),
              _buildStatCard('Active Jobs', activeJobs.toString(), Icons.hourglass_empty, Colors.orange),
              _buildStatCard('Completed Jobs', completedJobs.toString(), Icons.check_circle_outline, Colors.green),
              _buildStatCard('Total Cost', 'RM ${totalCost.toStringAsFixed(2)}', Icons.monetization_on_outlined, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 24),

          // Filters & Search Box
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
                        hintText: 'Search by vehicle, service type, or remarks...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      underline: const SizedBox(),
                      items: ['All', 'Pending', 'In Progress', 'Completed'].map((s) {
                        return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedFilter = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // List / Table
          Expanded(
            child: filteredJobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.build_circle_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No service logs found matching filters.', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: isDesktop ? _buildDesktopTable(filteredJobs) : _buildMobileList(filteredJobs),
                  ),
          ),
        ],
      ),
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

  Widget _buildDesktopTable(List<MaintenanceJobModel> jobs) {
    return ListView(
      children: [
        DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Service Type', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Cost (RM)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: jobs.map((job) {
            Color statusColor = Colors.orange;
            if (job.status == 'In Progress') statusColor = Colors.blue;
            if (job.status == 'Completed') statusColor = Colors.green;

            return DataRow(
              cells: [
                DataCell(Text(job.vehicleName, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(job.serviceType)),
                DataCell(Text('RM ${job.cost.toStringAsFixed(2)}')),
                DataCell(Text(job.date)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      job.status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataCell(Text(job.notes.isNotEmpty ? job.notes : 'N/A')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: job.status,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.edit_note, size: 18),
                        items: ['Pending', 'In Progress', 'Completed'].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _updateStatus(job.id, val);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.secondaryBlue, size: 18),
                        onPressed: () => _showAddEditJobDialog(job: job),
                      ),
                      const SizedBox(width: 8),
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
      ],
    );
  }

  Widget _buildMobileList(List<MaintenanceJobModel> jobs) {
    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        Color statusColor = Colors.orange;
        if (job.status == 'In Progress') statusColor = Colors.blue;
        if (job.status == 'Completed') statusColor = Colors.green;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(job.vehicleName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        job.status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Service: ${job.serviceType}', style: const TextStyle(fontSize: 13)),
                Text('Cost: RM ${job.cost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                Text('Scheduled: ${job.date}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (job.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Notes: ${job.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Status: ', style: TextStyle(fontSize: 12)),
                    DropdownButton<String>(
                      value: job.status,
                      underline: const SizedBox(),
                      items: ['Pending', 'In Progress', 'Completed'].map((s) {
                        return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _updateStatus(job.id, val);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.secondaryBlue, size: 20),
                      onPressed: () => _showAddEditJobDialog(job: job),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteJob(job.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
