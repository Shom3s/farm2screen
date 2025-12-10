import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/entrepreneur.dart';
import '../models/product.dart';
import '../models/announcement.dart';
import '../models/order.dart' as m;
import '../models/customer.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get entrepreneursRef =>
      _db.collection('entrepreneurs');

  CollectionReference<Map<String, dynamic>> get productsRef =>
      _db.collection('products');

  CollectionReference<Map<String, dynamic>> get announcementsRef =>
      _db.collection('announcements');

  CollectionReference<Map<String, dynamic>> get ordersRef =>
      _db.collection('orders');

  CollectionReference<Map<String, dynamic>> get customersRef =>
      _db.collection('customers');

  // ----------------- PRODUCTS -----------------

  /// Produk yang aktif untuk pelanggan.
  Stream<List<Product>> productsForCustomer() {
    return productsRef
        .where('available', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => Product.fromMap(d.id, d.data()))
          .toList();
    });
  }

  /// Produk milik usahawan tertentu (untuk portal usahawan).
  Stream<List<Product>> productsForEntrepreneur(String entrepreneurId) {
    return productsRef
        .where('entrepreneurId', isEqualTo: entrepreneurId)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => Product.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Future<void> addProduct(Product product) async {
    await productsRef.add(product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await productsRef.doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await productsRef.doc(productId).delete();
  }

  // ----------------- ENTREPRENEUR PROFILE -----------------

  Future<Entrepreneur?> getEntrepreneurByOwner(String uid) async {
    final snap = await entrepreneursRef
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    return Entrepreneur.fromMap(doc.id, doc.data());
  }

  Future<void> upsertEntrepreneur(Entrepreneur profile) async {
    final existing = await entrepreneursRef
        .where('ownerUid', isEqualTo: profile.ownerUid)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      await entrepreneursRef.add(profile.toMap());
    } else {
      await entrepreneursRef
          .doc(existing.docs.first.id)
          .update(profile.toMap());
    }
  }

  /// Senarai semua usahawan (digunakan untuk carian pelanggan).
  Stream<List<Entrepreneur>> entrepreneursStream() {
    return entrepreneursRef
        .orderBy('name')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => Entrepreneur.fromMap(d.id, d.data()))
          .toList();
    });
  }

  // ----------------- CUSTOMER PROFILE -----------------

  Future<Customer?> getCustomerByOwner(String uid) async {
    final snap = await customersRef
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    return Customer.fromMap(doc.id, doc.data());
  }

  Future<void> upsertCustomer(Customer profile) async {
    final existing = await customersRef
        .where('ownerUid', isEqualTo: profile.ownerUid)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      await customersRef.add(profile.toMap());
    } else {
      await customersRef
          .doc(existing.docs.first.id)
          .update(profile.toMap());
    }
  }

  // ----------------- ANNOUNCEMENTS -----------------

  Stream<List<Announcement>> announcementsStream() {
    return announcementsRef
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => Announcement.fromMap(d.id, d.data()))
          .toList();
    });
  }

  Future<void> addAnnouncement(Announcement a) async {
    await announcementsRef.add(a.toMap());
  }

  // ----------------- ORDERS & ANALYTICS -----------------

  Future<void> createOrder({
    required String customerUid,
    required String entrepreneurId,
    required List<m.OrderLine> lines,
  }) async {
    await _db.runTransaction((txn) async {
      // 1) Validate stock for each product
      final Map<String, DocumentSnapshot<Map<String, dynamic>>> productSnaps =
          {};

      for (final line in lines) {
        final prodRef = productsRef.doc(line.productId);
        final snap = await txn.get(prodRef);

        if (!snap.exists) {
          throw Exception(
            'Produk "${line.productName}" tidak lagi wujud dalam sistem.',
          );
        }

        productSnaps[line.productId] = snap;

        final data = snap.data()!;
        final rawStock = data['stockQty'];
        int currentStock;

        if (rawStock is int) {
          currentStock = rawStock;
        } else if (rawStock is double) {
          currentStock = rawStock.toInt();
        } else {
          currentStock = 0;
        }

        if (currentStock < line.quantity) {
          throw Exception(
            'Stok tidak mencukupi untuk "${line.productName}". '
            'Baki stok: $currentStock.',
          );
        }
      }

      // 2) Compute total
      final total = lines.fold<double>(
        0,
        (sum, line) => sum + line.lineTotal,
      );

      // 3) Create order document
      final orderRef = ordersRef.doc();
      final orderCode = 'ORD${DateTime.now().millisecondsSinceEpoch}';

      txn.set(orderRef, {
        'code': orderCode,
        'customerUid': customerUid,
        'entrepreneurId': entrepreneurId,
        'total': total,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'processing',
        'lines': lines.map((l) => l.toMap()).toList(),
      });

      // 4) Decrease stock for each product
      for (final line in lines) {
        final prodRef = productsRef.doc(line.productId);
        final snap = productSnaps[line.productId]!;
        final data = snap.data()!;
        final rawStock = data['stockQty'];

        int currentStock;
        if (rawStock is int) {
          currentStock = rawStock;
        } else if (rawStock is double) {
          currentStock = rawStock.toInt();
        } else {
          currentStock = 0;
        }

        final newStock = currentStock - line.quantity;
        txn.update(prodRef, {
          'stockQty': newStock,
          'available': newStock > 0,
        });
      }
    });
  }

  /// Semua order yang masuk untuk usahawan.
  Stream<List<m.Order>> ordersForEntrepreneur(String entrepreneurId) {
    return ordersRef
        .where('entrepreneurId', isEqualTo: entrepreneurId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => m.Order.fromMap(d.id, d.data()))
          .toList();
    });
  }

  /// Sejarah pesanan pelanggan.
  Stream<List<m.Order>> ordersForCustomer(String customerUid) {
    return ordersRef
        .where('customerUid', isEqualTo: customerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => m.Order.fromMap(d.id, d.data()))
          .toList();
    });
  }
}
