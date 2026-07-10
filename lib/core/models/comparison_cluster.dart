class ComparisonCluster {
  const ComparisonCluster({
    required this.clusterId,
    required this.sources,
    required this.titles,
    required this.category,
    required this.oneLiner,
    required this.shortSummary,
    required this.keyPoints,
    required this.missingInfo,
    required this.coverageBreakdown,
  });

  final int clusterId;
  final List<String> sources;
  final List<String> titles;
  final String category;
  final String oneLiner;
  final String shortSummary;
  final String keyPoints;
  final String missingInfo;
  final String coverageBreakdown;
}
