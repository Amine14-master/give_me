import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

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
    NotificationService().markAllAsRead();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'request': return Icons.volunteer_activism_rounded;
      case 'accepted': return Icons.check_circle_rounded;
      case 'declined': return Icons.cancel_rounded;
      case 'message': return Icons.chat_bubble_rounded;
      case 'new_post': return Icons.new_releases_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'like': return AppTheme.warmCoral;
      case 'request': return AppTheme.accent;
      case 'accepted': return AppTheme.success;
      case 'declined': return const Color(0xFF94A3B8);
      case 'message': return AppTheme.primary;
      case 'new_post': return AppTheme.info;
      default: return AppTheme.textMuted;
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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Notifications', style: AppTheme.headingMd),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear_all_rounded, size: 20, color: AppTheme.textMuted),
            label: Text('Clear', style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
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
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5));
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_none_rounded, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(height: 20),
                  Text('No notifications yet', style: AppTheme.headingSm.copyWith(color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  Text('We\'ll let you know when something happens', style: AppTheme.bodySm),
                ],
              ),
            );
          }

          final map = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          final entries = map.entries.toList()
            ..sort((a, b) {
              final ta = (a.value as Map)['timestamp'] as int? ?? 0;
              final tb = (b.value as Map)['timestamp'] as int? ?? 0;
              return tb.compareTo(ta);
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
              final color = _colorForType(type);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isRead ? Colors.white : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: isRead ? null : Border.all(color: color.withValues(alpha: 0.15), width: 1),
                  boxShadow: isRead ? [] : AppTheme.softShadow,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(_iconForType(type), color: color, size: 22),
                  ),
                  title: Text(title, style: GoogleFonts.inter(
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(body, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(_timeAgo(timestamp), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
