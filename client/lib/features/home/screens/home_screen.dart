import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_helper.dart';
import '../../../core/services/notification_service.dart';
import '../../messages/screens/chat_screen.dart';
import '../../profile/screens/public_profile_screen.dart';
import '../../items/screens/edit_item_screen.dart';
import '../../items/screens/item_details_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../categories/screens/categories_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _itemsRef = FirebaseDatabase.instance.ref().child('items');
  String? _currentUserId;
  Position? _currentPosition;
  Set<String> _viewedPostIds = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _currentPosition = pos);
      }
    } catch (_) {}
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('phoneNumber');
    setState(() {
      _currentUserId = userId;
    });

    if (userId != null) {
      final snap = await FirebaseDatabase.instance.ref().child('users/$userId/viewedPosts').get();
      if (snap.exists && snap.value != null) {
        final Map map = snap.value as Map;
        if (mounted) {
          setState(() {
            _viewedPostIds = map.keys.map((k) => k.toString()).toSet();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Premium SliverAppBar ──
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.primaryDark,
            surfaceTintColor: Colors.transparent,
            actions: [
              // Map Icon
              IconButton(
                icon: const Icon(Icons.map_rounded, color: Colors.white, size: 24),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(
                    initialPosition: _currentPosition,
                    currentUserId: _currentUserId,
                  )));
                },
              ),
              // Notification bell
              StreamBuilder<int>(
                stream: NotificationService().unreadCount,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? NotificationService().currentUnreadCount;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                          },
                        ),
                        if (count > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.warmCoral,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primaryDark, width: 2),
                              ),
                              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                              child: Text('$count', style: GoogleFonts.inter(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
                              ), textAlign: TextAlign.center),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                child: Padding(
                  padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find Free Items\nNearby',
                        style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800,
                          height: 1.2, letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Search Bar ──
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.7), size: 22),
                              const SizedBox(width: 12),
                              Text(
                                'Search clothes, food, books...',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.6), fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Feed ──
          StreamBuilder(
            stream: _itemsRef.onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
                        const SizedBox(height: 16),
                        Text('Loading items...', style: AppTheme.bodySm),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No items available yet', style: AppTheme.bodyLg.copyWith(color: AppTheme.textMuted)),
                        const SizedBox(height: 8),
                        Text('Be the first to give! 🎁', style: AppTheme.bodySm),
                      ],
                    ),
                  ),
                );
              }

              final Map<dynamic, dynamic> itemsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              final items = itemsMap.entries.map((e) => {
                'id': e.key,
                ...Map<String, dynamic>.from(e.value as Map)
              }).toList();

              final availableItems = items.where((i) => i['status'] != 'claimed' && i['status'] != 'deleted').toList().reversed.toList();
              
              final unviewedItems = availableItems.where((i) => !_viewedPostIds.contains(i['id'])).toList();
              final itemsToShow = unviewedItems.isNotEmpty ? unviewedItems : availableItems;

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = itemsToShow[index];
                      return _ItemCard(item: item, currentUserId: _currentUserId, currentPosition: _currentPosition);
                    },
                    childCount: itemsToShow.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ─── ITEM CARD ───────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════

class _ItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? currentUserId;
  final Position? currentPosition;

  const _ItemCard({super.key, required this.item, this.currentUserId, this.currentPosition});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> with SingleTickerProviderStateMixin {
  String? _ownerProfileImage;
  String? _placeName;
  late AnimationController _likeAnimController;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _loadOwnerInfo();
    _markAsViewed();
    _resolveLocationName();
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    super.dispose();
  }

  void _markAsViewed() {
    if (widget.currentUserId != null) {
      FirebaseDatabase.instance.ref().child('users/${widget.currentUserId}/viewedPosts/${widget.item['id']}').set(true);
    }
  }

  Future<void> _loadOwnerInfo() async {
    final ref = FirebaseDatabase.instance.ref().child('users/${widget.item['userId']}/profileImage');
    final snap = await ref.get();
    if (snap.exists && mounted) {
      setState(() => _ownerProfileImage = snap.value as String);
    }
  }

  Future<void> _resolveLocationName() async {
    final stored = widget.item['location'] as String? ?? '';
    if (stored.isNotEmpty && !stored.startsWith('Lat:') && !RegExp(r'^-?\d+\.\d+').hasMatch(stored)) {
      setState(() => _placeName = stored);
      return;
    }
    final lat = widget.item['lat'] as num?;
    final lng = widget.item['lng'] as num?;
    if (lat != null && lng != null) {
      try {
        final placemarks = await placemarkFromCoordinates(lat.toDouble(), lng.toDouble());
        if (placemarks.isNotEmpty && mounted) {
          final p = placemarks.first;
          final parts = <String>[
            if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
            if (p.locality != null && p.locality!.isNotEmpty && p.locality != p.subLocality) p.locality!,
          ];
          if (parts.isEmpty && p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
            parts.add(p.administrativeArea!);
          }
          final name = parts.isNotEmpty ? parts.join(', ') : stored;
          setState(() => _placeName = name);
          FirebaseDatabase.instance.ref().child('items/${widget.item['id']}/location').set(name);
          return;
        }
      } catch (_) {}
    }
    setState(() => _placeName = stored.isNotEmpty ? stored : 'Unknown');
  }

  void _toggleLike() {
    if (widget.currentUserId == null) return;
    final String itemId = widget.item['id'];
    final ref = FirebaseDatabase.instance.ref().child('items/$itemId/likes/${widget.currentUserId}');
    
    final Map<dynamic, dynamic> likes = widget.item['likes'] ?? {};
    if (likes.containsKey(widget.currentUserId)) {
      ref.remove();
    } else {
      ref.set(true);
      _likeAnimController.forward().then((_) => _likeAnimController.reverse());
      NotificationHelper.onLike(
        itemOwnerId: widget.item['userId'],
        likerUserId: widget.currentUserId!,
        itemTitle: widget.item['title'] ?? 'Item',
      );
    }
  }

  void _messageOwner(BuildContext context) {
    if (widget.currentUserId == null || widget.currentUserId == widget.item['userId']) return;
    
    final participants = [widget.currentUserId!, widget.item['userId'] as String]..sort();
    final chatId = '${participants[0]}_${participants[1]}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: widget.item['userId'],
          itemTitle: widget.item['title'],
        ),
      ),
    );
  }

  void _openMaps() async {
    final lat = widget.item['lat'];
    final lng = widget.item['lng'];
    final Uri url;
    if (lat != null && lng != null) {
      url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    } else {
      url = Uri.parse('https://maps.google.com/?q=${widget.item['location'] ?? ''}');
    }
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _callOwner() async {
    final url = Uri.parse('tel:${widget.item['userId']}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _viewProfile(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: widget.item['userId'])));
  }

  void _requestItem() async {
    if (widget.currentUserId == null) return;
    
    final requests = widget.item['requests'] as Map? ?? {};
    if (requests.containsKey(widget.currentUserId)) return;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final limitRef = FirebaseDatabase.instance.ref().child('users/${widget.currentUserId}/dailyLimits/$todayStr');
    final snap = await limitRef.get();
    int countToday = (snap.value as int?) ?? 0;
    
    if (countToday >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only request 3 items per day!', style: GoogleFonts.inter()),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    final ref = FirebaseDatabase.instance.ref().child('items/${widget.item['id']}/requests/${widget.currentUserId}');
    await ref.set({
      'timestamp': ServerValue.timestamp,
      'status': 'pending'
    });

    await limitRef.set(countToday + 1);

    final statsRef = FirebaseDatabase.instance.ref().child('users/${widget.currentUserId}/stats/requestsMade');
    final snapshot = await statsRef.get();
    int currentReqs = (snapshot.value as int?) ?? 0;
    await statsRef.set(currentReqs + 1);

    NotificationHelper.onRequest(
      itemOwnerId: widget.item['userId'],
      requesterUserId: widget.currentUserId!,
      itemTitle: widget.item['title'] ?? 'Item',
      itemId: widget.item['id'],
    );
  }

  void _deletePost() {
    if (widget.currentUserId == null || widget.item['userId'] != widget.currentUserId) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Post', style: AppTheme.headingMd),
        content: Text('Are you sure you want to delete this post?', style: AppTheme.bodySm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              FirebaseDatabase.instance.ref().child('items/${widget.item['id']}/status').set('deleted');
              Navigator.pop(ctx);
            }, 
            child: Text('Delete', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _editPost() {
    if (widget.currentUserId == null || widget.item['userId'] != widget.currentUserId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditItemScreen(
          itemId: widget.item['id'],
          initialTitle: widget.item['title'] ?? '',
          initialDesc: widget.item['description'] ?? '',
          initialCategory: widget.item['category'] ?? 'Other',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final currentUserId = widget.currentUserId;
    final Map? likesMap = item['likes'] as Map?;
    final int likesCount = likesMap?.length ?? 0;
    final bool isLiked = currentUserId != null && likesMap?.containsKey(currentUserId) == true;
    final bool hasRequested = (item['requests'] as Map? ?? {}).containsKey(currentUserId);
    final bool isOwner = currentUserId == item['userId'];
    final String category = item['category'] ?? 'Other';

    String displayDistance = '';
    if (widget.currentPosition != null && item['lat'] != null && item['lng'] != null) {
      double d = Geolocator.distanceBetween(
        widget.currentPosition!.latitude, widget.currentPosition!.longitude,
        (item['lat'] as num).toDouble(), (item['lng'] as num).toDouble(),
      );
      displayDistance = '${(d / 1000).toStringAsFixed(1)} km';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(
              item: item,
              currentUserId: currentUserId,
              currentPosition: widget.currentPosition,
            ),
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: Avatar + Name + Actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _viewProfile(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 8)],
                    ),
                    child: ClipOval(
                      child: _ownerProfileImage != null
                          ? CachedNetworkImage(imageUrl: _ownerProfileImage!, fit: BoxFit.cover)
                          : const Icon(Icons.person, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['userId'] ?? 'Unknown',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (displayDistance.isNotEmpty) ...[
                            Icon(Icons.near_me_rounded, size: 12, color: AppTheme.primary.withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Text(displayDistance, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 3, height: 3,
                              decoration: BoxDecoration(color: AppTheme.textMuted.withValues(alpha: 0.4), shape: BoxShape.circle),
                            ),
                          ],
                          Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textMuted.withValues(alpha: 0.7)),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              _placeName ?? '...',
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Quick actions
                IconButton(
                  icon: Icon(Icons.phone_outlined, color: AppTheme.primary.withValues(alpha: 0.7), size: 20),
                  onPressed: _callOwner,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.map_outlined, color: AppTheme.primary.withValues(alpha: 0.7), size: 20),
                  onPressed: _openMaps,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // ── Title + Description ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? '',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(AppTheme.categoryStyles[category]?['color'] ?? 0xFF14B8A6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(AppTheme.categoryStyles[category]?['color'] ?? 0xFF14B8A6),
                        ),
                      ),
                    ),
                  ],
                ),
                if (item['description'] != null && (item['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item['description'],
                    style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Image ──
          if (item['imageUrl'] != null)
            Hero(
              tag: 'item_image_${item['id']}',
              child: ClipRRect(
                child: CachedNetworkImage(
                  imageUrl: item['imageUrl'],
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    height: 200,
                    color: AppTheme.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 200,
                    color: AppTheme.surfaceVariant,
                    child: const Center(child: Icon(Icons.broken_image_rounded, size: 40, color: AppTheme.textMuted)),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 140,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(AppTheme.categoryStyles[category]?['color'] ?? 0xFF14B8A6).withValues(alpha: 0.08),
                    Color(AppTheme.categoryStyles[category]?['color'] ?? 0xFF14B8A6).withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Center(
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  size: 48,
                  color: Color(AppTheme.categoryStyles[category]?['color'] ?? 0xFF14B8A6).withValues(alpha: 0.4),
                ),
              ),
            ),

          // ── Like count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF3B82F6)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.thumb_up_rounded, size: 10, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Text('$likesCount', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                if (hasRequested)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.success),
                      const SizedBox(width: 4),
                      Text('Requested', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
          ),

          // ── Divider ──
          Divider(height: 1, color: Colors.grey.shade100),

          // ── Action Buttons ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                  color: isLiked ? AppTheme.primary : AppTheme.textMuted,
                  label: 'Like',
                  onTap: _toggleLike,
                ),
                if (currentUserId != null && !isOwner) ...[
                  _buildActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppTheme.textMuted,
                    label: 'Message',
                    onTap: () => _messageOwner(context),
                  ),
                  _buildActionButton(
                    icon: hasRequested ? Icons.check_circle_rounded : Icons.volunteer_activism_outlined,
                    color: hasRequested ? AppTheme.success : AppTheme.accent,
                    label: hasRequested ? 'Sent' : 'Request',
                    onTap: _requestItem,
                  ),
                ],
                if (isOwner) ...[
                  _buildActionButton(
                    icon: Icons.edit_outlined,
                    color: AppTheme.info,
                    label: 'Edit',
                    onTap: _editPost,
                  ),
                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: AppTheme.error,
                    label: 'Delete',
                    onTap: _deletePost,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
