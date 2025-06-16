import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cuflix/models/content_item.dart';
import 'package:cuflix/screens/content_detail_screen.dart';
import 'package:cuflix/services/content_service.dart';
import 'package:cuflix/services/telegram_service.dart';
import 'package:cuflix/widgets/telegram_setup_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScrollController _scrollController;
  String _selectedCategory = 'All';
  ContentItem? _featuredContent;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Load content only if needed (smart caching)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ContentService>().loadContentIfNeeded();
      if (!mounted) return;
      _updateFeaturedContent();
    });
  }

  void _updateFeaturedContent() {
    final contentService = context.read<ContentService>();
    setState(() => _featuredContent = contentService.getRandomFeaturedContent());
  }

  // Reset to home screen
  void _resetToHome() {
    setState(() => _selectedCategory = 'All');
    _updateFeaturedContent();

    // Scroll to top
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<ContentService>(
        builder: (context, contentService, child) {
          // Show error only if there's an actual error
          if (contentService.error != null && contentService.allContent.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${contentService.error}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => contentService.loadContent(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Show content immediately, even if still loading in background
          return RefreshIndicator(
            onRefresh: () async {
              await contentService.forceRefresh();
              if (!mounted) return;
              _updateFeaturedContent();
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _CustomSliverAppBar(
                  selectedCategory: _selectedCategory,
                  onCategoryChanged: (category) {
                    setState(() {
                      _selectedCategory = category;
                      _updateFeaturedContent();
                    });
                  },
                  onLogoTap: _resetToHome,
                ),
                _buildFeaturedContent(contentService),
                _buildContentSections(contentService),
              ],
            ),
          );
        },
      ),
    );
  }

  /* ---------- Featured header ---------- */

  Widget _buildFeaturedContent(ContentService contentService) {
    final featuredContent =
        _featuredContent ?? contentService.getRandomFeaturedContent();

    if (featuredContent == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: _ContentHeader(
        featuredContent: featuredContent,
        onRefresh: _updateFeaturedContent,
      ),
    );
  }

  /* ---------- Category sections ---------- */

  Widget _buildContentSections(ContentService contentService) {
    final filteredContent = contentService.getFilteredContent(_selectedCategory);
    final List<Widget> sections = [];

    if (_selectedCategory == 'All') {
      // Show all categories with dynamic content rows
      sections.addAll([
        _ContentList(
          title: 'New Releases',
          contentList: contentService.allContent.reversed.take(10).toList(),
        ),
        ..._getIndividualCategorySections(contentService.allContent)
            .take(6)
            .map(
          (section) => _ContentList(
            title: section['title']!,
            contentList: section['content'].take(8).toList(),
          ),
        ),
      ]);
    } else {
      // Show only selected category content
      sections.add(
        _ContentList(title: _selectedCategory, contentList: filteredContent),
      );

      // Add sub-categories for the selected type
      if (_selectedCategory == 'TV Shows') {
        final tvSections =
            _getIndividualCategorySections(contentService.tvShows, contentType: 'tv');
        sections.addAll(tvSections.take(3).map((section) => _ContentList(
              title: section['title']!,
              contentList: section['content'].take(8).toList(),
            )));
      } else if (_selectedCategory == 'Movies') {
        final movieSections =
            _getIndividualCategorySections(contentService.movies, contentType: 'movie');
        sections.addAll(movieSections.take(3).map((section) => _ContentList(
              title: section['title']!,
              contentList: section['content'].take(8).toList(),
            )));
      } else if (_selectedCategory == 'Anime') {
        sections.addAll([
          _ContentList(
              title: 'Anime Movies',
              contentList: contentService.animeMovies.take(8).toList()),
          _ContentList(
              title: 'Anime Series',
              contentList: contentService.animeSeries.take(8).toList()),
        ]);

        final animeSections =
            _getIndividualCategorySections(contentService.allAnime, contentType: 'anime');
        sections.addAll(animeSections.take(2).map((section) => _ContentList(
              title: section['title']!,
              contentList: section['content'].take(8).toList(),
            )));
      }
    }

    return SliverList(delegate: SliverChildListDelegate(sections));
  }

  /* ---------- Helper for splitting comma-separated categories ---------- */

  List<Map<String, dynamic>> _getIndividualCategorySections(
    List<ContentItem> contentList, {
    String? contentType,
  }) {
    final Map<String, List<ContentItem>> categoryMap = {};

    for (final item in contentList) {
      final categories = item.category.split(',').map((c) => c.trim());

      for (final cat in categories) {
        if (cat.isEmpty) continue;
        categoryMap.putIfAbsent(cat, () => []).add(item);
      }
    }

    final sections = categoryMap.entries
        .map((e) => {'title': e.key, 'content': e.value})
        .toList()
      ..sort((a, b) =>
          (b['content'] as List).length.compareTo((a['content'] as List).length));

    return sections;
  }
}

/* ════════════════════  APP BAR  ════════════════════ */

class _CustomSliverAppBar extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onLogoTap;

  const _CustomSliverAppBar({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onLogoTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.black,
      title: GestureDetector(
        onTap: onLogoTap,
        child: Image.asset('assets/logo1.png', height: 170),
      ),
      centerTitle: true,
      leading: selectedCategory != 'All'
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => onCategoryChanged('All'),
            )
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _AppBarButton(
              title: 'TV Shows',
              isSelected: selectedCategory == 'TV Shows',
              onTap: () => onCategoryChanged('TV Shows'),
            ),
            _AppBarButton(
              title: 'Movies',
              isSelected: selectedCategory == 'Movies',
              onTap: () => onCategoryChanged('Movies'),
            ),
            _AppBarButton(
              title: 'Anime',
              isSelected: selectedCategory == 'Anime',
              onTap: () => onCategoryChanged('Anime'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppBarButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/* ════════════════════  FEATURED HEADER  ════════════════════ */

class _ContentHeader extends StatelessWidget {
  final ContentItem featuredContent;
  final VoidCallback? onRefresh;

  const _ContentHeader({
    required this.featuredContent,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          if (onRefresh != null)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: onRefresh,
                ),
              ),
            ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentDetailScreen(content: featuredContent),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                featuredContent.posterUrl,
                height: 400,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 400,
                  color: Colors.grey[800],
                  child: const Icon(Icons.error, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${featuredContent.category} • ${featuredContent.contentType}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PlayButton(content: featuredContent),
              _InfoButton(content: featuredContent),
            ],
          ),
        ],
      ),
    );
  }
}

/* ════════════════════  PLAY / INFO BUTTONS  ════════════════════ */

class _PlayButton extends StatelessWidget {
  final ContentItem content;
  const _PlayButton({required this.content});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: FilledButton.icon(
        onPressed: () => _handlePlayButton(context),
        style: FilledButton.styleFrom(backgroundColor: Colors.white),
        icon: const Icon(Icons.play_arrow, color: Colors.black),
        label: const Text(
          'Play',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /* ------------ 1. Decide what to do ------------ */
  Future<void> _handlePlayButton(BuildContext context) async {
    final isSetupComplete = await TelegramService.isSetupComplete();

    // Guard: context might have un-mounted while we were waiting
    if (!context.mounted) return;

    if (isSetupComplete) {
      await _sendDirectly(context);
    } else {
      _showTelegramDialog(context);
    }
  }

  /* ------------ 2. Send files directly ------------ */
  Future<void> _sendDirectly(BuildContext context) async {
    // Show progress before the async gap
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
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
        linkIndex: 0,
      );

      if (!context.mounted) return;

      Navigator.of(context).pop(); // close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '✅ Files sent successfully!' : '❌ Failed to send files.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      Navigator.of(context).pop(); // close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /* ------------ 3. First-time setup ------------ */
  void _showTelegramDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => TelegramSetupDialog(content: content, linkIndex: 0),
    );
  }
}

class _InfoButton extends StatelessWidget {
  final ContentItem content;
  const _InfoButton({required this.content});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContentDetailScreen(content: content),
          ),
        ),
        style: FilledButton.styleFrom(backgroundColor: Colors.grey.shade800),
        icon: const Icon(Icons.info_outline, color: Colors.white),
        label: const Text(
          'Info',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/* ════════════════════  HORIZONTAL CONTENT LIST  ════════════════════ */

class _ContentList extends StatelessWidget {
  final String title;
  final List<ContentItem> contentList;
  const _ContentList({required this.title, required this.contentList});

  @override
  Widget build(BuildContext context) {
    if (contentList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: contentList.length,
              itemBuilder: (_, index) {
                final item = contentList[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContentDetailScreen(content: item),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 200,
                    width: 130,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.posterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.white),
                              const SizedBox(height: 8),
                              Text(
                                item.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
