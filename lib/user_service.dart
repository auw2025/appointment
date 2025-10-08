// user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Signs up (creates) a new user in Firestore with a hashed password.
  Future<void> signUpUser({
    required String email,
    required String password,
    required String role,
  }) async {
    final hashed = BCrypt.hashpw(password, BCrypt.gensalt());
    await _firestore.collection('Users').add({
      'email': email,
      'hashedPassword': hashed,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Attempts to login a user with the provided email and plain-text password.
  /// Returns [role] if login is successful, or null if login fails.
  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    // Look up the user document in Firestore by matching the email.
    final query = await _firestore
        .collection('Users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      // No user found with that email.
      return null;
    }

    // We only expect one document because of .limit(1).
    final userDoc = query.docs.first;
    final userData = userDoc.data();
    final hashedPassword = userData['hashedPassword'] as String;
    final role = userData['role'] as String;

    // Check the given `password` against the hashed password from Firestore.
    final passwordMatches = BCrypt.checkpw(password, hashedPassword);
    if (passwordMatches) {
      return role; // Return the "chaplain" or "student"
    } else {
      return null;
    }
  }
}