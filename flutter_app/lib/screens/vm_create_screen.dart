import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preset.dart';
import '../providers/vm_setup_provider.dart';
import '../providers/vm_list_provider.dart';
import '../providers/preset_provider.dart';
import 'presets_screen.dart';

class VmCreateScreen extends StatefulWidget {
  const VmCreateScreen({super.key});

  @override
  State<VmCreateScreen> createState() => _VmCreateScreenState();
}

class _VmCreateScreenState extends State<VmCreateScreen> {
  final _controller = TextEditingController();
  Preset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VmSetupProvider>().reset();
      _controller.clear();
      setState(() => _selectedPreset = null);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: setup.status == SetupStatus.running || 
                 setup.status == SetupStatus.success || 
                 setup.status == SetupStatus.error
              ? _buildProgress(theme, setup)
              : _buildForm(theme, setup),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme, VmSetupProvider setup) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // VM Name
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      setup.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Preset Selection
          Text('Preset (Optional)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Choose a preset to auto-install tools and configure your VM',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _buildPresetSelector(theme),
          
          const SizedBox(height: 32),
          
          // Create Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => _create(setup),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(_selectedPreset != null 
                ? 'Create with ${_selectedPreset!.name}'
                : 'Create Minimal Ubuntu VM'
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Center(
            child: Text(
              'This will download ~300MB of Ubuntu rootfs',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSelector(ThemeData theme) {
    return Consumer<PresetProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Selected preset or "None"
            Card(
              child: ListTile(
                leading: _selectedPreset != null 
                  ? _buildPresetIcon(_selectedPreset!.category)
                  : const CircleAvatar(child: Icon(Icons.computer)),
                title: Text(_selectedPreset?.name ?? 'Minimal (No preset)'),
                subtitle: Text(_selectedPreset?.description ?? 'Clean Ubuntu installation'),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _showPresetPicker(context, provider),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Quick actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PresetsScreen()),
                    );
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Manage Presets'),
                ),
                if (_selectedPreset != null) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedPreset = null),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPresetIcon(String category) {
    final icon = switch (category) {
      'base' => Icons.computer,
      'devops' => Icons.cloud,
      'ai' => Icons.smart_toy,
      'development' => Icons.code,
      'security' => Icons.security,
      _ => Icons.folder,
    };
    return CircleAvatar(child: Icon(icon));
  }

  void _showPresetPicker(BuildContext context, PresetProvider provider) {
    final presets = provider.presets;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Choose a Preset',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: presets.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Minimal option
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.computer)),
                      title: const Text('Minimal'),
                      subtitle: const Text('Clean Ubuntu, no extras'),
                      trailing: _selectedPreset == null 
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                      onTap: () {
                        setState(() => _selectedPreset = null);
                        Navigator.pop(context);
                      },
                    );
                  }
                  
                  final preset = presets[index - 1];
                  final isSelected = _selectedPreset?.id == preset.id;
                  
                  return ListTile(
                    leading: _buildPresetIcon(preset.category),
                    title: Text(preset.name),
                    subtitle: Text('${preset.commands.length} commands • ${preset.description}'),
                    trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                    onTap: () {
                      setState(() => _selectedPreset = preset);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(ThemeData theme, VmSetupProvider setup) {
    final bool isRunning = setup.status == SetupStatus.running;
    final bool isSuccess = setup.status == SetupStatus.success;
    final bool isError = setup.status == SetupStatus.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        if (isRunning) ...[
          LinearProgressIndicator(value: setup.progress > 0 ? setup.progress : null),
          const SizedBox(height: 16),
          Text(
            'Step ${setup.currentStep}/${setup.totalSteps}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            setup.currentStepLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        
        if (isSuccess) ...[
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 64),
                const SizedBox(height: 16),
                Text(
                  'VM "${setup.vmName}" ready!',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedPreset != null
                    ? '${_selectedPreset!.name} installed successfully'
                    : 'Minimal Ubuntu installed',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
        
        if (isError) ...[
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Creation Failed',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  setup.error ?? 'Unknown error',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 24),
        
        // Logs
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                setup.logText.isEmpty 
                  ? 'Initializing...' 
                  : setup.logText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Actions
        if (isSuccess || isError)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (isSuccess) {
                  context.read<VmListProvider>().loadVms();
                  Navigator.pop(context);
                } else {
                  setup.reset();
                  _controller.clear();
                  setState(() => _selectedPreset = null);
                }
              },
              child: Text(isSuccess ? 'Go to VMs' : 'Try Again'),
            ),
          ),
      ],
    );
  }

  void _create(VmSetupProvider setup) {
    final name = _controller.text.trim();
    setup.createVm(name, preset: _selectedPreset);
  }
}
