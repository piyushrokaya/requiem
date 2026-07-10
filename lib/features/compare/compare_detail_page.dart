import 'package:flutter/material.dart';

import '../../core/models/comparison_cluster.dart';

class CompareDetailPage extends StatelessWidget {
  const CompareDetailPage({super.key, required this.cluster});

  final ComparisonCluster cluster;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(cluster.category)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              cluster.oneLiner,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (cluster.shortSummary.isNotEmpty) ...[
              Text('Short Summary:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(cluster.shortSummary),
              const SizedBox(height: 12),
            ],
            if (cluster.keyPoints.isNotEmpty) ...[
              Text('Key Points:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(cluster.keyPoints),
              const SizedBox(height: 12),
            ],
            if (cluster.coverageBreakdown.isNotEmpty) ...[
              Text(
                'Coverage Breakdown:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(cluster.coverageBreakdown),
              const SizedBox(height: 12),
            ],
            if (cluster.missingInfo.isNotEmpty) ...[
              Text('Missing Info:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(cluster.missingInfo),
            ],
          ],
        ),
      ),
    );
  }
}
