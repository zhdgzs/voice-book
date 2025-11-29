import 'dart:io';
import 'package:flutter/material.dart';
import 'package:voice_book/services/permission_service.dart';
import 'package:voice_book/services/file_scanner_service.dart';
import 'package:voice_book/services/audio_metadata_service.dart';

/// 文件扫描测试页面
///
/// 用于测试文件扫描服务的功能
class FileScannerTestScreen extends StatefulWidget {
  const FileScannerTestScreen({super.key});

  @override
  State<FileScannerTestScreen> createState() => _FileScannerTestScreenState();
}

class _FileScannerTestScreenState extends State<FileScannerTestScreen> {
  final _permissionService = PermissionService();
  final _scannerService = FileScannerService();

  bool _hasPermission = false;
  bool _isScanning = false;
  List<File> _scannedFiles = [];
  List<AudioMetadata> _metadataList = [];
  String _statusMessage = '准备就绪';
  int _scanProgress = 0;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  /// 检查权限状态
  Future<void> _checkPermission() async {
    final hasPermission = await _permissionService.checkStoragePermission();
    setState(() {
      _hasPermission = hasPermission;
      _statusMessage = hasPermission ? '已有存储权限' : '需要请求存储权限';
    });
  }

  /// 请求权限
  Future<void> _requestPermission() async {
    setState(() {
      _statusMessage = '正在请求权限...';
    });

    final granted = await _permissionService.requestStoragePermission();

    setState(() {
      _hasPermission = granted;
      _statusMessage = granted ? '权限已授予' : '权限被拒绝';
    });

    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('需要存储权限才能扫描音频文件'),
            action: SnackBarAction(
              label: '打开设置',
              onPressed: PermissionService().openSettings,
            ),
          ),
        );
      }
    }
  }

  /// 扫描常用目录
  Future<void> _scanCommonDirectories() async {
    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = '正在获取常用目录...';
      _scannedFiles.clear();
      _metadataList.clear();
      _scanProgress = 0;
    });

    try {
      // 获取常用目录
      final directories = await _scannerService.getCommonAudioDirectories();

      setState(() {
        _statusMessage = '找到 ${directories.length} 个目录，开始扫描...';
      });

      // 扫描目录
      final files = await _scannerService.scanMultipleDirectories(
        directories,
        recursive: true,
        onProgress: (count) {
          setState(() {
            _scanProgress = count;
            _statusMessage = '已扫描 $count 个音频文件...';
          });
        },
      );

      setState(() {
        _scannedFiles = files;
        _statusMessage = '扫描完成！找到 ${files.length} 个音频文件';
      });

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描完成！找到 ${files.length} 个音频文件')),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = '扫描失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// 读取元数据（快速模式，不加载封面）
  Future<void> _readMetadata() async {
    await _readMetadataInternal(loadCover: false);
  }

  /// 读取元数据（完整模式，包含封面）
  Future<void> _readMetadataWithCover() async {
    await _readMetadataInternal(loadCover: true);
  }

  /// 内部方法：读取元数据
  Future<void> _readMetadataInternal({required bool loadCover}) async {
    if (_scannedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先扫描音频文件')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = loadCover ? '正在读取元数据（含封面）...' : '正在读取元数据（快速模式）...';
      _metadataList.clear();
    });

    try {
      // 只读取前 10 个文件的元数据（避免耗时过长）
      final filesToRead = _scannedFiles.take(10).toList();

      final metadataList = loadCover
          ? await _scannerService.readMultipleMetadataWithCover(
              filesToRead,
              onProgress: (current, total) {
                setState(() {
                  _statusMessage = '正在读取元数据（含封面） $current/$total...';
                });
              },
            )
          : await _scannerService.readMultipleMetadata(
              filesToRead,
              onProgress: (current, total) {
                setState(() {
                  _statusMessage = '正在读取元数据 $current/$total...';
                });
              },
            );

      setState(() {
        _metadataList = metadataList;
        _statusMessage = '元数据读取完成！共 ${metadataList.length} 个文件'
            '${loadCover ? '，其中 ${metadataList.where((m) => m.hasCover).length} 个有封面' : ''}';
      });

      if (mounted) {
        final coverCount = _metadataList.where((m) => m.hasCover).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('元数据读取完成！共 ${_metadataList.length} 个文件'
                '${loadCover ? '，其中 $coverCount 个有封面' : ''}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = '读取元数据失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取元数据失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件扫描测试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkPermission,
            tooltip: '刷新权限状态',
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _hasPermission ? Icons.check_circle : Icons.warning,
                        color: _hasPermission ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (_isScanning) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!_hasPermission)
                        ElevatedButton.icon(
                          onPressed: _requestPermission,
                          icon: const Icon(Icons.security),
                          label: const Text('请求权限'),
                        ),
                      if (_hasPermission)
                        ElevatedButton.icon(
                          onPressed:
                              _isScanning ? null : _scanCommonDirectories,
                          icon: const Icon(Icons.search),
                          label: const Text('扫描音频文件'),
                        ),
                      if (_scannedFiles.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _isScanning ? null : _readMetadata,
                          icon: const Icon(Icons.info),
                          label: const Text('读取元数据（快速）'),
                        ),
                      if (_scannedFiles.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed:
                              _isScanning ? null : _readMetadataWithCover,
                          icon: const Icon(Icons.image),
                          label: const Text('读取元数据（含封面）'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 统计信息
          if (_scannedFiles.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '扫描结果',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text('找到音频文件: ${_scannedFiles.length} 个'),
                    Text('已读取元数据: ${_metadataList.length} 个'),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // 文件列表
          Expanded(
            child: _metadataList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.audio_file,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _scannedFiles.isEmpty
                              ? '点击"扫描音频文件"开始'
                              : '点击"读取元数据"查看详情',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _metadataList.length,
                    itemBuilder: (context, index) {
                      final metadata = _metadataList[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              metadata.hasCover ? Colors.blue : Colors.grey,
                          child: Icon(
                            metadata.hasCover ? Icons.image : Icons.music_note,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          metadata.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '作者: ${metadata.displayArtist}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '专辑: ${metadata.displayAlbum}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '时长: ${metadata.formattedDuration} | '
                              '大小: ${metadata.formattedFileSize}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _showFileDetails(metadata),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 格式化时长
  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// 显示文件详情
  void _showFileDetails(AudioMetadata metadata) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文件详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 封面图片（如果有）
              if (metadata.hasCover) ...[
                Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: MemoryImage(metadata.coverImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildDetailRow('标题', metadata.displayTitle),
              _buildDetailRow('作者', metadata.displayArtist),
              _buildDetailRow('专辑', metadata.displayAlbum),
              _buildDetailRow('时长', metadata.formattedDuration),
              _buildDetailRow('曲目编号', metadata.trackNumber?.toString()),
              _buildDetailRow('年份', metadata.year?.toString()),
              _buildDetailRow('流派', metadata.genre),
              _buildDetailRow('文件名', metadata.fileName),
              _buildDetailRow('文件大小', metadata.formattedFileSize),
              _buildDetailRow('封面', metadata.hasCover ? '有' : '无'),
              _buildDetailRow('文件路径', metadata.filePath, isPath: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String? value, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value ?? '未知',
            style: TextStyle(
              fontSize: isPath ? 10 : 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
