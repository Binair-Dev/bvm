import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vm_list_provider.dart';
import '../constants.dart';
import 'terminal_screen.dart';
import 'vm_create_screen.dart';
import 'settings_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
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
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(Icons.terminal, color: Colors.white),
                    ),
                    title: Text(vm.name),
                    subtitle: Text('${vm.size} • Created ${vm.createdAt.toLocal().toString().split(' ').first}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.terminal),
                          tooltip: 'Open terminal',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TerminalScreen(vmName: vm.name),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete VM',
                          onPressed: () => _confirmDelete(context, vm),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TerminalScreen(vmName: vm.name),
                      ),
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
