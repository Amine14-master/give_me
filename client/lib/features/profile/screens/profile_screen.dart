import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/screens/login_screen.dart';
import 'saved_items_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _currentUserId;
  String? _profileImageUrl;
  int _itemsGivenCount = 0;
  int _requestsMade = 0;
  int _accepted = 0;
  int _declined = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('phoneNumber');
    if (userId == null) return;

    setState(() => _currentUserId = userId);

    final ref = FirebaseDatabase.instance.ref();
    
    final userSnapshot = await ref.child('users/$userId/profileImage').get();
    if (userSnapshot.exists) {
      setState(() => _profileImageUrl = userSnapshot.value as String);
    }

    final statsSnapshot = await ref.child('users/$userId/stats').get();
    if (statsSnapshot.exists) {
      final stats = statsSnapshot.value as Map;
      setState(() {
        _itemsGivenCount = stats['posts'] ?? 0;
        _requestsMade = stats['requestsMade'] ?? 0;
        _accepted = stats['accepted'] ?? 0;
        _declined = stats['declined'] ?? 0;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null || _currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/drbsi3edb/image/upload');
      final request = http.MultipartRequest('POST', url)..fields['upload_preset'] = 'giveme';
      
      final bytes = await pickedFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: pickedFile.name));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);
        final imageUrl = jsonResponse['secure_url'];

        await FirebaseDatabase.instance.ref().child('users/$_currentUserId/profileImage').set(imageUrl);
        setState(() => _profileImageUrl = imageUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Premium Glassmorphic Header ──
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.primaryDark,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // ── Avatar ──
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 47,
                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                backgroundImage: _profileImageUrl != null ? CachedNetworkImageProvider(_profileImageUrl!) : null,
                                child: _profileImageUrl == null
                                    ? const Icon(Icons.person_rounded, size: 48, color: Colors.white)
                                    : null,
                              ),
                            ),
                            if (_isLoading)
                              const Positioned.fill(
                                child: CircularProgressIndicator(color: AppTheme.accentLight, strokeWidth: 3),
                              ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUserId ?? 'Guest',
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Community Member',
                        style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                      ),

                      const SizedBox(height: 20),

                      // ── Glassmorphic Stats Row ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildGlassStat('$_itemsGivenCount', 'Given'),
                                  _buildDivider(),
                                  _buildGlassStat('$_requestsMade', 'Requests'),
                                  _buildDivider(),
                                  _buildGlassStat('$_accepted', 'Won'),
                                  _buildDivider(),
                                  _buildGlassStat('$_declined', 'Lost'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Menu Items ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings', style: AppTheme.labelMd),
                  const SizedBox(height: 12),
                  _buildMenuTile(Icons.history_rounded, 'Giving History', AppTheme.primary),
                  _buildMenuTile(
                    Icons.favorite_border_rounded, 
                    'Saved Items', 
                    AppTheme.warmCoral,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedItemsScreen()));
                    },
                  ),
                  _buildMenuTile(Icons.settings_rounded, 'Preferences', AppTheme.textSecondary),
                  _buildMenuTile(Icons.help_outline_rounded, 'Help & Support', AppTheme.info),
                  const SizedBox(height: 24),

                  // ── Logout ──
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.15)),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
                      ),
                      title: Text('Log Out', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 15)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.error, size: 20),
                      onTap: () => _logout(context),
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

  Widget _buildGlassStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, Color iconColor, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadow,
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          onTap: onTap ?? () {},
        ),
      ),
    );
  }
}
