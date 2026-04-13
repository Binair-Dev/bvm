import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_sharing_provider.dart';
import '../providers/text_editor_provider.dart';
import '../widgets/file_list_tile.dart';
import 'text_editor_screen.dart';

class VmFilesScreen extends StatefulWidget {
  final String vmName;

  const VmFilesScreen({super.key, required this.vmName});

  @override
  State<VmFilesScreen> createState() => _VmFilesScreenState();
}

class _VmFilesScreenState extends State<VmFilesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  Future<void> _initialize() async {
    final provider = context.read<FileSharingProvider>();
    await provider.setupSharedDir(widget.vmName);
    await provider.loadSharedFiles(widget.vmName);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _uploadFile() async {
    final provider = context.read<FileSharingProvider>();
    final success = await provider.uploadFile(widget.vmName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'File uploaded' : 'Upload failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Files: ${widget.vmName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder_shared), text: 'Shared'),
            Tab(icon: Icon(Icons.computer), text: 'VM Explorer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SharedTab(vmName: widget.vmName, onUpload: _uploadFile),
          _VmExplorerTab(vmName: widget.vmName),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _uploadFile,
              tooltip: 'Upload file',
              child: const Icon(Icons.upload_file),
            )
          : null,
    );
  }
}

class _SharedTab extends StatelessWidget {
  final String vmName;
  final VoidCallback onUpload;

  const _SharedTab({required this.vmName, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Consumer<FileSharingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.sharedFiles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${provider.error}'),
                ElevatedButton(
                  onPressed: () => provider.loadSharedFiles(vmName),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.sharedFiles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No shared files yet'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload file'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadSharedFiles(vmName),
          child: ListView.builder(
            itemCount: provider.sharedFiles.length,
            itemBuilder: (context, index) {
              final file = provider.sharedFiles[index];
              return FileListTile(
                file: file,
                onTap: () {
                  if (file.isDirectory) {
                    // Navigate to subdirectory
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _VmExplorerTab extends StatefulWidget {
  final String vmName;

  const _VmExplorerTab({required this.vmName});

  @override
  State<_VmExplorerTab> createState() => _VmExplorerTabState();
}

class _VmExplorerTabState extends State<_VmExplorerTab> {
  @override
  void initState() {
    super.initState();
    _loadDirectory('/');
  }

  Future<void> _loadDirectory(String path) async {
    final provider = context.read<FileSharingProvider>();
    await provider.loadVmDirectory(widget.vmName, path);
  }

  Future<void> _downloadFile(FileItem file) async {
    final provider = context.read<FileSharingProvider>();
    final success = await provider.downloadFile(
      file.path,
      file.isDirectory ? '${file.name}.zip' : file.name,
      file.isDirectory,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Downloaded ${file.name}' : 'Download failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FileSharingProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Breadcrumb
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.home),
                    onPressed: provider.currentPath == '/'
                        ? null
                        : () => _loadDirectory('/'),
                  ),
                  Expanded(
                    child: Text(
                      provider.currentPath,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (provider.currentPath != '/')
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: () {
                        final parent = provider.currentPath.split('/').where((s) => s.isNotEmpty).toList()..removeLast();
                        _loadDirectory(parent.isEmpty ? '/' : '/${parent.join('/')}/');
                      },
                    ),
                ],
              ),
            ),
            // File list
            Expanded(
              child: provider.isLoading && provider.vmFiles.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error: ${provider.error}'),
                              ElevatedButton(
                                onPressed: () => _loadDirectory(provider.currentPath),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadDirectory(provider.currentPath),
                          child: ListView.builder(
                            itemCount: provider.vmFiles.length,
                            itemBuilder: (context, index) {
                              final file = provider.vmFiles[index];
                              return FileListTile(
                                file: file,
                                onTap: () {
                                  if (file.isDirectory) {
                                    _loadDirectory(file.path);
                                  }
                                },
                                onLongPress: () => _showFileActions(file),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  bool _isTextFile(String fileName) {
    final textExtensions = {
      'txt', 'md', 'json', 'yaml', 'yml', 'xml', 'html', 'css', 'scss',
      'js', 'ts', 'dart', 'py', 'java', 'kt', 'swift', 'go', 'rs', 'rb',
      'php', 'sql', 'sh', 'bash', 'zsh', 'c', 'cpp', 'h', 'hpp',
      'dockerfile', 'tf', 'ini', 'conf', 'config', 'log', 'csv',
      'gitignore', 'env', 'properties', 'gradle', 'plist',
    };
    final ext = fileName.split('.').last.toLowerCase();
    return textExtensions.contains(ext);
  }

  void _editFile(FileItem file) {
    context.read<TextEditorProvider>().clear();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextEditorScreen(
          vmName: widget.vmName,
          filePath: file.path,
        ),
      ),
    );
  }

  void _showFileActions(FileItem file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!file.isDirectory && _isTextFile(file.name))
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editFile(file);
                },
              ),
            ListTile(
              leading: Icon(file.isDirectory ? Icons.folder_zip : Icons.download),
              title: Text(file.isDirectory ? 'Download as ZIP' : 'Download'),
              onTap: () {
                Navigator.pop(context);
                _downloadFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Properties'),
              subtitle: Text('Size: ${file.formattedSize}\nPermissions: ${file.permissions}'),
            ),
          ],
        ),
      ),
    );
  }
}
