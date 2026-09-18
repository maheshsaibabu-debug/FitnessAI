import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_monitor.dart';

/// The one place the app admits it's offline — subtle, never blocking.
/// Per docs/OFFLINE_FIRST.md: offline status is informational, not a gate.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityStatusProvider);
    final isOffline = status.valueOrNull == false;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isOffline
          ? Container(
              key: const ValueKey('offline'),
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Offline — your data is safe on this device.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('online')),
    );
  }
}
