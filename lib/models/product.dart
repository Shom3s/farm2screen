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

  // NEW: stock quantity
  final int stockQty;

  // Convenience getters for UI
  bool get inStock => available && stockQty > 0;
  bool get isLowStock => inStock && stockQty <= 5;

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
    required this.stockQty,
  });

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else {
      created = DateTime.now();
    }

    // Handle old documents that don’t have stockQty yet
    final dynamic rawStock = data['stockQty'];
    int stock;
    if (rawStock is int) {
      stock = rawStock;
    } else if (rawStock is double) {
      stock = rawStock.toInt();
    } else {
      stock = 0;
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
      stockQty: stock,
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
      'stockQty': stockQty, // NEW
    };
  }
}
