import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/file_extensions.dart';
import '../../providers/service_providers.dart';
import '../../providers/transfer_providers.dart';

/// Screen for selecting files to send to a peer device.
class FilePickerScreen extends ConsumerStatefulWidget {
  final String peerName;
  final String peerAddress;
  final int peerPort;
  final String? peerId;

  const FilePickerScreen({
    super.key,
    required this.peerName,
    required this.peerAddress,
    this.peerPort = 9876,
    this.peerId,
  });

  @override
  ConsumerState<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends ConsumerState<FilePickerScreen> {
  bool _isSending = false;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final paths = result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();

        ref.read(selectedFilesProvider.notifier).state = paths;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件出错: $e')),
        );
      }
    }
  }

  Future<void> _sendFiles() async {
    final files = ref.read(selectedFilesProvider);
    if (files.isEmpty) return;

    setState(() => _isSending = true);

    final transferService = ref.read(transferServiceProvider);

    try {
      for (final filePath in files) {
        await transferService.sendFile(
          filePath: filePath,
          peerAddress: widget.peerAddress,
          peerDataPort: widget.peerPort,
          peerName: widget.peerName,
          peerId: widget.peerId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${files.length} 个文件发送成功！')),
        );
        ref.read(selectedFilesProvider.notifier).state = [];
        context.go('/transfers');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _removeFile(int index) {
    final files = [...ref.read(selectedFilesProvider)];
    files.removeAt(index);
    ref.read(selectedFilesProvider.notifier).state = files;
  }

  @override
  Widget build(BuildContext context) {
    final selectedFiles = ref.watch(selectedFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('发送给 ${widget.peerName}'),
      ),
      body: Column(
        children: [
          // Selected files section
          Expanded(
            child: selectedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '选择要发送的文件',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '给 ${widget.peerName}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add),
                          label: const Text('选择文件'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...List.generate(selectedFiles.length, (index) {
                        final path = selectedFiles[index];
                        final fileName = path.split('/').last.split('\\').last;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(fileName),
                            subtitle: Text(fileName.mimeType),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _removeFile(index),
                            ),
                          ),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add),
                          label: const Text('添加更多文件'),
                        ),
                      ),
                    ],
                  ),
          ),

          // Send button
          if (selectedFiles.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '已选择 ${selectedFiles.length} 个文件',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSending ? null : _sendFiles,
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(_isSending ? '发送中...' : '发送文件'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
