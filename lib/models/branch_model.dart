class BranchModel {
  final String id;
  final String name;
  final String address;
  final String phone;

  BranchModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
  });

  factory BranchModel.fromMap(String id, Map<dynamic, dynamic> data) {
    return BranchModel(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
    };
  }
}
