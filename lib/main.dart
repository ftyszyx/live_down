import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config_service.dart';
import 'downloader_service.dart';
import 'path_service.dart';

late AppConfig appConfig;

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 必须在异步操作前调用
  appConfig = await AppConfig.load();

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
  final String fileType;
  final String downloadUrl;
  final String size;
  double progress;
  final String customName;
  bool isSelected;

  DownloadTask({
    required this.id,
    this.fileType = 'm3u8',
    required this.downloadUrl,
    this.size = '未知',
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
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
      final liveDetail = await DownloaderService.parseUrl(url);
      setState(() {
        _downloadTasks.add(DownloadTask(
          id: _downloadTasks.length + 1,
          downloadUrl: liveDetail.replayUrl ?? '未知地址',
          customName: liveDetail.title,
        ));
      });
    } on DownloadError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失败: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发生未知错误: $e')),
        );
      }
    } finally {
      setState(() {
        _isParsing = false;
      });
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDownloadListTab(), // 第一个 tab 的内容
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
                  onPressed: () {},
                  child: const Text('下载选中', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {},
                  child: const Text('停止下载选中', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () async {
                  final String absolutePath = await PathService.getAbsoluteSavePath(appConfig.saveDir);
                  final Uri uri = Uri.file(absolutePath);
                  developer.log(absolutePath);
                  if (!await launchUrl(uri)) {
                    if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('无法打开目录: $absolutePath')),
                      );
                    }
                    developer.log('Could not launch $uri');
                  }
                }, child: const Text('打开保存目录')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {}, child: const Text('清空列表')),
                const Spacer(),
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
                      DataCell(Text(task.size)),
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
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
