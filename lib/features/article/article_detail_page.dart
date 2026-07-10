import 'package:flutter/material.dart';

import '../../core/models/news_article.dart';

class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({super.key, required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final bodyText = (article.fullText ?? '').trim().isNotEmpty
        ? article.fullText!
        : article.summary;

    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(article.source, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(bodyText),
            ),
          ),
        ],
      ),
    );
  }
}
