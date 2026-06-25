class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String profileImage;
  final String createdAt;
  final String? licenseNumber;
  final String licenseImage;
  final bool isVerified;
  final bool isActive;
  final String licenseStatus; // 'unprovided', 'pending', 'approved', 'rejected'
  final String licenseRejectionReason;
  
  // High fidelity visual fields
  final String address;
  final String licenseClass;
  final String licenseExpiry;

  bool get isAdmin => role == 'admin';

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImage = '',
    required this.createdAt,
    this.licenseNumber,
    this.licenseImage = '',
    this.isVerified = false,
    this.isActive = true,
    this.licenseStatus = 'unprovided',
    this.licenseRejectionReason = '',
    this.address = '4521 Oakwood Avenue, Suite 300, Los Angeles, CA 90024',
    this.licenseClass = 'Class DA',
    this.licenseExpiry = '12 / 2028',
  });

  factory UserModel.fromMap(
    String id,
    Map<dynamic, dynamic> data,
  ) {
    return UserModel(
      id: id,
      fullName: data['fullName'] ?? data['name'] ?? 'User',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'customer',
      profileImage: data['profileImage'] ?? '',
      createdAt: data['createdAt'] ?? '',
      licenseNumber: data['licenseNumber'],
      licenseImage: data['licenseImage'] ?? '',
      isVerified: data['isVerified'] ?? false,
      isActive: data['isActive'] ?? true,
      licenseStatus: data['licenseStatus'] ?? 
          ((data['licenseImage'] != null && (data['licenseImage'] as String).trim().isNotEmpty)
              ? (data['isVerified'] == true ? 'approved' : 'pending')
              : 'unprovided'),
      licenseRejectionReason: data['licenseRejectionReason'] ?? '',
      address: data['address'] ?? '4521 Oakwood Avenue, Suite 300, Los Angeles, CA 90024',
      licenseClass: data['licenseClass'] ?? 'Class DA',
      licenseExpiry: data['licenseExpiry'] ?? '12 / 2028',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImage': profileImage,
      'createdAt': createdAt,
      'licenseNumber': licenseNumber,
      'licenseImage': licenseImage,
      'isVerified': isVerified,
      'isActive': isActive,
      'licenseStatus': licenseStatus,
      'licenseRejectionReason': licenseRejectionReason,
      'address': address,
      'licenseClass': licenseClass,
      'licenseExpiry': licenseExpiry,
    };
  }
}
