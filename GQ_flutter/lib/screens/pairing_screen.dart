import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pairing_providers.dart';
import '../providers/user_providers.dart';
import '../widgets/sticker.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final ok = await ref
        .read(pairingControllerProvider.notifier)
        .linkWithPartnerCode(_codeController.text);
    if (ok) _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myProfile = ref.watch(myProfileStreamProvider).value;
    final actionState = ref.watch(pairingControllerProvider);
    final partnerUid = myProfile?.linkedWith;
    final isLinked = partnerUid != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Pairing')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Link with your partner',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isLinked
                    ? "You're linked — you can see each other's wishlists."
                    : 'Share your code, or enter theirs, to connect your wishlists.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              if (actionState.error != null) ...[
                StickerCard(
                  color: scheme.errorContainer,
                  borderColor: scheme.error,
                  child: Text(
                    actionState.error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (isLinked)
                _LinkedCard(partnerUid: partnerUid)
              else
                const _ShareCodeCard(),
              const SizedBox(height: 24),
              if (isLinked)
                StickerButton(
                  label: 'Unlink partner',
                  onPressed: actionState.loading
                      ? null
                      : () => ref.read(pairingControllerProvider.notifier).unlink(),
                  isLoading: actionState.loading,
                  variant: StickerButtonVariant.outline,
                )
              else ...[
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: "Enter their code",
                  ),
                ),
                const SizedBox(height: 16),
                StickerButton(
                  label: 'Connect',
                  onPressed: actionState.loading ? null : _connect,
                  isLoading: actionState.loading,
                  variant: StickerButtonVariant.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareCodeCard extends ConsumerWidget {
  const _ShareCodeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final code = ref.watch(myShareCodeProvider);

    return Column(
      children: [
        StickerCard(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Text(
                'YOUR CODE',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                code.value?.isNotEmpty == true
                    ? code.value!
                    : (code.isLoading ? '…' : '—'),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 4,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _QrPlaceholder(code: code.value ?? ''),
      ],
    );
  }
}

/// Static bordered box standing in for a real QR code — matches the
/// "QR code placeholder box" from the design brief.
class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 180,
      width: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'QR code coming soon',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LinkedCard extends ConsumerWidget {
  const _LinkedCard({required this.partnerUid});

  final String partnerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final partner = ref.watch(userProfileStreamProvider(partnerUid)).value;
    final name = partner?.nickname.isNotEmpty == true
        ? partner!.nickname
        : (partner?.name ?? 'your partner');

    return StickerCard(
      color: scheme.secondary,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.surfaceContainerHigh,
            backgroundImage:
                (partner?.photoUrl?.isNotEmpty ?? false) ? NetworkImage(partner!.photoUrl!) : null,
            child: (partner?.photoUrl?.isNotEmpty ?? false)
                ? null
                : Icon(Icons.favorite, color: scheme.onSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Linked with $name',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
