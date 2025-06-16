// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cuflix/services/content_service.dart';
import 'package:cuflix/models/content_item.dart';
import 'package:cuflix/screens/content_detail_screen.dart';
import 'package:cuflix/widgets/telegram_setup_dialog.dart';
import 'package:cuflix/services/telegram_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  String _selectedCategory = 'All';
  ContentItem? _featuredContent;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Load content only if needed (smart caching)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContentService>().loadContentIfNeeded().then((_) {
        _updateFeaturedContent();
      });
    });
  }

  void _updateFeaturedContent() {
    final contentService = context.read<ContentService>();
    setState(() {
      _featuredContent = contentService.getRandomFeaturedContent();
    });
  }

  // Reset to home screen
  void _resetToHome() {
    setState(() {
      _selectedCategory = 'All';
    });
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

  Widget _buildFeaturedContent(ContentService contentService) {
    final featuredContent = _featuredContent ?? contentService.getRandomFeaturedContent();

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

  Widget _buildContentSections(ContentService contentService) {
  final filteredContent = contentService.getFilteredContent(_selectedCategory);
  
  List<Widget> sections = [];

  if (_selectedCategory == 'All') {
    // Show all categories with dynamic content rows
    sections.addAll([
      _ContentList(title: 'New Releases', contentList: contentService.allContent.reversed.take(10).toList()),
      
      // NEW: Get individual categories from comma-separated values
      ..._getIndividualCategorySections(contentService.allContent).take(6).map((categorySection) =>
        _ContentList(
          title: categorySection['title']!,
          contentList: categorySection['content'].take(8).toList(),
        ),
      ),
    ]);
  } else {
    // Show only selected category content
    sections.add(_ContentList(
      title: _selectedCategory,
      contentList: filteredContent,
    ));

    // Add subcategories for the selected type
    if (_selectedCategory == 'TV Shows') {
      final tvShowSections = _getIndividualCategorySections(
        contentService.tvShows,
        contentType: 'tv',
      );
      sections.addAll([
        ...tvShowSections.take(3).map((categorySection) =>
          _ContentList(
            title: categorySection['title']!,
            contentList: categorySection['content'].take(8).toList(),
          ),
        ),
      ]);
    } else if (_selectedCategory == 'Movies') {
      final movieSections = _getIndividualCategorySections(
        contentService.movies,
        contentType: 'movie',
      );
      sections.addAll([
        ...movieSections.take(3).map((categorySection) =>
          _ContentList(
            title: categorySection['title']!,
            contentList: categorySection['content'].take(8).toList(),
          ),
        ),
      ]);
    } else if (_selectedCategory == 'Anime') {
      sections.addAll([
        _ContentList(title: 'Anime Movies', contentList: contentService.animeMovies.take(8).toList()),
        _ContentList(title: 'Anime Series', contentList: contentService.animeSeries.take(8).toList()),
      ]);
      
      final animeSections = _getIndividualCategorySections(
        contentService.allAnime,
        contentType: 'anime',
      );
      sections.addAll([
        ...animeSections.take(2).map((categorySection) =>
          _ContentList(
            title: categorySection['title']!,
            contentList: categorySection['content'].take(8).toList(),
          ),
        ),
      ]);
    }
  }

  return SliverList(
    delegate: SliverChildListDelegate(sections),
  );
}

// NEW: Helper method to create individual category sections from comma-separated categories
List<Map<String, dynamic>> _getIndividualCategorySections(
  List<ContentItem> contentList, {
  String? contentType,
}) {
  // Create a map to group content by individual categories
  final Map<String, List<ContentItem>> categoryMap = {};
  
  for (final item in contentList) {
    // Split comma-separated categories and trim whitespace
    final categories = item.category.split(',').map((cat) => cat.trim()).toList();
    
    for (final category in categories) {
      if (category.isNotEmpty) {
        if (!categoryMap.containsKey(category)) {
          categoryMap[category] = [];
        }
        categoryMap[category]!.add(item);
      }
    }
  }
  
  // Convert to list of maps and sort by content count (most popular first)
  final List<Map<String, dynamic>> sections = categoryMap.entries
      .map((entry) => {
            'title': entry.key,
            'content': entry.value,
          })
      .toList();
  
  // Sort by number of items in each category (descending)
  sections.sort((a, b) => (b['content'] as List).length.compareTo((a['content'] as List).length));
  
  return sections;
}

}

class _CustomSliverAppBar extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategoryChanged;
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
      // Make logo clickable
      title: GestureDetector(
        onTap: onLogoTap,
        child: Image.asset('assets/logo1.png', height: 170),
      ),
      centerTitle: true,
      // Add back button when not on "All" category
      leading: selectedCategory != 'All' 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => onCategoryChanged('All'),
            )
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40.0),
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
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        children: [
          if (onRefresh != null)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
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
                builder: (context) => ContentDetailScreen(content: featuredContent),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                featuredContent.posterUrl,
                height: 400,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 400,
                    color: Colors.grey[800],
                    child: const Icon(Icons.error, color: Colors.white),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${featuredContent.category} • ${featuredContent.contentType}',
            style: const TextStyle(color: Colors.white, fontSize: 14.0),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PlayButton(content: featuredContent),
              _InfoButton(content: featuredContent),
            ],
          )
        ],
      ),
    );
  }
}

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
        label: const Text('Play', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _handlePlayButton(BuildContext context) async {
    final isSetupComplete = await TelegramService.isSetupComplete();
    
    if (isSetupComplete) {
      // Send directly without dialog
      _sendDirectly(context);
    } else {
      // Show setup dialog
      _showTelegramDialog(context);
    }
  }

  Future<void> _sendDirectly(BuildContext context) async {
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
        linkIndex: 0, // Default to first link
      );

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? '✅ Files sent successfully!'
                : '❌ Failed to send files.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTelegramDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TelegramSetupDialog(
        content: content,
        linkIndex: 0,
      ),
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
            builder: (context) => ContentDetailScreen(content: content),
          ),
        ),
        style: FilledButton.styleFrom(backgroundColor: Colors.grey.shade800),
        icon: const Icon(Icons.info_outline, color: Colors.white),
        label: const Text('Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ContentList extends StatelessWidget {
  final String title;
  final List<ContentItem> contentList;
  const _ContentList({required this.title, required this.contentList});

  @override
  Widget build(BuildContext context) {
    if (contentList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 220.0,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: contentList.length,
              itemBuilder: (BuildContext context, int index) {
                final ContentItem content = contentList[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContentDetailScreen(content: content),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    height: 200.0,
                    width: 130.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        content.posterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, color: Colors.white),
                                const SizedBox(height: 8),
                                Text(
                                  content.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
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
