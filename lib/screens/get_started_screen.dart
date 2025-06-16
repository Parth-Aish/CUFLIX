import 'package:cuflix/screens/sign_in_screen.dart';
import 'package:cuflix/screens/nav_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  GetStartedScreenState createState() => GetStartedScreenState();
}

class GetStartedScreenState extends State<GetStartedScreen> {
  final List<String> posters = [
    'assets/Image2.png',
    'assets/Image3.png',
    'assets/Image4.png',
    'assets/Image5.png',
  ];

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
  }

  Future<void> _checkSignInStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSignedIn = prefs.getBool('isSignedIn') ?? false;
      
      if (isSignedIn) {
        // User is already signed in, navigate directly to NavScreen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const NavScreen()),
          );
        }
      }
      // If not signed in, stay on GetStartedScreen
    } catch (e) {
      print('Error checking sign-in status: $e');
      // On error, stay on GetStartedScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(30.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background GridView
            GridView.count(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: (screenWidth / 2) / (screenHeight / 2),
              children: posters.map((poster) {
                return Image.asset(
                  poster,
                  fit: BoxFit.cover,
                  color: const Color.fromRGBO(0, 0, 0, 0.2),
                  colorBlendMode: BlendMode.darken,
                );
              }).toList(),
            ),

            // Bottom Overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black,
                      const Color.fromRGBO(0, 0, 0, 0.8),
                      Colors.transparent,
                    ],
                    stops: const [0.2, 0.6, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
                      child: Column(
                        children: [
                          const Text(
                            "Unlimited\nentertainment,\nfree for all.",
                            style: TextStyle(
                              fontSize: 32.0,
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "All of Netflix, And Other OTT Just For\nFree For CU",
                            style: TextStyle(
                              fontSize: 16.0,
                              color: Colors.white70,
                              fontFamily: 'Montserrat',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF076AE0),
                        minimumSize: const Size.fromHeight(65),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const SignInScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'GET STARTED',
                        style: TextStyle(
                          fontSize: 18.0,
                          color: Colors.white,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
