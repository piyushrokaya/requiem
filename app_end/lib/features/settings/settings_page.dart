import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_endpoint_store.dart';

/// Lets a developer point the app at a different backend — a LAN IP when
/// testing on a physical device, or a tunnel URL — without rebuilding.
/// Defaults to [ApiConfig.baseUrl] when nothing is saved.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _controller = TextEditingController();
  late Future<String> _resolvedUrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = ApiEndpointStore.serverBaseUrl();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final normalized = ApiEndpointStore.normalizeServerBaseUrl(raw);
    if (normalized == null) {
      setState(() {
        _saving = false;
        _error = 'मान्य URL होइन। उदाहरण: http://192.168.1.50:5000';
      });
      return;
    }

    await ApiEndpointStore.setOverrideServerBaseUrl(normalized);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _resolvedUrl = ApiEndpointStore.serverBaseUrl();
      _controller.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Server set: $normalized')));
  }

  Future<void> _reset() async {
    await ApiEndpointStore.clearOverrideServerBaseUrl();
    if (!mounted) return;
    setState(() => _resolvedUrl = ApiEndpointStore.serverBaseUrl());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Server reset to default: ${ApiConfig.baseUrl}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Server Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Backend server',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'यो app ले समाचार र तुलना डेटा ल्याउने backend server को ठेगाना। '
            'डिफल्टमा emulator/simulator मार्फत यही computer मा चलिरहेको server खोजिन्छ।',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _resolvedUrl,
            builder: (context, snapshot) {
              final url = snapshot.data ?? '…';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.dns_outlined, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          url,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Override',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.50:5000',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _reset,
                  child: const Text('Reset to default'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
