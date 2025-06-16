// lib/screens/content_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cuflix/models/content_item.dart';
import 'package:cuflix/widgets/telegram_setup_dialog.dart';
import 'package:cuflix/services/telegram_service.dart';

class ContentDetailScreen extends StatelessWidget {
  final ContentItem content;

  const ContentDetailScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Hero Image with App Bar
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    content.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 48,
                        ),
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    content.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Content Type, Season, Category Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        label: content.contentType,
                        color: _getContentTypeColor(content.contentType),
                      ),
                      if (content.season != null && content.season!.isNotEmpty)
                        _InfoChip(
                          label: '${content.season} Season${content.season == '1' ? '' : 's'}',
                          color: Colors.blue[700]!,
                        ),
                      if (content.episodeType != null && content.episodeType!.isNotEmpty)
                        _InfoChip(
                          label: content.episodeType!,
                          color: Colors.green[700]!,
                        ),
                      _InfoChip(
                        label: content.category,
                        color: Colors.orange[700]!,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Description
                  if (content.description.isNotEmpty) ...[
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Watch Options with Smart Telegram Integration
                  if (content.availableLinks.isNotEmpty) ...[
                    const Text(
                      'Watch Options',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...content.availableLinks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final link = entry.value;
                      final episodeCount = link.split(',').length;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleSendToTelegram(context, index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF076AE0),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.send, color: Colors.white),
                            label: Column(
                              children: [
                                Text(
                                  _getLinkLabel(index, content.contentType),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (episodeCount > 1)
                                  Text(
                                    '$episodeCount episodes',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  
                  // Settings Section
                  const SizedBox(height: 32),
                  _buildSettingsSection(context),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Smart handler for sending to Telegram
  Future<void> _handleSendToTelegram(BuildContext context, int linkIndex) async {
    // Check if setup is complete
    final isSetupComplete = await TelegramService.isSetupComplete();
    
    if (isSetupComplete) {
      // Setup is complete, send directly
      _sendDirectly(context, linkIndex);
    } else {
      // Setup needed, show dialog
      _showTelegramDialog(context, linkIndex);
    }
  }

  // Send files directly without showing dialog
  Future<void> _sendDirectly(BuildContext context, int linkIndex) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Sending ${content.name}...',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    try {
      final success = await TelegramService.sendContentFiles(
        content: content,
        linkIndex: linkIndex,
      );

      Navigator.of(context).pop(); // Close loading dialog

      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? '✅ Files sent successfully to Telegram!'
                : '❌ Failed to send files. Please try again.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTelegramDialog(BuildContext context, int linkIndex) {
    showDialog(
      context: context,
      builder: (context) => TelegramSetupDialog(
        content: content,
        linkIndex: linkIndex,
      ),
    );
  }

  // Settings section to manage Telegram configuration
  Widget _buildSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<bool>(
          future: TelegramService.isSetupComplete(),
          builder: (context, snapshot) {
            final isSetup = snapshot.data ?? false;
            
            return ListTile(
              leading: Icon(
                isSetup ? Icons.check_circle : Icons.settings,
                color: isSetup ? Colors.green : Colors.orange,
              ),
              title: Text(
                isSetup ? 'Telegram Setup Complete' : 'Setup Telegram',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                isSetup 
                    ? 'Bot is configured and ready to send files'
                    : 'Configure your Telegram bot',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: isSetup 
                  ? TextButton(
                      onPressed: () => _resetTelegramSettings(context),
                      child: const Text('Reset'),
                    )
                  : const Icon(Icons.arrow_forward_ios, color: Colors.white54),
              onTap: isSetup 
                  ? null
                  : () => _showTelegramDialog(context, 0),
            );
          },
        ),
      ],
    );
  }

  Future<void> _resetTelegramSettings(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Reset Telegram Settings', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear your saved bot token and chat ID. You\'ll need to set them up again.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TelegramService.clearStoredCredentials();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telegram settings have been reset'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _getLinkLabel(int index, String contentType) {
    if (contentType.toLowerCase().contains('tv show') || 
        contentType.toLowerCase().contains('anime series')) {
      switch (index) {
        case 0: return 'Send Season 1';
        case 1: return 'Send Season 2';
        case 2: return 'Send Season 3';
        case 3: return 'Send Season 4';
        default: return 'Send Season ${index + 1}';
      }
    } else {
      return 'Send to Telegram';
    }
  }

  Color _getContentTypeColor(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'tv show':
        return Colors.blue[700]!;
      case 'movie':
        return Colors.red[700]!;
      case 'anime movie':
      case 'anime series':
        return Colors.purple[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Widget _InfoChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
