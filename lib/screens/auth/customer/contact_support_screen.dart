import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../widgets/custom_app_bar.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Back Arrow Row
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
                vertical: 20.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.secondaryBlue, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // Hero Headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Text(
                    'Contact Support',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondaryBlue,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Our team is here to help you get back on the road. Reach out via any of the channels below and we\'ll assist you immediately.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Grid of 3 Cards
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60.0 : 20.0),
              child: Flex(
                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildContactCard(
                    icon: Icons.phone_in_talk_outlined,
                    title: 'Phone',
                    description: 'Available 24/7 for urgent rental assistance.',
                    actionText: '+1 (800) CAR-RENT',
                    isLink: true,
                  ),
                  if (!isDesktop) const SizedBox(height: 24),
                  _buildContactCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    description: 'Get a response within 2 business hours.',
                    actionText: 'support@carrent.com',
                    isLink: true,
                  ),
                  if (!isDesktop) const SizedBox(height: 24),
                  _buildContactCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Live Chat',
                    description: 'Chat now with our automotive experts.',
                    actionText: 'Start Chat',
                    isButton: true,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Starting live chat connection with our support agents...'),
                          backgroundColor: AppColors.primaryOrange,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),

            // Headquarters segment
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60.0 : 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
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
                      // Address details
                      Expanded(
                        flex: isDesktop ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Headquarters',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryBlue,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined, color: AppColors.primaryOrange, size: 24),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      '1200 Innovation Way\nSuite 400, Silicon Valley\nCA 94025, United States',
                                      style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, color: AppColors.primaryOrange, size: 24),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Mon - Fri: 9:00 AM - 6:00 PM PST',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Mock map visual
                      Expanded(
                        flex: isDesktop ? 1 : 0,
                        child: Container(
                          height: isDesktop ? 260 : 200,
                          color: const Color(0xFFE2E8F0),
                          child: Stack(
                            children: [
                              // Abstract gridlines representation
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.15,
                                  child: Image.network(
                                    'https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&q=80&w=800',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // Location pin
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
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
            const SizedBox(height: 80),

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
    bool isLink = false,
    bool isButton = false,
    VoidCallback? onTap,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
            child: Icon(icon, color: AppColors.primaryOrange, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (isLink)
            Text(
              actionText,
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          if (isButton)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: onTap,
              child: Text(
                actionText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      color: const Color(0xFFFFFBEB),
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
                crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  const Text(
                    'CARRENT PLATFORM',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondaryBlue,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2026 CARRENT PLATFORM. ALL RIGHTS RESERVED.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
              if (!isDesktop) const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFooterLink('Privacy Policy'),
                  const SizedBox(width: 16),
                  _buildFooterLink('Terms of Service'),
                  const SizedBox(width: 16),
                  _buildFooterLink('Fleet Management'),
                  const SizedBox(width: 16),
                  _buildFooterLink('Contact Us'),
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
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
