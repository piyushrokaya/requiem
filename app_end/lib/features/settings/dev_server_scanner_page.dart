import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/api_endpoint_store.dart';

/// Scans a QR code containing the backend server URL (LAN IP or a tunnel
/// like ngrok) and saves it as the runtime override, so a physical device
/// doesn't need the URL typed in by hand.
class DevServerScannerPage extends StatefulWidget {
  const DevServerScannerPage({super.key});

  @override
  State<DevServerScannerPage> createState() => _DevServerScannerPageState();
}

class _DevServerScannerPageState extends State<DevServerScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRawValue(String raw) async {
    final normalized = ApiEndpointStore.normalizeServerBaseUrl(raw);
    if (normalized == null) {
      setState(
        () => _error =
            'QR भित्र मान्य server URL छैन।\n'
            'उदाहरण: http://192.168.1.50:5000 वा https://xxxx.ngrok-free.dev',
      );
      return;
    }

    try {
      await ApiEndpointStore.setOverrideServerBaseUrl(normalized);
    } catch (_) {
      setState(() => _error = 'URL save गर्न सकिएन।');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server URL Scan'),
        actions: [
          IconButton(
            tooltip: 'Flash',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_handled) return;
                final raw = capture.barcodes.firstOrNull?.rawValue;
                if (raw == null || raw.trim().isEmpty) return;
                _handled = true;
                _handleRawValue(raw).whenComplete(() {
                  // If it failed (didn't pop), allow scanning again.
                  if (mounted) {
                    setState(() {
                      _handled = false;
                    });
                  }
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend चलिरहेको कम्प्युटरको server URL लाई QR बनाएर यहाँ स्क्यान गर्नुहोस्।',
                ),
                const SizedBox(height: 8),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
