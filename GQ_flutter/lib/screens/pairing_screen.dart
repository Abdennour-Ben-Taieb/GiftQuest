import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/pairing_providers.dart';
import '../providers/user_providers.dart';
import '../widgets/sticker.dart';
import 'qr_scan_screen.dart';

/// Standalone route for pairing, reachable from Settings. The primary entry
/// point per spec is [PairingPanel] embedded directly in Home's partner tab
/// (single tab slot, not a separate screen) — this just wraps the same panel
/// in a Scaffold for the times a dedicated screen is still useful.
class PairingScreen extends StatelessWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pairing')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: PairingPanel(),
        ),
      ),
    );
  }
}

/// The actual pairing UI: incoming-request card, own QR/code + scan/enter,
/// waiting-for-confirmation status, and the linked state. No Scaffold of its
/// own so it can be dropped straight into Home's partner tab.
class PairingPanel extends ConsumerStatefulWidget {
  const PairingPanel({super.key});

  @override
  ConsumerState<PairingPanel> createState() => _PairingPanelState();
}

class _PairingPanelState extends ConsumerState<PairingPanel> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final ok = await ref
        .read(pairingControllerProvider.notifier)
        .sendPairRequest(_codeController.text);
    if (ok) _codeController.clear();
  }

  Future<void> _scan() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (result == null || !mounted) return;
    final ok = await ref
        .read(pairingControllerProvider.notifier)
        .sendPairRequest(result);
    if (ok) _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myProfile = ref.watch(myProfileStreamProvider).value;
    final actionState = ref.watch(pairingControllerProvider);
    final partnerUid = myProfile?.linkedWith;
    final isLinked = partnerUid != null;
    final incomingFrom = myProfile?.pendingPairRequestFrom;
    final pendingTo = myProfile?.pendingPairRequestTo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isLinked) ...[
          Text(
            'Link with your partner',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Share your code, or enter theirs, to connect your wishlists.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
        ],
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
        if (incomingFrom != null) ...[
          _IncomingRequestCard(requesterUid: incomingFrom),
          const SizedBox(height: 16),
        ],
        if (isLinked)
          _LinkedCard(partnerUid: partnerUid)
        else ...[
          const _ShareCodeCard(),
          const SizedBox(height: 24),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: "Enter their code"),
          ),
          const SizedBox(height: 16),
          StickerButton(
            label: 'Connect',
            onPressed: actionState.loading ? null : _connect,
            isLoading: actionState.loading,
            variant: StickerButtonVariant.secondary,
          ),
          const SizedBox(height: 12),
          StickerButton(
            label: 'Scan QR code',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: actionState.loading ? null : _scan,
          ),
          if (pendingTo != null) ...[
            const SizedBox(height: 20),
            _WaitingRow(partnerUid: pendingTo),
          ],
        ],
        if (isLinked) ...[
          const SizedBox(height: 24),
          StickerButton(
            label: 'Unlink partner',
            onPressed: actionState.loading
                ? null
                : () => ref.read(pairingControllerProvider.notifier).unlink(),
            isLoading: actionState.loading,
            variant: StickerButtonVariant.outline,
          ),
        ],
      ],
    );
  }
}

class _ShareCodeCard extends ConsumerWidget {
  const _ShareCodeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final code = ref.watch(myShareCodeProvider);
    final value = code.value ?? '';

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
                value.isNotEmpty ? value : (code.isLoading ? '…' : '—'),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StickerCard(
          padding: const EdgeInsets.all(16),
          child: value.isEmpty
              ? const SizedBox(height: 180, width: 180)
              : QrImageView(
                  data: value,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: scheme.surfaceContainerHigh,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: scheme.onSurface,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: scheme.onSurface,
                  ),
                ),
        ),
      ],
    );
  }
}

class _WaitingRow extends ConsumerWidget {
  const _WaitingRow({required this.partnerUid});

  final String partnerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final partner = ref.watch(userProfileStreamProvider(partnerUid)).value;
    final name = partner?.nickname.isNotEmpty == true
        ? partner!.nickname
        : (partner?.name.isNotEmpty == true ? partner!.name : 'them');
    final actionState = ref.watch(pairingControllerProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: scheme.secondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'waiting for $name to confirm',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: actionState.loading
              ? null
              : () => ref
                    .read(pairingControllerProvider.notifier)
                    .cancelMyPendingRequest(partnerUid),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _IncomingRequestCard extends ConsumerWidget {
  const _IncomingRequestCard({required this.requesterUid});

  final String requesterUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final requester = ref.watch(userProfileStreamProvider(requesterUid)).value;
    final name = requester?.nickname.isNotEmpty == true
        ? requester!.nickname
        : (requester?.name.isNotEmpty == true ? requester!.name : 'Someone');
    final actionState = ref.watch(pairingControllerProvider);

    return StickerCard(
      color: scheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$name wants to pair',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StickerButton(
                  label: 'Decline',
                  variant: StickerButtonVariant.outline,
                  isLoading: actionState.loading,
                  onPressed: actionState.loading
                      ? null
                      : () => ref
                            .read(pairingControllerProvider.notifier)
                            .declinePairRequest(requesterUid),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StickerButton(
                  label: 'Accept',
                  isLoading: actionState.loading,
                  onPressed: actionState.loading
                      ? null
                      : () => ref
                            .read(pairingControllerProvider.notifier)
                            .acceptPairRequest(requesterUid),
                ),
              ),
            ],
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
            backgroundImage: (partner?.photoUrl?.isNotEmpty ?? false)
                ? NetworkImage(partner!.photoUrl!)
                : null,
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
