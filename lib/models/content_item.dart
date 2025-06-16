// lib/models/content_item.dart

class ContentItem {
  final String name;
  final String posterUrl;
  final String contentType;
  final String? season;
  final String? episodeType;
  final String? link1;
  final String? link2;
  final String? link3;
  final String? link4;
  final String description;
  final String category;

  ContentItem({
    required this.name,
    required this.posterUrl,
    required this.contentType,
    this.season,
    this.episodeType,
    this.link1,
    this.link2,
    this.link3,
    this.link4,
    required this.description,
    required this.category,
  });

  factory ContentItem.fromCsvRow(List<dynamic> row) {
    return ContentItem(
      name: row.isNotEmpty ? row[0]?.toString() ?? '' : '',
      posterUrl: row.length > 1 ? row[1]?.toString() ?? '' : '',
      contentType: row.length > 2 ? row[2]?.toString() ?? '' : '',
      season: row.length > 3 ? row[3]?.toString() : null,
      episodeType: row.length > 4 ? row[4]?.toString() : null,
      link1: row.length > 5 ? row[5]?.toString() : null,
      link2: row.length > 6 ? row[6]?.toString() : null,
      link3: row.length > 7 ? row[7]?.toString() : null,
      link4: row.length > 8 ? row[8]?.toString() : null,
      description: row.length > 9 ? row[9]?.toString() ?? '' : '',
      category: row.length > 10 ? row[10]?.toString() ?? '' : '',
    );
  }

  // NEW: JSON serialization methods for caching
  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      name: json['name'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      contentType: json['contentType'] ?? '',
      season: json['season'],
      episodeType: json['episodeType'],
      link1: json['link1'],
      link2: json['link2'],
      link3: json['link3'],
      link4: json['link4'],
      description: json['description'] ?? '',
      category: json['category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'posterUrl': posterUrl,
      'contentType': contentType,
      'season': season,
      'episodeType': episodeType,
      'link1': link1,
      'link2': link2,
      'link3': link3,
      'link4': link4,
      'description': description,
      'category': category,
    };
  }

  bool get isTVShow => contentType.toUpperCase().contains('TV SHOW');
  bool get isMovie => contentType.toUpperCase().contains('MOVIE') && !contentType.toUpperCase().contains('ANIME');
  bool get isAnimeMovie => contentType.toUpperCase().contains('ANIME MOVIE');
  bool get isAnimeSeries => contentType.toUpperCase().contains('ANIME SERIES');
  bool get isAnime => isAnimeMovie || isAnimeSeries;

  List<String> get availableLinks {
    return [link1, link2, link3, link4]
        .where((link) => link != null && link.isNotEmpty)
        .cast<String>()
        .toList();
  }
}
