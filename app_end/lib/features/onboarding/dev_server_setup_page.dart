import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_endpoint_store.dart';

/// First screen shown on app launch: scan the backend server's QR code
/// (LAN IP or a tunnel URL) so a physical device knows where to fetch news
/// from. Can also be skipped to fall back to [ApiConfig.baseUrl].
class DevServerSetupPage extends StatefulWidget {
  const DevServerSetupPage({super.key, required this.onConfigured});

  final VoidCallback onConfigured;

  @override
  State<DevServerSetupPage> createState() => _DevServerSetupPageState();
}

class _DevServerSetupPageState extends State<DevServerSetupPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveServer(String raw) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final normalized = ApiEndpointStore.normalizeServerBaseUrl(raw);
    if (normalized == null) {
      setState(() {
        _saving = false;
        _error =
            'QR भित्र मान्य server URL भेटिएन।\n'
            'उदाहरण: http://192.168.1.50:5000 वा https://xxxx.ngrok-free.dev';
      });
      return;
    }

    try {
      await ApiEndpointStore.setOverrideServerBaseUrl(normalized);
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'URL save गर्न सकिएन।';
      });
      return;
    }

    if (!mounted) return;
    widget.onConfigured();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Setup'),
        actions: [
          IconButton(
            tooltip: 'Flash',
            icon: const Icon(Icons.flash_on),
            onPressed: _saving ? null : () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch),
            onPressed: _saving ? null : () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AbsorbPointer(
              absorbing: _saving,
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  if (_saving) return;
                  final raw = capture.barcodes.firstOrNull?.rawValue;
                  if (raw == null || raw.trim().isEmpty) return;
                  _saveServer(raw);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend चलिरहेको कम्प्युटरको server URL लाई QR बनाएर स्क्यान गर्नुहोस्।',
                ),
                const SizedBox(height: 8),
                if (_saving) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('URL save गर्दैछ...'),
                ],
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          widget.onConfigured();
                        },
                  child: Text(
                    'यसलाई छोड्नुहोस् (default: ${ApiConfig.baseUrl})',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
