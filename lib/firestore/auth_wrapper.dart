// Determines page based on user authentication status (logged in/not)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:group_assignment/pages/login.dart';
import 'package:group_assignment/layout/main_scaffold.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is logged in, show main app with user ID
        if (snapshot.hasData && snapshot.data != null) {
          final userId = snapshot.data!.uid;
          return MainScaffold(userId: userId);
        }

        // If user is not logged in, show login page
        return const LoginPage();
      },
    );
  }
}