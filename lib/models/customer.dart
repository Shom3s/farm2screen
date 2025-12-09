class Customer {
  final String id;
  final String ownerUid;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String photoUrl;

  Customer({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.photoUrl,
  });

  factory Customer.fromMap(String id, Map<String, dynamic> data) {
    return Customer(
      id: id,
      ownerUid: data['ownerUid'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'photoUrl': photoUrl,
      };
}
