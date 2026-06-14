import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../items/screens/item_details_screen.dart';

class MapScreen extends StatefulWidget {
  final Position? initialPosition;
  final String? currentUserId;

  const MapScreen({super.key, this.initialPosition, this.currentUserId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final DatabaseReference _itemsRef = FirebaseDatabase.instance.ref().child('items');
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    _itemsRef.onValue.listen((event) {
      if (event.snapshot.value == null) {
        setState(() {
          _items = [];
          _isLoading = false;
        });
        return;
      }
      final Map<dynamic, dynamic> itemsMap = event.snapshot.value as Map<dynamic, dynamic>;
      final itemsList = itemsMap.entries.map((e) => {
        'id': e.key,
        ...Map<String, dynamic>.from(e.value as Map)
      }).toList();
      
      final availableItems = itemsList.where((i) => 
        i['status'] != 'claimed' && 
        i['status'] != 'deleted' && 
        i['lat'] != null && 
        i['lng'] != null
      ).toList();

      if (mounted) {
        setState(() {
          _items = availableItems;
          _isLoading = false;
        });
      }
    });
  }

  void _showItemPreview(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ItemPreviewCard(
        item: item,
        currentUserId: widget.currentUserId,
        currentPosition: widget.initialPosition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = widget.initialPosition != null
        ? LatLng(widget.initialPosition!.latitude, widget.initialPosition!.longitude)
        : const LatLng(36.752887, 3.042048); // default to Algiers

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppTheme.cardShadow),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.giveme.app',
                ),
                MarkerLayer(
                  markers: [
                    if (widget.initialPosition != null)
                      Marker(
                        point: center,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ..._items.map((item) {
                      final category = item['category'] ?? 'Other';
                      final color = Color(AppTheme.categoryStyles[category]?['color'] ?? 0xFF14B8A6);
                      return Marker(
                        point: LatLng((item['lat'] as num).toDouble(), (item['lng'] as num).toDouble()),
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () => _showItemPreview(item),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
                                ),
                                child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item['title'] != null ? (item['title'] as String).substring(0, item['title'].toString().length > 10 ? 10 : item['title'].toString().length) : '...',
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ItemPreviewCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String? currentUserId;
  final Position? currentPosition;

  const _ItemPreviewCard({required this.item, this.currentUserId, this.currentPosition});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 5,
            width: 40,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: item['imageUrl'] != null
                      ? CachedNetworkImage(
                          imageUrl: item['imageUrl'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: AppTheme.surfaceVariant,
                          child: const Icon(Icons.volunteer_activism_rounded, color: AppTheme.textMuted),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title'] ?? '', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(item['location'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ItemDetailsScreen(
                                item: item,
                                currentUserId: currentUserId,
                                currentPosition: currentPosition,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text('View Details', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
