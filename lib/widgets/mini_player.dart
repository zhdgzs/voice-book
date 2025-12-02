import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_player_provider.dart';
import '../main.dart';

/// 迷你播放器组件
///
/// 显示在主页右下角的悬浮播放器，包括：
/// - 正在播放的音频标题（滚动显示）
/// - 播放/暂停状态图标
/// - 点击跳转到完整播放页面
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerProvider>(
      builder: (context, playerProvider, child) {
        if (playerProvider.currentAudioFile == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            MainScreen.openPlayer(
              context,
              audioFile: playerProvider.currentAudioFile!,
            );
          },
          child: Container(
            width: 200,
            height: 56,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // 播放/暂停按钮
                IconButton(
                  icon: Icon(
                    playerProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  onPressed: () {
                    if (playerProvider.isPlaying) {
                      playerProvider.pause();
                    } else {
                      playerProvider.play();
                    }
                  },
                ),
                // 标题（滚动显示）
                Expanded(
                  child: _ScrollingText(
                    text: playerProvider.currentAudioFile!.fileName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 滚动文本组件
class _ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _ScrollingText({
    required this.text,
    this.style,
  });

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNeedsScroll();
    });
  }

  @override
  void didUpdateWidget(_ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scrollController.jumpTo(0);
      _animationController.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfNeedsScroll();
      });
    }
  }

  void _checkIfNeedsScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      setState(() {
        _needsScroll = maxScroll > 0;
      });

      if (_needsScroll) {
        _startScrolling();
      }
    }
  }

  void _startScrolling() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    _animationController.repeat(reverse: true);
    _animationController.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(maxScroll * _animationController.value);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.visible,
      ),
    );
  }
}
