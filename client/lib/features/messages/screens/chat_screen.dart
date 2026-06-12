import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_helper.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String? itemTitle;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    this.itemTitle,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
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

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    _chatsRef.child(widget.chatId).child('messages').push().set({
      'senderId': _currentUserId,
      'text': text,
      'timestamp': ServerValue.timestamp,
    });

    // Update latest message metadata for the chat thread
    _chatsRef.child(widget.chatId).update({
      'participants': {
        _currentUserId: true,
        widget.otherUserId: true,
      },
      'lastMessage': text,
      'lastMessageTime': ServerValue.timestamp,
      'itemTitle': widget.itemTitle,
    });

    // Notify the other user
    NotificationHelper.onMessage(
      targetUserId: widget.otherUserId,
      senderUserId: _currentUserId!,
      preview: text.length > 50 ? '${text.substring(0, 50)}...' : text,
    );

    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserId, style: const TextStyle(fontSize: 16)),
            if (widget.itemTitle != null)
              Text('Re: ${widget.itemTitle}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _chatsRef.child(widget.chatId).child('messages').orderByChild('timestamp').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return const Center(child: Text('Say hi! 👋', style: TextStyle(color: AppTheme.textMuted)));
                }

                final Map<dynamic, dynamic> map = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final messages = map.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
                messages.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0)); // reversed list

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == _currentUserId;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primary : AppTheme.primaryLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : AppTheme.textPrimary),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: AppTheme.primaryLight.withOpacity(0.1),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
