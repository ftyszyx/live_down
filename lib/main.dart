import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';
import 'logger.dart';
import 'download_manager.dart';
import 'url_parse.dart';
import 'path_service.dart';

late AppConfig appConfig;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await logger.initialize();
  appConfig = await AppConfig.load();
  logger.i('App config loaded.');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appConfig.appTitle,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.standard,
        useMaterial3: true,
        fontFamily: 'Microsoft YaHei', // 使用更常见的字体
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14.0),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// 定义一个数据模型来表示下载任务
class DownloadTask {
  final int id;
  String fileType;
  String downloadUrl;
  int totalSize;
  int duration;
  double progress;
  final String customName;
  bool isSelected;

  DownloadTask({
    required this.id,
    this.fileType = 'm3u8',
    required this.downloadUrl,
    this.totalSize = 0,
    this.duration = 0,
    this.progress = 0.0,
    required this.customName,
    this.isSelected = false,
  });
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late TabController _tabController;
  final List<DownloadTask> _downloadTasks = [];
  final String _statusMessage = '部分主流平台, 无需嗅探, 填入地址, 点击解析即可, 不能解析的, 就用嗅探功能';
  String _appVersion = '';
  bool _isParsing = false;
  final DownloadManager _downloadManager = DownloadManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
    });
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null) {
      _controller.text = clipboardData.text ?? '';
    }
  }

  void _startAnalysis() async {
    final url = _controller.text;
    if (url.isEmpty || _isParsing) {
      return;
    }

    setState(() {
      _isParsing = true;
    });

    try {
      final liveDetail = await UrlParseService.parseUrl(url);
      setState(() {
        _downloadTasks.add(DownloadTask(
          id: _downloadTasks.length + 1,
          downloadUrl: liveDetail.replayUrl ?? '未知地址',
          customName: liveDetail.title,
          totalSize: liveDetail.size,
          duration: liveDetail.duration,
        ));
      });
    } on DownloadError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失败: ${e.message}')),
        );
      }
      logger.e('解析失败', error: e);
    } catch (e, s) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发生未知错误: $e')),
        );
      }
      logger.e('解析时发生未知错误', error: e, stackTrace: s);
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  void _startSelectedDownloads() {
    final selectedTasks = _downloadTasks.where((task) => task.isSelected).toList();
    if (selectedTasks.isEmpty) {
      _showSnackBar('请先选择要下载的任务');
      return;
    }

    for (final task in selectedTasks) {
      _downloadManager
          .startDownload(task.id, task.downloadUrl, task.customName)
          .catchError((e) {
        final errorMessage = '任务 ${task.customName} 下载失败';
        _showSnackBar(errorMessage);
        logger.e(errorMessage, error: e);
      });
    }
    _showSnackBar('${selectedTasks.length} 个任务已开始下载。');
  }

  void _stopSelectedDownloads() {
    final selectedTasks = _downloadTasks.where((task) => task.isSelected);
    if (selectedTasks.isEmpty) {
      _showSnackBar('请先选择要停止的任务');
      return;
    }

    for (final task in selectedTasks) {
      _downloadManager.stopDownload(task.id);
    }
    _showSnackBar('${selectedTasks.length} 个任务已发送停止信号。');
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('${appConfig.appTitle} $_appVersion', style: const TextStyle(fontSize: 16)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: '【下载列表】'),
            Tab(text: '【设置】'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDownloadListTab(), // 第一个 tab 的内容
          _buildSettingsTab(), // 第二个 tab 的内容
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('应用设置', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('日志记录级别:'),
              const SizedBox(width: 20),
              DropdownButton<LogLevel>(
                value: logger.currentLevel,
                onChanged: (LogLevel? newValue) {
                  if (newValue != null) {
                    setState(() {
                      logger.setLevel(newValue);
                    });
                  }
                },
                items: LogLevel.values.map<DropdownMenuItem<LogLevel>>((LogLevel value) {
                  return DropdownMenuItem<LogLevel>(
                    value: value,
                    child: Text(value.name),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadListTab() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 地址解析区域
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text(_statusMessage, style: TextStyle(color: Colors.grey[600])),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('分享地址'),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        border: OutlineInputBorder(),
                        hintText: '请输入分享地址',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () => _controller.clear(), child: const Text('清空')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _pasteFromClipboard, child: const Text('粘贴')),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[100]),
                  onPressed: _isParsing ? null : _startAnalysis,
                  child: _isParsing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        )
                      : const Text('点我直接解析地址'),
                ),
              ],
            ),
          ),
          // 操作区域
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('操作'),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: _startSelectedDownloads,
                  child: const Text('下载选中', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _stopSelectedDownloads,
                  child: const Text('停止下载选中', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () async {
                  final String absolutePath = await PathService.getAbsoluteSavePath(appConfig.saveDir);
                  final Uri uri = Uri.file(absolutePath);
                  logger.i('Attempting to open directory: $absolutePath');

                  if (await canLaunchUrl(uri)) {
                    if (!await launchUrl(uri)) {
                      _showSnackBar('无法打开目录: $absolutePath');
                      logger.e('launchUrl failed for $uri');
                    }
                  } else {
                     _showSnackBar('无法处理该路径: $absolutePath');
                     logger.e('canLaunchUrl returned false for $uri');
                  }
                }, child: const Text('打开保存目录')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {}, child: const Text('清空列表')),
              ],
            ),
          ),
          // 下载列表
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('序号')),
                  DataColumn(label: Text('文件类型')),
                  DataColumn(label: Text('下载地址')),
                  DataColumn(label: Text('大小')),
                  DataColumn(label: Text('时长')),
                  DataColumn(label: Text('下载速度')),
                  DataColumn(label: Text('下载进度')),
                  DataColumn(label: Text('自定义名字(双击)')),
                ],
                rows: _downloadTasks.map((task) {
                  return DataRow(
                    selected: task.isSelected,
                    onSelectChanged: (isSelected) {
                      setState(() {
                        task.isSelected = isSelected ?? false;
                      });
                    },
                    cells: [
                      DataCell(Text(task.id.toString())),
                      DataCell(Text(task.fileType)),
                      DataCell(Text(task.downloadUrl)),
                      DataCell(Text(task.totalSize > 0
                          ? '${(task.totalSize / 1024 / 1024).toStringAsFixed(2)}MB'
                          : '--')),
                      DataCell(Text(task.duration > 0
                          ? '${(task.duration / 60).toStringAsFixed(2)}分钟'
                          : '--')),
                      DataCell(Text('--/--')),
                      DataCell(
                        LinearProgressIndicator(value: task.progress),
                      ),
                      DataCell(Text(task.customName), onDoubleTap: () {
                        // 双击编辑名字的逻辑
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    logger.dispose(); // Clean up the file sink
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
