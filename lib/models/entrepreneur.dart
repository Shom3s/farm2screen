class Entrepreneur {
  final String id;
  final String ownerUid;
  final String name;
  final String phone;
  final String email;
  final String farmLocation;
  final String shopLocation;
  final String description;
  final List<String> productCategories;
  final String? photoUrl;

  // Social media links (optional)
  final String? whatsappUrl;
  final String? facebookUrl;
  final String? instagramUrl;

  Entrepreneur({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.phone,
    required this.email,
    required this.farmLocation,
    required this.shopLocation,
    required this.description,
    required this.productCategories,
    required this.photoUrl,
    this.whatsappUrl,
    this.facebookUrl,
    this.instagramUrl,
  });

  factory Entrepreneur.fromMap(String id, Map<String, dynamic> data) {
    return Entrepreneur(
      id: id,
      ownerUid: data['ownerUid'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      farmLocation: data['farmLocation'] ?? '',
      shopLocation: data['shopLocation'] ?? '',
      description: data['description'] ?? '',
      productCategories: List<String>.from(
        data['productCategories'] ?? const [],
      ),
      photoUrl: data['photoUrl'] as String?,
      whatsappUrl: data['whatsappUrl'] as String?,
      facebookUrl: data['facebookUrl'] as String?,
      instagramUrl: data['instagramUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'name': name,
      'phone': phone,
      'email': email,
      'farmLocation': farmLocation,
      'shopLocation': shopLocation,
      'description': description,
      'productCategories': productCategories,
      'photoUrl': photoUrl,
      'whatsappUrl': whatsappUrl,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
    };
  }
}
