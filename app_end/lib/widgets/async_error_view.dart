import 'package:flutter/material.dart';

/// Shown when a backend request fails — e.g. the API server isn't
/// reachable yet. Gives the user a way to retry without restarting the app.
class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off,
                size: 30,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'सर्भरसँग जोड्न सकिएन',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('फेरि प्रयास गर्नुहोस्'),
            ),
          ],
        ),
      ),
    );
  }
}
