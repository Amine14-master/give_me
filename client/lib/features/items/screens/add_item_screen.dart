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
import '../../../core/theme/app_theme.dart';
import '../../navigation/screens/main_container.dart';
import 'location_picker_screen.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({Key? key}) : super(key: key);

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
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'giveme';
      
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
        // Build a rich name: prefer subLocality (baladiya/neighborhood), then locality (city)
        final parts = <String>[
          if (place.subLocality != null && place.subLocality!.isNotEmpty) place.subLocality!,
          if (place.locality != null && place.locality!.isNotEmpty && place.locality != place.subLocality) place.locality!,
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty && place.subAdministrativeArea != place.locality) place.subAdministrativeArea!,
        ];
        // Fallback to administrative area if parts is empty
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
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
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
            content: const Text('Item added successfully!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
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
      appBar: AppBar(title: const Text('Give an Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 220,
                decoration: BoxDecoration(
                  color: _imageFile != null ? Colors.transparent : AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(
                    color: _imageFile != null ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  ),
                  image: _imageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_imageBytes!), // Use MemoryImage for web
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imageFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_a_photo, size: 36, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 12),
                          const Text('Upload a clear photo', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'What are you giving away?'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                hintText: 'Any specific details? Condition? Pick-up info?',
              ),
            ),
            const SizedBox(height: 20),
            Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationName.isEmpty ? 'No location selected' : _locationName,
                          style: TextStyle(color: _locationName.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _getCurrentLocation,
                          icon: const Icon(Icons.gps_fixed),
                          label: const Text('Auto'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _pickOnMap,
                          icon: const Icon(Icons.map),
                          label: const Text('Map'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Give Away', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
