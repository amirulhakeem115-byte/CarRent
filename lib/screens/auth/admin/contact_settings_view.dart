import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../services/database_service.dart';
import '../../../widgets/loading_widget.dart';

class ContactSettingsView extends StatefulWidget {
  const ContactSettingsView({super.key});

  @override
  State<ContactSettingsView> createState() => _ContactSettingsViewState();
}

class _ContactSettingsViewState extends State<ContactSettingsView> {
  final DatabaseService _databaseService = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _companyNameController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _headquartersAddressController = TextEditingController();
  final _businessHoursController = TextEditingController();
  final _whatsappNumberController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _supportPhoneController.dispose();
    _supportEmailController.dispose();
    _headquartersAddressController.dispose();
    _businessHoursController.dispose();
    _whatsappNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _databaseService.getContactSettings().timeout(const Duration(seconds: 10));
      if (settings != null && settings.isNotEmpty) {
        _companyNameController.text = settings['companyName'] ?? 'CARRENT PLATFORM';
        _supportPhoneController.text = settings['supportPhone'] ?? '+60 3-2274 1234';
        _supportEmailController.text = settings['supportEmail'] ?? 'support@carrent.com.my';
        _headquartersAddressController.text = settings['headquartersAddress'] ?? 
            'Level 15, Menara Shell\nJalan Tun Sambanthan, KL Sentral\n50470 Kuala Lumpur, Malaysia';
        _businessHoursController.text = settings['businessHours'] ?? 'Mon - Fri: 9:00 AM - 6:00 PM MYT';
        _whatsappNumberController.text = settings['whatsappNumber'] ?? '';
      } else {
        // Populate default fallbacks if database node is empty
        _companyNameController.text = 'CARRENT PLATFORM';
        _supportPhoneController.text = '+60 3-2274 1234';
        _supportEmailController.text = 'support@carrent.com.my';
        _headquartersAddressController.text = 
            'Level 15, Menara Shell\nJalan Tun Sambanthan, KL Sentral\n50470 Kuala Lumpur, Malaysia';
        _businessHoursController.text = 'Mon - Fri: 9:00 AM - 6:00 PM MYT';
        _whatsappNumberController.text = '';
      }
    } catch (e) {
      debugPrint('[CONTACT_SETTINGS] Error loading contact settings: $e');
      setState(() {
        _error = 'Failed to load contact configurations. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'companyName': _companyNameController.text.trim(),
        'supportPhone': _supportPhoneController.text.trim(),
        'supportEmail': _supportEmailController.text.trim(),
        'headquartersAddress': _headquartersAddressController.text.trim(),
        'businessHours': _businessHoursController.text.trim(),
        'whatsappNumber': _whatsappNumberController.text.trim(),
      };
      
      await _databaseService.updateContactSettings(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact information updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('[CONTACT_SETTINGS] Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingWidget(message: 'Syncing Contact Settings...'));
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
            ElevatedButton(onPressed: _loadSettings, child: const Text('Retry')),
          ],
        ),
      );
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 800;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact settings configuration',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
              ),
              Text(
                'Configure the headquarters address, phone numbers, email support channels, and hours shown to customers.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Form Container
          Expanded(
            child: SingleChildScrollView(
              child: Builder(
                builder: (context) {
                  final supportPhoneField = TextFormField(
                    controller: _supportPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Support Phone Number',
                      hintText: 'e.g., +60 3-2274 1234',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Phone number cannot be empty' : null,
                  );

                  final whatsappField = TextFormField(
                    controller: _whatsappNumberController,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp Number (Optional)',
                      hintText: 'e.g., +60 12-345 6789',
                      prefixIcon: Icon(Icons.chat_outlined),
                    ),
                  );

                  final formCard = Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _companyNameController,
                              decoration: const InputDecoration(
                                labelText: 'Company Name',
                                hintText: 'e.g., CARRENT SDN BHD',
                                prefixIcon: Icon(Icons.business_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            isDesktop
                                ? Row(
                                    children: [
                                      Expanded(child: supportPhoneField),
                                      const SizedBox(width: 16),
                                      Expanded(child: whatsappField),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      supportPhoneField,
                                      const SizedBox(height: 16),
                                      whatsappField,
                                    ],
                                  ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _supportEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Support Email Address',
                                hintText: 'e.g., support@carrent.com.my',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Support email is required';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return 'Enter a valid email address';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _businessHoursController,
                              decoration: const InputDecoration(
                                  labelText: 'Business Hours',
                                  hintText: 'e.g., Mon - Fri: 9:00 AM - 6:00 PM MYT',
                                  prefixIcon: Icon(Icons.access_time_outlined),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Business hours cannot be empty' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _headquartersAddressController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Headquarters Address',
                                hintText: 'e.g., Level 15, Menara Shell...',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Address cannot be empty' : null,
                            ),
                            const SizedBox(height: 32),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.borderGray),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    onPressed: _saving ? null : _loadSettings,
                                    child: const Text('Reset Changes', style: TextStyle(color: AppColors.secondaryBlue, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryOrange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    onPressed: _saving ? null : _saveSettings,
                                    child: _saving
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  final infoCard = Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How this is displayed',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'These details are bound in real-time to the Contact Support page. Customers can view coordinates, check business hours, send mail, and access phone hotlines based on these configuration sets.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.primaryOrange, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Live stream binding active',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryOrange),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );

                  return isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: formCard),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: infoCard),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            formCard,
                            const SizedBox(height: 24),
                            infoCard,
                          ],
                        );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
