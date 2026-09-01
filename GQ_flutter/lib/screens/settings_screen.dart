import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/pairing_providers.dart';
import '../providers/user_providers.dart';
import 'login_screen.dart';
import 'pairing_screen.dart';

/// Dense bordered-row list per the CDS convention ("bordered rows, not
/// rounded-rect cards"). Kept deliberately low-risk/low-scope: several rows
/// are stubs with no backing infra (notifications, privacy) rather than
/// half-built features.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmUnlink(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unlink partner?'),
        content: const Text(
          "You'll stop seeing each other's wishlists, and your guesses "
          'against their gifts will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Unlink',
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(pairingControllerProvider.notifier).unlink();
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final myProfile = ref.watch(myProfileStreamProvider).value;
    final isLinked = myProfile?.isLinked ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionLabel('ACCOUNT'),
          _SettingsRow(
            icon: Icons.person_outline,
            title: myProfile?.name.isNotEmpty == true
                ? myProfile!.name
                : 'Account',
            subtitle: myProfile?.email,
          ),
          _SectionLabel('PREFERENCES'),
          const _SettingsRow(
            icon: Icons.notifications_outlined,
            title: 'Notification preferences',
            subtitle: 'Coming soon',
          ),
          const _SettingsRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle: 'Coming soon',
          ),
          _SectionLabel('PARTNER'),
          if (isLinked)
            _SettingsRow(
              icon: Icons.link_off,
              title: 'Unlink partner',
              titleColor: scheme.error,
              onTap: () => _confirmUnlink(context, ref),
            )
          else
            _SettingsRow(
              icon: Icons.favorite_outline,
              title: 'Link with partner',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PairingScreen()),
              ),
            ),
          _SectionLabel('SESSION'),
          _SettingsRow(
            icon: Icons.logout,
            title: 'Log out',
            onTap: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? scheme.onSurfaceVariant),
        title: Text(
          title,
          style: TextStyle(color: titleColor ?? scheme.onSurface),
        ),
        subtitle: (subtitle?.isNotEmpty ?? false) ? Text(subtitle!) : null,
        trailing: onTap != null
            ? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
            : null,
        onTap: onTap,
      ),
    );
  }
}
