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

  factory ComparisonCluster.fromJson(Map<String, dynamic> json) {
    return ComparisonCluster(
      clusterId: (json['cluster_id'] as num?)?.toInt() ?? 0,
      sources:
          (json['sources'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      titles:
          (json['titles'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      category: (json['category'] ?? '').toString(),
      oneLiner: (json['one_liner'] ?? '').toString(),
      shortSummary: (json['short_summary'] ?? '').toString(),
      keyPoints: (json['key_points'] ?? '').toString(),
      missingInfo: (json['missing_info'] ?? '').toString(),
      coverageBreakdown: (json['coverage_breakdown'] ?? '').toString(),
    );
  }
}
