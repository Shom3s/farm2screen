import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  CartService._internal();
  static final CartService instance = CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  double get total =>
      _items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  bool get isEmpty => _items.isEmpty;

  void add(Product product) {
    final existing =
        _items.where((i) => i.product.id == product.id).toList();
    if (existing.isNotEmpty) {
      existing.first.quantity += 1;
    } else {
      _items.add(CartItem(product: product, quantity: 1));
    }
    notifyListeners();
  }

  void decrease(Product product) {
    final existing =
        _items.where((i) => i.product.id == product.id).toList();
    if (existing.isEmpty) return;
    final item = existing.first;
    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _items.remove(item);
    }
    notifyListeners();
  }

  void remove(Product product) {
    _items.removeWhere((i) => i.product.id == product.id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  List<OrderLine> toOrderLines() {
    return _items
        .map(
          (item) => OrderLine(
            productId: item.product.id,
            productName: item.product.name,
            unitPrice: item.product.price,
            quantity: item.quantity,
          ),
        )
        .toList();
  }
}
