// lib/screens/sign_up_info_screen.dart

import 'package:flutter/material.dart';

class SignUpInfoScreen extends StatelessWidget {
  const SignUpInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sign Up Information'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'You have to take admission to sign in to this app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
