import 'package:flutter/material.dart';
import '../providers/file_sharing_provider.dart';

class FileListTile extends StatelessWidget {
  final FileItem file;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FileListTile({
    super.key,
    required this.file,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        file.isDirectory ? Icons.folder : _getFileIcon(file.name),
        color: file.isDirectory ? Colors.amber : theme.colorScheme.primary,
      ),
      title: Text(file.name),
      subtitle: Text(
        '${file.formattedSize} · ${file.permissions}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: file.isDirectory
          ? const Icon(Icons.chevron_right)
          : IconButton(
              icon: const Icon(Icons.download),
              onPressed: onLongPress,
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  IconData _getFileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.gif')) {
      return Icons.image;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.avi') || lower.endsWith('.mkv')) {
      return Icons.movie;
    }
    if (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.ogg')) {
      return Icons.music_note;
    }
    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.tar') || lower.endsWith('.gz')) {
      return Icons.folder_zip;
    }
    if (lower.endsWith('.txt') || lower.endsWith('.md') || lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description;
    }
    if (lower.endsWith('.dart') || lower.endsWith('.py') || lower.endsWith('.js') || lower.endsWith('.kt') || lower.endsWith('.java') || lower.endsWith('.cpp') || lower.endsWith('.c') || lower.endsWith('.go') || lower.endsWith('.rs')) {
      return Icons.code;
    }
    return Icons.insert_drive_file;
  }
}
