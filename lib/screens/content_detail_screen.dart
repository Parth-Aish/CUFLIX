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
          // ── Hero image & collapsing app-bar ──────────────────────────────
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
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child:
                          const Icon(Icons.error, color: Colors.white, size: 48),
                    ),
                  ),
                  // top-to-bottom black fade
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7), // ← no deprecation
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Details body ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title
                  Text(
                    content.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(
                        label: content.contentType,
                        color: _getContentTypeColor(content.contentType),
                      ),
                      if (content.season?.isNotEmpty ?? false)
                        _infoChip(
                          label:
                              '${content.season} Season${content.season == '1' ? '' : 's'}',
                          color: Colors.blue[700]!,
                        ),
                      if (content.episodeType?.isNotEmpty ?? false)
                        _infoChip(
                          label: content.episodeType!,
                          color: Colors.green[700]!,
                        ),
                      _infoChip(
                        label: content.category,
                        color: Colors.orange[700]!,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // description
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

                  // watch options
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
                      final idx = entry.key;
                      final link = entry.value;
                      final episodeCount = link.split(',').length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF076AE0),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () =>
                                _handleSendToTelegram(context, idx),
                            icon: const Icon(Icons.send, color: Colors.white),
                            label: Column(
                              children: [
                                Text(
                                  _getLinkLabel(idx, content.contentType),
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

                  // settings
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

  // ─────────────────────────── Actions ──────────────────────────────────

  Future<void> _handleSendToTelegram(BuildContext ctx, int linkIdx) async {
  final setupDone = await TelegramService.isSetupComplete();

  // Make sure the context is still in the tree
  if (!ctx.mounted) return;

  if (setupDone) {
    _sendDirectly(ctx, linkIdx);
  } else {
    _showTelegramDialog(ctx, linkIdx);
  }
}



  Future<void> _sendDirectly(BuildContext ctx, int linkIdx) async {
    // show loading immediately (synchronous)
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Sending ${content.name}…',
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    // capture navigator & messenger BEFORE the await
    final navigator = Navigator.of(ctx);
    final messenger = ScaffoldMessenger.of(ctx);

    try {
      final ok = await TelegramService.sendContentFiles(
        content: content,
        linkIndex: linkIdx,
      );

      if (!navigator.mounted) return;
      navigator.pop(); // close loader
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '✅ Files sent successfully to Telegram!'
                : '❌ Failed to send files. Please try again.',
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!navigator.mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTelegramDialog(BuildContext ctx, int linkIdx) {
    showDialog(
      context: ctx,
      builder: (_) => TelegramSetupDialog(
        content: content,
        linkIndex: linkIdx,
      ),
    );
  }

  // ───────────────────────── Settings section ───────────────────────────

  Widget _buildSettingsSection(BuildContext ctx) {
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
          builder: (_, snap) {
            final isSetup = snap.data ?? false;
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
                      onPressed: () => _resetTelegramSettings(ctx),
                      child: const Text('Reset'),
                    )
                  : const Icon(Icons.arrow_forward_ios,
                      color: Colors.white54),
              onTap: isSetup ? null : () => _showTelegramDialog(ctx, 0),
            );
          },
        ),
      ],
    );
  }

  Future<void> _resetTelegramSettings(BuildContext ctx) async {
    final navigator = Navigator.of(ctx);
    final messenger = ScaffoldMessenger.of(ctx);

    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Reset Telegram Settings',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear your saved bot token and chat ID.\n'
          'You\'ll need to set them up again.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => navigator.pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TelegramService.clearStoredCredentials();
      if (!navigator.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Telegram settings have been reset'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ───────────────────────── Helpers ────────────────────────────────────

  String _getLinkLabel(int idx, String type) {
    final lower = type.toLowerCase();
    if (lower.contains('tv show') || lower.contains('anime series')) {
      return 'Send Season ${idx + 1}';
    }
    return 'Send to Telegram';
  }

  Color _getContentTypeColor(String type) {
    switch (type.toLowerCase()) {
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

  // renamed & camel-cased
  Widget _infoChip({required String label, required Color color}) {
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
