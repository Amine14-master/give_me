import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class EditItemScreen extends StatefulWidget {
  final String itemId;
  final String initialTitle;
  final String initialDesc;
  final String initialCategory;

  const EditItemScreen({
    super.key,
    required this.itemId,
    required this.initialTitle,
    required this.initialDesc,
    required this.initialCategory,
  });

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late String _selectedCategory;
  bool _isLoading = false;

  final List<String> _categories = ['Clothes', 'Food', 'Electronics', 'Books', 'Furniture', 'Toys', 'Tools', 'Other'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController(text: widget.initialDesc);
    _selectedCategory = widget.initialCategory;
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'Other';
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
    
    setState(() => _isLoading = true);
    
    try {
      await FirebaseDatabase.instance.ref().child('items/${widget.itemId}').update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Item updated successfully! ✅'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update item: $e'), backgroundColor: AppTheme.error),
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
        title: Text('Edit Item', style: AppTheme.headingMd),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Title', style: AppTheme.labelMd),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Item title',
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 20),

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

            Text('Description', style: AppTheme.labelMd),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Update item details...',
                hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

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
                            const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text('Save Changes', style: GoogleFonts.inter(
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
}
