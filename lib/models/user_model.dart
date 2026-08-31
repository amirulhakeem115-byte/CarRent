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
  final String accountStatus;
  final String licenseStatus; // 'unprovided', 'pending', 'approved', 'rejected'
  final String licenseRejectionReason;

  // High fidelity visual fields
  final String address;
  final String licenseClass;
  final String licenseExpiry;
  final int rewardPoints;

  // Additional license metadata
  final String licenseUploadDate;
  final String licenseReviewedBy;
  final String licenseReviewedDate;

  // Passport/National ID fields
  final String idNumber;
  final String idType; // 'National ID', 'Passport'
  final String idImage;
  final String idStatus; // 'unprovided', 'pending', 'approved', 'rejected'
  final String idUploadDate;
  final String idRejectionReason;
  final String idReviewedBy;
  final String idReviewedDate;
  // Passport/Driving License explicit fields
  final String passportNumber;
  final String drivingLicenseNumber;

  final String employeeId;
  final String preferredLanguage;

  String get effectivePassportNumber => passportNumber.isNotEmpty ? passportNumber : idNumber;
  String get effectiveDrivingLicenseNumber => drivingLicenseNumber.isNotEmpty ? drivingLicenseNumber : (licenseNumber ?? '');

  String get normalizedRole => role.trim().toLowerCase();
  bool get isAdmin => normalizedRole == 'admin';
  bool get isEmployee => normalizedRole == 'employee';
  bool get isCustomer => normalizedRole == 'customer';

  List<String> get missingProfileFields {
    final missing = <String>[];
    if (fullName.trim().isEmpty || fullName.trim().toLowerCase() == 'user') {
      missing.add('Full Name');
    }
    if (phone.trim().isEmpty) {
      missing.add('Phone Number');
    }
    if (idNumber.trim().isEmpty && idImage.trim().isEmpty) {
      missing.add('Passport / IC Information');
    }
    if ((licenseNumber == null || licenseNumber!.trim().isEmpty) &&
        licenseImage.trim().isEmpty) {
      missing.add('Driving License Information');
    }
    return missing;
  }

  bool get isProfileCompleteForBooking => missingProfileFields.isEmpty;

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
    this.accountStatus = 'Active',
    this.licenseStatus = 'unprovided',
    this.licenseRejectionReason = '',
    this.address = '4521 Oakwood Avenue, Suite 300, Los Angeles, CA 90024',
    this.licenseClass = 'Class DA',
    this.licenseExpiry = '12 / 2028',
    this.rewardPoints = 0,
    this.licenseUploadDate = '',
    this.licenseReviewedBy = '',
    this.licenseReviewedDate = '',
    this.idNumber = '',
    this.idType = 'National ID',
    this.idImage = '',
    this.idStatus = 'unprovided',
    this.idUploadDate = '',
    this.idRejectionReason = '',
    this.idReviewedBy = '',
    this.idReviewedDate = '',
    this.passportNumber = '',
    this.drivingLicenseNumber = '',
    this.employeeId = '',
    this.preferredLanguage = 'en',
  });

  factory UserModel.fromMap(String id, Map<dynamic, dynamic> data) {
    final String parsedAccountStatus = (data['accountStatus'] ?? '')
        .toString()
        .trim();
    final bool parsedIsActive =
        data['isActive'] ?? (parsedAccountStatus.toLowerCase() != 'suspended');
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
      isActive: parsedIsActive,
      accountStatus: parsedAccountStatus.isNotEmpty
          ? parsedAccountStatus
          : (parsedIsActive ? 'Active' : 'Disabled'),
      licenseStatus:
          data['licenseStatus'] ??
          ((data['licenseImage'] != null &&
                  (data['licenseImage'] as String).trim().isNotEmpty)
              ? (data['isVerified'] == true ? 'approved' : 'pending')
              : 'unprovided'),
      licenseRejectionReason: data['licenseRejectionReason'] ?? '',
      address:
          data['address'] ??
          '4521 Oakwood Avenue, Suite 300, Los Angeles, CA 90024',
      licenseClass: data['licenseClass'] ?? 'Class DA',
      licenseExpiry: data['licenseExpiry'] ?? '12 / 2028',
      rewardPoints: data['rewardPoints'] is int
          ? data['rewardPoints'] as int
          : int.tryParse(data['rewardPoints']?.toString() ?? '') ?? 0,
      licenseUploadDate: data['licenseUploadDate'] ?? '',
      licenseReviewedBy: data['licenseReviewedBy'] ?? '',
      licenseReviewedDate: data['licenseReviewedDate'] ?? '',
      idNumber: data['idNumber'] ?? '',
      idType: data['idType'] ?? 'National ID',
      idImage: data['idImage'] ?? '',
      idStatus: data['idStatus'] ?? 'unprovided',
      idUploadDate: data['idUploadDate'] ?? '',
      idRejectionReason: data['idRejectionReason'] ?? '',
      idReviewedBy: data['idReviewedBy'] ?? '',
      idReviewedDate: data['idReviewedDate'] ?? '',
      passportNumber: data['passportNumber'] ?? data['idNumber'] ?? '',
      drivingLicenseNumber: data['drivingLicenseNumber'] ?? data['licenseNumber'] ?? '',
      employeeId: data['employeeId'] ?? '',
      preferredLanguage: data['preferredLanguage'] ?? 'en',
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
      'accountStatus': accountStatus,
      'licenseStatus': licenseStatus,
      'licenseRejectionReason': licenseRejectionReason,
      'address': address,
      'licenseClass': licenseClass,
      'licenseExpiry': licenseExpiry,
      'rewardPoints': rewardPoints,
      'licenseUploadDate': licenseUploadDate,
      'licenseReviewedBy': licenseReviewedBy,
      'licenseReviewedDate': licenseReviewedDate,
      'idNumber': idNumber,
      'idType': idType,
      'idImage': idImage,
      'idStatus': idStatus,
      'idUploadDate': idUploadDate,
      'idRejectionReason': idRejectionReason,
      'idReviewedBy': idReviewedBy,
      'idReviewedDate': idReviewedDate,
      'passportNumber': passportNumber,
      'drivingLicenseNumber': drivingLicenseNumber,
      'employeeId': employeeId,
      'preferredLanguage': preferredLanguage,
    };
  }
}
