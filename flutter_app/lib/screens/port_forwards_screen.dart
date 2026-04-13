import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/port_forward_provider.dart';
import '../widgets/add_port_forward_dialog.dart';

class PortForwardsScreen extends StatefulWidget {
  final String vmName;
  const PortForwardsScreen({super.key, required this.vmName});

  @override
  State<PortForwardsScreen> createState() => _PortForwardsScreenState();
}

class _PortForwardsScreenState extends State<PortForwardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PortForwardProvider>().loadForwards();
    });
  }

  Future<void> _openAddDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddPortForwardDialog(vmName: widget.vmName),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port forward started')),
      );
    }
  }

  Future<void> _stopForward(PortForward forward) async {
    final provider = context.read<PortForwardProvider>();
    final ok = await provider.removeForward(forward.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Port forward stopped' : 'Failed to stop port forward'),
        ),
      );
    }
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $url')),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vmName} — Ports'),
      ),
      body: Consumer<PortForwardProvider>(
        builder: (context, provider, _) {
          final forwards = provider.forwardsForVm(widget.vmName);

          if (provider.isLoading && forwards.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (forwards.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.router_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No port forwards', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Expose a port from this VM to your device or local network.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _openAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Port Forward'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: forwards.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.icon(
                    onPressed: _openAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Port Forward'),
                  ),
                );
              }
              final forward = forwards[index - 1];
              final displayUrl = provider.resolveUrl(forward);
              final isNetwork = forward.bindAddress == '0.0.0.0';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isNetwork ? Icons.wifi : Icons.phone_android,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'VM:${forward.vmPort} → Host:${forward.hostPort}',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isNetwork ? 'Accessible from local network' : 'Local device only',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayUrl,
                                style: const TextStyle(fontFamily: 'DejaVuSansMono', fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              tooltip: 'Copy URL',
                              onPressed: () => _copyUrl(displayUrl),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_browser, size: 20),
                              tooltip: 'Open in browser',
                              onPressed: () => _openUrl(displayUrl),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _stopForward(forward),
                          icon: const Icon(Icons.stop, size: 18),
                          label: const Text('Stop'),
                          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
