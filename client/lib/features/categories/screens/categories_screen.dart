import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'category_items_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<Map<String, dynamic>> categories = [
    {'name': 'Clothes', 'icon': Icons.checkroom, 'color': Color(0xFF8B5CF6), 'emoji': '👕', 'gradient': [Color(0xFF8B5CF6), Color(0xFFA78BFA)]},
    {'name': 'Food', 'icon': Icons.restaurant, 'color': Color(0xFF10B981), 'emoji': '🍲', 'gradient': [Color(0xFF10B981), Color(0xFF34D399)]},
    {'name': 'Electronics', 'icon': Icons.devices, 'color': Color(0xFF3B82F6), 'emoji': '📱', 'gradient': [Color(0xFF3B82F6), Color(0xFF60A5FA)]},
    {'name': 'Books', 'icon': Icons.menu_book, 'color': Color(0xFFF59E0B), 'emoji': '📚', 'gradient': [Color(0xFFF59E0B), Color(0xFFFBBF24)]},
    {'name': 'Furniture', 'icon': Icons.chair, 'color': Color(0xFFEF4444), 'emoji': '🪑', 'gradient': [Color(0xFFEF4444), Color(0xFFF87171)]},
    {'name': 'Toys', 'icon': Icons.toys, 'color': Color(0xFFEC4899), 'emoji': '🧸', 'gradient': [Color(0xFFEC4899), Color(0xFFF472B6)]},
    {'name': 'Tools', 'icon': Icons.build, 'color': Color(0xFF64748B), 'emoji': '🔧', 'gradient': [Color(0xFF64748B), Color(0xFF94A3B8)]},
    {'name': 'Other', 'icon': Icons.more_horiz, 'color': Color(0xFF14B8A6), 'emoji': '📦', 'gradient': [Color(0xFF14B8A6), Color(0xFF5EEAD4)]},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Categories', style: AppTheme.headingMd),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.05,
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

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final List<Color> gradient = category['gradient'];
    final Color color = category['color'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradient[0].withValues(alpha: 0.12), gradient[1].withValues(alpha: 0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(category['emoji'] ?? '', style: const TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                category['name'],
                style: GoogleFonts.inter(
                  fontSize: 15,
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
