import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_helper.dart';
import '../../profile/screens/public_profile_screen.dart';

class ItemRequestsScreen extends StatefulWidget {
  final String itemId;
  final Map requests;

  const ItemRequestsScreen({super.key, required this.itemId, required this.requests});

  @override
  State<ItemRequestsScreen> createState() => _ItemRequestsScreenState();
}

class _ItemRequestsScreenState extends State<ItemRequestsScreen> {
  Map<String, Map<String, dynamic>> _requestersInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequestersInfo();
  }

  Future<void> _fetchRequestersInfo() async {
    final pendingReqs = widget.requests.entries.where((e) => e.value['status'] == 'pending').toList();
    Map<String, Map<String, dynamic>> info = {};
    
    for (var req in pendingReqs) {
      final reqId = req.key as String;
      final snap = await FirebaseDatabase.instance.ref().child('users/$reqId').get();
      if (snap.exists && snap.value != null) {
        info[reqId] = Map<String, dynamic>.from(snap.value as Map);
      }
    }
    
    setState(() {
      _requestersInfo = info;
      _isLoading = false;
    });
  }

  void _acceptRequest(BuildContext context, String winnerId) async {
    final itemRef = FirebaseDatabase.instance.ref().child('items/${widget.itemId}');
    final usersRef = FirebaseDatabase.instance.ref().child('users');
    final prefs = await SharedPreferences.getInstance();
    final ownerUserId = prefs.getString('phoneNumber') ?? '';

    final itemSnap = await itemRef.child('title').get();
    final itemTitle = (itemSnap.value as String?) ?? 'Item';

    await itemRef.update({'status': 'claimed'});

    for (String reqId in widget.requests.keys) {
      if (reqId == winnerId) {
        await itemRef.child('requests/$reqId/status').set('accepted');
        final snap = await usersRef.child('$reqId/stats/accepted').get();
        await usersRef.child('$reqId/stats/accepted').set(((snap.value as int?) ?? 0) + 1);
        NotificationHelper.onAccepted(
          requesterUserId: reqId,
          ownerUserId: ownerUserId,
          itemTitle: itemTitle,
          itemId: widget.itemId,
        );
      } else {
        await itemRef.child('requests/$reqId/status').set('declined');
        final snap = await usersRef.child('$reqId/stats/declined').get();
        await usersRef.child('$reqId/stats/declined').set(((snap.value as int?) ?? 0) + 1);
        NotificationHelper.onDeclined(
          requesterUserId: reqId,
          ownerUserId: ownerUserId,
          itemTitle: itemTitle,
          itemId: widget.itemId,
        );
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request Accepted! 🎉'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _declineRequest(BuildContext context, String requesterId) async {
    await FirebaseDatabase.instance.ref().child('items/${widget.itemId}/requests/$requesterId/status').set('declined');
    final userStatRef = FirebaseDatabase.instance.ref().child('users/$requesterId/stats/declined');
    final snap = await userStatRef.get();
    await userStatRef.set(((snap.value as int?) ?? 0) + 1);

    final prefs = await SharedPreferences.getInstance();
    final ownerUserId = prefs.getString('phoneNumber') ?? '';
    final titleSnap = await FirebaseDatabase.instance.ref().child('items/${widget.itemId}/title').get();
    final itemTitle = (titleSnap.value as String?) ?? 'Item';

    NotificationHelper.onDeclined(
      requesterUserId: requesterId,
      ownerUserId: ownerUserId,
      itemTitle: itemTitle,
      itemId: widget.itemId,
    );
    
    setState(() {
      _requestersInfo.remove(requesterId);
    });

    if (_requestersInfo.isEmpty) {
      await FirebaseDatabase.instance.ref().child('items/${widget.itemId}/status').set('deleted');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All requests declined. Item removed.'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request Declined'),
          backgroundColor: AppTheme.textMuted,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Item Requests', style: AppTheme.headingMd),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5))
          : _requestersInfo.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No pending requests', style: AppTheme.bodySm),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requestersInfo.length,
                  itemBuilder: (context, index) {
                    final reqId = _requestersInfo.keys.elementAt(index);
                    final userInfo = _requestersInfo[reqId]!;
                    final stats = userInfo['stats'] as Map? ?? {};
                    final accepted = stats['accepted'] ?? 0;
                    final declined = stats['declined'] ?? 0;
                    final profileImg = userInfo['profileImage'] as String?;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Column(
                        children: [
                          // ── User Info ──
                          ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: ClipOval(
                                child: profileImg != null
                                    ? CachedNetworkImage(imageUrl: profileImg, fit: BoxFit.cover)
                                    : const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                              ),
                            ),
                            title: Text(reqId, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  _buildMiniStat(Icons.check_circle_rounded, AppTheme.success, '$accepted'),
                                  const SizedBox(width: 12),
                                  _buildMiniStat(Icons.cancel_rounded, AppTheme.error, '$declined'),
                                ],
                              ),
                            ),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: reqId))),
                          ),

                          // ── Actions ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _declineRequest(context, reqId),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.close_rounded, size: 18, color: AppTheme.error),
                                          const SizedBox(width: 6),
                                          Text('Decline', style: GoogleFonts.inter(
                                            color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 13,
                                          )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _acceptRequest(context, reqId),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [AppTheme.success, Color(0xFF34D399)]),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                        boxShadow: AppTheme.glowShadow(AppTheme.success),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                          const SizedBox(width: 6),
                                          Text('Accept', style: GoogleFonts.inter(
                                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13,
                                          )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildMiniStat(IconData icon, Color color, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
