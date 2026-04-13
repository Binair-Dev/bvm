import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/preset.dart';
import '../providers/preset_provider.dart';

class PresetsScreen extends StatelessWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VM Presets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _showImportDialog(context),
            tooltip: 'Import Preset',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreatePresetDialog(context),
            tooltip: 'Create Preset',
          ),
        ],
      ),
      body: Consumer<PresetProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final builtIn = provider.builtInPresets;
          final custom = provider.customPresets;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (builtIn.isNotEmpty) ...[
                _buildSectionHeader(context, 'Built-in Presets', Icons.auto_awesome),
                ...builtIn.map((p) => _PresetCard(preset: p, isCustom: false)),
                const SizedBox(height: 24),
              ],
              if (custom.isNotEmpty) ...[
                _buildSectionHeader(context, 'Custom Presets', Icons.build),
                ...custom.map((p) => _PresetCard(preset: p, isCustom: true)),
              ] else ...[
                _buildEmptyState(context),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No custom presets yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first preset',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showCreatePresetDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreatePresetScreen()),
    );
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Preset'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Paste preset JSON here...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final json = controller.text.trim();
              if (json.isEmpty) return;
              final provider = context.read<PresetProvider>();
              final imported = await provider.importPresetFromJson(json);
              Navigator.pop(context);
              if (imported != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Imported "${imported.name}"')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid preset JSON')),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final Preset preset;
  final bool isCustom;

  const _PresetCard({required this.preset, required this.isCustom});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showPresetDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildCategoryIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.category.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _exportPreset(context),
                    tooltip: 'Export Preset',
                  ),
                  if (isCustom)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                preset.description,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${preset.commands.length} command${preset.commands.length > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon() {
    final icon = switch (preset.category) {
      'base' => Icons.computer,
      'devops' => Icons.cloud,
      'ai' => Icons.smart_toy,
      'development' => Icons.code,
      'security' => Icons.security,
      _ => Icons.folder,
    };

    return CircleAvatar(
      child: Icon(icon),
    );
  }

  void _showPresetDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  preset.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  preset.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Text(
                  'Commands (${preset.commands.length}):',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...preset.commands.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _exportPreset(BuildContext context) {
    final provider = context.read<PresetProvider>();
    final json = provider.exportPresetToJson(preset);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preset "${preset.name}" copied to clipboard')),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset?'),
        content: Text('Delete "${preset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<PresetProvider>().deleteCustomPreset(preset.id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class CreatePresetScreen extends StatefulWidget {
  const CreatePresetScreen({super.key});

  @override
  State<CreatePresetScreen> createState() => _CreatePresetScreenState();
}

class _CreatePresetScreenState extends State<CreatePresetScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _commandController = TextEditingController();
  String _category = 'custom';

  final List<String> _commands = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Preset'),
        actions: [
          TextButton(
            onPressed: _savePreset,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                hintText: 'e.g. My Dev Stack',
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What does this preset install?',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.folder),
              ),
              items: const [
                DropdownMenuItem(value: 'custom', child: Text('Custom')),
                DropdownMenuItem(value: 'base', child: Text('Base System')),
                DropdownMenuItem(value: 'devops', child: Text('DevOps')),
                DropdownMenuItem(value: 'ai', child: Text('AI/ML')),
                DropdownMenuItem(value: 'development', child: Text('Development')),
                DropdownMenuItem(value: 'security', child: Text('Security')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Commands',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. apt install -y docker.io',
                      prefixIcon: Icon(Icons.terminal),
                    ),
                    onSubmitted: (_) => _addCommand(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addCommand,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._commands.asMap().entries.map((entry) {
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${entry.key + 1}'),
                  ),
                  title: Text(
                    entry.value,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _commands.removeAt(entry.key)),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _addCommand() {
    final cmd = _commandController.text.trim();
    if (cmd.isNotEmpty) {
      setState(() {
        _commands.add(cmd);
        _commandController.clear();
      });
    }
  }

  void _savePreset() {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a preset name')),
      );
      return;
    }
    if (_commands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one command')),
      );
      return;
    }

    final preset = Preset(
      id: const Uuid().v4(),
      name: name,
      description: desc.isEmpty ? 'Custom preset' : desc,
      category: _category,
      commands: List.from(_commands),
      isBuiltIn: false,
    );

    context.read<PresetProvider>().addCustomPreset(preset);
    Navigator.pop(context);
  }
}
