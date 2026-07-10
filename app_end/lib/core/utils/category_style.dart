import 'package:flutter/material.dart';

class CategoryStyle {
  const CategoryStyle(this.color, this.icon);

  final Color color;
  final IconData icon;
}

CategoryStyle categoryStyleFor(String category) {
  switch (category.toLowerCase()) {
    case 'politics':
      return const CategoryStyle(Color(0xFF8E4EC6), Icons.account_balance);
    case 'business':
      return const CategoryStyle(Color(0xFF2F9E6E), Icons.trending_up);
    case 'sports':
      return const CategoryStyle(Color(0xFFE2762E), Icons.sports_soccer);
    case 'health':
      return const CategoryStyle(Color(0xFFD64550), Icons.health_and_safety);
    case 'crime':
      return const CategoryStyle(Color(0xFF5C6470), Icons.gavel);
    case 'entertainment':
      return const CategoryStyle(Color(0xFFC94F8B), Icons.theater_comedy);
    case 'general':
      return const CategoryStyle(Color(0xFF2F5DE3), Icons.article);
    default:
      return const CategoryStyle(Color(0xFF2F5DE3), Icons.article);
  }
}

/// Nepali label shown to users for a backend category key (e.g. "Politics").
String categoryLabelNepali(String category) {
  switch (category.toLowerCase()) {
    case 'politics':
      return 'राजनीति';
    case 'business':
      return 'व्यापार';
    case 'sports':
      return 'खेलकुद';
    case 'health':
      return 'स्वास्थ्य';
    case 'crime':
      return 'अपराध';
    case 'entertainment':
      return 'मनोरञ्जन';
    case 'general':
      return 'सामान्य';
    default:
      return category;
  }
}
