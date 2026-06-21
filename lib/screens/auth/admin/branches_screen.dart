import 'package:flutter/material.dart';
import '../../../models/branch_model.dart';
import '../../../services/branch_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final BranchService _branchService = BranchService();

  List<BranchModel> _branches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _branches = await _branchService.getBranches().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error loading branches: $e');
      setState(() {
        _error = 'Failed to load branch list. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showAddEditBranchDialog({BranchModel? branch}) {
    final isEdit = branch != null;
    final nameController = TextEditingController(text: branch?.name);
    final addressController = TextEditingController(text: branch?.address);
    final phoneController = TextEditingController(text: branch?.phone);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(isEdit ? 'Edit Branch' : 'Add Branch Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Branch Name')),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameController.text.trim().isEmpty || addressController.text.trim().isEmpty) return;

                final name = nameController.text.trim();
                final address = addressController.text.trim();
                final phone = phoneController.text.trim();

                if (isEdit) {
                  await _branchService.updateBranch(branch.id, {
                    'name': name,
                    'address': address,
                    'phone': phone,
                  });
                } else {
                  final newBranch = BranchModel(id: '', name: name, address: address, phone: phone);
                  await _branchService.addBranch(newBranch);
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                _loadBranches();
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Branch'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBranch(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Branch'),
        content: const Text('Are you sure you want to delete this branch? Vehicles assigned to it will need to be reallocated.'),
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
      await _branchService.deleteBranch(id);
      _loadBranches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Manage Branches', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: LoadingWidget(message: 'Loading branch locations...'))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1A237E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadBranches,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry Loading'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
          : _branches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No branch locations registered', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _branches.length,
                  itemBuilder: (context, index) {
                    final branch = _branches[index];
                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF1A237E),
                              foregroundColor: Colors.white,
                              child: Icon(Icons.location_on),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(branch.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text(branch.address, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  Text('Phone: ${branch.phone}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showAddEditBranchDialog(branch: branch),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _deleteBranch(branch.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A237E),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddEditBranchDialog(),
      ),
    );
  }
}
