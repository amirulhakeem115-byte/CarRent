import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../services/database_service.dart';
import '../../../services/company_settings_provider.dart';
import '../../../services/payment_restriction_service.dart';
import '../../../l10n/app_translations.dart';
import '../../../utils/url_launcher_helper.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _databaseService = DatabaseService();
  bool _submitting = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor =>
      _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor =>
      _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;
  Color get _borderColor =>
      _isDark ? const Color(0xFF334155) : AppColors.borderGray;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (PaymentRestrictionService().checkRestriction(context)) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _databaseService.createTicket(
        _subjectController.text.trim(),
        _messageController.text.trim(),
        senderName: _nameController.text.trim(),
        senderEmail: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Support ticket created successfully! Our support team will get in touch with you shortly.'.tr(context),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _nameController.clear();
        _emailController.clear();
        _subjectController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'Failed to create ticket:'.tr(context)} ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    final companySettings = context.watch<CompanySettingsProvider>();
    final String phone = companySettings.companyPhone;
    final String email = companySettings.companyEmail;
    final String address = companySettings.companyAddress;
    final String hours = companySettings.businessHours;
    final socialLinks = companySettings.socialMediaLinks;

    // Retrieve WhatsApp contact number from social links or support info
    final String rawWa = (socialLinks['whatsapp'] ??
            companySettings.supportContactInfo['whatsapp'] ??
            phone)
        .toString();
    final String whatsappNumber = rawWa.isEmpty ? phone : rawWa;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom + 24,
        ),
        child: Column(
          children: [
            // Hero Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                children: [
                  Text(
                    'Contact Support'.tr(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Our team is here to help you get back on the road. Reach out via any of the channels below and we\'ll assist you immediately.'
                        .tr(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: _subColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Three Interactive Contact Cards (WhatsApp + Phone + Email)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
              ),
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildContactCard(
                      icon: Icons.chat_bubble_rounded,
                      title: 'WhatsApp'.tr(context),
                      description:
                          'Chat live with our support team instantly on WhatsApp.'.tr(context),
                      actionText: whatsappNumber,
                      brandColor: const Color(0xFF25D366),
                      onTap: () => UrlLauncherHelper.openWhatsApp(whatsappNumber),
                    ),
                    _buildContactCard(
                      icon: Icons.phone_in_talk_outlined,
                      title: 'Phone'.tr(context),
                      description:
                          'Available 24/7 for urgent rental assistance.'.tr(context),
                      actionText: phone,
                      brandColor: AppColors.primaryOrange,
                      onTap: () => UrlLauncherHelper.openPhoneCall(phone),
                    ),
                    _buildContactCard(
                      icon: Icons.email_outlined,
                      title: 'Email'.tr(context),
                      description: 'Get a response within 2 business hours.'.tr(context),
                      actionText: email,
                      brandColor: Colors.blue,
                      onTap: () => UrlLauncherHelper.openEmail(email),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),

            // Send Us a Message form
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Send Us a Message'.tr(context),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Have a question or feedback? Drop us a line and we\'ll get back to you as soon as possible.'
                            .tr(context),
                        style: TextStyle(color: _subColor, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          labelText: 'Full Name'.tr(context),
                          labelStyle: TextStyle(color: _subColor),
                          hintText: 'Enter your name'.tr(context),
                          hintStyle: TextStyle(
                            color: _isDark ? Colors.white30 : Colors.grey,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: _subColor,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: _borderColor),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Name is required'.tr(context)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          labelText: 'Email Address'.tr(context),
                          labelStyle: TextStyle(color: _subColor),
                          hintText: 'Enter your email'.tr(context),
                          hintStyle: TextStyle(
                            color: _isDark ? Colors.white30 : Colors.grey,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: _subColor,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: _borderColor),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Email is required'.tr(context);
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) {
                            return 'Enter a valid email'.tr(context);
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _subjectController,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          labelText: 'Subject'.tr(context),
                          labelStyle: TextStyle(color: _subColor),
                          hintText: 'What is this regarding?'.tr(context),
                          hintStyle: TextStyle(
                            color: _isDark ? Colors.white30 : Colors.grey,
                          ),
                          prefixIcon: Icon(
                            Icons.subject_outlined,
                            color: _subColor,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: _borderColor),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Subject is required'.tr(context)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _messageController,
                        maxLines: 4,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          labelText: 'Message'.tr(context),
                          labelStyle: TextStyle(color: _subColor),
                          hintText: 'How can we help you?'.tr(context),
                          hintStyle: TextStyle(
                            color: _isDark ? Colors.white30 : Colors.grey,
                          ),
                          prefixIcon: Icon(
                            Icons.message_outlined,
                            color: _subColor,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: _borderColor),
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Message cannot be empty'.tr(context)
                            : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _submitting ? null : _submitForm,
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'SEND MESSAGE'.tr(context),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),

            // My Support Tickets
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
              ),
              child: _buildMyTicketsSection(),
            ),
            const SizedBox(height: 50),

            // Headquarters block — live from Firebase
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Flex(
                    direction: isDesktop ? Axis.horizontal : Axis.vertical,
                    children: [
                      // Address details — live from Firebase
                      Expanded(
                        flex: isDesktop ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Headquarters'.tr(context),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: AppColors.primaryOrange,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Directionality(
                                      textDirection: ui.TextDirection.ltr,
                                      child: Text(
                                        address,
                                        style: TextStyle(
                                          color: _subColor,
                                          height: 1.5,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    color: AppColors.primaryOrange,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Directionality(
                                      textDirection: ui.TextDirection.ltr,
                                      child: Text(
                                        hours,
                                        style: TextStyle(
                                          color: _subColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Decorative map visual
                      Expanded(
                        flex: isDesktop ? 1 : 0,
                        child: Container(
                          height: isDesktop ? 260 : 200,
                          color: _isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.15,
                                  child: Image.network(
                                    'https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&q=80&w=800',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.directions_car_filled_rounded,
                                    color: AppColors.primaryOrange,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),

            // Bottom WhatsApp Action Card
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Flex(
                  direction: isDesktop ? Axis.horizontal : Axis.vertical,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.chat_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                    Expanded(
                      flex: isDesktop ? 1 : 0,
                      child: Column(
                        crossAxisAlignment: isDesktop
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Direct WhatsApp Support'.tr(context),
                            textAlign:
                                isDesktop ? TextAlign.start : TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chat with our team directly on WhatsApp for instant assistance.'
                                .tr(context),
                            textAlign:
                                isDesktop ? TextAlign.start : TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDesktop) const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF128C7E),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        'CHAT NOW'.tr(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: () {
                        UrlLauncherHelper.openWhatsApp(whatsappNumber);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),

            // Social Media Channels Section — placed down at the bottom of the page
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
              ),
              child: _buildSocialMediaSection(socialLinks),
            ),
            const SizedBox(height: 50),

            // Footer
            _buildFooter(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    Color brandColor = AppColors.primaryOrange,
    VoidCallback? onTap,
  }) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: brandColor.withValues(alpha: 0.12),
                child: Icon(icon, color: brandColor, size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: _subColor, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 14, color: brandColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Text(
                          actionText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: brandColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialMediaSection(Map<String, dynamic> socialLinks) {
    final channels = [
      {
        'key': 'whatsapp',
        'label': 'WhatsApp'.tr(context),
        'icon': Icons.chat_rounded,
        'color': const Color(0xFF25D366),
        'url': (socialLinks['whatsapp'] ?? '').toString(),
        'isWhatsApp': true,
      },
      {
        'key': 'facebook',
        'label': 'Facebook'.tr(context),
        'icon': Icons.facebook_rounded,
        'color': const Color(0xFF1877F2),
        'url': (socialLinks['facebook'] ?? '').toString(),
        'isWhatsApp': false,
      },
      {
        'key': 'instagram',
        'label': 'Instagram'.tr(context),
        'icon': Icons.camera_alt_outlined,
        'color': const Color(0xFFE4405F),
        'url': (socialLinks['instagram'] ?? '').toString(),
        'isWhatsApp': false,
      },
      {
        'key': 'twitter',
        'label': 'Twitter'.tr(context),
        'icon': Icons.alternate_email_rounded,
        'color': const Color(0xFF1DA1F2),
        'url': (socialLinks['twitter'] ?? '').toString(),
        'isWhatsApp': false,
      },
      {
        'key': 'linkedin',
        'label': 'LinkedIn'.tr(context),
        'icon': Icons.work_outline_rounded,
        'color': const Color(0xFF0A66C2),
        'url': (socialLinks['linkedin'] ?? '').toString(),
        'isWhatsApp': false,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.share_rounded, color: AppColors.primaryOrange, size: 24),
              const SizedBox(width: 12),
              Text(
                'Social Media Channels'.tr(context),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Connect with us on our official social media accounts.'.tr(context),
            style: TextStyle(color: _subColor, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: channels.map((c) {
              final String url = (c['url'] as String).trim();
              if (url.isEmpty) return const SizedBox.shrink();
              final Color brandColor = c['color'] as Color;
              final bool isWa = c['isWhatsApp'] as bool;

              return ActionChip(
                elevation: 1,
                backgroundColor: brandColor.withValues(alpha: 0.1),
                side: BorderSide(color: brandColor.withValues(alpha: 0.3)),
                avatar: Icon(c['icon'] as IconData, size: 18, color: brandColor),
                label: Text(
                  c['label'] as String,
                  style: TextStyle(
                    color: brandColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  if (isWa) {
                    UrlLauncherHelper.openWhatsApp(url);
                  } else {
                    UrlLauncherHelper.launchURL(url);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTicketsSection() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _databaseService.getTicketsStream(customerId: currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            ),
          );
        }
        if (snapshot.hasError) {
          final raw = snapshot.error.toString();
          final isPermission = raw.toLowerCase().contains('permission-denied');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                isPermission
                    ? 'Support tickets access is currently denied by backend rules. Please retry after session refresh.'.tr(context)
                    : 'Error loading tickets: $raw',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        final tickets = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'My Support Tickets'.tr(context),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track and reply to your conversation with our customer care agents.'.tr(context),
              style: TextStyle(fontSize: 13, color: _subColor),
            ),
            const SizedBox(height: 16),
            tickets.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Center(
                      child: Text(
                        'You have not submitted any support tickets yet.'.tr(context),
                        style: TextStyle(color: _subColor, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      final msg = tickets[index];
                      final String subject = msg['subject'] ?? 'No Subject';
                      final String status = msg['status'] ?? 'Open';
                      final String rawTime =
                          msg['lastReplyAt'] ?? msg['createdAt'] ?? '';

                      String fTime = '';
                      if (rawTime.isNotEmpty) {
                        try {
                          fTime = DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(DateTime.parse(rawTime));
                        } catch (_) {
                          fTime = rawTime;
                        }
                      }

                      Color statusColor = Colors.orange;
                      if (status.toLowerCase() == 'pending' ||
                          status.toLowerCase() == 'in progress') {
                        statusColor = Colors.blue;
                      }
                      if (status.toLowerCase() == 'closed') {
                        statusColor = Colors.green;
                      }

                      return Card(
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _borderColor),
                        ),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showTicketDetailsChat(msg),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: statusColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.forum_outlined,
                                    color: statusColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subject,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: _textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Directionality(
                                        textDirection: ui.TextDirection.ltr,
                                        child: Text(
                                          '${'Last Active:'.tr(context)} $fTime',
                                          style: TextStyle(
                                            color: _subColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.toUpperCase().tr(context),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        );
      },
    );
  }

  void _showTicketDetailsChat(Map<String, dynamic> ticket) {
    final String id = ticket['id'] ?? '';
    final String subject = ticket['subject'] ?? 'No Subject';
    final String customerId =
        (ticket['customerId'] ??
                ticket['userId'] ??
                ticket['customerUid'] ??
                '')
            .toString();
    final bool isLegacyTicket = customerId.trim().isEmpty;
    final replyController = TextEditingController();
    final scrollController = ScrollController();

    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: _borderColor),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _databaseService.getTicketsStream(
                  customerId: FirebaseAuth.instance.currentUser?.uid,
                ),
                builder: (context, snap) {
                  String status = ticket['status'] ?? 'Open';
                  if (snap.hasData) {
                    try {
                      final currentTicket = snap.data!.firstWhere(
                        (t) => t['id'] == id,
                      );
                      status = currentTicket['status'] ?? 'Open';
                    } catch (_) {}
                  }
                  Color statusColor = Colors.orange;
                  if (status.toLowerCase() == 'pending' ||
                      status.toLowerCase() == 'in progress') {
                    statusColor = Colors.blue;
                  }
                  if (status.toLowerCase() == 'closed') {
                    statusColor = Colors.green;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase().tr(context),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Text(
                    'Ticket ID: #${id.toUpperCase()}',
                    style: TextStyle(fontSize: 10, color: _subColor),
                  ),
                ),
                if (isLegacyTicket) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade800,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This support ticket was created using an older version of the system.'.tr(context),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Conversation History'.tr(context),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _textColor,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Live Real-time Sync'.tr(context),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _databaseService.getTicketMessagesStream(id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryOrange,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'Error loading conversation: ${snapshot.error}',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      }
                      final messages = snapshot.data ?? [];
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            'No messages in this ticket yet.'.tr(context),
                            style: TextStyle(color: _subColor, fontSize: 11),
                          ),
                        );
                      }
                      scrollToBottom();
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final r = messages[index];
                          final bool isAdmin = r['senderRole'] == 'admin';
                          final String senderName =
                              r['senderName'] ??
                              (isAdmin ? 'Support Admin'.tr(context) : 'You'.tr(context));
                          final String senderRole =
                              (r['senderRole'] ?? 'customer').toUpperCase().tr(context);
                          final String rTime = r['timestamp'] ?? '';
                          String fRTime = '';
                          if (rTime.isNotEmpty) {
                            try {
                              fRTime = DateFormat(
                                'hh:mm a',
                              ).format(DateTime.parse(rTime));
                            } catch (_) {
                              fRTime = rTime;
                            }
                          }

                          return Align(
                            alignment: isAdmin
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 360),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? (_isDark
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFF1F5F9))
                                    : AppColors.primaryOrange,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: isAdmin
                                      ? Radius.zero
                                      : const Radius.circular(14),
                                  bottomRight: isAdmin
                                      ? const Radius.circular(14)
                                      : Radius.zero,
                                ),
                                border: isAdmin
                                    ? Border.all(color: _borderColor)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isAdmin
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        senderName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          color: isAdmin
                                              ? AppColors.primaryOrange
                                              : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAdmin
                                              ? AppColors.primaryOrange
                                                    .withValues(alpha: 0.2)
                                              : Colors.white24,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          senderRole,
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: isAdmin
                                                ? AppColors.primaryOrange
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    r['message'] ?? '',
                                    style: TextStyle(
                                      color: isAdmin
                                          ? _textColor
                                          : Colors.white,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (fRTime.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Directionality(
                                      textDirection: ui.TextDirection.ltr,
                                      child: Text(
                                        fRTime,
                                        style: TextStyle(
                                          color: isAdmin
                                              ? _subColor
                                              : Colors.white70,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        style: TextStyle(color: _textColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Type your reply message...'.tr(context),
                          hintStyle: TextStyle(
                            color: _isDark ? Colors.white30 : Colors.grey,
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: _borderColor),
                          ),
                        ),
                        onSubmitted: (val) async {
                          if (PaymentRestrictionService().checkRestriction(
                            context,
                          )) {
                            return;
                          }
                          final text = val.trim();
                          if (text.isEmpty) return;
                          replyController.clear();
                          try {
                            await _databaseService.sendTicketMessage(
                              id,
                              text,
                              'customer',
                            );
                            scrollToBottom();
                          } catch (e) {
                            debugPrint('Failed to send reply: $e');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: AppColors.primaryOrange,
                      ),
                      onPressed: () async {
                        if (PaymentRestrictionService().checkRestriction(
                          context,
                        )) {
                          return;
                        }
                        final text = replyController.text.trim();
                        if (text.isEmpty) return;
                        replyController.clear();
                        try {
                          await _databaseService.sendTicketMessage(
                            id,
                            text,
                            'customer',
                          );
                          scrollToBottom();
                        } catch (e) {
                          debugPrint('Failed to send reply: $e');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                scrollController.dispose();
                replyController.dispose();
                Navigator.pop(context);
              },
              child: Text(
                'Close'.tr(context),
                style: TextStyle(
                  color: _isDark ? const Color(0xFF94A3B8) : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60.0 : 20.0,
        vertical: 40.0,
      ),
      child: Column(
        children: [
          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: isDesktop
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Text(
                    CompanySettingsProvider().companyName.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      '© 2026 ${CompanySettingsProvider().companyName.toUpperCase()}. ALL RIGHTS RESERVED.',
                      style: TextStyle(color: _subColor, fontSize: 11),
                    ),
                  ),
                ],
              ),
              if (!isDesktop) const SizedBox(height: 24),
              isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFooterLink('Privacy Policy'.tr(context)),
                        const SizedBox(width: 16),
                        _buildFooterLink('Terms of Service'.tr(context)),
                        const SizedBox(width: 16),
                        _buildFooterLink('Fleet Management'.tr(context)),
                        const SizedBox(width: 16),
                        _buildFooterLink('Contact Us'.tr(context)),
                      ],
                    )
                  : Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildFooterLink('Privacy Policy'.tr(context)),
                        _buildFooterLink('Terms of Service'.tr(context)),
                        _buildFooterLink('Fleet Management'.tr(context)),
                        _buildFooterLink('Contact Us'.tr(context)),
                      ],
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return InkWell(
      onTap: () {},
      child: Text(
        text,
        style: TextStyle(
          color: _subColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
