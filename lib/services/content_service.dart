// lib/services/content_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuflix/models/content_item.dart';

class ContentService extends ChangeNotifier {
  static const String csvUrl = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vQf6DkBvmrYvRNUql0nmXTVegXCR55qldn4vS1IolTsoR7e6sVG6mF8UDKj6q8XyUPVF8rWpbUQgBSb/pub?gid=0&single=true&output=csv';
  static const String _cacheKey = 'cached_content_data';
  static const String _cacheTimeKey = 'cache_timestamp';
  
  List<ContentItem> _allContent = [];
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedOnce = false; // NEW: Track if we've loaded data this session

  List<ContentItem> get allContent => _allContent;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Filtered content by type
  List<ContentItem> get tvShows => _allContent.where((item) => item.isTVShow).toList();
  List<ContentItem> get movies => _allContent.where((item) => item.isMovie).toList();
  List<ContentItem> get animeMovies => _allContent.where((item) => item.isAnimeMovie).toList();
  List<ContentItem> get animeSeries => _allContent.where((item) => item.isAnimeSeries).toList();
  List<ContentItem> get allAnime => _allContent.where((item) => item.isAnime).toList();

  // NEW: Get random featured content
  ContentItem? getRandomFeaturedContent() {
    if (_allContent.isEmpty) return null;
    final random = Random();
    return _allContent[random.nextInt(_allContent.length)];
  }

  // NEW: Get content by selected filter
  List<ContentItem> getFilteredContent(String filter) {
    switch (filter.toLowerCase()) {
      case 'tv shows':
        return tvShows;
      case 'movies':
        return movies;
      case 'anime':
        return allAnime;
      default:
        return _allContent;
    }
  }

  // Get unique categories for each type
  List<String> get tvShowCategories => tvShows.map((e) => e.category).toSet().toList();
  List<String> get movieCategories => movies.map((e) => e.category).toSet().toList();
  List<String> get animeCategories => allAnime.map((e) => e.category).toSet().toList();

  // NEW: Smart loading - only load if not already loaded this session
  Future<void> loadContentIfNeeded() async {
    if (_hasLoadedOnce && _allContent.isNotEmpty) {
      // print('Content already loaded this session, skipping...');
      return;
    }
    await loadContent();
  }

  Future<void> loadContent() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // NEW: Try to load from cache first
      final cachedData = await _loadFromCache();
      if (cachedData != null) {
        _allContent = cachedData;
        _hasLoadedOnce = true;
        // print('Loaded ${_allContent.length} items from cache');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // If no cache, download from network
      // print('No cache found, downloading from network...');
      final response = await http.get(Uri.parse(csvUrl));
      
      if (response.statusCode == 200) {
        final csvData = const CsvToListConverter().convert(response.body);
        final contentRows = csvData.skip(1);
        
        _allContent = contentRows
            .map((row) => ContentItem.fromCsvRow(row))
            .where((item) => item.name.isNotEmpty)
            .toList();
        
        // NEW: Cache the data
        await _saveToCache(_allContent);
        _hasLoadedOnce = true;
        // print('Loaded ${_allContent.length} content items from network');
      } else {
        _error = 'Failed to load content: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error loading content: $e';
      // print('Error loading content: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // NEW: Cache management methods
  Future<List<ContentItem>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        return jsonList.map((json) => ContentItem.fromJson(json)).toList();
      }
    } catch (e) {
      // print('Error loading from cache: $e');
    }
    return null;
  }

  Future<void> _saveToCache(List<ContentItem> content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(content.map((item) => item.toJson()).toList());
      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      // print('Content cached successfully');
    } catch (e) {
      // print('Error saving to cache: $e');
    }
  }

  // NEW: Force refresh (for pull-to-refresh)
  Future<void> forceRefresh() async {
    _hasLoadedOnce = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
    await loadContent();
  }

  List<ContentItem> getContentByCategory(String category, {String? contentType}) {
    var filtered = _allContent.where((item) => 
        item.category.toLowerCase().contains(category.toLowerCase()));
    
    if (contentType != null) {
      switch (contentType.toLowerCase()) {
        case 'tv':
          filtered = filtered.where((item) => item.isTVShow);
          break;
        case 'movie':
          filtered = filtered.where((item) => item.isMovie);
          break;
        case 'anime':
          filtered = filtered.where((item) => item.isAnime);
          break;
      }
    }
    
    return filtered.toList();
  }
}
