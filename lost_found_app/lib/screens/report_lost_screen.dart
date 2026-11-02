import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../widgets/cut_logo_badge.dart';

import '../widgets/fade_slide_in.dart';
import '../widgets/success_check.dart';

class ReportLostScreen extends StatefulWidget {
  const ReportLostScreen({super.key});

  @override
  State<ReportLostScreen> createState() => _ReportLostScreenState();
}

class _ReportLostScreenState extends State<ReportLostScreen> {
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

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
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
      setState(() => _errorMessage = 'Could not open the gallery.');
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please tell us what you lost.');
      return;
    }
    if (location.isEmpty) {
      setState(() => _errorMessage = 'Please tell us where you lost it.');
      return;
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

      await _service.reportLostItem(
        itemName: name,
        category: _category,
        description: description,
        locationLost: location,
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      await showSuccessCheck(
        context,
        title: 'Lost item reported',
        subtitle: 'Protection Services will look out for it.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Lost report failed: $e');
      if (!mounted) return;
      setState(() =>
          _errorMessage = 'Could not submit your report. Please try again.');
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
          'Report Lost Item',
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
                'Tell us what is missing. You will be able to search for it here, and Protection Services will match it against items handed in.',
                style: TextStyle(color: _labelColor, fontSize: 14),
              )),
              const SizedBox(height: 16),

              // ---------- Photo ----------
              staggerIn(1, GestureDetector(
                onTap: _pickImage,
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
                              Text('Upload a picture of it, if you have one',
                                  style: TextStyle(
                                      color: _hintColor, fontSize: 13)),
                            ],
                          ),
                        ),
                ),
              )),
              const SizedBox(height: 26),

              // ---------- What did you lose? ----------
              staggerIn(2, _label('What did you lose?')),
              staggerIn(2, TextField(
                controller: _nameController,
                style: const TextStyle(color: _fieldText, fontSize: 15),
                cursorColor: const Color(0xFF3B2FE0),
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    _fieldDecoration(hint: 'e.g. Student card, black wallet'),
              )),
              const SizedBox(height: 22),

              // ---------- Category ----------
              staggerIn(3, _label('Category')),
              staggerIn(3, DropdownButtonFormField<String>(
                initialValue: _category,
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
                      'Colour, brand, scratches, what was inside it — anything that identifies it',
                ),
              )),
              const SizedBox(height: 22),

              // ---------- Where lost ----------
              staggerIn(5, _label('Where did you lose it?')),
              staggerIn(5, TextField(
                controller: _locationController,
                style: const TextStyle(color: _fieldText, fontSize: 15),
                cursorColor: const Color(0xFF3B2FE0),
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration(
                  hint: 'e.g. Library, Block A, Res A',
                  prefix: const Icon(Icons.location_on_outlined,
                      color: Color(0xFF3A4A5C), size: 22),
                ),
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