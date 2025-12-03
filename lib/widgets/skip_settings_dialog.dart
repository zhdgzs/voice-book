import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../providers/book_provider.dart';
import '../providers/audio_player_provider.dart';

/// 跳过设置对话框
///
/// 用于设置书籍的跳过开头和结尾时长
/// 可在书籍详情页和播放页复用
class SkipSettingsDialog extends StatefulWidget {
  /// 书籍ID
  final int bookId;

  /// 是否在播放页调用（播放页需要立即应用跳过设置）
  final bool isFromPlayer;

  const SkipSettingsDialog({
    super.key,
    required this.bookId,
    this.isFromPlayer = false,
  });

  @override
  State<SkipSettingsDialog> createState() => _SkipSettingsDialogState();
}

class _SkipSettingsDialogState extends State<SkipSettingsDialog> {
  Book? _currentBook;
  int _skipStartSeconds = 0;
  int _skipEndSeconds = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookInfo();
  }

  /// 加载书籍信息
  Future<void> _loadBookInfo() async {
    final bookProvider = context.read<BookProvider>();
    final book = await bookProvider.getBookById(widget.bookId);

    if (book != null && mounted) {
      setState(() {
        _currentBook = book;
        _skipStartSeconds = book.skipStartSeconds;
        _skipEndSeconds = book.skipEndSeconds;
        _isLoading = false;
      });

      debugPrint('📖 加载跳过设置 - 书籍: ${book.title}, 跳过开头: ${book.skipStartSeconds}秒, 跳过结尾: ${book.skipEndSeconds}秒');
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 保存跳过设置
  Future<void> _saveSettings() async {
    if (_currentBook == null) return;

    debugPrint('💾 保存跳过设置 - 跳过开头: $_skipStartSeconds秒, 跳过结尾: $_skipEndSeconds秒');

    final bookProvider = context.read<BookProvider>();
    final updatedBook = _currentBook!.copyWith(
      skipStartSeconds: _skipStartSeconds,
      skipEndSeconds: _skipEndSeconds,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final success = await bookProvider.updateBook(updatedBook);
    debugPrint('💾 数据库更新结果: $success');

    if (!mounted) return;

    if (success) {
      // 如果是从播放页调用，需要重新加载书籍信息到播放器
      if (widget.isFromPlayer) {
        final audioPlayer = context.read<AudioPlayerProvider>();
        await audioPlayer.loadBookProgress(widget.bookId);
        debugPrint('✅ 已重新加载书籍信息到播放器');

        // 应用新的跳过设置：如果当前位置在跳过开头范围内，则跳到跳过开头的位置
        if (_skipStartSeconds > 0 && audioPlayer.position < _skipStartSeconds * 1000) {
          debugPrint('⏭️ 应用新的跳过开头设置: $_skipStartSeconds秒');
          await audioPlayer.seek(_skipStartSeconds * 1000);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('跳过设置已更新')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('跳过设置更新失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_currentBook == null) {
      return AlertDialog(
        title: const Text('错误'),
        content: const Text('未找到书籍信息'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('跳过设置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '为《${_currentBook!.title}》设置跳过开头和结尾的时长',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // 跳过开头
            Text(
              '跳过开头: ${_skipStartSeconds == 0 ? '不跳过' : '$_skipStartSeconds 秒'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _skipStartSeconds.toDouble(),
              min: 0,
              max: 120,
              divisions: 120,
              label: _skipStartSeconds == 0 ? '不跳过' : '$_skipStartSeconds秒',
              onChanged: (value) {
                setState(() {
                  _skipStartSeconds = value.toInt();
                });
              },
            ),
            const SizedBox(height: 16),
            // 跳过结尾
            Text(
              '跳过结尾: ${_skipEndSeconds == 0 ? '不跳过' : '$_skipEndSeconds 秒'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _skipEndSeconds.toDouble(),
              min: 0,
              max: 120,
              divisions: 120,
              label: _skipEndSeconds == 0 ? '不跳过' : '$_skipEndSeconds秒',
              onChanged: (value) {
                setState(() {
                  _skipEndSeconds = value.toInt();
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _saveSettings,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
