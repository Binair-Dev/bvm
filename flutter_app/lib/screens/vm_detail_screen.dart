import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vm_list_provider.dart';
import 'terminal_screen.dart';
import 'vm_files_screen.dart';
import 'port_forwards_screen.dart';

class VmDetailScreen extends StatelessWidget {
  final String vmName;

  const VmDetailScreen({super.key, required this.vmName});

  @override
  Widget build(BuildContext context) {
    return Consumer<VmListProvider>(
      builder: (context, provider, child) {
        final vm = provider.vms.firstWhere(
          (v) => v.name == vmName,
          orElse: () => VmInfo(
            name: vmName,
            createdAt: DateTime.now(),
            distro: 'ubuntu',
            size: '0 B',
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(vm.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'backup') {
                    _backupVm(context, vm.name);
                  } else if (value == 'delete') {
                    _confirmDelete(context, vm);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'backup',
                    child: Row(
                      children: [
                        Icon(Icons.save_alt, size: 20),
                        SizedBox(width: 8),
                        Text('Backup'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              vm.isRunning ? Icons.play_circle_filled : Icons.stop_circle,
                              color: vm.isRunning ? Colors.green : Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vm.isRunning ? 'Running' : 'Stopped',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  '${vm.distro} · ${vm.size}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Created: ${_formatDate(vm.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: vm.autoStart,
                              onChanged: (value) {
                                if (value != null) {
                                  provider.setAutoStart(vm.name, value);
                                }
                              },
                            ),
                            const Text('Auto-start on app launch'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Actions
                if (!vm.isRunning) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => provider.startVm(vm.name),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('START VM'),
                    ),
                  ),
                ] else ...[
                  _ActionButton(
                    icon: Icons.terminal,
                    label: 'Terminal',
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TerminalScreen(vmName: vm.name),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.folder,
                    label: 'Files',
                    color: Theme.of(context).colorScheme.secondary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VmFilesScreen(vmName: vm.name),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.router,
                    label: 'Port Forwards',
                    color: Theme.of(context).colorScheme.tertiary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PortForwardsScreen(vmName: vm.name),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => provider.stopVm(vm.name),
                      icon: const Icon(Icons.stop),
                      label: const Text('STOP VM'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _backupVm(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup feature: use Backup tab')),
    );
  }

  void _confirmDelete(BuildContext context, VmInfo vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete VM?'),
        content: Text('This will permanently delete "${vm.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await context.read<VmListProvider>().deleteVm(vm.name);
              if (ok && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
