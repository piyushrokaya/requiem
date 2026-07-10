import 'package:flutter/material.dart';

import '../../core/data/dummy_data.dart';
import 'compare_detail_page.dart';

class ComparePage extends StatelessWidget {
  const ComparePage({super.key});

  @override
  Widget build(BuildContext context) {
    final clusters = dummyClusters;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clusters.length,
      itemBuilder: (context, index) {
        final cluster = clusters[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CompareDetailPage(cluster: cluster),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cluster.category,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(cluster.oneLiner),
                  const SizedBox(height: 8),
                  Text('Sources: ${cluster.sources.join(', ')}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
