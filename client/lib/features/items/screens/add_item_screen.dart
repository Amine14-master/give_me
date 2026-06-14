import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../navigation/screens/main_container.dart';
import 'location_picker_screen.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Clothes';
  bool _isLoading = false;
  XFile? _imageFile;
  Uint8List? _imageBytes;

  double? _lat;
  double? _lng;
  String _locationName = '';

  final List<String> _categories = ['Clothes', 'Food', 'Electronics', 'Books', 'Furniture', 'Toys', 'Tools', 'Other'];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageFile = pickedFile;
        _imageBytes = bytes;
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/drbsi3edb/image/upload');
      final request = http.MultipartRequest('POST', url)..fields['upload_preset'] = 'giveme';
      final bytes = await _imageFile!.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: _imageFile!.name));
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url'];
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
    }
    return null;
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions denied');
      }
      Position position = await Geolocator.getCurrentPosition();
      await _updateLocationFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: _lat != null && _lng != null ? ll.LatLng(_lat!, _lng!) : null,
        ),
      ),
    );
    if (result != null && result is ll.LatLng) {
      await _updateLocationFromCoordinates(result.latitude, result.longitude);
    }
  }

  Future<void> _updateLocationFromCoordinates(double latitude, double longitude) async {
    setState(() => _isLoading = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String>[
          if (place.subLocality != null && place.subLocality!.isNotEmpty) place.subLocality!,
          if (place.locality != null && place.locality!.isNotEmpty && place.locality != place.subLocality) place.locality!,
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty && place.subAdministrativeArea != place.locality) place.subAdministrativeArea!,
        ];
        if (parts.isEmpty && place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          parts.add(place.administrativeArea!);
        }
        final name = parts.isNotEmpty ? parts.join(', ') : 'Unknown Location';
        setState(() {
          _lat = latitude;
          _lng = longitude;
          _locationName = name;
        });
      }
    } catch (e) {
      setState(() {
        _lat = latitude;
        _lng = longitude;
        _locationName = 'Location set';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submit() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all fields'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a location'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      String? imageUrl = await _uploadImage();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('phoneNumber') ?? 'unknown';
      final ref = FirebaseDatabase.instance.ref().child('items').push();
      
      await ref.set({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'imageUrl': imageUrl,
        'userId': userId,
        'status': 'available',
        'createdAt': ServerValue.timestamp,
        'location': _locationName,
        'lat': _lat,
        'lng': _lng,
      });

      final statsRef = FirebaseDatabase.instance.ref().child('users/$userId/stats/posts');
      final statSnap = await statsRef.get();
      final currentPosts = (statSnap.value as int?) ?? 0;
      await statsRef.set(currentPosts + 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Item added successfully! 🎉'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _titleController.clear();
        _descController.clear();
        setState(() => _imageFile = null);
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainContainer()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add item: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Give an Item', style: AppTheme.headingMd),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image Picker ──
            GestureDetector(
              onTap: _pickImage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 200,
                decoration: BoxDecoration(
                  color: _imageFile != null ? Colors.transparent : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: _imageFile != null ? AppTheme.primary : Colors.grey.shade200,
                    width: _imageFile != null ? 2 : 1,
                  ),
                  image: _imageBytes != null
                      ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                      : null,
                ),
                child: _imageFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_a_photo_rounded, size: 32, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 12),
                          Text('Upload a clear photo', style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 14,
                          )),
                          const SizedBox(height: 4),
                          Text('Tap to add', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // ── Title ──
            Text('Title', style: AppTheme.labelMd),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'What are you giving away?',
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 20),

            // ── Category ──
            Text('Category', style: AppTheme.labelMd),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textPrimary),
                items: _categories.map((cat) {
                  final style = AppTheme.categoryStyles[cat];
                  return DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Text(style?['emoji'] ?? '📦', style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text(cat),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Description ──
            Text('Description', style: AppTheme.labelMd),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Condition? Pick-up info? Any details...',
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // ── Location ──
            Text('Location', style: AppTheme.labelMd),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _locationName.isNotEmpty ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _locationName.isNotEmpty ? Icons.location_on_rounded : Icons.location_off_rounded,
                          color: _locationName.isNotEmpty ? AppTheme.success : AppTheme.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _locationName.isEmpty ? 'No location selected' : _locationName,
                          style: GoogleFonts.inter(
                            color: _locationName.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationButton(
                          icon: Icons.gps_fixed_rounded,
                          label: 'Auto',
                          onTap: _isLoading ? null : _getCurrentLocation,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildLocationButton(
                          icon: Icons.map_rounded,
                          label: 'Pick on Map',
                          onTap: _isLoading ? null : _pickOnMap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Submit ──
            GestureDetector(
              onTap: _isLoading ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: _isLoading ? null : AppTheme.primaryGradient,
                  color: _isLoading ? AppTheme.textMuted.withValues(alpha: 0.3) : null,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: _isLoading ? [] : AppTheme.glowShadow(AppTheme.primary),
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text('Give Away', style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
                            )),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButton({required IconData icon, required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.scaffoldBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}
