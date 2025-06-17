// lib/widgets/telegram_setup_dialog.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cuflix/services/telegram_service.dart';
import 'package:cuflix/models/content_item.dart';

class TelegramSetupDialog extends StatefulWidget {
  final ContentItem content;
  final int linkIndex;

  const TelegramSetupDialog({
    super.key,
    required this.content,
    required this.linkIndex,
  });

  @override
  State<TelegramSetupDialog> createState() => _TelegramSetupDialogState();
}

class _TelegramSetupDialogState extends State<TelegramSetupDialog> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _currentStep;
  bool _isSetupComplete = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final token = await TelegramService.getStoredBotToken();
    final isComplete = await TelegramService.isSetupComplete();

    setState(() {
      if (token != null) _tokenController.text = token;
      _isSetupComplete = isComplete;
    });
  }

  Future<void> _openTutorial() async {
    const url = 'https://www.youtube.com/watch?v=JIU_H7gXy54';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _resetToken() async {
    await TelegramService.clearStoredCredentials();
    setState(() {
      _tokenController.clear();
      _successMessage = null;
      _errorMessage = null;
      _currentStep = null;
      _isSetupComplete = false;
    });
  }

  Future<void> _sendFiles() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your bot token';
      });
      return;
    }

    if (!TelegramService.isValidBotToken(token)) {
      setState(() {
        _errorMessage = 'Invalid bot token format.\nShould be like: 123456789:ABCdefGHIjklMNOpqrSTUvwxyz';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _currentStep = 'Validating bot token...';
    });

    try {
      await TelegramService.saveBotToken(token);
      setState(() {
        _currentStep = 'Looking for chat messages...';
      });

      final success = await TelegramService.sendContentFiles(
        providedBotToken: token,
        content: widget.content,
        linkIndex: widget.linkIndex,
      );

      setState(() {
        _isLoading = false;
        _currentStep = null;
        if (success) {
          _successMessage = '✅ Files sent successfully to Telegram!';
          _errorMessage = null;
          _isSetupComplete = true;
        } else {
          _errorMessage = 'Failed to send files. Please check your bot token.';
        }
      });

      if (success) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentStep = null;

        if (e.toString().contains('CHAT_ID_NOT_FOUND')) {
          _errorMessage = _buildChatIdNotFoundMessage();
        } else if (e.toString().contains('Bot token is invalid')) {
          _errorMessage = 'Invalid bot token. Please check and try again.';
        } else {
          _errorMessage = 'Error: ${e.toString()}';
        }
      });
    }
  }

  String _buildChatIdNotFoundMessage() {
    return '''❗ Cannot find your chat with the bot.

📍 Follow these steps:

1. Search for your bot username in Telegram
2. Start a chat with your bot
3. Send this message: /start
4. Send any other message (like "hello")
5. Come back and try again

💡 Your bot needs at least one message from you to work!''';
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Row(
        children: [
          const Icon(Icons.send, color: Colors.blue),
          const SizedBox(width: 8),
          const Text(
            'Send to Telegram',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_isSetupComplete)
            Tooltip(
              message: 'Setup Complete',
              child: const Icon(Icons.verified, color: Colors.green),
            )
          else
            Tooltip(
              message: 'Setup Incomplete',
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[900]?.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎬 ${widget.content.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (widget.content.isTVShow || widget.content.isAnimeSeries)
                      Text(
                        '📺 Season ${widget.linkIndex + 1}',
                        style: const TextStyle(color: Colors.blue, fontSize: 14),
                      ),
                    Text(
                      '📂 ${widget.content.availableLinks[widget.linkIndex].split(',').length} file(s)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bot Token Input
              TextField(
                controller: _tokenController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Bot Token',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: '123456789:ABCdefGHIjklMNOpqrSTUvwxyz',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.grey[800],
                  prefixIcon: const Icon(Icons.token, color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Help Button
              Center(
                child: TextButton.icon(
                  onPressed: _openTutorial,
                  icon: const Icon(Icons.help_outline, color: Colors.blue),
                  label: const Text(
                    "How to get Bot Token?",
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_currentStep != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]?.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentStep!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[900]?.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[700]!),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),

              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[900]?.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[700]!),
                  ),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _resetToken,
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _sendFiles,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF076AE0),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send, color: Colors.white),
          label: Text(_isLoading ? 'Sending...' : 'Send Files'),
        ),
      ],
    );
  }
}
