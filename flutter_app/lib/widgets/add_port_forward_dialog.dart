import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/port_forward_provider.dart';

class AddPortForwardDialog extends StatefulWidget {
  final String vmName;
  const AddPortForwardDialog({super.key, required this.vmName});

  @override
  State<AddPortForwardDialog> createState() => _AddPortForwardDialogState();
}

class _AddPortForwardDialogState extends State<AddPortForwardDialog> {
  final _vmPortController = TextEditingController();
  final _hostPortController = TextEditingController();
  bool _exposeOnNetwork = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _vmPortController.dispose();
    _hostPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Port Forward'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VM: ${widget.vmName}', style: theme.textTheme.labelMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _vmPortController,
            decoration: const InputDecoration(
              labelText: 'VM Port',
              hintText: 'e.g. 3000',
              prefixIcon: Icon(Icons.arrow_forward),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _error = null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostPortController,
            decoration: const InputDecoration(
              labelText: 'Host Port',
              hintText: 'e.g. 8080',
              prefixIcon: Icon(Icons.phone_android),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: (_) => _error = null,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expose on local network'),
            subtitle: const Text('Allows other devices on WiFi to connect'),
            value: _exposeOnNetwork,
            onChanged: (v) => setState(() => _exposeOnNetwork = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Start'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final vmPortText = _vmPortController.text.trim();
    final hostPortText = _hostPortController.text.trim();

    final vmPort = int.tryParse(vmPortText);
    final hostPort = int.tryParse(hostPortText);

    if (vmPort == null || vmPort <= 0 || vmPort > 65535) {
      setState(() => _error = 'Enter a valid VM port (1-65535)');
      return;
    }
    if (hostPort == null || hostPort <= 0 || hostPort > 65535) {
      setState(() => _error = 'Enter a valid host port (1-65535)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final provider = context.read<PortForwardProvider>();
    final ok = await provider.addForward(
      vmName: widget.vmName,
      vmPort: vmPort,
      hostPort: hostPort,
      exposeOnNetwork: _exposeOnNetwork,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = provider.error ?? 'Failed to start port forward');
      }
    }
  }
}
