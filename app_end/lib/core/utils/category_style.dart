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
    default:
      return const CategoryStyle(Color(0xFF2F5DE3), Icons.article);
  }
}
