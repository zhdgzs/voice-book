import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/permission_service.dart';
import '../services/file_scanner_service.dart';
import '../providers/book_provider.dart';
import '../models/book.dart';
import '../models/audio_file.dart';

/// 文件导入页面
///
/// 新的导入流程：
/// 1. 用户选择文件夹
/// 2. 扫描该文件夹下的音频文件
/// 3. 将所有音频文件作为一本书籍导入
/// 4. 书籍名称默认为文件夹名，可修改
class FileImportScreen extends StatefulWidget {
  const FileImportScreen({super.key});

  @override
  State<FileImportScreen> createState() => _FileImportScreenState();
}

class _FileImportScreenState extends State<FileImportScreen> {
  final _permissionService = PermissionService();
  final _scannerService = FileScannerService();
  final _bookNameController = TextEditingController();
  final _authorController = TextEditingController();

  bool _hasPermission = false;
  bool _isScanning = false;
  bool _recursiveScan = true; // 默认开启递归扫描
  String? _selectedFolderPath;
  List<File> _scannedFiles = [];
  String _statusMessage = '准备就绪';

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _bookNameController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  /// 检查权限状态
  Future<void> _checkPermission() async {
    final hasPermission = await _permissionService.checkStoragePermission();
    setState(() {
      _hasPermission = hasPermission;
      _statusMessage = hasPermission ? '已有存储权限，请选择文件夹' : '需要请求存储权限';
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
      _statusMessage = granted ? '权限已授予，请选择文件夹' : '权限被拒绝';
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

  /// 选择文件夹
  Future<void> _pickFolder() async {
    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) return;
    }

    try {
      // 使用文件选择器选择目录
      final result = await FilePicker.platform.getDirectoryPath();

      if (result != null) {
        final folderName = result.split(Platform.pathSeparator).last;

        // 立即显示 loading 状态
        setState(() {
          _isScanning = true;
          _selectedFolderPath = result;
          _bookNameController.text = folderName;
          _statusMessage = '准备扫描文件夹: $folderName';
          _scannedFiles.clear();
        });

        // 等待下一帧让 UI 刷新显示 loading，然后开始扫描
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scanFolder();
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件夹失败: $e')),
        );
      }
    }
  }

  /// 扫描文件夹
  Future<void> _scanFolder() async {
    if (_selectedFolderPath == null) return;

    // 更新状态消息（loading 已经在 _pickFolder 中显示）
    setState(() {
      _statusMessage = '正在扫描文件夹...';
    });

    try {
      // 扫描文件夹（根据用户选择决定是否递归）
      final files = await _scannerService.scanDirectory(
        _selectedFolderPath!,
        recursive: _recursiveScan,
        onProgress: (count) {
          setState(() {
            _statusMessage = '已找到 $count 个音频文件...';
          });
        },
      );

      setState(() {
        _scannedFiles = files;
        _statusMessage = '扫描完成！找到 ${files.length} 个音频文件';
      });

      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该文件夹中没有找到音频文件')),
          );
        }
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

  /// 导入书籍
  Future<void> _importBook() async {
    if (_scannedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导入的音频文件')),
      );
      return;
    }

    final bookName = _bookNameController.text.trim();
    if (bookName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入书籍名称')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = '正在读取音频信息 (0/${_scannedFiles.length})...';
    });

    try {
      final bookProvider = context.read<BookProvider>();

      // 读取所有音频文件的元数据
      final metadataList = await _scannerService.readMultipleMetadata(
        _scannedFiles,
        onProgress: (current, total) {
          setState(() {
            _statusMessage = '正在读取音频信息 ($current/$total)...';
          });
        },
      );

      // 计算总时长
      int totalDuration = 0;
      for (final metadata in metadataList) {
        totalDuration += metadata.duration ?? 0;
      }

      setState(() {
        _statusMessage = '正在创建书籍...';
      });

      // 创建书籍
      final book = Book(
        title: bookName,
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        totalDuration: totalDuration,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final createdBook = await bookProvider.createBook(book);
      if (createdBook == null) {
        throw Exception('创建书籍失败');
      }

      // 创建音频文件记录（使用已读取的元数据）
      final db = await bookProvider.databaseService.database;
      for (int i = 0; i < _scannedFiles.length; i++) {
        final metadata = metadataList[i];
        final audioFile = AudioFile(
          bookId: createdBook.id!,
          filePath: metadata.filePath,
          fileName: metadata.fileName,
          fileSize: metadata.fileSize,
          duration: metadata.duration ?? 0,
          sortOrder: i,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await db.insert('audio_files', audioFile.toMap());
      }

      // 刷新书籍列表（会自动触发后台补全时长）
      await bookProvider.loadBooks();

      setState(() {
        _statusMessage = '导入完成！';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入《$bookName》，共 ${_scannedFiles.length} 个音频文件'),
          ),
        );

        // 延迟后返回书架
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '导入失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
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
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('导入书籍'),
            actions: [
              if (_scannedFiles.isNotEmpty)
                TextButton.icon(
                  onPressed: _isScanning ? null : _importBook,
                  icon: const Icon(Icons.check),
                  label: const Text('导入'),
                ),
            ],
          ),
          body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 状态卡片
              Card(
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 递归扫描开关
              if (_hasPermission)
                Card(
                  child: SwitchListTile(
                    title: const Text('递归扫描子文件夹'),
                    subtitle: Text(
                      _recursiveScan
                          ? '将扫描选中文件夹及其所有子文件夹'
                          : '仅扫描选中文件夹，不包含子文件夹',
                    ),
                    value: _recursiveScan,
                    onChanged: _isScanning
                        ? null
                        : (value) {
                            setState(() {
                              _recursiveScan = value;
                            });
                          },
                    secondary: Icon(
                      _recursiveScan ? Icons.folder_open : Icons.folder,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

              if (_hasPermission) const SizedBox(height: 16),

              // 选择文件夹按钮
              if (!_hasPermission)
                ElevatedButton.icon(
                  onPressed: _requestPermission,
                  icon: const Icon(Icons.security),
                  label: const Text('请求权限'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _pickFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择文件夹'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),

              // 已选择的文件夹信息
              if (_selectedFolderPath != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '书籍信息',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        // 书籍名称
                        TextField(
                          controller: _bookNameController,
                          decoration: const InputDecoration(
                            labelText: '书籍名称 *',
                            hintText: '请输入书籍名称',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.book),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 作者
                        TextField(
                          controller: _authorController,
                          decoration: const InputDecoration(
                            labelText: '作者（可选）',
                            hintText: '请输入作者名称',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 文件夹路径
                        Row(
                          children: [
                            Icon(Icons.folder, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedFolderPath!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 文件数量
                        Row(
                          children: [
                            Icon(Icons.audio_file, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              '共 ${_scannedFiles.length} 个音频文件',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],


              // 使用说明
              if (_selectedFolderPath == null && _hasPermission) ...[
                const SizedBox(height: 24),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '使用说明',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. 选择是否递归扫描子文件夹\n'
                          '2. 点击"选择文件夹"按钮\n'
                          '3. 选择包含音频文件的文件夹\n'
                          '4. 系统会自动扫描该文件夹下的音频文件\n'
                          '5. 确认书籍名称和作者信息\n'
                          '6. 点击"导入"按钮完成导入',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[700],
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '提示：\n'
                          '• 递归扫描：会扫描选中文件夹及其所有子文件夹（推荐）\n'
                          '• 非递归扫描：仅扫描选中文件夹，不包含子文件夹',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),

        // Loading 遮罩层
        if (_isScanning)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          _statusMessage,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '请稍候，正在处理中...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
