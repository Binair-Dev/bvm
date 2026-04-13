import 'package:flutter/material.dart';
import '../providers/backup_provider.dart';

class BackupProgressDialog extends StatefulWidget {
  final String title;
  final Future<dynamic> Function(Function(BackupProgress)) onStart;

  const BackupProgressDialog({
    super.key,
    required this.title,
    required this.onStart,
  });

  @override
  State<BackupProgressDialog> createState() => _BackupProgressDialogState();
}

class _BackupProgressDialogState extends State<BackupProgressDialog> {
  BackupProgress _progress = BackupProgress();
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    dynamic result;
    try {
      result = await widget.onStart((p) {
        if (mounted) {
          setState(() {
            _progress = p;
            if (p.isComplete) _done = true;
            if (p.error != null) {
              _error = p.error;
              _done = true;
            }
          });
        }
      });
    } catch (e) {
      result = false;
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) {
      setState(() => _done = true);
      if (result != null && result != false && _error == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => _done,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error == null) ...[
              LinearProgressIndicator(
                value: _progress.percent / 100,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 12),
              Text(
                '${_progress.percent.toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(_progress.message, style: theme.textTheme.bodySmall),
            ] else ...[
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 12),
              Text('Backup failed', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 4),
              Text(_error!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _done ? () => Navigator.of(context).pop(_error == null) : null,
            child: Text(_error == null ? (_done ? 'Done' : 'Please wait...') : 'Close'),
          ),
        ],
      ),
    );
  }
}
