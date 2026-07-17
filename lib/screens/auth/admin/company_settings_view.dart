import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../services/company_settings_provider.dart';
import '../../../widgets/app_image.dart';

class CompanySettingsView extends StatefulWidget {
  const CompanySettingsView({super.key});

  @override
  State<CompanySettingsView> createState() => _CompanySettingsViewState();
}

class _CompanySettingsViewState extends State<CompanySettingsView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  int _activeTab = 0;

  // Controllers
  final _companyNameController = TextEditingController();
  final _companyRegNoController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _businessHoursController = TextEditingController();
  final _companyDescriptionController = TextEditingController();
  final _openingTimeController = TextEditingController();
  final _closingTimeController = TextEditingController();
  final _silverThresholdController = TextEditingController();
  final _goldThresholdController = TextEditingController();
  final _premiumThresholdController = TextEditingController();

  // Socials
  final _socialWhatsappController = TextEditingController();
  final _socialFacebookController = TextEditingController();
  final _socialInstagramController = TextEditingController();
  final _socialTwitterController = TextEditingController();
  final _socialLinkedinController = TextEditingController();

  // Support
  final _supportWhatsappController = TextEditingController();
  final _supportHotlineController = TextEditingController();
  final _supportEmailController = TextEditingController();

  String? _logoUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    _populateFields();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _companyRegNoController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _companyWebsiteController.dispose();
    _companyAddressController.dispose();
    _businessHoursController.dispose();
    _companyDescriptionController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _silverThresholdController.dispose();
    _goldThresholdController.dispose();
    _premiumThresholdController.dispose();
    _socialWhatsappController.dispose();
    _socialFacebookController.dispose();
    _socialInstagramController.dispose();
    _socialTwitterController.dispose();
    _socialLinkedinController.dispose();
    _supportWhatsappController.dispose();
    _supportHotlineController.dispose();
    _supportEmailController.dispose();
    super.dispose();
  }

  void _populateFields() {
    final provider = Provider.of<CompanySettingsProvider>(
      context,
      listen: false,
    );
    _companyNameController.text = provider.companyName;
    _companyRegNoController.text = provider.companyRegistrationNumber;
    _companyPhoneController.text = provider.companyPhone;
    _companyEmailController.text = provider.companyEmail;
    _companyWebsiteController.text = provider.companyWebsite;
    _companyAddressController.text = provider.companyAddress;
    _businessHoursController.text = provider.businessHours;
    _companyDescriptionController.text = provider.companyDescription;
    _openingTimeController.text = provider.openingTime;
    _closingTimeController.text = provider.closingTime;

    final social = provider.socialMediaLinks;
    _socialWhatsappController.text = social['whatsapp']?.toString() ?? '';
    _socialFacebookController.text = social['facebook']?.toString() ?? '';
    _socialInstagramController.text = social['instagram']?.toString() ?? '';
    _socialTwitterController.text = social['twitter']?.toString() ?? '';
    _socialLinkedinController.text = social['linkedin']?.toString() ?? '';

    final support = provider.supportContactInfo;
    _supportWhatsappController.text = support['whatsapp']?.toString() ?? '';
    _supportHotlineController.text = support['hotline']?.toString() ?? '';
    _supportEmailController.text = support['email']?.toString() ?? '';
    _silverThresholdController.text = provider.silverThreshold.toString();
    _goldThresholdController.text = provider.goldThreshold.toString();
    _premiumThresholdController.text = provider.premiumThreshold.toString();

    _logoUrl = provider.companyLogo;
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (pickedFile == null) return;

      setState(() => _saving = true);
      final bytes = await pickedFile.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      setState(() {
        _logoUrl = base64String;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo loaded. Press Save Settings to publish!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('[COMPANY_SETTINGS] Error picking logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Picking image failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      if (!mounted) return;
      final now = DateTime.now();
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      final formatted = DateFormat('hh:mm a').format(dt);
      setState(() {
        controller.text = formatted;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final data = {
        'companyName': _companyNameController.text.trim(),
        'companyRegistrationNumber': _companyRegNoController.text.trim(),
        'companyPhone': _companyPhoneController.text.trim(),
        'companyEmail': _companyEmailController.text.trim(),
        'companyWebsite': _companyWebsiteController.text.trim(),
        'companyAddress': _companyAddressController.text.trim(),
        'businessHours': _businessHoursController.text.trim(),
        'companyDescription': _companyDescriptionController.text.trim(),
        'openingTime': _openingTimeController.text.trim(),
        'closingTime': _closingTimeController.text.trim(),
        'companyLogo': _logoUrl ?? '',
        'socialMediaLinks': {
          'whatsapp': _socialWhatsappController.text.trim(),
          'facebook': _socialFacebookController.text.trim(),
          'instagram': _socialInstagramController.text.trim(),
          'twitter': _socialTwitterController.text.trim(),
          'linkedin': _socialLinkedinController.text.trim(),
        },
        'supportContactInfo': {
          'whatsapp': _supportWhatsappController.text.trim(),
          'hotline': _supportHotlineController.text.trim(),
          'email': _supportEmailController.text.trim(),
        },
        'silverThreshold':
            int.tryParse(_silverThresholdController.text.trim()) ?? 500,
        'goldThreshold':
            int.tryParse(_goldThresholdController.text.trim()) ?? 1000,
        'premiumThreshold':
            int.tryParse(_premiumThresholdController.text.trim()) ?? 2000,
      };

      final provider = Provider.of<CompanySettingsProvider>(
        context,
        listen: false,
      );
      debugPrint('Writing settings to Firebase path: /company_settings');
      await provider.updateSettings(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[COMPANY_SETTINGS] Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF8FAFC);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
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
                          Text(
                            'Company Settings Configuration',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Configure company name, registration, contact channels, and branding.',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      _buildSaveButton(),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Configure company profile, contacts, and branding.',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _buildSaveButton(),
                      ),
                    ],
                  ),
            const SizedBox(height: 20),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: textSecondary,
                indicatorColor: AppColors.primaryOrange,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                isScrollable: !isDesktop,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.business_outlined, size: 18),
                    text: 'Branding & Profile',
                  ),
                  Tab(
                    icon: Icon(Icons.share_outlined, size: 18),
                    text: 'Social Channels',
                  ),
                  Tab(
                    icon: Icon(Icons.support_agent_outlined, size: 18),
                    text: 'Support & Hotline',
                  ),
                  Tab(
                    icon: Icon(Icons.stars_rounded, size: 18),
                    text: 'Membership Thresholds',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Main Content Area — no Expanded, just natural column
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildActiveTabContent(
                          isDark: isDark,
                          cardColor: cardColor,
                          surfaceColor: surfaceColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: _buildPreviewCard(
                          isDark: isDark,
                          cardColor: cardColor,
                          surfaceColor: surfaceColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildActiveTabContent(
                        isDark: isDark,
                        cardColor: cardColor,
                        surfaceColor: surfaceColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: 24),
                      _buildPreviewCard(
                        isDark: isDark,
                        cardColor: cardColor,
                        surfaceColor: surfaceColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      onPressed: _saving ? null : _saveSettings,
      icon: _saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.save_outlined, size: 20),
      label: const Text(
        'Save Settings',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActiveTabContent({
    required bool isDark,
    required Color cardColor,
    required Color surfaceColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final Widget tabContent;
    switch (_activeTab) {
      case 1:
        tabContent = _buildSocialsTab(
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
        break;
      case 2:
        tabContent = _buildSupportTab(
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
        break;
      case 3:
        tabContent = _buildMembershipTab(
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
        break;
      default:
        tabContent = _buildProfileTab(
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(24),
      child: tabContent,
    );
  }

  Widget _buildProfileTab({
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Branding Profile Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyNameController,
          decoration: const InputDecoration(
            labelText: 'Company Name',
            hintText: 'e.g. CARRENT PLATFORM SDN BHD',
            prefixIcon: Icon(Icons.business_outlined),
          ),
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Company name is required'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyRegNoController,
          decoration: const InputDecoration(
            labelText: 'Company Registration Number',
            hintText: 'e.g. 202601023456 (1234567-X)',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Registration number is required'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyWebsiteController,
          decoration: const InputDecoration(
            labelText: 'Company Website',
            hintText: 'e.g. www.carrent.com.my',
            prefixIcon: Icon(Icons.language_outlined),
          ),
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Website URL is required'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _businessHoursController,
          decoration: const InputDecoration(
            labelText: 'Business Hours Description',
            hintText: 'e.g. Mon - Fri: 9:00 AM - 6:00 PM MYT',
            prefixIcon: Icon(Icons.access_time_outlined),
          ),
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Business hours details required'
              : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _openingTimeController,
                readOnly: true,
                onTap: () => _selectTime(_openingTimeController),
                decoration: const InputDecoration(
                  labelText: 'Opening Time',
                  prefixIcon: Icon(Icons.alarm_on_outlined),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _closingTimeController,
                readOnly: true,
                onTap: () => _selectTime(_closingTimeController),
                decoration: const InputDecoration(
                  labelText: 'Closing Time',
                  prefixIcon: Icon(Icons.alarm_off_outlined),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyAddressController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Headquarters Address',
            hintText: 'Full physical building address',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Physical address required'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyDescriptionController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Company Description',
            hintText: 'Short brand description shown to guests',
            prefixIcon: Icon(Icons.description_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialsTab({
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Social Media Connections',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add URLs to configure the clickable handles in app footers.',
          style: TextStyle(fontSize: 11, color: textSecondary),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _socialWhatsappController,
          decoration: const InputDecoration(
            labelText: 'WhatsApp Connection API URL',
            hintText: 'e.g., https://wa.me/60123456789',
            prefixIcon: Icon(Icons.chat_bubble_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _socialFacebookController,
          decoration: const InputDecoration(
            labelText: 'Facebook Brand URL',
            hintText: 'e.g., https://facebook.com/carrent',
            prefixIcon: Icon(Icons.facebook_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _socialInstagramController,
          decoration: const InputDecoration(
            labelText: 'Instagram Profile URL',
            hintText: 'e.g., https://instagram.com/carrent',
            prefixIcon: Icon(Icons.camera_alt_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _socialTwitterController,
          decoration: const InputDecoration(
            labelText: 'Twitter Profile URL',
            hintText: 'e.g., https://twitter.com/carrent',
            prefixIcon: Icon(Icons.alternate_email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _socialLinkedinController,
          decoration: const InputDecoration(
            labelText: 'LinkedIn Corporate URL',
            hintText: 'e.g., https://linkedin.com/company/carrent',
            prefixIcon: Icon(Icons.work_outline),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportTab({
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Support Configuration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _companyPhoneController,
          decoration: const InputDecoration(
            labelText: 'Global Support Phone Hotline',
            hintText: 'e.g., +60 3-2274 1234',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Phone hotline required'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyEmailController,
          decoration: const InputDecoration(
            labelText: 'Support Email Address',
            hintText: 'e.g., support@carrent.com.my',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty)
              return 'Support email required';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val))
              return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Additional Support Desk Channels',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _supportWhatsappController,
          decoration: const InputDecoration(
            labelText: 'Support Desk WhatsApp Contact',
            hintText: 'e.g., +60 12-345 6789',
            prefixIcon: Icon(Icons.chat_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _supportHotlineController,
          decoration: const InputDecoration(
            labelText: 'Support Desk Hotline',
            hintText: 'e.g., +60 3-2274 1234',
            prefixIcon: Icon(Icons.call_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _supportEmailController,
          decoration: const InputDecoration(
            labelText: 'Support Desk Email',
            hintText: 'e.g., support@carrent.com.my',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipTab({
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Membership Level Thresholds Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure reward point thresholds for automatic membership tier assignments.',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _silverThresholdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Silver Level Threshold (Points)',
            hintText: 'e.g. 500',
            prefixIcon: Icon(Icons.verified_user_rounded),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty)
              return 'Silver threshold is required';
            final parsed = int.tryParse(val);
            if (parsed == null || parsed < 0)
              return 'Must be a positive integer';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _goldThresholdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Gold Level Threshold (Points)',
            hintText: 'e.g. 1000',
            prefixIcon: Icon(Icons.stars_rounded),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty)
              return 'Gold threshold is required';
            final parsed = int.tryParse(val);
            if (parsed == null || parsed < 0)
              return 'Must be a positive integer';
            final silverVal = int.tryParse(_silverThresholdController.text);
            if (silverVal != null && parsed <= silverVal)
              return 'Gold threshold must be higher than Silver';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _premiumThresholdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Premium Level Threshold (Points)',
            hintText: 'e.g. 2000',
            prefixIcon: Icon(Icons.military_tech_rounded),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty)
              return 'Premium threshold is required';
            final parsed = int.tryParse(val);
            if (parsed == null || parsed < 0)
              return 'Must be a positive integer';
            final goldVal = int.tryParse(_goldThresholdController.text);
            if (goldVal != null && parsed <= goldVal)
              return 'Premium threshold must be higher than Gold';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPreviewCard({
    required bool isDark,
    required Color cardColor,
    required Color surfaceColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Corporate Logo & Preview',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: _logoUrl != null && _logoUrl!.isNotEmpty
                ? AppImage(
                    imageSrc: _logoUrl!,
                    fit: BoxFit.contain,
                    placeholder: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 50,
                        color: textSecondary,
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car_filled_rounded,
                          size: 48,
                          color: textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No Custom Corporate Logo',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryOrange),
              foregroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _pickLogo,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(
              _logoUrl != null && _logoUrl!.isNotEmpty
                  ? 'Replace Corporate Logo'
                  : 'Upload Corporate Logo',
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: borderColor),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.primaryOrange,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Global Updates Enabled',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Changes to the logo and company metadata will immediately update all invoices, public landing pages, PDFs, and drawer titles in real-time.',
            style: TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
