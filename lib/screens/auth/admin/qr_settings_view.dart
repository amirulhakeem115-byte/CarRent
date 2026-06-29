import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../constants/colors.dart';
import '../../../services/database_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/app_image.dart';

class QrSettingsView extends StatefulWidget {
  const QrSettingsView({super.key});

  @override
  State<QrSettingsView> createState() => _QrSettingsViewState();
}

class _QrSettingsViewState extends State<QrSettingsView> {
  final DatabaseService _databaseService = DatabaseService();

  final _bankNameController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  
  bool _isEnabled = true;
  String? _qrCodeUrl;
  String? _bankLogoUrl;
  
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
    _bankNameController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _databaseService.getQrPaymentSettings().timeout(const Duration(seconds: 10));
      debugPrint('[QR_SETTINGS] Firebase load success: ${settings != null}');
      if (settings != null) {
        _bankNameController.text = settings['bankName'] ?? '';
        _accountNameController.text = settings['accountName'] ?? '';
        _accountNumberController.text = settings['accountNumber'] ?? '';
        _isEnabled = settings['isEnabled'] ?? true;
        _qrCodeUrl = settings['qrCodeBase64'] ?? settings['qrCodeUrl'];
        _bankLogoUrl = settings['bankLogoUrl'];
      }
    } catch (e) {
      debugPrint('[QR_SETTINGS] Error loading QR settings: $e');
      setState(() {
        _error = 'Failed to load QR configurations. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickImage(bool isQrCode) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 35,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (pickedFile == null) return;

      setState(() => _saving = true);
      final bytes = await pickedFile.readAsBytes();
      
      debugPrint('[QR_SETTINGS] Image selected: ${pickedFile.name}');
      debugPrint('[QR_SETTINGS] Image bytes length: ${bytes.length}');
      
      final base64Url = await _databaseService.uploadSettingsImage(bytes, pickedFile.name);
      debugPrint('[QR_SETTINGS] Base64 length: ${base64Url.length}');
      
      final data = {
        'bankName': _bankNameController.text.trim(),
        'accountName': _accountNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'isEnabled': _isEnabled,
        'qrCodeBase64': isQrCode ? base64Url : (_qrCodeUrl ?? ''),
        'qrCodeUrl': isQrCode ? base64Url : (_qrCodeUrl ?? ''),
        'bankLogoUrl': !isQrCode ? base64Url : (_bankLogoUrl ?? ''),
      };
      
      await _databaseService.updateQrPaymentSettings(data);
      debugPrint('[QR_SETTINGS] Firebase save success');

      setState(() {
        if (isQrCode) {
          _qrCodeUrl = base64Url;
        } else {
          _bankLogoUrl = base64Url;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isQrCode ? "QR Code" : "Bank Logo"} saved to database successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('[QR_SETTINGS] Error picking or saving settings image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final data = {
        'bankName': _bankNameController.text.trim(),
        'accountName': _accountNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'isEnabled': _isEnabled,
        'qrCodeBase64': _qrCodeUrl ?? '',
        'qrCodeUrl': _qrCodeUrl ?? '',
        'bankLogoUrl': _bankLogoUrl ?? '',
      };
      
      await _databaseService.updateQrPaymentSettings(data);
      debugPrint('[QR_SETTINGS] Firebase save success');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR payment settings updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('[QR_SETTINGS] Error saving settings: $e');
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
      return const Center(child: LoadingWidget(message: 'Syncing QR Settings...'));
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
                'QR Payment Settings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
              ),
              Text(
                'Configure the DuitNow bank details and QR codes shown to customers during checkout.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Form and Assets Container
          Expanded(
            child: SingleChildScrollView(
              child: Builder(
                builder: (context) {
                  final formCard = Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('QR Payments Enabled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
                              Switch(
                                value: _isEnabled,
                                activeThumbColor: AppColors.primaryOrange,
                                onChanged: (val) {
                                  setState(() {
                                    _isEnabled = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          TextField(
                            controller: _bankNameController,
                            decoration: const InputDecoration(
                              labelText: 'Bank Name',
                              hintText: 'e.g., Maybank, CIMB Bank',
                              prefixIcon: Icon(Icons.account_balance_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _accountNameController,
                            decoration: const InputDecoration(
                              labelText: 'Account Holder Name',
                              hintText: 'e.g., CARRENT SDN BHD',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _accountNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Bank Account Number',
                              hintText: 'e.g., 514012345678',
                              prefixIcon: Icon(Icons.credit_card_outlined),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _saving ? null : _saveSettings,
                              child: _saving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Save QR Credentials', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  final assetColumn = Column(
                    children: [
                      _buildAssetUploadCard('Company DuitNow QR', _qrCodeUrl, true),
                      const SizedBox(height: 20),
                      _buildAssetUploadCard('Bank Logo/Icon', _bankLogoUrl, false),
                    ],
                  );

                  return isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: formCard),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: assetColumn),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            formCard,
                            const SizedBox(height: 24),
                            assetColumn,
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

  Widget _buildAssetUploadCard(String label, String? url, bool isQr) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue)),
            const SizedBox(height: 12),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: url != null && url.isNotEmpty
                  ? AppImage(
                      imageSrc: url,
                      fit: BoxFit.contain,
                      placeholder: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isQr ? Icons.qr_code_2 : Icons.image_search, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('No asset selected', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryOrange),
                foregroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _saving ? null : () => _pickImage(isQr),
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(url != null && url.isNotEmpty ? 'Replace Image' : 'Upload Image'),
            ),
          ],
        ),
      ),
    );
  }
}
