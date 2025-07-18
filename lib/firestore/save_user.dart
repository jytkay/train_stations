import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:group_assignment/main.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

// Register with email and password
Future<User?> registerWithEmailAndPassword(String email, String password, String name) async {
  try {
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? user = result.user;

    if (user != null) {
      await user.updateDisplayName(name);
      await user.sendEmailVerification(); // 🔐 Send verification email

      // Sign out immediately to prevent unverified login
      await _auth.signOut();

      throw Exception('A verification email has been sent. Please verify before logging in.');
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

    User? user = result.user;

    if (user != null) {
      // Refresh user data to get the latest verification status
      await user.reload();
      user = _auth.currentUser; // Get the refreshed user

      if (user != null && !user.emailVerified) {
        await _auth.signOut(); // Sign out immediately if not verified
        throw Exception('Email not verified. Please verify your email first.');
      }

      return user; // Email is verified
    }

    return null;
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

// Delete current user
Future<void> deleteUserAccount(BuildContext context, String email, String password) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Re-authenticate the user
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);

      // Delete the user
      await user.delete();

      // Sign out after account deletion and clear any cached state
      await FirebaseAuth.instance.signOut();

      // Close loading dialog first
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      // Show success message
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to MyApp and let AuthWrapper handle the redirect
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MyApp()),
              (route) => false,
        );
      }
    } else {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('No authenticated user found.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } on FirebaseAuthException catch (e) {
    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading dialog
    }

    String message = switch (e.code) {
      'wrong-password' => 'Incorrect password.',
      'user-mismatch' => 'Email does not match the current user.',
      'requires-recent-login' => 'Please re-authenticate and try again.',
      _ => 'Error: ${e.message}',
    };

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading dialog
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('Account deletion failed: ${e.toString()}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}