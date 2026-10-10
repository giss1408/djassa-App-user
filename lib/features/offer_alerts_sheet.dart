import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push/offer_alerts.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';

/// Turns offer alerts on or off, and picks the commune they come from.
/// Favourite shops are always included while alerts are on.
class OfferAlertsSheet extends ConsumerStatefulWidget {
  const OfferAlertsSheet({super.key});

  @override
  ConsumerState<OfferAlertsSheet> createState() => _OfferAlertsSheetState();
}

class _OfferAlertsSheetState extends ConsumerState<OfferAlertsSheet> {
  bool _busy = false;
  String? _problem;

  Future<void> _toggle(bool on) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final alerts = ref.read(offerAlertsProvider.notifier);
    if (on) {
      final ok = await alerts.enable();
      if (!ok && mounted) setState(() => _problem = Strings.offerAlertsDenied);
    } else {
      await alerts.disable();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(offerAlertsProvider);
    final available = ref.watch(pushGatewayProvider).available;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Strings.offerAlerts, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(Strings.offerAlertsHint, style: text.bodyMedium),
            const SizedBox(height: 12),
            if (!available)
              Text(Strings.offerAlertsUnavailable, style: text.bodyMedium?.copyWith(color: FideliaColors.orangeDeep))
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(Strings.offerAlertsSwitch),
                value: settings.enabled,
                onChanged: _busy ? null : _toggle,
              ),
              if (_problem != null)
                Text(_problem!, style: text.bodySmall?.copyWith(color: FideliaColors.orangeDeep)),
              if (settings.enabled) ...[
                const SizedBox(height: 12),
                Text(Strings.offerAlertsCommune, style: text.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final commune in <String?>[...Strings.communes, null])
                      ChoiceChip(
                        label: Text(commune ?? Strings.offerAlertsFavoritesOnly),
                        selected: settings.commune == commune,
                        onSelected: _busy ? null : (_) => ref.read(offerAlertsProvider.notifier).chooseCommune(commune),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
