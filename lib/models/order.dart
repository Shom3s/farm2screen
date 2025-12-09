import 'package:cloud_firestore/cloud_firestore.dart';

class OrderLine {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  OrderLine({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  double get lineTotal => unitPrice * quantity;

  factory OrderLine.fromMap(Map<String, dynamic> data) {
    return OrderLine(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'quantity': quantity,
    };
  }
}

class Order {
  final String id;
  final String code;
  final String customerUid;
  final String entrepreneurId;
  final List<OrderLine> lines;
  final double total;
  final DateTime createdAt;
  final String status;

  Order({
    required this.id,
    required this.code,
    required this.customerUid,
    required this.entrepreneurId,
    required this.lines,
    required this.total,
    required this.createdAt,
    required this.status,
  });

  factory Order.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    final created = ts is Timestamp ? ts.toDate() : DateTime.now();
    final rawLines = List<Map<String, dynamic>>.from(
      data['lines'] ?? const [],
    );
    final lines = rawLines.map((m) => OrderLine.fromMap(m)).toList();

    return Order(
      id: id,
      code: data['code'] ?? '',
      customerUid: data['customerUid'] ?? '',
      entrepreneurId: data['entrepreneurId'] ?? '',
      lines: lines,
      total: (data['total'] ?? 0).toDouble(),
      createdAt: created,
      status: data['status'] ?? 'processing',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'customerUid': customerUid,
      'entrepreneurId': entrepreneurId,
      'lines': lines.map((l) => l.toMap()).toList(),
      'total': total,
      'createdAt': createdAt,
      'status': status,
    };
  }

  String get createdAtFormatted =>
      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
}
