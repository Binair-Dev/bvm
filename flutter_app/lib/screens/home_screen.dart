import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vm_list_provider.dart';
import '../providers/backup_provider.dart';
import '../constants.dart';
import '../widgets/backup_progress_dialog.dart';
import 'terminal_screen.dart';
import 'vm_create_screen.dart';
import 'settings_screen.dart';
import 'port_forwards_screen.dart';
import 'vm_files_screen.dart';
import 'vm_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VmListProvider>().loadVms();
    });
  }

  Future<void> _confirmDelete(BuildContext context, VmInfo vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete VM'),
        content: Text('This will permanently delete "${vm.name}" and ALL its files.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<VmListProvider>();
      final ok = await provider.deleteVm(vm.name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'VM "${vm.name}" deleted' : 'Failed to delete "${vm.name}"'),
          ),
        );
      }
    }
  }

  Future<void> _backupVm(BuildContext context, String vmName) async {
    final provider = context.read<BackupProvider>();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackupProgressDialog(
        title: 'Backing up $vmName',
        onStart: (onProgress) async {
          final result = await provider.exportVm(vmName, onProgress);
          return result;
        },
      ),
    );
    if (context.mounted && ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup of "$vmName" saved')),
      );
    } else if (context.mounted && ok == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: ${provider.error}')),
      );
    }
  }

  Future<void> _importVm(BuildContext context) async {
    final provider = context.read<BackupProvider>();
    final vmName = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackupProgressDialog(
        title: 'Importing VM',
        onStart: (onProgress) => provider.importVm(onProgress),
      ),
    );
    if (context.mounted && vmName != null) {
      context.read<VmListProvider>().loadVms();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VM imported as "$vmName"')),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${provider.error}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import VM',
            onPressed: () => _importVm(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<VmListProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.vms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.vms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: ${provider.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: provider.loadVms,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.vms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.computer_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No VMs yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Tap + to create your first Ubuntu VM', style: theme.textTheme.bodySmall),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadVms,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.vms.length,
              itemBuilder: (context, index) {
                final vm = provider.vms[index];
                return Card(
                  child: ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VmDetailScreen(vmName: vm.name),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: vm.isRunning ? Colors.green : theme.colorScheme.primary,
                      child: Icon(
                        vm.isRunning ? Icons.play_arrow : Icons.stop,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(vm.name),
                    subtitle: Row(
                      children: [
                        Text('${vm.size}'),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: vm.isRunning ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(vm.isRunning ? 'Running' : 'Stopped'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'files':
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VmFilesScreen(vmName: vm.name),
                              ),
                            );
                            break;
                          case 'ports':
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PortForwardsScreen(vmName: vm.name),
                              ),
                            );
                            break;
                          case 'backup':
                            _backupVm(context, vm.name);
                            break;
                          case 'delete':
                            _confirmDelete(context, vm);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'files',
                          child: Row(
                            children: [
                              Icon(Icons.folder, size: 20),
                              SizedBox(width: 8),
                              Text('Files'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'ports',
                          child: Row(
                            children: [
                              Icon(Icons.router, size: 20),
                              SizedBox(width: 8),
                              Text('Port forwards'),
                            ],
                          ),
                        ),
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
                              Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                              const SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VmCreateScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New VM'),
      ),
    );
  }
}
