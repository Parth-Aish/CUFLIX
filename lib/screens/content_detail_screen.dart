import 'package:flutter/material.dart';
import 'package:cuflix/models/content_item.dart';
import 'package:cuflix/widgets/telegram_setup_dialog.dart';
import 'package:cuflix/services/telegram_service.dart';

class ContentDetailScreen extends StatefulWidget {
  final ContentItem content;
  const ContentDetailScreen({super.key, required this.content});

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  late Future<bool> _isSetupFuture;

  @override
  void initState() {
    super.initState();
    _isSetupFuture = TelegramService.isSetupComplete();
  }

  void _refreshSetupState() {
    setState(() {
      _isSetupFuture = TelegramService.isSetupComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.content.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.error,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.content.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(
                        label: widget.content.contentType,
                        color: _getContentTypeColor(widget.content.contentType),
                      ),
                      if (widget.content.season?.isNotEmpty ?? false)
                        _infoChip(
                          label:
                              '${widget.content.season} Season${widget.content.season == '1' ? '' : 's'}',
                          color: Colors.blue[700]!,
                        ),
                      if (widget.content.episodeType?.isNotEmpty ?? false)
                        _infoChip(
                          label: widget.content.episodeType!,
                          color: Colors.green[700]!,
                        ),
                      _infoChip(
                        label: widget.content.category,
                        color: Colors.orange[700]!,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (widget.content.description.isNotEmpty) ...[
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
                      widget.content.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (widget.content.availableLinks.isNotEmpty) ...[
                    const Text(
                      'Watch Options',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...widget.content.availableLinks.asMap().entries.map((
                      entry,
                    ) {
                      final idx = entry.key;
                      final link = entry.value;
                      final episodeCount = link.split(',').length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF076AE0),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () =>
                                _handleSendToTelegram(context, idx),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment:
                                  MainAxisAlignment.center, // center everything
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.send, color: Colors.white),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      _getLinkLabel(
                                        idx,
                                        widget.content.contentType,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (episodeCount > 1)
                                      Text(
                                        '$episodeCount episodes',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
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

  Future<void> _handleSendToTelegram(BuildContext ctx, int linkIdx) async {
    final setupDone = await TelegramService.isSetupComplete();
    if (!ctx.mounted) return;

    if (setupDone) {
      await _sendDirectly(ctx, linkIdx);
      _refreshSetupState();
    } else {
      await _showTelegramDialog(ctx, linkIdx);
      _refreshSetupState();
    }
  }

  Future<void> _sendDirectly(BuildContext ctx, int linkIdx) async {
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
            Text(
              'Sending ${widget.content.name}…',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    final navigator = Navigator.of(ctx);
    final messenger = ScaffoldMessenger.of(ctx);

    try {
      final ok = await TelegramService.sendContentFiles(
        content: widget.content,
        linkIndex: linkIdx,
      );

      if (!navigator.mounted) return;
      navigator.pop();
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
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showTelegramDialog(BuildContext ctx, int linkIdx) async {
    await showDialog(
      context: ctx,
      builder: (_) =>
          TelegramSetupDialog(content: widget.content, linkIndex: linkIdx),
    );
  }

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
          future: _isSetupFuture,
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
                  : const Icon(Icons.arrow_forward_ios, color: Colors.white54),
              onTap: isSetup
                  ? null
                  : () async {
                      await _showTelegramDialog(ctx, 0);
                      _refreshSetupState();
                    },
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
        title: const Text(
          'Reset Telegram Settings',
          style: TextStyle(color: Colors.white),
        ),
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
      _refreshSetupState();
      if (!navigator.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Telegram settings have been reset'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

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
