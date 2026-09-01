import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/game_config.dart';
import '../models/game_result.dart';
import '../models/gift.dart';
import '../models/user_profile.dart';
import '../providers/auth_providers.dart';
import '../providers/gifts_providers.dart';
import '../providers/guess_chat_providers.dart';
import '../providers/pairing_providers.dart';
import '../providers/user_providers.dart';
import '../utils/date_format.dart';
import '../widgets/pill_toggle.dart';
import '../widgets/sticker.dart';
import 'add_edit_gift_screen.dart';
import 'guess_chat_screen.dart';
import 'login_screen.dart';
import 'pairing_screen.dart';
import 'reveal_screen.dart';
import 'settings_screen.dart';

String _displayName(UserProfile? profile, {String fallback = 'your partner'}) {
  if (profile?.nickname.isNotEmpty == true) return profile!.nickname;
  if (profile?.name.isNotEmpty == true) return profile!.name;
  return fallback;
}

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
    final myProfileAsync = ref.watch(myProfileStreamProvider);
    final myProfile = myProfileAsync.value;
    final myPhoto = myProfile?.photoUrl;
    final greetingName = _displayName(myProfile, fallback: 'there');
    final partnerUid = myProfile?.linkedWith;
    final partnerProfile = partnerUid == null
        ? null
        : ref.watch(userProfileStreamProvider(partnerUid)).value;
    final partnerName = _displayName(partnerProfile);
    final isPaired = partnerUid != null;

    return Scaffold(
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditGiftScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: _BottomNavBar(
        onSettingsTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'hey,',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              Text(
                                greetingName,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _openAccountMenu,
                          child: CircleAvatar(
                            radius: 24,
                            backgroundImage: (myPhoto?.isNotEmpty ?? false)
                                ? NetworkImage(myPhoto!)
                                : null,
                            child: (myPhoto?.isNotEmpty ?? false)
                                ? null
                                : const Icon(Icons.person_outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: PillToggle(
                      labels: ['my wishes', partnerName],
                      selectedIndex: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ),
                  Expanded(
                    child: _tab == 0
                        ? _MyWishesList(uid: uid, partnerName: partnerName)
                        : (partnerUid == null
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: SingleChildScrollView(
                                    child: PairingPanel(),
                                  ),
                                )
                              : _PartnerList(
                                  partnerUid: partnerUid,
                                  isPaired: isPaired,
                                )),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: true,
                onTap: () {},
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                active: false,
                onTap: onSettingsTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            width: 20,
            height: 2.5,
            decoration: BoxDecoration(
              color: active ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyWishesList extends ConsumerWidget {
  const _MyWishesList({required this.uid, required this.partnerName});

  final String uid;
  final String partnerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftsAsync = ref.watch(giftsStreamProvider(uid));
    final resultsAsync = ref.watch(myOwnGameResultsProvider);

    if (giftsAsync.isLoading || resultsAsync.isLoading) {
      return const _SkeletonList();
    }

    final gifts = giftsAsync.value ?? const <Gift>[];
    final results = resultsAsync.value ?? const <GameResult>[];
    final resultByItemId = {for (final r in results) r.itemId: r};

    if (gifts.isEmpty) {
      return _EmptyState(
        headline: 'nothing hidden yet',
        body: 'Add a wish and $partnerName will have to guess their way to it.',
        actionLabel: 'add first wish',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditGiftScreen()),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      itemCount: gifts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final gift = gifts[index];
        return _MyWishRow(gift: gift, result: resultByItemId[gift.id], partnerName: partnerName);
      },
    );
  }
}

class _MyWishRow extends StatelessWidget {
  const _MyWishRow({required this.gift, required this.result, required this.partnerName});

  final Gift gift;
  final GameResult? result;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Owner's own list: an onPairing wish is never "locked" from the
    // owner's own point of view — only onDate/manual can hide it from them.
    final ownerLocked = gift.visibility == GiftVisibility.onPairing
        ? false
        : gift.isLocked(isPaired: true);

    late final String status;
    late final IconData icon;
    late final Color iconColor;

    if (ownerLocked) {
      status = gift.visibility == GiftVisibility.onDate && gift.unlockAt != null
          ? 'unlocks ${formatShortDate(gift.unlockAt!)}'
          : 'locked';
      icon = Icons.lock_outline;
      iconColor = scheme.onSurfaceVariant;
    } else if (result == null) {
      status = 'hidden';
      icon = Icons.visibility_off_outlined;
      iconColor = scheme.onSurfaceVariant;
    } else if (!result!.gifted) {
      status = 'guessed by $partnerName';
      icon = Icons.check_circle;
      iconColor = scheme.secondary;
    } else {
      status = 'gifted';
      icon = Icons.card_giftcard;
      iconColor = scheme.secondary;
    }

    return _WishRow(
      faded: ownerLocked,
      leading: _ThumbnailSquare(photoUrl: gift.photoUrl),
      title: gift.title,
      subtitle: status,
      trailing: Icon(icon, color: iconColor),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddEditGiftScreen(existing: gift)),
      ),
    );
  }
}

class _PartnerList extends ConsumerWidget {
  const _PartnerList({required this.partnerUid, required this.isPaired});

  final String partnerUid;
  final bool isPaired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftsAsync = ref.watch(giftsStreamProvider(partnerUid));
    final resultsAsync = ref.watch(gameResultsForOwnerProvider(partnerUid));
    final partnerProfile = ref.watch(userProfileStreamProvider(partnerUid)).value;
    final partnerName = _displayName(partnerProfile);

    if (giftsAsync.isLoading || resultsAsync.isLoading) {
      return const _SkeletonList();
    }

    final gifts = giftsAsync.value ?? const <Gift>[];
    final results = resultsAsync.value ?? const <GameResult>[];
    final resultByItemId = {for (final r in results) r.itemId: r};

    if (gifts.isEmpty) {
      return _EmptyState(
        headline: 'nothing to guess yet',
        body: "$partnerName hasn't hidden any wishes yet.",
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: gifts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final gift = gifts[index];
        return _PartnerWishRow(
          gift: gift,
          partnerUid: partnerUid,
          isPaired: isPaired,
          result: resultByItemId[gift.id],
          wishNumber: index + 1,
        );
      },
    );
  }
}

class _PartnerWishRow extends StatelessWidget {
  const _PartnerWishRow({
    required this.gift,
    required this.partnerUid,
    required this.isPaired,
    required this.result,
    required this.wishNumber,
  });

  final Gift gift;
  final String partnerUid;
  final bool isPaired;
  final GameResult? result;
  final int wishNumber;

  GuessChatArgs get _args => (itemId: gift.id, itemOwnerId: partnerUid);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = gift.isLocked(isPaired: isPaired);
    final anonymizedTitle = 'wish #$wishNumber';

    if (locked) {
      final label = gift.visibility == GiftVisibility.onDate && gift.unlockAt != null
          ? 'unlocks ${formatShortDate(gift.unlockAt!)}'
          : 'locked';
      return _WishRow(
        faded: true,
        leading: _IconSquare(icon: Icons.lock_outline, color: scheme.onSurfaceVariant),
        title: anonymizedTitle,
        subtitle: label,
        trailing: null,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not unlocked yet')),
        ),
      );
    }

    if (result == null) {
      return _WishRow(
        leading: _IconSquare(icon: Icons.help_outline, color: scheme.secondary),
        title: anonymizedTitle,
        subtitle: '${GameConfig.maxGuesses} guesses left',
        trailing: Icon(Icons.chat_bubble_outline, color: scheme.onSurfaceVariant),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GuessChatScreen(
              itemId: gift.id,
              itemOwnerId: partnerUid,
              wishLabel: anonymizedTitle,
            ),
          ),
        ),
      );
    }

    final won = result!.won;
    return _WishRow(
      leading: _IconSquare(
        icon: won ? Icons.check_circle : Icons.sentiment_dissatisfied_outlined,
        color: won ? scheme.secondary : scheme.error,
      ),
      title: gift.title,
      subtitle: won ? 'you got this one' : 'revealed',
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RevealScreen(args: _args)),
      ),
    );
  }
}

class _WishRow extends StatelessWidget {
  const _WishRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.faded = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: faded ? 0.5 : 1,
      duration: const Duration(milliseconds: 150),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailSquare extends StatelessWidget {
  const _ThumbnailSquare({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = photoUrl?.isNotEmpty ?? false;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Icon(Icons.card_giftcard_rounded, color: scheme.onSurfaceVariant, size: 20),
    );
  }
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.headline,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String headline;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant, width: 2),
              ),
              child: Icon(
                Icons.card_giftcard_outlined,
                size: 36,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              StickerButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.4, end: 1)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 140,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 90,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('• • •', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
