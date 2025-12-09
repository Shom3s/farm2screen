import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String entrepreneurId;
  final String name;
  final String description;
  final String category;
  final double price;
  final String unit;
  final String? imageUrl;
  final bool available;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.entrepreneurId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.unit,
    required this.imageUrl,
    required this.available,
    required this.createdAt,
  });

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else {
      created = DateTime.now();
    }

    return Product(
      id: id,
      entrepreneurId: data['entrepreneurId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      unit: data['unit'] ?? 'unit',
      imageUrl: data['imageUrl'] as String?,
      available: data['available'] ?? true,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entrepreneurId': entrepreneurId,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'unit': unit,
      'imageUrl': imageUrl,
      'available': available,
      'createdAt': createdAt,
    };
  }
}
