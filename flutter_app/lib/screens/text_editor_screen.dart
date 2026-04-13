import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:provider/provider.dart';
import '../providers/text_editor_provider.dart';

class TextEditorScreen extends StatefulWidget {
  final String vmName;
  final String filePath;

  const TextEditorScreen({
    super.key,
    required this.vmName,
    required this.filePath,
  });

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _textController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFile();
    });
  }

  Future<void> _loadFile() async {
    final provider = context.read<TextEditorProvider>();
    await provider.loadFile(widget.vmName, widget.filePath);
    _textController.text = provider.content;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveFile() async {
    final provider = context.read<TextEditorProvider>();
    final success = await provider.saveFile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'File saved' : 'Failed to save'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    final provider = context.read<TextEditorProvider>();
    if (!provider.hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Do you want to save before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _saveFile();
      return true;
    } else if (result == false) {
      return true;
    }
    return false;
  }

  String _detectLanguage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const map = {
      'dart': 'dart',
      'py': 'python',
      'js': 'javascript',
      'ts': 'typescript',
      'json': 'json',
      'yaml': 'yaml',
      'yml': 'yaml',
      'xml': 'xml',
      'html': 'html',
      'css': 'css',
      'scss': 'scss',
      'md': 'markdown',
      'sh': 'bash',
      'bash': 'bash',
      'zsh': 'bash',
      'c': 'c',
      'cpp': 'cpp',
      'h': 'cpp',
      'java': 'java',
      'kt': 'kotlin',
      'swift': 'swift',
      'go': 'go',
      'rs': 'rust',
      'rb': 'ruby',
      'php': 'php',
      'sql': 'sql',
      'dockerfile': 'dockerfile',
      'tf': 'terraform',
    };
    return map[ext] ?? 'plaintext';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Consumer<TextEditorProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Scaffold(
              appBar: AppBar(title: Text(provider.fileName)),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text('${provider.fileName}${provider.hasUnsavedChanges ? " *" : ""}'),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.edit), text: 'Edit'),
                  Tab(icon: Icon(Icons.preview), text: 'Preview'),
                ],
              ),
              actions: [
                if (provider.isSaving)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: provider.hasUnsavedChanges ? _saveFile : null,
                    tooltip: 'Save',
                  ),
              ],
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                // Edit tab
                _buildEditTab(provider, isDark),
                // Preview tab
                _buildPreviewTab(provider, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditTab(TextEditorProvider provider, bool isDark) {
    return Column(
      children: [
        if (provider.error != null)
          Container(
            width: double.infinity,
            color: Colors.red,
            padding: const EdgeInsets.all(8),
            child: Text(
              provider.error!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        Expanded(
          child: TextField(
            controller: _textController,
            onChanged: provider.updateContent,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: 'DejaVuSansMono',
              fontSize: 13,
            ),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
              hintText: 'Start typing...',
            ),
            keyboardType: TextInputType.multiline,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTab(TextEditorProvider provider, bool isDark) {
    final language = _detectLanguage(provider.fileName);
    
    if (language == 'plaintext') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          provider.content,
          style: const TextStyle(
            fontFamily: 'DejaVuSansMono',
            fontSize: 13,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HighlightView(
        provider.content,
        language: language,
        theme: isDark ? atomOneDarkTheme : githubTheme,
        padding: const EdgeInsets.all(12),
        textStyle: const TextStyle(
          fontFamily: 'DejaVuSansMono',
          fontSize: 13,
        ),
      ),
    );
  }
}
