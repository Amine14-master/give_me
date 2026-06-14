import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../items/screens/item_details_screen.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  String? _currentUserId;
  List<Map<String, dynamic>> _savedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedItems();
  }

  Future<void> _loadSavedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('phoneNumber');
    if (userId == null) return;
    setState(() => _currentUserId = userId);

    final ref = FirebaseDatabase.instance.ref();
    final likesRef = ref.child('users/$userId/savedItems');
    final itemsRef = ref.child('items');

    // Currently we don't have "savedItems" table natively built. 
    // Wait, the Like button saves to `items/$itemId/likes/$userId`.
    // We should either query all items where user has liked, or build an index.
    // For simplicity, we fetch all items and filter locally (small dataset usually) or build a listener.

    itemsRef.onValue.listen((event) {
      if (event.snapshot.value == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final Map<dynamic, dynamic> itemsMap = event.snapshot.value as Map<dynamic, dynamic>;
      final itemsList = itemsMap.entries.map((e) => {
        'id': e.key,
        ...Map<String, dynamic>.from(e.value as Map)
      }).toList();

      final likedItems = itemsList.where((item) {
        final likes = item['likes'] as Map?;
        return likes != null && likes.containsKey(userId);
      }).toList();

      if (mounted) {
        setState(() {
          _savedItems = likedItems;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Saved Items', style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.surfaceVariant, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _savedItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: AppTheme.warmCoral.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.favorite_border_rounded, size: 64, color: AppTheme.warmCoral),
                      ),
                      const SizedBox(height: 16),
                      Text('No saved items yet', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Text('Items you like will appear here.', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _savedItems.length,
                  itemBuilder: (context, index) {
                    final item = _savedItems[index];
                    return _SavedItemCard(item: item, currentUserId: _currentUserId);
                  },
                ),
    );
  }
}

class _SavedItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String? currentUserId;

  const _SavedItemCard({required this.item, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final category = item['category'] ?? 'Other';
    final color = Color(AppTheme.categoryStyles[category]?['color'] ?? 0xFF14B8A6);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(
              item: item,
              currentUserId: currentUserId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: AppTheme.surfaceVariant),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppTheme.radiusLg), bottomLeft: Radius.circular(AppTheme.radiusLg)),
              child: item['imageUrl'] != null
                  ? CachedNetworkImage(
                      imageUrl: item['imageUrl'],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: color.withValues(alpha: 0.1),
                      child: Icon(Icons.volunteer_activism_rounded, color: color),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
                      child: Text(category, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ),
                    const SizedBox(height: 6),
                    Text(item['title'] ?? '', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(item['location'] ?? 'Unknown location', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
