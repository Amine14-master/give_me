import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../messages/screens/chat_screen.dart';
import '../../profile/screens/public_profile_screen.dart';
import '../../../core/services/notification_helper.dart';

class ItemDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final String? currentUserId;
  final Position? currentPosition;

  const ItemDetailsScreen({
    super.key,
    required this.item,
    this.currentUserId,
    this.currentPosition,
  });

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  String? _ownerProfileImage;
  String _placeName = '...';
  bool _isLiked = false;
  int _likesCount = 0;
  bool _hasRequested = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadOwnerInfo();
    _placeName = widget.item['location'] ?? 'Unknown location';
    _initStats();
  }

  void _initStats() {
    final Map? likesMap = widget.item['likes'] as Map?;
    _likesCount = likesMap?.length ?? 0;
    _isLiked = widget.currentUserId != null && likesMap?.containsKey(widget.currentUserId) == true;
    _hasRequested = (widget.item['requests'] as Map? ?? {}).containsKey(widget.currentUserId);
  }

  Future<void> _loadOwnerInfo() async {
    final ref = FirebaseDatabase.instance.ref().child('users/${widget.item['userId']}/profileImage');
    final snap = await ref.get();
    if (snap.exists && mounted) {
      setState(() => _ownerProfileImage = snap.value as String);
    }
  }

  void _toggleLike() {
    if (widget.currentUserId == null) return;
    final String itemId = widget.item['id'];
    final ref = FirebaseDatabase.instance.ref().child('items/$itemId/likes/${widget.currentUserId}');

    if (_isLiked) {
      ref.remove();
      setState(() {
        _isLiked = false;
        _likesCount--;
      });
    } else {
      ref.set(true);
      setState(() {
        _isLiked = true;
        _likesCount++;
      });
      NotificationHelper.onLike(
        itemOwnerId: widget.item['userId'],
        likerUserId: widget.currentUserId!,
        itemTitle: widget.item['title'] ?? 'Item',
      );
    }
  }

  void _requestItem() async {
    if (widget.currentUserId == null || _hasRequested) return;

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

    setState(() {
      _hasRequested = true;
    });
  }

  void _messageOwner() {
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

  void _callOwner() async {
    final url = Uri.parse('tel:${widget.item['userId']}');
    if (await canLaunchUrl(url)) await launchUrl(url);
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

  @override
  Widget build(BuildContext context) {
    final bool isOwner = widget.currentUserId == widget.item['userId'];
    final String category = widget.item['category'] ?? 'Other';
    final Color categoryColor = Color(AppTheme.categoryStyles[category]?['color'] ?? 0xFF14B8A6);

    String displayDistance = '';
    if (widget.currentPosition != null && widget.item['lat'] != null && widget.item['lng'] != null) {
      double d = Geolocator.distanceBetween(
        widget.currentPosition!.latitude, widget.currentPosition!.longitude,
        (widget.item['lat'] as num).toDouble(), (widget.item['lng'] as num).toDouble(),
      );
      displayDistance = '${(d / 1000).toStringAsFixed(1)} km away';
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Parallax Header ──
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                backgroundColor: AppTheme.primaryDark,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(_isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _isLiked ? AppTheme.error : Colors.white),
                      onPressed: _toggleLike,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'item_image_${widget.item['id']}',
                    child: widget.item['imageUrl'] != null
                        ? CachedNetworkImage(
                            imageUrl: widget.item['imageUrl'],
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [categoryColor.withValues(alpha: 0.8), categoryColor.withValues(alpha: 0.4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.volunteer_activism_rounded, size: 80, color: Colors.white),
                            ),
                          ),
                  ),
                ),
              ),

              // ── Content ──
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0, -20, 0),
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
                  decoration: const BoxDecoration(
                    color: AppTheme.scaffoldBg,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Tag & Likes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              category,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: categoryColor,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.favorite_rounded, color: AppTheme.error, size: 18),
                              const SizedBox(width: 4),
                              Text('$_likesCount', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Title
                      Text(
                        widget.item['title'] ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Location & Distance
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _placeName,
                              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      if (displayDistance.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const SizedBox(width: 20),
                            Text(displayDistance, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),
                      
                      // Description
                      Text('Description', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      Text(
                        widget.item['description'] ?? 'No description provided.',
                        style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary, height: 1.6),
                      ),

                      const SizedBox(height: 32),
                      
                      // Owner Card
                      Text('Giver', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: widget.item['userId'])));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            boxShadow: AppTheme.cardShadow,
                            border: Border.all(color: AppTheme.surfaceVariant),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.primaryGradient,
                                ),
                                child: ClipOval(
                                  child: _ownerProfileImage != null
                                      ? CachedNetworkImage(imageUrl: _ownerProfileImage!, fit: BoxFit.cover)
                                      : const Icon(Icons.person, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.item['userId'] ?? 'Unknown User',
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.verified_rounded, size: 14, color: AppTheme.success),
                                        const SizedBox(width: 4),
                                        Text('Verified Member', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 80), // padding for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Floating Action Bar ──
          if (!isOwner)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Contact buttons
                      Expanded(
                        flex: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCircleButton(Icons.phone_rounded, AppTheme.accent, _callOwner),
                            _buildCircleButton(Icons.chat_bubble_rounded, AppTheme.primary, _messageOwner),
                            _buildCircleButton(Icons.map_rounded, AppTheme.info, _openMaps),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Main Action Button
                      Expanded(
                        flex: 1,
                        child: GestureDetector(
                          onTap: _requestItem,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: _hasRequested ? null : AppTheme.primaryGradient,
                              color: _hasRequested ? AppTheme.success : null,
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                              boxShadow: _hasRequested ? [] : [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_hasRequested ? Icons.check_circle_rounded : Icons.volunteer_activism_rounded, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  _hasRequested ? 'Requested' : 'Request Now',
                                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
