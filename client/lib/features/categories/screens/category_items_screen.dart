import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';

class CategoryItemsScreen extends StatelessWidget {
  final String category;

  const CategoryItemsScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final itemsRef = FirebaseDatabase.instance.ref().child('items');

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(category, style: AppTheme.headingMd),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder(
        stream: itemsRef.orderByChild('category').equalTo(category).onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5));
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('No $category items yet', style: AppTheme.bodyLg.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            );
          }

          final Map<dynamic, dynamic> map = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final items = map.entries
              .map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value as Map)})
              .where((i) => i['status'] != 'claimed' && i['status'] != 'deleted')
              .toList()
              .reversed
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.softShadow,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      color: AppTheme.surfaceVariant,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item['imageUrl'] != null
                        ? CachedNetworkImage(imageUrl: item['imageUrl'], fit: BoxFit.cover)
                        : const Icon(Icons.volunteer_activism_rounded, color: AppTheme.primary),
                  ),
                  title: Text(
                    item['title'] ?? 'Item',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item['location'] ?? 'Unknown',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
