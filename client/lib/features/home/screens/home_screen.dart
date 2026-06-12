import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_helper.dart';
import '../../../core/services/notification_service.dart';
import '../../messages/screens/chat_screen.dart';
import '../../profile/screens/public_profile_screen.dart';
import '../../items/screens/edit_item_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import 'item_requests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

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
      backgroundColor: Colors.grey[200],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            actions: [
              StreamBuilder<int>(
                stream: NotificationService().unreadCount,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? NotificationService().currentUnreadCount;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
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
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                child: Padding(
                  padding: const EdgeInsets.only(top: 60, left: 24, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Find Free Items Nearby',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search clothes, food...',
                            prefixIcon: const Icon(Icons.search, color: AppTheme.primary, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          StreamBuilder(
            stream: _itemsRef.onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No items available', style: TextStyle(color: AppTheme.textMuted))),
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
                padding: const EdgeInsets.all(16),
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

class _ItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? currentUserId;
  final Position? currentPosition;

  const _ItemCard({Key? key, required this.item, this.currentUserId, this.currentPosition}) : super(key: key);

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  String? _ownerProfileImage;
  String? _placeName;

  @override
  void initState() {
    super.initState();
    _loadOwnerInfo();
    _markAsViewed();
    _resolveLocationName();
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

  /// Resolve a human-readable place name from coordinates if the stored
  /// location field looks like raw coordinates or is missing.
  Future<void> _resolveLocationName() async {
    final stored = widget.item['location'] as String? ?? '';
    // If it already has a proper name (doesn't start with digits/minus and doesn't contain 'Lat:'), use it
    if (stored.isNotEmpty && !stored.startsWith('Lat:') && !RegExp(r'^-?\d+\.\d+').hasMatch(stored)) {
      setState(() => _placeName = stored);
      return;
    }
    // Try reverse geocoding from lat/lng
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
          // Update the stored location in the DB so future loads are instant
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
      // Notify the item owner
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
          const SnackBar(content: Text('You can only request 3 items per day!'), backgroundColor: AppTheme.error),
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

    // Notify the item owner
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
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FirebaseDatabase.instance.ref().child('items/${widget.item['id']}/status').set('deleted');
              Navigator.pop(ctx);
            }, 
            child: const Text('Delete', style: TextStyle(color: AppTheme.error))
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

    String displayDistance = item['distance'] ?? '2.5 km';
    if (widget.currentPosition != null && item['lat'] != null && item['lng'] != null) {
      double d = Geolocator.distanceBetween(
        widget.currentPosition!.latitude, widget.currentPosition!.longitude,
        (item['lat'] as num).toDouble(), (item['lng'] as num).toDouble(),
      );
      displayDistance = '${(d / 1000).toStringAsFixed(1)} km';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: GestureDetector(
              onTap: () => _viewProfile(context),
              child: CircleAvatar(
                backgroundColor: AppTheme.primaryLight.withOpacity(0.2),
                backgroundImage: _ownerProfileImage != null ? NetworkImage(_ownerProfileImage!) : null,
                child: _ownerProfileImage == null ? const Icon(Icons.person, color: AppTheme.primary) : null,
              ),
            ),
            title: Text(
              item['userId'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '$displayDistance • ${_placeName ?? 'Loading...'}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.call, color: AppTheme.primary), onPressed: _callOwner),
                IconButton(icon: const Icon(Icons.map, color: AppTheme.primary), onPressed: _openMaps),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  item['description'] ?? '',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (item['imageUrl'] != null)
            Image.network(
              item['imageUrl'],
              fit: BoxFit.cover,
              height: 150,
              errorBuilder: (c, e, s) => const SizedBox(
                height: 150,
                child: Center(child: Icon(Icons.broken_image, size: 50, color: AppTheme.textMuted)),
              ),
            )
          else
            Container(
              height: 150,
              color: AppTheme.primaryLight.withOpacity(0.2),
              child: const Center(child: Icon(Icons.volunteer_activism, size: 60, color: AppTheme.primary)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.thumb_up, size: 10, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text('$likesCount', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                  color: isLiked ? AppTheme.primary : AppTheme.textMuted,
                  label: 'Like',
                  onTap: _toggleLike,
                ),
                if (currentUserId != null && currentUserId != item['userId']) ...[
                  _buildActionButton(
                    icon: Icons.chat_bubble_outline,
                    color: AppTheme.textMuted,
                    label: 'Message',
                    onTap: () => _messageOwner(context),
                  ),
                  _buildActionButton(
                    icon: (item['requests'] as Map? ?? {}).containsKey(currentUserId) ? Icons.check_circle : Icons.pan_tool_outlined,
                    color: (item['requests'] as Map? ?? {}).containsKey(currentUserId) ? AppTheme.success : AppTheme.textMuted,
                    label: (item['requests'] as Map? ?? {}).containsKey(currentUserId) ? 'Requested' : 'Request',
                    onTap: _requestItem,
                  ),
                ],
                if (currentUserId == item['userId']) ...[
                  _buildActionButton(
                    icon: Icons.edit,
                    color: AppTheme.textMuted,
                    label: 'Edit',
                    onTap: _editPost,
                  ),
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    color: AppTheme.error,
                    label: 'Supp',
                    onTap: _deletePost,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
