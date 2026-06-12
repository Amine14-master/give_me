import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/screens/item_requests_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({Key? key}) : super(key: key);

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  String? _currentUserId;
  late final Stream<DatabaseEvent> _itemsStream;

  @override
  void initState() {
    super.initState();
    _itemsStream = FirebaseDatabase.instance.ref().child('items').onValue.asBroadcastStream();
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests Hub'),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(text: 'My Reqs'),
              Tab(text: 'For Me'),
              Tab(text: 'Historique'),
            ],
          ),
        ),
        body: StreamBuilder(
          stream: _itemsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Center(child: Text('No requests found.', style: TextStyle(color: AppTheme.textMuted)));
            }

            final Map<dynamic, dynamic> itemsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

            return TabBarView(
              children: [
                _buildRequestsList(tabIndex: 0, itemsMap: itemsMap),
                _buildRequestsList(tabIndex: 1, itemsMap: itemsMap),
                _buildRequestsList(tabIndex: 2, itemsMap: itemsMap),
              ],
            );
          },
        ),
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
            item['_displayStatus'] = 'PENDING';
            item['_displayColor'] = Colors.orange;
            displayList.add(item);
          }
        }
      } else if (tabIndex == 1) {
        if (isOwner) {
          final hasPending = requests.values.any((r) => (r as Map)['status'] == 'pending');
          if (hasPending) {
            item['_displayStatus'] = 'NEEDS REVIEW';
            item['_displayColor'] = AppTheme.accent;
            displayList.add(item);
          }
        }
      } else if (tabIndex == 2) {
        if (iRequested) {
          final status = requests[_currentUserId]['status'] as String? ?? 'pending';
          if (status == 'accepted') {
            item['_displayStatus'] = 'ACCEPTED (ME)';
            item['_displayColor'] = AppTheme.success;
            displayList.add(item);
          } else if (status == 'declined') {
            item['_displayStatus'] = 'DECLINED (ME)';
            item['_displayColor'] = AppTheme.error;
            displayList.add(item);
          }
        } else if (isOwner) {
          final itemStatus = item['status'] as String? ?? 'available';
          if (itemStatus == 'deleted') {
            item['_displayStatus'] = 'DELETED';
            item['_displayColor'] = Colors.black;
            displayList.add(item);
          } else if (itemStatus == 'claimed') {
            item['_displayStatus'] = 'GIVEN AWAY';
            item['_displayColor'] = Colors.blue;
            displayList.add(item);
          } else {
            final hasDeclined = requests.values.any((r) => (r as Map)['status'] == 'declined');
            if (hasDeclined) {
              item['_displayStatus'] = 'DECLINED REQ(S)';
              item['_displayColor'] = Colors.grey;
              displayList.add(item);
            }
          }
        }
      }
    });

    if (displayList.isEmpty) {
      return const Center(child: Text('No items to display.', style: TextStyle(color: AppTheme.textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final item = displayList[index];
        final displayStatus = item['_displayStatus'] as String;
        final displayColor = item['_displayColor'] as Color;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () {
              if (tabIndex == 1) {
                // If in "Requests For Me", clicking opens the ItemRequestsScreen
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ItemRequestsScreen(itemId: item['id'], requests: item['requests'] as Map? ?? {}),
                ));
              }
            },
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                image: item['imageUrl'] != null
                    ? DecorationImage(image: NetworkImage(item['imageUrl']), fit: BoxFit.cover)
                    : null,
              ),
              child: item['imageUrl'] == null ? const Icon(Icons.image, color: AppTheme.primary) : null,
            ),
            title: Text(item['title'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(tabIndex == 1 ? 'Pending Reqs: ${item['requests'].length}' : 'Owner: ${item['userId']}'),
            trailing: Chip(
              label: Text(displayStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: displayColor,
            ),
          ),
        );
      },
    );
  }
}
