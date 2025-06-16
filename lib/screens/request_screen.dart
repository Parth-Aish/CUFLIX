// lib/screens/request_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _searchController = TextEditingController();

  // Try multiple methods to open Gmail/Email
  Future<void> sendRequestEmail(String contentName) async {
    final String subject = 'Content Request - $contentName';
    final String body = '''Hello CU-FLIX Team,

I would like to request the following content to be added to the app:

Content Name: $contentName

Please consider adding this to your content library so I can watch it through the app.

Thank you!

Best regards,
CU-FLIX User''';

    // Method 1: Try Gmail app directly
    bool gmailSuccess = await _tryGmailApp(subject, body);
    if (gmailSuccess) return;

    // Method 2: Try general email intent
    bool emailSuccess = await _tryEmailIntent(subject, body);
    if (emailSuccess) return;

    // Method 3: Try mailto as fallback
    bool mailtoSuccess = await _tryMailto(subject, body);
    if (mailtoSuccess) return;

    // If all methods fail, show error
    _showErrorMessage();
  }

  // Method 1: Try Gmail app specifically
  Future<bool> _tryGmailApp(String subject, String body) async {
    try {
      // Gmail app intent for Android
      final Uri gmailUri = Uri.parse(
        'android-app://com.google.android.gm/mailto/xyz@gmail.com?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}'
      );
      
      if (await canLaunchUrl(gmailUri)) {
        await launchUrl(gmailUri);
        _showSuccessMessage('Gmail opened successfully!');
        return true;
      }
    } catch (e) {
      print('Gmail app method failed: $e');
    }
    return false;
  }

  // Method 2: Try email intent (works with any email app)
  Future<bool> _tryEmailIntent(String subject, String body) async {
    try {
      // General email intent for Android
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'xyz@gmail.com',
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication, // Force external app
        );
        _showSuccessMessage('Email app opened successfully!');
        return true;
      }
    } catch (e) {
      print('Email intent method failed: $e');
    }
    return false;
  }

  // Method 3: Traditional mailto fallback
  Future<bool> _tryMailto(String subject, String body) async {
    try {
      final String mailtoUrl = 'mailto:xyz@gmail.com?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
      final Uri mailtoUri = Uri.parse(mailtoUrl);

      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri);
        _showSuccessMessage('Email app opened successfully!');
        return true;
      }
    } catch (e) {
      print('Mailto method failed: $e');
    }
    return false;
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $message'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showErrorMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ No email app found. Please install Gmail or any email app.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Install Gmail',
            textColor: Colors.white,
            onPressed: () async {
              const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.google.android.gm';
              if (await canLaunchUrl(Uri.parse(playStoreUrl))) {
                await launchUrl(Uri.parse(playStoreUrl), mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );
    }
  }

  void _handleSendRequest() {
    final contentName = _searchController.text.trim();
    if (contentName.isNotEmpty) {
      sendRequestEmail(contentName);
      // Clear the text field after sending
      _searchController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the content name you want to request'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Request Content'),
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search/Request Input Field
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter movie, TV show, or anime name...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[850],
                prefixIcon: const Icon(Icons.movie_creation, color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) => _handleSendRequest(),
            ),
            
            const SizedBox(height: 20),
            
            // Send Request Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _handleSendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF076AE0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                icon: const Icon(Icons.email, color: Colors.white),
                label: const Text(
                  'Send Request via Gmail',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Information Section
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 60,
                            color: Color(0xFF076AE0),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Request New Content',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Can\'t find what you\'re looking for?',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter the name of any movie, TV show, or anime you want to watch and we\'ll consider adding it to our library!',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF076AE0).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF076AE0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/gmail_icon.png', // Add Gmail icon if you have it
                                  width: 16,
                                  height: 16,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.mail,
                                      size: 16,
                                      color: Color(0xFF076AE0),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Sends to: xyz@gmail.com',
                                  style: TextStyle(
                                    color: Color(0xFF076AE0),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
