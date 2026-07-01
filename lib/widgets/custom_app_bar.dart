import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../screens/auth/customer/home_screen.dart';
import '../screens/auth/customer/vehicle_list_screen.dart';
import '../screens/auth/customer/profile_screen.dart';
import '../screens/auth/customer/contact_support_screen.dart';
import '../services/company_settings_provider.dart';
import 'app_logo.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 750;

    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AppColors.primaryOrange,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Branding logo matching Image References
            InkWell(
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
                  (route) => false,
                );
              },
              child: Row(
                children: [
                  const AppLogo(size: 24, fallbackColor: AppColors.secondaryBlue),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.watch<CompanySettingsProvider>().companyName,
                        style: const TextStyle(
                          color: AppColors.secondaryBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Text(
                        'SINCE 2026',
                        style: TextStyle(
                          color: AppColors.secondaryBlue,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Navigation Links
            Row(
              children: [
                _buildNavLink(
                  context,
                  'HOME',
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
                      (route) => false,
                    );
                  },
                ),
                SizedBox(width: isDesktop ? 30 : 12),
                _buildNavLink(
                  context,
                  'CAR DETAILS',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VehicleListScreen()),
                    );
                  },
                ),
                SizedBox(width: isDesktop ? 30 : 12),
                _buildNavLink(
                  context,
                  'CONTACT INFO',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
                    );
                  },
                ),
              ],
            ),
            
            // Profile icon on the right
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.secondaryBlue,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLink(BuildContext context, String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.secondaryBlue,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
