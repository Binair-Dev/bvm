import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vm_setup_provider.dart';
import '../providers/vm_list_provider.dart';

class VmCreateScreen extends StatefulWidget {
  const VmCreateScreen({super.key});

  @override
  State<VmCreateScreen> createState() => _VmCreateScreenState();
}

class _VmCreateScreenState extends State<VmCreateScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VmSetupProvider>().reset();
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setup = context.watch<VmSetupProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create VM')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: setup.status == SetupStatus.running || setup.status == SetupStatus.success || setup.status == SetupStatus.error
            ? _buildProgress(theme, setup)
            : _buildForm(theme, setup),
      ),
    );
  }

  Widget _buildForm(ThemeData theme, VmSetupProvider setup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VM Name', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'e.g. devbox',
            prefixIcon: Icon(Icons.computer),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _create(setup),
        ),
        if (setup.error != null) ...[
          const SizedBox(height: 12),
          Text(setup.error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _create(setup),
            child: const Text('Create Ubuntu VM'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This will download and install an Ubuntu rootfs (~300MB).',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildProgress(ThemeData theme, VmSetupProvider setup) {
    final bool isRunning = setup.status == SetupStatus.running;
    final bool isSuccess = setup.status == SetupStatus.success;
    final bool isError = setup.status == SetupStatus.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRunning) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text('Creating ${setup.vmName}...', style: theme.textTheme.titleMedium),
        ],
        if (isSuccess) ...[
          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 48),
          const SizedBox(height: 12),
          Text('VM "${setup.vmName}" created!', style: theme.textTheme.titleMedium),
        ],
        if (isError) ...[
          Icon(Icons.error, color: theme.colorScheme.error, size: 48),
          const SizedBox(height: 12),
          Text('Failed to create VM', style: theme.textTheme.titleMedium),
          Text(setup.error ?? '', style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                setup.logText.isEmpty ? (isRunning ? 'Starting installation...' : setup.logText) : setup.logText,
                style: const TextStyle(fontFamily: 'DejaVuSansMono', fontSize: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (isSuccess)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context.read<VmListProvider>().loadVms();
                context.read<VmSetupProvider>().reset();
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ),
        if (isError)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setup.reset();
              },
              child: const Text('Try Again'),
            ),
          ),
      ],
    );
  }

  void _create(VmSetupProvider setup) {
    final name = _controller.text.trim();
    setup.createVm(name);
  }
}
