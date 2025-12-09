import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_role.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  /// REGISTER NEW USER
  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,      // ✅ this MUST exist
    required UserRole role,           // ✅ entrepreneur / customer
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await cred.user!.updateDisplayName(displayName);

    await _db.collection('users').doc(cred.user!.uid).set({
      'name': displayName,
      'email': email,
      'role': role.asString,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  /// LOGIN and ensure Firestore document has a role
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user!;
    final docRef = _db.collection('users').doc(user.uid);
    final snap = await docRef.get();

    const defaultRole = UserRole.entrepreneur;

    if (!snap.exists) {
      await docRef.set({
        'name': user.displayName ?? '',
        'email': user.email ?? email,
        'role': defaultRole.asString,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final data = snap.data()!;
      final roleStr = data['role'] as String?;
      if (roleStr == null || roleStr.isEmpty) {
        await docRef.update({'role': defaultRole.asString});
      }
    }

    return cred;
  }

  /// ALWAYS returns a role (never null)
  Future<UserRole> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      return UserRole.entrepreneur;
    }
    final data = doc.data();
    final roleStr = data?['role'] as String?;
    return UserRoleX.fromString(roleStr);
  }

  Future<void> logout() => _auth.signOut();
}
