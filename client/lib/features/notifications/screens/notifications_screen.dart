import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('phoneNumber');
    });
    // Mark all as read when screen is opened
    NotificationService().markAllAsRead();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'request':
        return Icons.pan_tool;
      case 'accepted':
        return Icons.check_circle;
      case 'declined':
        return Icons.cancel;
      case 'message':
        return Icons.chat_bubble;
      case 'new_post':
        return Icons.new_releases;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'like':
        return AppTheme.error;
      case 'request':
        return AppTheme.accent;
      case 'accepted':
        return AppTheme.success;
      case 'declined':
        return Colors.grey;
      case 'message':
        return AppTheme.primary;
      case 'new_post':
        return Colors.blue;
      default:
        return AppTheme.textMuted;
    }
  }

  String _timeAgo(int timestamp) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateTime.fromMillisecondsSinceEpoch(timestamp).toString().split(' ')[0];
  }

  Future<void> _clearAll() async {
    if (_userId == null) return;
    await FirebaseDatabase.instance.ref().child('notifications/$_userId').remove();
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all, color: AppTheme.textMuted),
            tooltip: 'Clear all',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref()
            .child('notifications/$_userId')
            .orderByChild('timestamp')
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppTheme.textMuted.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('No notifications yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                ],
              ),
            );
          }

          final map = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          final entries = map.entries.toList()
            ..sort((a, b) {
              final ta = (a.value as Map)['timestamp'] as int? ?? 0;
              final tb = (b.value as Map)['timestamp'] as int? ?? 0;
              return tb.compareTo(ta); // newest first
            });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final notif = Map<String, dynamic>.from(entries[index].value as Map);
              final type = notif['type'] as String? ?? '';
              final title = notif['title'] as String? ?? 'Notification';
              final body = notif['body'] as String? ?? '';
              final isRead = notif['read'] == true;
              final timestamp = notif['timestamp'] as int? ?? 0;

              return Container(
                color: isRead ? Colors.transparent : AppTheme.primaryLight.withOpacity(0.08),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _colorForType(type).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_iconForType(type), color: _colorForType(type), size: 22),
                  ),
                  title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(body, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(_timeAgo(timestamp), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                  isThreeLine: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
