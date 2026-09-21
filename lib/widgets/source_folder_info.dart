import 'package:flutter/material.dart';

/// 只读展示书籍源目录。
class SourceFolderInfo extends StatelessWidget {
  final String? path;
  final String label;

  const SourceFolderInfo({
    super.key,
    required this.path,
    this.label = '存储目录',
  });

  @override
  Widget build(BuildContext context) {
    final displayPath = path == null || path!.isEmpty ? '未记录源目录' : path!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                displayPath,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
