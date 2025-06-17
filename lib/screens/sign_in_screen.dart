// lib/screens/sign_in_screen.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cuflix/screens/nav_screen.dart';
import 'package:cuflix/screens/sign_up_info_screen.dart';
import 'package:cuflix/screens/help_screen.dart';

enum LoginState { idle, loading, captchaRequired, success, error }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _uidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  LoginState _loginState = LoginState.idle;
  String _errorMessage = '';
  Uint8List? _captchaScreenshot;

  HeadlessInAppWebView? _headlessWebView;

  @override
  void initState() {
    super.initState();
    _headlessWebView = HeadlessInAppWebView(
      initialSize: const Size(414, 896), // Force high-resolution rendering
      initialUrlRequest: URLRequest(url: WebUri("https://students.cuchd.in/")),
      onProgressChanged: (controller, progress) {
        if (progress == 100) {
          _handlePageReady(controller);
        }
      },
    );
    _headlessWebView?.run();
  }

  // Wait for specific elements to appear on the page
  Future<bool> _waitForElement(InAppWebViewController controller, String elementId) async {
    for (int i = 0; i < 20; i++) {
      final bool elementExists = await controller.evaluateJavascript(
          source: "!!document.getElementById('$elementId');") as bool? ?? false;
      if (elementExists) return true;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  // Handle page ready events
  void _handlePageReady(InAppWebViewController controller) async {
  final currentUrl = (await controller.getUrl()).toString();

  // ── 1.  Successful login ───────────────────────────────────────────────
  if (currentUrl.contains('StudentHome.aspx') ||
      currentUrl.contains('LandingPage.aspx')) {

    // a) everything that does NOT need context ----------------------------
    await _saveSignInState(true);

    // b) bail out if widget got disposed while we were waiting ------------
    if (!mounted) return;

    // c) now we can safely use context / setState -------------------------
    setState(() => _loginState = LoginState.success);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NavScreen()),
      (_) => false,
    );
    return;
  }

  // ── 2.  Wait for password page to load ─────────────────────────────────
  final isPasswordPageReady =
      await _waitForElement(controller, 'txtLoginPassword');

  if (!mounted) return;               // <- guard after the await again

  if (isPasswordPageReady) {
    await _extractCaptchaAsScreenshot(controller);
  } else if (_loginState == LoginState.loading) {
    setState(() {
      _loginState  = LoginState.error;
      _errorMessage = 'Page timed out or an unknown error occurred.';
    });
  }
}


  // Save sign-in state for persistent authentication
  Future<void> _saveSignInState(bool isSignedIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSignedIn', isSignedIn);
      // print('Sign-in state saved: $isSignedIn');
    } catch (e) {
      // print('Error saving sign-in state: $e');
    }
  }
  
  // Start the login process
  Future<void> _startLogin() async {
    // Validate UID format
    final uidPattern = RegExp(r'^\d{2}[a-zA-Z]{3}\d{5}$');
    if (!uidPattern.hasMatch(_uidController.text)) {
      setState(() {
        _loginState = LoginState.error;
        _errorMessage = "Invalid UID format. It should be like '21BCS12345'.";
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _loginState = LoginState.error;
        _errorMessage = "Please enter your password.";
      });
      return;
    }

    setState(() { 
      _loginState = LoginState.loading; 
      _errorMessage = ''; 
    });

    // Inject UID and click next
    await _headlessWebView?.webViewController?.evaluateJavascript(source: """
      document.getElementById('txtUserId').value = '${_uidController.text}';
      document.getElementById('btnNext').click();
    """);
  }

  // Extract CAPTCHA as high-quality screenshot
  Future<void> _extractCaptchaAsScreenshot(InAppWebViewController controller) async {
    try {
      // Get CAPTCHA element position
      final rectData = await controller.evaluateJavascript(
          source: "JSON.stringify(document.getElementById('imgCaptcha').getBoundingClientRect());");

      InAppWebViewRect? cropRect;
      if (rectData is String && rectData.isNotEmpty) {
        final map = Map<String, dynamic>.from(jsonDecode(rectData));
        cropRect = InAppWebViewRect(
          x: (map['left'] as num).toDouble(),
          y: (map['top'] as num).toDouble(),
          width: (map['width'] as num).toDouble(),
          height: (map['height'] as num).toDouble(),
        );
      }

      // Take high-quality screenshot
      Uint8List? screenshotBytes = await controller.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.PNG,
          quality: 100,
          rect: cropRect,
        ),
      );

      if (mounted && screenshotBytes != null) {
        setState(() {
          _captchaScreenshot = screenshotBytes;
          _loginState = LoginState.captchaRequired;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loginState = LoginState.error;
          _errorMessage = "Could not capture CAPTCHA. Please try again.";
        });
      }
    }
  }

  // Submit password and CAPTCHA
  Future<void> _submitPasswordAndCaptcha() async {
    if (_captchaController.text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter the CAPTCHA.";
      });
      return;
    }

    setState(() { _loginState = LoginState.loading; });

    // Submit login form
    await _headlessWebView?.webViewController?.evaluateJavascript(source: """
      document.getElementById('txtLoginPassword').value = '${_passwordController.text}';
      document.getElementById('txtcaptcha').value = '${_captchaController.text}';
      document.getElementById('btnLogin').click();
    """);
  }

  @override
  void dispose() {
    _uidController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    _headlessWebView?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Image.asset('assets/logo1.png', height: 170),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Loading indicator
              if (_loginState == LoginState.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF076AE0)),
                        SizedBox(height: 16),
                        Text(
                          "Authenticating...",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Main form
              if (_loginState != LoginState.loading) _buildForm(),
              
              // Error messages
              if (_loginState == LoginState.error && _errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[900]?.withValues(alpha:0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[700]!),
                    ),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // UID/Email field
        _buildTextField(
          controller: _uidController,
          label: 'Email or UID',
          hint: 'Enter your student UID (e.g., 21BCS12345)',
          icon: Icons.person,
          enabled: _loginState == LoginState.idle || _loginState == LoginState.error,
        ),
        const SizedBox(height: 16),
        
        // Password field
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock,
          isPassword: true,
          enabled: _loginState == LoginState.idle || _loginState == LoginState.error,
        ),
        const SizedBox(height: 24),
        
        // CAPTCHA section (only shown when required)
        if (_loginState == LoginState.captchaRequired && _captchaScreenshot != null) ...[
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.memory(
              _captchaScreenshot!,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _captchaController,
            label: 'Enter CAPTCHA',
            hint: 'Enter the text shown above',
            icon: Icons.security,
          ),
          const SizedBox(height: 24),
        ],
        
        // Sign In button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _loginState == LoginState.captchaRequired 
                ? _submitPasswordAndCaptcha 
                : _startLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF076AE0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Text(
              _loginState == LoginState.captchaRequired ? 'LOGIN' : 'Sign In',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Help and sign up links
        _buildHelpAndSignUpLinks(),
        
        const SizedBox(height: 32),
        
        // Footer text
        const Text(
          "Sign in is protected by Google\nUID to ensure you're a CU Student.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: Colors.grey[850],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFF076AE0), width: 2),
        ),
      ),
    );
  }

  Widget _buildHelpAndSignUpLinks() {
    return Column(
      children: [
        // Need help button
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpScreen()),
            );
          },
          child: const Text(
            'Need help?',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Sign up text with clickable link
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Montserrat',
            ),
            children: <TextSpan>[
              const TextSpan(text: 'New to CU-FLIX? '),
              TextSpan(
                text: 'Sign up now.',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF076AE0),
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpInfoScreen(),
                      ),
                    );
                  },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
