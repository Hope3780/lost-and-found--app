import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../widgets/cut_logo_badge.dart';

import '../widgets/fade_slide_in.dart';
import '../widgets/success_check.dart';

class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key});

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  static const _labelColor = Color(0xFFB8C4D4);
  static const _fieldText = Color(0xFF1F2A37);
  static const _hintColor = Color(0xFF6B7785);
  static const _navyButton = Color(0xFF1C4A7D);
  static const _cardBlue = Color(0xFFE8EEF7);

  static const _categories = [
    'Electronics',
    'Keys',
    'Cards & IDs',
    'Bags',
    'Clothing',
    'Books & Stationery',
    'Bottles & Lunchboxes',
    'Other',
  ];

  final _service = SupabaseService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _category = 'Other';
  Uint8List? _selectedImageBytes;
  String? _selectedImageExt;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Bottom sheet: take a photo or choose from the gallery
  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: Color(0xFF17396A)),
              title: const Text('Take a photo',
                  style: TextStyle(color: _fieldText)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF17396A)),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: _fieldText)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageExt = picked.path.split('.').last;
        });
      }
    } catch (e) {
      debugPrint('Image pick failed: $e');
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not open the camera or gallery.');
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    var description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty || location.isEmpty) {
      setState(() => _errorMessage =
          'Please fill in at least what the item is and where you found it.');
      return;
    }

    // There is no category column yet, so keep it in the description
    // (skipped for "Other"). See notes for how to store it properly.
    if (_category != 'Other') {
      description =
          description.isEmpty ? 'Category: $_category' : 'Category: $_category\n$description';
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      String? photoUrl;
      if (_selectedImageBytes != null) {
        photoUrl = await _service.uploadItemPhoto(
          _selectedImageBytes!,
          _selectedImageExt ?? 'jpg',
        );
      }

      await _service.reportFoundItem(
        itemName: name,
        description: description,
        locationFound: location,
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      await showSuccessCheck(
        context,
        title: 'Item reported',
        subtitle: 'Thank you for helping the owner find it.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Report failed: $e');
      if (!mounted) return;
      setState(() =>
          _errorMessage = 'Could not report the item. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(color: _labelColor, fontSize: 15)),
    );
  }

  InputDecoration _fieldDecoration({String? hint, Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B2FE0), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: CutLogoBadge.toolbarHeight,
        title: const Text(
          'Report Found Item',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: CutLogoBadge(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              staggerIn(0, const Text(
                'Hand the item in at Protection Services, then record it here so the owner can find it.',
                style: TextStyle(color: _labelColor, fontSize: 14),
              )),
              const SizedBox(height: 16),

              // ---------- Photo ----------
              staggerIn(1, GestureDetector(
                onTap: _choosePhotoSource,
                child: Container(
                  height: 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, _cardBlue],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _selectedImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_selectedImageBytes!,
                                  fit: BoxFit.cover),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(
                                        11, 22, 35, 0.75),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Change photo',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  size: 40, color: Color(0xFF17396A)),
                              SizedBox(height: 10),
                              Text('Add a photo',
                                  style: TextStyle(
                                      color: _fieldText, fontSize: 16)),
                              SizedBox(height: 4),
                              Text('Take one now or choose from your gallery',
                                  style: TextStyle(
                                      color: _hintColor, fontSize: 13)),
                            ],
                          ),
                        ),
                ),
              )),
              const SizedBox(height: 26),

              // ---------- What is it? ----------
              staggerIn(2, _label('What is it?')),
              staggerIn(2, TextField(
                controller: _nameController,
                style: const TextStyle(color: _fieldText, fontSize: 15),
                cursorColor: const Color(0xFF3B2FE0),
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration(hint: 'e.g. Black water bottle'),
              )),
              const SizedBox(height: 22),

              // ---------- Category ----------
              staggerIn(3, _label('Category')),
              staggerIn(3, DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _category,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: Color(0xFF3A4A5C)),
                style: const TextStyle(color: _fieldText, fontSize: 15),
                decoration: _fieldDecoration(
                  prefix: const Icon(Icons.category_outlined,
                      color: Color(0xFF3A4A5C), size: 22),
                ),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'Other'),
              )),
              const SizedBox(height: 22),

              // ---------- Description ----------
              staggerIn(4, _label('Description')),
              staggerIn(4, TextField(
                controller: _descriptionController,
                style: const TextStyle(color: _fieldText, fontSize: 15),
                cursorColor: const Color(0xFF3B2FE0),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                decoration: _fieldDecoration(
                  hint:
                      'Colour, brand, scratches or anything that helps the owner recognise it',
                ),
              )),
              const SizedBox(height: 22),

              // ---------- Where found ----------
              staggerIn(5, _label('Where did you find it?')),
              staggerIn(5, TextField(
                controller: _locationController,
                style: const TextStyle(color: _fieldText, fontSize: 15),
                cursorColor: const Color(0xFF3B2FE0),
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    _fieldDecoration(hint: 'e.g. Library, Block A, Res A'),
              )),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFFF8A80)),
                ),
              ],

              const SizedBox(height: 28),

              // ---------- Submit ----------
              staggerIn(6, Center(
                child: SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navyButton,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color.fromRGBO(28, 74, 125, 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              )),
             
            ],
          ),
        ),
      ),
    );
  }
}