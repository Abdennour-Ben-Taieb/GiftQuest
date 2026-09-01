import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gift.dart';
import '../providers/auth_providers.dart';
import '../providers/gifts_providers.dart';
import '../services/cloudinary_service.dart';
import '../utils/date_format.dart';
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

const _visibilityLabels = {
  GiftVisibility.onPairing: "as soon as we're paired",
  GiftVisibility.onDate: 'on a set date',
  GiftVisibility.manual: 'manually',
};

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
  late final _priceController = TextEditingController(text: _initialPriceText());
  late final _linkController = TextEditingController(
    text: widget.existing?.link ?? '',
  );
  late final _hintController = TextEditingController(
    text: widget.existing?.hint ?? '',
  );

  late String? _category = _initialCategory();
  late String _currency = widget.existing?.currency ?? 'TND';

  late GiftVisibility _visibility =
      widget.existing?.visibility ?? GiftVisibility.onPairing;
  late DateTime? _unlockAt = widget.existing?.unlockAt;

  String? _categoryError;
  String? _priceError;

  /// New wishes start with category/price genuinely blank, forcing a
  /// conscious choice. Wishes saved before category/price were required
  /// fields would otherwise come back null/0 here and immediately show a
  /// validation error the moment the user opens them to tweak something
  /// unrelated (e.g. just the title) — so an *existing* wish missing this
  /// data is pre-filled with a reasonable fallback instead, and the user is
  /// free to leave it as-is or correct it.
  String? _initialCategory() {
    final existing = widget.existing;
    if (existing == null) return null;
    if (kGiftCategories.contains(existing.category)) return existing.category;
    return kGiftCategories.last; // "🎁 Something Else" — the catch-all bucket
  }

  String _initialPriceText() {
    final existing = widget.existing;
    if (existing == null) return '';
    if (existing.price > 0) return existing.price.toStringAsFixed(2);
    // Same rationale as _initialCategory: 0 is already how the rest of the
    // app treats "no price recorded" (see the AI prompt's price<=0 branch),
    // so prefilling it here is just making that existing sentinel visible
    // and valid, not inventing new data.
    return '0.00';
  }

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
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _newPhoto = file);
  }

  Future<void> _pickUnlockDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _unlockAt ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _unlockAt = picked);
  }

  /// Returns the parsed price, or null if the price field is invalid.
  double? _validate() {
    final categoryValid = _category != null && _category!.isNotEmpty;
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);
    final priceValid = priceText.isNotEmpty && price != null && price >= 0;

    setState(() {
      _categoryError = categoryValid ? null : 'Pick a category';
      _priceError = priceValid ? null : 'Enter a price (0 if unknown)';
    });

    return priceValid ? price : null;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;

    final price = _validate();
    if (price == null) return;

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

    final repo = ref.read(giftsRepositoryProvider);
    final existing = widget.existing;
    final unlockAt = _visibility == GiftVisibility.onDate ? _unlockAt : null;

    try {
      if (existing == null) {
        await repo.addGift(
          userId: uid,
          title: title,
          category: _category!,
          price: price,
          currency: _currency,
          link: _linkController.text.trim(),
          hint: _hintController.text.trim(),
          photoUrl: photoUrl,
          visibility: _visibility,
          unlockAt: unlockAt,
        );
      } else {
        await repo.updateGift(
          userId: uid,
          giftId: existing.id,
          title: title,
          category: _category!,
          price: price,
          currency: _currency,
          link: _linkController.text.trim(),
          hint: _hintController.text.trim(),
          photoUrl: photoUrl,
          visibility: _visibility,
          unlockAt: unlockAt,
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
        title: const Text('Delete wish?'),
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

  ImageProvider? get _photoImage {
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
      appBar: AppBar(title: Text(isEditing ? 'edit wish' : 'add wish')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashedPhotoBox(
                image: _photoImage,
                onTap: _uploadingPhoto ? () {} : _pickPhoto,
                label: _uploadingPhoto ? 'uploading…' : 'add a photo',
              ),
              const SizedBox(height: 24),
              _FieldLabel('TITLE'),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'What do you wish for?'),
                autofocus: !isEditing,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _FieldLabel('HINT FOR THE AI'),
                  const Spacer(),
                  Text(
                    'only the AI sees this',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hintController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'A clue only the AI can use to answer questions',
                ),
              ),
              const SizedBox(height: 20),
              _FieldLabel('CATEGORY'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(errorText: _categoryError),
                hint: const Text('Select a category'),
                isExpanded: true,
                items: [
                  for (final c in kGiftCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (value) => setState(() {
                  _category = value;
                  _categoryError = null;
                }),
              ),
              const SizedBox(height: 20),
              _FieldLabel('PRICE'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(errorText: _priceError),
                      onChanged: (_) {
                        if (_priceError != null) setState(() => _priceError = null);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      isExpanded: true,
                      items: [
                        for (final c in kCurrencyCodes)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _currency = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _FieldLabel('LINK (OPTIONAL)'),
              const SizedBox(height: 8),
              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(hintText: 'Where to find it'),
              ),
              const SizedBox(height: 20),
              _FieldLabel('GUESSABLE'),
              const SizedBox(height: 8),
              DropdownButtonFormField<GiftVisibility>(
                initialValue: _visibility,
                isExpanded: true,
                items: [
                  for (final v in GiftVisibility.values)
                    DropdownMenuItem(value: v, child: Text(_visibilityLabels[v]!)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _visibility = value);
                },
              ),
              if (_visibility == GiftVisibility.onDate) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickUnlockDate,
                  borderRadius: BorderRadius.circular(28),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Unlocks on'),
                    child: Text(
                      _unlockAt != null
                          ? formatShortDate(_unlockAt!)
                          : 'Choose a date',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (_uploadingPhoto) ...[
                Text(
                  'Uploading photo…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
              ],
              StickerButton(
                label: 'save wish',
                onPressed: _titleController.text.trim().isEmpty ? null : _save,
                isLoading: _saving,
              ),
              if (isEditing) ...[
                const SizedBox(height: 12),
                StickerButton(
                  label: 'delete wish',
                  onPressed: _delete,
                  variant: StickerButtonVariant.outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        letterSpacing: 1.5,
      ),
    );
  }
}
