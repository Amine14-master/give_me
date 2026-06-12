import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/theme/app_theme.dart';

class CategoryItemsScreen extends StatelessWidget {
  final String category;

  const CategoryItemsScreen({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _itemsRef = FirebaseDatabase.instance.ref().child('items');

    return Scaffold(
      appBar: AppBar(
        title: Text('$category Items'),
      ),
      body: StreamBuilder(
        stream: _itemsRef.orderByChild('category').equalTo(category).onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Text('No items found in $category.', style: const TextStyle(color: AppTheme.textMuted)),
            );
          }

          final Map<dynamic, dynamic> itemsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final items = itemsMap.entries.map((e) => {
            'id': e.key,
            ...Map<String, dynamic>.from(e.value as Map)
          }).where((i) => i['status'] != 'claimed').toList().reversed.toList();

          if (items.isEmpty) {
            return Center(
              child: Text('All $category items have been claimed.', style: const TextStyle(color: AppTheme.textMuted)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: item['imageUrl'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(item['imageUrl'], width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image)),
                        )
                      : Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(color: AppTheme.primaryLight.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.image, color: AppTheme.primary),
                        ),
                  title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(item['location'] ?? 'Algiers, Algeria'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to detail if needed or do nothing.
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
