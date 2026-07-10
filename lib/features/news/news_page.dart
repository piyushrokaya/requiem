import 'package:flutter/material.dart';

import '../../core/data/dummy_data.dart';
import '../article/article_detail_page.dart';

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final articles = dummyArticles;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('शीर्ष समाचार', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...articles.map(
          (a) => Card(
            child: ListTile(
              title: Text(a.title),
              subtitle: Text('${a.source} • ${_relativeTime(a.publishedAt)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailPage(article: a),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} मिनेट अघि';
    if (diff.inHours < 24) return '${diff.inHours} घण्टा अघि';
    return '${diff.inDays} दिन अघि';
  }
}
