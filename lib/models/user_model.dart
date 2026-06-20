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
  });

  factory UserModel.fromMap(
    String id,
    Map<dynamic, dynamic> data,
  ) {
    return UserModel(
      id: id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'customer',
      profileImage: data['profileImage'] ?? '',
      createdAt: data['createdAt'] ?? '',
      licenseNumber: data['licenseNumber'],
      licenseImage: data['licenseImage'] ?? '',
      isVerified: data['isVerified'] ?? false,
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
    };
  }
}
