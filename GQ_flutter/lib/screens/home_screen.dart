import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_result.dart';
import '../models/gift.dart';
import '../providers/auth_providers.dart';
import '../providers/gifts_providers.dart';
import '../providers/pairing_providers.dart';
import '../providers/user_providers.dart';
import '../widgets/pill_toggle.dart';
import '../widgets/sticker.dart';
import 'add_edit_gift_screen.dart';
import 'guess_chat_screen.dart';
import 'login_screen.dart';
import 'pairing_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  void _openAccountMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: const Text('Manage pairing'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PairingScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await ref.read(authRepositoryProvider).signOut();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final myProfile = ref.watch(myProfileStreamProvider).value;
    final myPhoto = myProfile?.photoUrl;
    final partnerUid = myProfile?.linkedWith;
    final partnerProfile = partnerUid == null
        ? null
        : ref.watch(userProfileStreamProvider(partnerUid)).value;
    final partnerLabel = partnerUid == null
        ? "Partner's Wishes"
        : (partnerProfile?.nickname.isNotEmpty == true
            ? "${partnerProfile!.nickname}'s Wishes"
            : "Partner's Wishes");

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'GiftQuest',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openAccountMenu,
              child: CircleAvatar(
                radius: 18,
                backgroundImage:
                    (myPhoto?.isNotEmpty ?? false) ? NetworkImage(myPhoto!) : null,
                child: (myPhoto?.isNotEmpty ?? false)
                    ? null
                    : const Icon(Icons.person_outline),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditGiftScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: uid == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: PillToggle(
                    labels: ['My Wishes', partnerLabel],
                    selectedIndex: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                Expanded(
                  child: _tab == 0
                      ? _MyWishesGrid(uid: uid)
                      : (partnerUid == null
                          ? const _NotLinkedState()
                          : _PartnerGrid(partnerUid: partnerUid)),
                ),
              ],
            ),
    );
  }
}

class _MyWishesGrid extends ConsumerWidget {
  const _MyWishesGrid({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gifts = ref.watch(giftsStreamProvider(uid)).value ?? const [];

    if (gifts.isEmpty) {
      return const _EmptyState(
        title: 'Start your first wishlist ✨',
        subtitle: 'Tap the + button to add your first gift.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        return _MyGiftCard(gift: gift);
      },
    );
  }
}

class _MyGiftCard extends StatelessWidget {
  const _MyGiftCard({required this.gift});

  final Gift gift;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddEditGiftScreen(existing: gift)),
      ),
      child: StickerCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.card_giftcard_rounded, color: scheme.primary),
            const Spacer(),
            Text(
              gift.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (gift.category.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                gift.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartnerGrid extends ConsumerWidget {
  const _PartnerGrid({required this.partnerUid});

  final String partnerUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gifts =
        ref.watch(giftsStreamProvider(partnerUid)).value ?? const [];
    final results =
        ref.watch(gameResultsForOwnerProvider(partnerUid)).value ??
            const <GameResult>[];
    final resultByItemId = {for (final r in results) r.itemId: r};

    if (gifts.isEmpty) {
      return const _EmptyState(
        title: 'No gifts yet ✨',
        subtitle: "Your partner hasn't added anything to guess yet.",
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        return _MysteryGiftCard(
          gift: gift,
          partnerUid: partnerUid,
          result: resultByItemId[gift.id],
        );
      },
    );
  }
}

class _MysteryGiftCard extends StatelessWidget {
  const _MysteryGiftCard({
    required this.gift,
    required this.partnerUid,
    required this.result,
  });

  final Gift gift;
  final String partnerUid;
  final GameResult? result;

  static const _hintCap = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final guessed = result != null;
    final filled = (result?.guessCount ?? 0).clamp(0, _hintCap);
    final status = result == null
        ? 'Not started yet'
        : (result!.won ? 'Guessed! 🎉' : 'Revealed');

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GuessChatScreen(
            itemId: gift.id,
            itemOwnerId: partnerUid,
          ),
        ),
      ),
      child: StickerCard(
        padding: const EdgeInsets.all(16),
        color: guessed ? scheme.surfaceContainerHigh : scheme.surfaceContainerHigh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.card_giftcard_rounded, color: scheme.secondary),
            const Spacer(),
            Text(
              'Mystery Gift',
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < _hintCap; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 2),
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < filled
                            ? scheme.secondary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              status,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotLinkedState extends StatelessWidget {
  const _NotLinkedState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Not linked with a partner',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Link with your partner to see their wishlist and share yours.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            StickerButton(
              label: 'Link with partner',
              expand: false,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PairingScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
