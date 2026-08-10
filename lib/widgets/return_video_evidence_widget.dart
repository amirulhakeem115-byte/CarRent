import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../models/booking_model.dart';
import 'app_video_player_widget.dart';

class ReturnVideoEvidenceWidget extends StatelessWidget {
  final BookingModel booking;
  final bool isCustomerView;
  final bool isEmployeeView;
  final bool isAdminView;
  final VoidCallback? onUploadClick;

  const ReturnVideoEvidenceWidget({
    super.key,
    required this.booking,
    this.isCustomerView = false,
    this.isEmployeeView = false,
    this.isAdminView = false,
    this.onUploadClick,
  });

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
    } catch (_) {
      return isoString;
    }
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return '';
    final int bytes = size is int ? size : (int.tryParse(size.toString()) ?? 0);
    if (bytes <= 0) return '';
    final double mb = bytes / (1024 * 1024);
    return ' (${mb.toStringAsFixed(2)} MB)';
  }

  void _openVideoUrl(BuildContext context, String url, {String? title, dynamic fileSize}) {
    if (url.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.video_library_rounded, color: AppColors.primaryOrange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title ?? 'Return Video Evidence Player',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : AppColors.secondaryBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppVideoPlayerWidget(
                  videoUrl: url,
                  title: title,
                  fileSize: fileSize,
                  autoPlay: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    final videos = booking.returnVideosList;
    final customerVideo = booking.customerReturnVideo;
    final bool hasCustVid = customerVideo != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.video_library_rounded, color: AppColors.primaryOrange, size: 22),
              const SizedBox(width: 10),
              Text(
                'Return Video Evidence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary),
              ),
              const Spacer(),
              if (videos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${videos.length} VIDEO EVIDENCE',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),

          // ── EMPLOYEE SPECIFIC NOTICE & FALLBACK ──
          if (isEmployeeView) ...[
            if (hasCustVid) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.teal, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Customer has already uploaded a return video.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            booking.returnVideoSkipped ? 'Customer skipped return video upload.' : 'Customer did not upload a return video.',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                    if (onUploadClick != null) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: onUploadClick,
                        icon: const Icon(Icons.video_call_rounded, size: 18),
                        label: const Text('Upload Employee Return Video'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

          // ── EMPTY STATE ──
          if (videos.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.no_photography_outlined, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      booking.returnVideoSkipped ? 'Return video skipped by customer.' : 'No return video evidence uploaded yet.',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                    ),
                    if (isCustomerView && onUploadClick != null) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
                        onPressed: onUploadClick,
                        icon: const Icon(Icons.videocam_rounded),
                        label: const Text('Upload Return Video'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            // ── CHRONOLOGICAL VIDEO LIST ──
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: videos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final vMap = videos[idx];
                final role = (vMap['uploaderRole']?.toString().toLowerCase() ?? 'customer');
                final isCustomer = role == 'customer';

                final roleColor = isCustomer ? Colors.teal : AppColors.primaryOrange;
                final roleLabel = isCustomer ? 'CUSTOMER VIDEO' : 'EMPLOYEE VIDEO';
                final uploaderName = vMap['uploaderName']?.toString() ?? (isCustomer ? 'Customer' : 'Staff Employee');
                final uploadTime = _formatDateTime(vMap['uploadedAt']?.toString());
                final fileSizeStr = _formatFileSize(vMap['fileSize']);
                final videoUrl = vMap['videoUrl']?.toString() ?? '';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: roleColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              roleLabel,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Uploaded by $uploaderName',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload Time: $uploadTime$fileSizeStr',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        'Booking ID: #${booking.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),

                      // Video Player Preview Card
                      InkWell(
                        onTap: () => _openVideoUrl(
                          context,
                          videoUrl,
                          title: '$roleLabel - $uploaderName',
                          fileSize: vMap['fileSize'],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 110,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                  : [Colors.grey.shade900, Colors.black87],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: roleColor,
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap to Watch ${isCustomer ? "Customer" : "Employee"} Evidence Video',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('MP4', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            if (onUploadClick != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryOrange),
                  onPressed: onUploadClick,
                  icon: const Icon(Icons.video_call_rounded),
                  label: Text(isCustomerView ? 'Upload Replacement Return Video' : 'Upload Additional Evidence Video'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
