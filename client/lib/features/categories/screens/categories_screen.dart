import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'category_items_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> categories = const [
    {'name': 'Clothes', 'icon': Icons.checkroom, 'color': Color(0xFF8B5CF6)},
    {'name': 'Food', 'icon': Icons.restaurant, 'color': Color(0xFF10B981)},
    {'name': 'Electronics', 'icon': Icons.devices, 'color': Color(0xFF3B82F6)},
    {'name': 'Books', 'icon': Icons.menu_book, 'color': Color(0xFFF59E0B)},
    {'name': 'Furniture', 'icon': Icons.chair, 'color': Color(0xFFEF4444)},
    {'name': 'Toys', 'icon': Icons.toys, 'color': Color(0xFFEC4899)},
    {'name': 'Tools', 'icon': Icons.build, 'color': Color(0xFF64748B)},
    {'name': 'Other', 'icon': Icons.more_horiz, 'color': Color(0xFF14B8A6)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return _CategoryCard(category: cat);
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;

  const _CategoryCard({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color color = category['color'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CategoryItemsScreen(category: category['name'])),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(category['icon'], size: 36, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                category['name'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
