import 'package:flutter/material.dart';
import '../models/audio_file.dart';

/// 显示完整的音频文件名和路径。
Future<void> showAudioFileDetails(
  BuildContext context,
  AudioFile audioFile,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('音频文件信息'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SelectableInfo(label: '文件名', value: audioFile.fileName),
            const SizedBox(height: 16),
            _SelectableInfo(label: '文件路径', value: audioFile.filePath),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

class _SelectableInfo extends StatelessWidget {
  final String label;
  final String value;

  const _SelectableInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    );
  }
}
