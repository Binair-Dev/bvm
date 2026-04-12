import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import '../services/native_bridge.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _loading = false;
  String _status = 'Base Ubuntu rootfs is required before creating VMs.';
  double _progress = 0.0;

  Future<void> _install() async {
    setState(() {
      _loading = true;
      _status = 'Downloading Ubuntu rootfs...';
      _progress = 0.0;
    });

    try {
      final arch = await NativeBridge.getArch();
      final url = AppConstants.getRootfsUrl(arch);
      final tempDir = await getTemporaryDirectory();
      final tarPath = '${tempDir.path}/ubuntu-rootfs.tar.gz';

      final dio = Dio();
      await dio.download(
        url,
        tarPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _progress = received / total;
              _status = 'Downloading... ${(_progress * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );

      setState(() {
        _status = 'Extracting rootfs...';
        _progress = -1;
      });

      final ok = await NativeBridge.extractRootfs(tarPath);
      if (ok) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _loading = false;
          _status = 'Extraction failed.';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.cloud_download, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Welcome to bVM',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (_loading && _progress >= 0) ...[
                const SizedBox(height: 24),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text('${(_progress * 100).toStringAsFixed(0)}%'),
              ] else if (_loading) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _install,
                  child: const Text('Install Ubuntu Base'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Downloads ~300MB. Requires stable internet.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
