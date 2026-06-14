import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final DatabaseReference _chatsRef = FirebaseDatabase.instance.ref().child('chats');
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('phoneNumber');
    });
  }

  String _timeAgo(int timestamp) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Messages', style: AppTheme.headingMd),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder(
        stream: _chatsRef.orderByChild('participants/$_currentUserId').equalTo(true).onValue,
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
                    child: Icon(Icons.chat_bubble_outline_rounded, size: 36, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(height: 20),
                  Text('No conversations yet', style: AppTheme.headingSm.copyWith(color: AppTheme.textMuted)),
                  const SizedBox(height: 8),
                  Text('Start chatting about items you\'re interested in', style: AppTheme.bodySm),
                ],
              ),
            );
          }

          final Map<dynamic, dynamic> chatsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final chats = chatsMap.entries.map((e) => {
            'id': e.key,
            ...Map<String, dynamic>.from(e.value as Map)
          }).toList();

          chats.sort((a, b) => (b['lastMessageTime'] ?? 0).compareTo(a['lastMessageTime'] ?? 0));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final Map participants = chat['participants'] ?? {};
              final otherUserId = participants.keys.firstWhere((k) => k != _currentUserId, orElse: () => 'Unknown');
              final lastTime = chat['lastMessageTime'] as int? ?? 0;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: AppTheme.softShadow,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.15), blurRadius: 8)],
                    ),
                    child: const ClipOval(
                      child: Icon(Icons.person_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherUserId,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        lastTime > 0 ? _timeAgo(lastTime) : '',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      chat['lastMessage'] ?? 'Started a chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: chat['id'],
                          otherUserId: otherUserId,
                          itemTitle: chat['itemTitle'],
                        ),
                      ),
                    );
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
