import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: _chatsRef.orderByChild('participants/$_currentUserId').equalTo(true).onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text('No messages yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 18)),
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

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final Map participants = chat['participants'] ?? {};
              final otherUserId = participants.keys.firstWhere((k) => k != _currentUserId, orElse: () => 'Unknown');
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryLight.withOpacity(0.2),
                  child: const Icon(Icons.person, color: AppTheme.primary),
                ),
                title: Text(
                  otherUserId,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  chat['lastMessage'] ?? 'Started a chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
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
              );
            },
          );
        },
      ),
    );
  }
}
