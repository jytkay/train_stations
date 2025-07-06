import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// Register with email and password
Future<User?> registerWithEmailAndPassword(String email, String password, String name) async {
  try {
    // Create user with email and password
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? user = result.user;

    if (user != null) {
      // Update display name
      await user.updateDisplayName(name);

      // Save user data to Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    }

    return null;
  } on FirebaseAuthException catch (e) {
    throw Exception(_getAuthErrorMessage(e.code));
  } catch (e) {
    throw Exception('Registration failed: ${e.toString()}');
  }
}

// Sign in with email and password
Future<User?> signInWithEmailAndPassword(String email, String password) async {
  try {
    UserCredential result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return result.user;
  } on FirebaseAuthException catch (e) {
    throw Exception(_getAuthErrorMessage(e.code));
  } catch (e) {
    throw Exception('Sign in failed: ${e.toString()}');
  }
}

// Send password reset email
Future<void> sendPasswordResetEmail(String email) async {
  try {
    await _auth.sendPasswordResetEmail(email: email);
  } on FirebaseAuthException catch (e) {
    throw Exception(_getAuthErrorMessage(e.code));
  } catch (e) {
    throw Exception('Password reset failed: ${e.toString()}');
  }
}

// Sign out
Future<void> signOut() async {
  try {
    await _auth.signOut();
  } catch (e) {
    throw Exception('Sign out failed: ${e.toString()}');
  }
}

// Get current user
User? getCurrentUser() {
  return _auth.currentUser;
}

// Auth state changes stream
Stream<User?> get authStateChanges => _auth.authStateChanges();

// Helper function to get user-friendly error messages
String _getAuthErrorMessage(String errorCode) {
  switch (errorCode) {
    case 'weak-password':
      return 'The password is too weak. Please use a stronger password.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'operation-not-allowed':
      return 'Email/password accounts are not enabled. Please contact support.';
    case 'user-disabled':
      return 'This user account has been disabled.';
    case 'user-not-found':
      return 'No user found with this email address.';
    case 'wrong-password':
      return 'Wrong password provided.';
    case 'invalid-credential':
      return 'Invalid email or password.';
    case 'too-many-requests':
      return 'Too many failed attempts. Please try again later.';
    case 'network-request-failed':
      return 'Network error. Please check your internet connection.';
    case 'channel-error':
      return 'Firebase connection error. Please check your internet connection and try again.';
    default:
      return 'Authentication failed. Please try again.';
  }
}