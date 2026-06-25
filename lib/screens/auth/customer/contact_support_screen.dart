import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../services/database_service.dart';

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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _databaseService.createTicket(
        _subjectController.text.trim(),
        _messageController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support ticket created successfully! Our support team will get in touch with you shortly.'),
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
            content: Text('Failed to create ticket: ${e.toString()}'),
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
                    actionText: '+60 3-2274 1234',
                    isLink: true,
                  ),
                  if (!isDesktop) const SizedBox(height: 24),
                  _buildContactCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    description: 'Get a response within 2 business hours.',
                    actionText: 'support@carrent.com.my',
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

            // Form Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60.0 : 20.0),
              child: Container(
                padding: const EdgeInsets.all(32),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Send Us a Message',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Have a question or feedback? Drop us a line and we\'ll get back to you as soon as possible.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Enter your name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Email is required';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          hintText: 'What is this regarding?',
                          prefixIcon: Icon(Icons.subject_outlined),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Subject is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _messageController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          hintText: 'How can we help you?',
                          prefixIcon: Icon(Icons.message_outlined),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Message cannot be empty' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _submitting ? null : _submitForm,
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('SEND MESSAGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
            _buildMyTicketsSection(isDesktop),
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
                                      'Level 15, Menara Shell\nJalan Tun Sambanthan, KL Sentral\n50470 Kuala Lumpur, Malaysia',
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
                                    'Mon - Fri: 9:00 AM - 6:00 PM MYT',
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

  Widget _buildMyTicketsSection(bool isDesktop) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _databaseService.getTicketsStream(customerId: currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(color: AppColors.primaryOrange),
          ));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading tickets: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        final tickets = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'My Support Tickets',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track and reply to your conversation with our customer care agents.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            tickets.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Text(
                        'You have not submitted any support tickets yet.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
                      final String rawTime = msg['lastReplyAt'] ?? msg['createdAt'] ?? '';
                      
                      String fTime = '';
                      if (rawTime.isNotEmpty) {
                        try {
                          fTime = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(rawTime));
                        } catch (_) {
                          fTime = rawTime;
                        }
                      }

                      Color statusColor = Colors.orange;
                      if (status.toLowerCase() == 'pending') statusColor = Colors.blue;
                      if (status.toLowerCase() == 'closed') statusColor = Colors.green;

                      return Card(
                        color: const Color(0xFFF8F9FA),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
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
                                  backgroundColor: statusColor.withValues(alpha: 0.1),
                                  child: Icon(Icons.forum_outlined, color: statusColor, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subject,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Last Active: $fTime',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
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
      }
    );
  }

  void _showTicketDetailsChat(Map<String, dynamic> ticket) {
    final String id = ticket['id'] ?? '';
    final String subject = ticket['subject'] ?? 'No Subject';
    final replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _databaseService.getTicketsStream(),
                builder: (context, snap) {
                  String status = ticket['status'] ?? 'Open';
                  if (snap.hasData) {
                    try {
                      final currentTicket = snap.data!.firstWhere((t) => t['id'] == id);
                      status = currentTicket['status'] ?? 'Open';
                    } catch (_) {}
                  }
                  Color statusColor = Colors.orange;
                  if (status.toLowerCase() == 'pending') statusColor = Colors.blue;
                  if (status.toLowerCase() == 'closed') statusColor = Colors.green;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  );
                }
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
                Text('Ticket ID: #${id.toUpperCase()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const Divider(height: 24),
                const Text('Conversation History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondaryBlue)),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _databaseService.getTicketMessagesStream(id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
                      }
                      final messages = snapshot.data ?? [];
                      if (messages.isEmpty) {
                        return Center(child: Text('No messages yet.', style: TextStyle(color: Colors.grey[400], fontSize: 11)));
                      }
                      return ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final r = messages[index];
                          final bool isAdmin = r['senderRole'] == 'admin';
                          final String rTime = r['timestamp'] ?? '';
                          String fRTime = '';
                          if (rTime.isNotEmpty) {
                            try {
                              fRTime = DateFormat('hh:mm a').format(DateTime.parse(rTime));
                            } catch (_) {}
                          }

                          return Align(
                            alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isAdmin ? Colors.white : AppColors.primaryOrange,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isAdmin ? Radius.zero : const Radius.circular(12),
                                  bottomRight: isAdmin ? const Radius.circular(12) : Radius.zero,
                                ),
                                border: isAdmin ? Border.all(color: Colors.grey[200]!) : null,
                              ),
                              child: Column(
                                crossAxisAlignment: isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r['message'] ?? '',
                                    style: TextStyle(color: isAdmin ? Colors.black : Colors.white, fontSize: 12),
                                  ),
                                  if (fRTime.isNotEmpty)
                                    Text(
                                      fRTime,
                                      style: TextStyle(color: isAdmin ? Colors.grey : Colors.white60, fontSize: 8),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        decoration: const InputDecoration(
                          hintText: 'Type your reply message...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: AppColors.primaryOrange),
                      onPressed: () async {
                        final text = replyController.text.trim();
                        if (text.isEmpty) return;

                        try {
                          await _databaseService.sendTicketMessage(id, text, 'customer');
                          replyController.clear();
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

