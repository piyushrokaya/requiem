class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.summary,
    this.fullText,
    this.category = '',
  });

  final String id;
  final String title;
  final String source;
  final Uri url;
  final DateTime publishedAt;
  final String summary;
  final String? fullText;
  final String category;

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['_id'] as String,
      title: json['title'] as String,
      source: json['source'] as String,
      url: Uri.parse(json['link'] as String),
      publishedAt: DateTime.parse(json['createdAt'] as String),
      summary: json['description'] as String,
      fullText: json['content'] as String?,
      category: (json['category'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'source': source,
    'link': url.toString(),
    'createdAt': publishedAt.toIso8601String(),
    'description': summary,
    'content': fullText,
    'category': category,
  };
}
