import 'package:firebase_database/firebase_database.dart';

/// Static helper to write notification entries into the Realtime Database.
/// Each notification is stored at `notifications/{targetUserId}/{autoId}`.
class NotificationHelper {
  static final _db = FirebaseDatabase.instance.ref();

  /// Generic writer — every notification goes through here.
  static Future<void> _write({
    required String targetUserId,
    required String title,
    required String body,
    required String type,
    String? itemId,
    String? fromUserId,
  }) async {
    // Don't notify yourself
    if (targetUserId == fromUserId) return;

    final ref = _db.child('notifications/$targetUserId').push();
    await ref.set({
      'title': title,
      'body': body,
      'type': type,
      'itemId': itemId,
      'fromUserId': fromUserId,
      'read': false,
      'timestamp': ServerValue.timestamp,
    });
  }

  // ─── Concrete event writers ────────────────────────────────

  /// Someone liked your post.
  static Future<void> onLike({
    required String itemOwnerId,
    required String likerUserId,
    required String itemTitle,
  }) =>
      _write(
        targetUserId: itemOwnerId,
        fromUserId: likerUserId,
        title: '❤️ New Like',
        body: '$likerUserId liked your item "$itemTitle"',
        type: 'like',
      );

  /// Someone requested your item.
  static Future<void> onRequest({
    required String itemOwnerId,
    required String requesterUserId,
    required String itemTitle,
    String? itemId,
  }) =>
      _write(
        targetUserId: itemOwnerId,
        fromUserId: requesterUserId,
        title: '🙏 New Request',
        body: '$requesterUserId requested your item "$itemTitle"',
        type: 'request',
        itemId: itemId,
      );

  /// Owner accepted your request.
  static Future<void> onAccepted({
    required String requesterUserId,
    required String ownerUserId,
    required String itemTitle,
    String? itemId,
  }) =>
      _write(
        targetUserId: requesterUserId,
        fromUserId: ownerUserId,
        title: '✅ Request Accepted!',
        body: 'Your request for "$itemTitle" was accepted!',
        type: 'accepted',
        itemId: itemId,
      );

  /// Owner declined your request.
  static Future<void> onDeclined({
    required String requesterUserId,
    required String ownerUserId,
    required String itemTitle,
    String? itemId,
  }) =>
      _write(
        targetUserId: requesterUserId,
        fromUserId: ownerUserId,
        title: '❌ Request Declined',
        body: 'Your request for "$itemTitle" was declined.',
        type: 'declined',
        itemId: itemId,
      );

  /// Someone sent you a message.
  static Future<void> onMessage({
    required String targetUserId,
    required String senderUserId,
    String? preview,
  }) =>
      _write(
        targetUserId: targetUserId,
        fromUserId: senderUserId,
        title: '💬 New Message',
        body: '$senderUserId: ${preview ?? "sent you a message"}',
        type: 'message',
      );

  /// A new item was posted (could notify nearby users — simplified here).
  static Future<void> onNewPost({
    required String targetUserId,
    required String posterUserId,
    required String itemTitle,
    String? itemId,
  }) =>
      _write(
        targetUserId: targetUserId,
        fromUserId: posterUserId,
        title: '🆕 New Item Nearby',
        body: '$posterUserId posted "$itemTitle" near you',
        type: 'new_post',
        itemId: itemId,
      );
}
