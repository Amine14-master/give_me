import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_helper.dart';
import '../../profile/screens/public_profile_screen.dart';

class ItemRequestsScreen extends StatefulWidget {
  final String itemId;
  final Map requests;

  const ItemRequestsScreen({Key? key, required this.itemId, required this.requests}) : super(key: key);

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

    // Get item title for notifications
    final itemSnap = await itemRef.child('title').get();
    final itemTitle = (itemSnap.value as String?) ?? 'Item';

    await itemRef.update({'status': 'claimed'});

    for (String reqId in widget.requests.keys) {
      if (reqId == winnerId) {
        await itemRef.child('requests/$reqId/status').set('accepted');
        final snap = await usersRef.child('$reqId/stats/accepted').get();
        await usersRef.child('$reqId/stats/accepted').set(((snap.value as int?) ?? 0) + 1);
        // Notify the winner
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
        // Notify the declined requester
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
        const SnackBar(content: Text('Request Accepted!'), backgroundColor: AppTheme.success),
      );
      Navigator.pop(context);
    }
  }

  void _declineRequest(BuildContext context, String requesterId) async {
    await FirebaseDatabase.instance.ref().child('items/${widget.itemId}/requests/$requesterId/status').set('declined');
    final userStatRef = FirebaseDatabase.instance.ref().child('users/$requesterId/stats/declined');
    final snap = await userStatRef.get();
    await userStatRef.set(((snap.value as int?) ?? 0) + 1);

    // Get owner info and item title for notification
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
          const SnackBar(content: Text('All requests declined. Item deleted.'), backgroundColor: Colors.black),
        );
        Navigator.pop(context);
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request Declined.'), backgroundColor: AppTheme.textMuted),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item Requests'), backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_requestersInfo.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item Requests'), backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('No pending requests found.', style: TextStyle(color: AppTheme.textMuted))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Item Requests'), backgroundColor: Colors.white, elevation: 0),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requestersInfo.length,
        itemBuilder: (context, index) {
          final reqId = _requestersInfo.keys.elementAt(index);
          final userInfo = _requestersInfo[reqId]!;
          final stats = userInfo['stats'] as Map? ?? {};
          final accepted = stats['accepted'] ?? 0;
          final declined = stats['declined'] ?? 0;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryLight.withOpacity(0.2),
                      backgroundImage: userInfo['profileImage'] != null ? NetworkImage(userInfo['profileImage']) : null,
                      child: userInfo['profileImage'] == null ? const Icon(Icons.person, color: AppTheme.primary) : null,
                    ),
                    title: Text(reqId, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Accepted: $accepted | Declined: $declined\nJoined: ${userInfo['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(userInfo['createdAt']).toString().split(' ')[0] : 'Unknown'}'),
                    isThreeLine: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: reqId))),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, color: AppTheme.error),
                        label: const Text('Decline', style: TextStyle(color: AppTheme.error)),
                        onPressed: () => _declineRequest(context, reqId),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Accept'),
                        onPressed: () => _acceptRequest(context, reqId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
