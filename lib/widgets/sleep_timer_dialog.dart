import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sleep_timer.dart';
import '../providers/sleep_timer_provider.dart';

/// 睡眠定时器对话框
///
/// 提供两种定时模式：
/// 1. 按分钟定时：设置倒计时分钟数
/// 2. 按集数定时：设置播放完指定集数后停止
class SleepTimerDialog extends StatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  SleepTimerMode _selectedMode = SleepTimerMode.minutes;
  int _selectedMinutes = 15;
  int _selectedEpisodes = 1;

  // 自定义输入控制器
  final TextEditingController _customMinutesController = TextEditingController();
  final TextEditingController _customEpisodesController = TextEditingController();

  // 预设的分钟选项
  final List<int> _minuteOptions = [5, 10, 15, 20, 30, 45, 60, 90, 120];

  // 预设的集数选项
  final List<int> _episodeOptions = [1, 2, 3, 5, 10];

  @override
  void dispose() {
    _customMinutesController.dispose();
    _customEpisodesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sleepTimerProvider = context.watch<SleepTimerProvider>();
    final isActive = sleepTimerProvider.isActive;

    return AlertDialog(
      title: const Text('睡眠定时器'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前定时器状态
            if (isActive) _buildActiveTimerStatus(sleepTimerProvider),

            // 模式选择
            if (!isActive) ...[
              Text(
                '定时模式',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildModeSelector(),
              const SizedBox(height: 24),

              // 根据模式显示不同的选项
              if (_selectedMode == SleepTimerMode.minutes)
                _buildMinutesSelector()
              else
                _buildEpisodesSelector(),
            ],
          ],
        ),
      ),
      actions: [
        // 取消按钮
        if (!isActive)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),

        // 取消定时器按钮
        if (isActive)
          TextButton(
            onPressed: () {
              sleepTimerProvider.cancelTimer();
              Navigator.pop(context);
            },
            child: const Text('取消定时器'),
          ),

        // 延长定时器按钮（仅在按分钟模式下显示）
        if (isActive && sleepTimerProvider.mode == SleepTimerMode.minutes)
          TextButton(
            onPressed: () {
              sleepTimerProvider.extendTimer(5);
            },
            child: const Text('延长 5 分钟'),
          ),

        // 启动定时器按钮
        if (!isActive)
          FilledButton(
            onPressed: () {
              if (_selectedMode == SleepTimerMode.minutes) {
                sleepTimerProvider.startMinutesTimer(_selectedMinutes);
              } else {
                sleepTimerProvider.startEpisodesTimer(_selectedEpisodes);
              }
              Navigator.pop(context);
            },
            child: const Text('启动'),
          ),

        // 关闭按钮
        if (isActive)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
      ],
    );
  }

  /// 构建激活状态的定时器信息
  Widget _buildActiveTimerStatus(SleepTimerProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.timer,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '定时器运行中',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.remainingTimeString,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            provider.mode == SleepTimerMode.minutes ? '剩余时间' : '剩余集数',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建模式选择器
  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeOption(
            mode: SleepTimerMode.minutes,
            icon: Icons.access_time,
            label: '按分钟',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildModeOption(
            mode: SleepTimerMode.episodes,
            icon: Icons.playlist_play,
            label: '按集数',
          ),
        ),
      ],
    );
  }

  /// 构建单个模式选项
  Widget _buildModeOption({
    required SleepTimerMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建分钟选择器
  Widget _buildMinutesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择时长',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _minuteOptions.map((minutes) {
            final isSelected = _selectedMinutes == minutes;
            return ChoiceChip(
              label: Text('$minutes 分钟'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedMinutes = minutes;
                    _customMinutesController.clear();
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 自定义输入框
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customMinutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '自定义分钟数',
                  hintText: '输入 1-999',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  final customMinutes = int.tryParse(value);
                  if (customMinutes != null && customMinutes > 0 && customMinutes <= 999) {
                    setState(() {
                      _selectedMinutes = customMinutes;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '分钟',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ],
    );
  }

  /// 构建集数选择器
  Widget _buildEpisodesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择集数',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _episodeOptions.map((episodes) {
            final isSelected = _selectedEpisodes == episodes;
            return ChoiceChip(
              label: Text('$episodes 集'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedEpisodes = episodes;
                    _customEpisodesController.clear();
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 自定义输入框
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customEpisodesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '自定义集数',
                  hintText: '输入 1-99',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  final customEpisodes = int.tryParse(value);
                  if (customEpisodes != null && customEpisodes > 0 && customEpisodes <= 99) {
                    setState(() {
                      _selectedEpisodes = customEpisodes;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '集',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '播放完指定集数后自动停止',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
