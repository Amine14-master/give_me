import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/screens/item_requests_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> with SingleTickerProviderStateMixin {
  String? _currentUserId;
  late final Stream<DatabaseEvent> _itemsStream;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _itemsStream = FirebaseDatabase.instance.ref().child('items').onValue.asBroadcastStream();
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Requests', style: AppTheme.headingMd),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'My Requests'),
            Tab(text: 'For Me'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: _itemsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5));
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No requests found', style: AppTheme.headingSm.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            );
          }

          final Map<dynamic, dynamic> itemsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildRequestsList(tabIndex: 0, itemsMap: itemsMap),
              _buildRequestsList(tabIndex: 1, itemsMap: itemsMap),
              _buildRequestsList(tabIndex: 2, itemsMap: itemsMap),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestsList({required int tabIndex, required Map<dynamic, dynamic> itemsMap}) {
    final List<Map<String, dynamic>> displayList = [];

    itemsMap.forEach((key, value) {
      final item = Map<String, dynamic>.from(value as Map);
      item['id'] = key;
      final requests = item['requests'] as Map? ?? {};
      final isOwner = item['userId'] == _currentUserId;
      final iRequested = requests.containsKey(_currentUserId);

      if (tabIndex == 0) {
        if (iRequested) {
          final status = requests[_currentUserId]['status'] as String? ?? 'pending';
          if (status == 'pending') {
            displayList.add({
              'item': item,
              'title': item['title'] ?? 'Item',
              'subtitle': 'Waiting for owner response',
              'displayStatus': 'PENDING',
              'displayColor': AppTheme.accent,
              'icon': Icons.hourglass_top_rounded,
            });
          }
        }
      } else if (tabIndex == 1) {
        if (isOwner) {
          final pendingCount = requests.values.where((r) => (r as Map)['status'] == 'pending').length;
          if (pendingCount > 0) {
            displayList.add({
              'item': item,
              'title': item['title'] ?? 'Item',
              'subtitle': '$pendingCount pending request${pendingCount > 1 ? 's' : ''}',
              'displayStatus': 'REVIEW',
              'displayColor': AppTheme.info,
              'icon': Icons.rate_review_rounded,
            });
          }
        }
      } else if (tabIndex == 2) {
        if (iRequested) {
          final status = requests[_currentUserId]['status'] as String? ?? 'pending';
          if (status == 'accepted') {
            displayList.add({
              'item': item,
              'title': item['title'] ?? 'Item',
              'subtitle': 'Owner accepted your request',
              'displayStatus': 'ACCEPTED',
              'displayColor': AppTheme.success,
              'icon': Icons.check_circle_rounded,
            });
          } else if (status == 'declined') {
            displayList.add({
              'item': item,
              'title': item['title'] ?? 'Item',
              'subtitle': 'Owner declined your request',
              'displayStatus': 'DECLINED',
              'displayColor': AppTheme.error,
              'icon': Icons.cancel_rounded,
            });
          }
        }

        if (isOwner) {
          requests.forEach((reqId, reqData) {
            final status = (reqData as Map)['status'] as String? ?? 'pending';
            if (status == 'accepted') {
              displayList.add({
                'item': item,
                'title': 'Request from $reqId',
                'subtitle': 'You accepted for ${item['title']}',
                'displayStatus': 'GIVEN',
                'displayColor': AppTheme.info,
                'icon': Icons.volunteer_activism_rounded,
              });
            } else if (status == 'declined') {
              displayList.add({
                'item': item,
                'title': 'Request from $reqId',
                'subtitle': 'You declined for ${item['title']}',
                'displayStatus': 'DECLINED',
                'displayColor': const Color(0xFF94A3B8),
                'icon': Icons.block_rounded,
              });
            }
          });

          final itemStatus = item['status'] as String? ?? 'available';
          if (itemStatus == 'deleted') {
            displayList.add({
              'item': item,
              'title': item['title'] ?? 'Item',
              'subtitle': 'All requests declined — auto deleted',
              'displayStatus': 'DELETED',
              'displayColor': const Color(0xFF1E293B),
              'icon': Icons.delete_forever_rounded,
            });
          }
        }
      }
    });

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Nothing here', style: AppTheme.bodySm),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final entry = displayList[index];
        final item = entry['item'] as Map<String, dynamic>;
        final displayStatus = entry['displayStatus'] as String;
        final displayColor = entry['displayColor'] as Color;
        final title = entry['title'] as String;
        final subtitle = entry['subtitle'] as String;
        final icon = entry['icon'] as IconData;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.softShadow,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onTap: () {
              if (tabIndex == 1) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ItemRequestsScreen(itemId: item['id'], requests: item['requests'] as Map? ?? {}),
                ));
              }
            },
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                color: AppTheme.surfaceVariant,
              ),
              clipBehavior: Clip.antiAlias,
              child: item['imageUrl'] != null
                  ? CachedNetworkImage(imageUrl: item['imageUrl'], fit: BoxFit.cover)
                  : Icon(Icons.volunteer_activism_rounded, color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
            title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: displayColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: displayColor),
                  const SizedBox(width: 4),
                  Text(displayStatus, style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700, color: displayColor,
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
