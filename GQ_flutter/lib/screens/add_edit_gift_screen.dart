import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gift.dart';
import '../providers/auth_providers.dart';
import '../providers/gifts_providers.dart';
import '../services/cloudinary_service.dart';
import '../widgets/sticker.dart';

/// Matches the categories used elsewhere in the app; emoji prefixes are
/// part of the stored value, not just decoration.
const kGiftCategories = <String>[
  '👗 Fashion & Clothing',
  '👜 Bags & Accessories',
  '💄 Beauty & Fragrance',
  '🍫 Food & Treats',
  '📱 Tech & Gadgets',
  '🏠 Home & Living',
  '🎮 Gaming & Entertainment',
  '📚 Books & Hobbies',
  '🏋️ Sports & Fitness',
  '🎟️ Experience',
  '💳 Gift Card / Money',
  '🎁 Something Else',
];

class AddEditGiftScreen extends ConsumerStatefulWidget {
  const AddEditGiftScreen({super.key, this.existing});

  /// When provided, the form edits this gift instead of creating a new one.
  final Gift? existing;

  @override
  ConsumerState<AddEditGiftScreen> createState() => _AddEditGiftScreenState();
}

class _AddEditGiftScreenState extends ConsumerState<AddEditGiftScreen> {
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _priceController = TextEditingController(
    text: widget.existing != null && widget.existing!.price > 0
        ? widget.existing!.price.toStringAsFixed(2)
        : '',
  );
  late final _linkController = TextEditingController(
    text: widget.existing?.link ?? '',
  );
  late final _noteController = TextEditingController(
    text: widget.existing?.note ?? '',
  );

  late String? _category = kGiftCategories.contains(widget.existing?.category)
      ? widget.existing!.category
      : null;

  /// Newly-picked local photo, if the user chose a new one this session.
  XFile? _newPhoto;

  /// The gift's photo as it exists in Firestore today — preserved on save
  /// unless [_newPhoto] is picked and successfully uploaded.
  late final String? _existingPhotoUrl = widget.existing?.photoUrl;

  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _linkController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _newPhoto = file);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() => _saving = true);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    // Upload a freshly-picked photo, but never let a failed upload wipe out
    // a photo that was already saved — fall back to the existing URL.
    var photoUrl = _existingPhotoUrl;
    if (_newPhoto != null) {
      setState(() => _uploadingPhoto = true);
      final uploaded = await CloudinaryService().uploadImage(_newPhoto!);
      if (uploaded != null) photoUrl = uploaded;
      if (mounted) setState(() => _uploadingPhoto = false);
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final repo = ref.read(giftsRepositoryProvider);
    final existing = widget.existing;

    try {
      if (existing == null) {
        await repo.addGift(
          userId: uid,
          title: title,
          category: _category ?? '',
          price: price,
          link: _linkController.text.trim(),
          note: _noteController.text.trim(),
          photoUrl: photoUrl,
        );
      } else {
        await repo.updateGift(
          userId: uid,
          giftId: existing.id,
          title: title,
          category: _category ?? '',
          price: price,
          link: _linkController.text.trim(),
          note: _noteController.text.trim(),
          photoUrl: photoUrl,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete gift?'),
        content: Text("This removes '${existing.title}' from your wishlist."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(giftsRepositoryProvider).deleteGift(
          userId: uid,
          giftId: existing.id,
        );
    if (mounted) Navigator.of(context).pop();
  }

  ImageProvider? get _avatarImage {
    if (_newPhoto != null) return FileImage(File(_newPhoto!.path));
    if (_existingPhotoUrl?.isNotEmpty ?? false) {
      return NetworkImage(_existingPhotoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit gift' : 'Add a gift'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: StickerAvatar(
                  image: _avatarImage,
                  onTap: _uploadingPhoto ? () {} : _pickPhoto,
                  placeholder: 'Add\nphoto',
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: StickerButton(
                  label: _avatarImage == null ? 'Choose photo' : 'Change photo',
                  onPressed: _uploadingPhoto ? null : _pickPhoto,
                  variant: StickerButtonVariant.outline,
                  expand: false,
                  isLoading: _uploadingPhoto,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                autofocus: !isEditing,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                hint: const Text('Select a category'),
                isExpanded: true,
                items: [
                  for (final category in kGiftCategories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Link'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 24),
              if (_uploadingPhoto) ...[
                Text(
                  'Uploading photo…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
              ],
              StickerButton(
                label: isEditing ? 'Save changes' : 'Add gift',
                onPressed: _titleController.text.trim().isEmpty ? null : _save,
                isLoading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
