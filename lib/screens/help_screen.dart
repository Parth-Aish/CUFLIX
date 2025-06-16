// lib/screens/help_screen.dart

import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // The title for the help screen.
        title: const Text('Help'),
        backgroundColor: Colors.black,
        // The back arrow is automatically added by Navigator.push
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'If you need help, please mail to\nxyz@gmail.com',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              height: 1.5, // Improves line spacing
            ),
          ),
        ),
      ),
    );
  }
}
