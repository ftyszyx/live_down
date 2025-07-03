import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:live_down/ui/home/viewmodels/home_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:live_down/core/utils/common.dart';

class TaskList extends StatelessWidget {
  const TaskList({super.key});

  void _copyToClipboard(BuildContext context, String text) {
    if (text.isEmpty || text == '--') {
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$text" 已复制到剪贴板'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return Expanded(
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text('序号')),
            DataColumn(label: Text('文件类型')),
            DataColumn(
              label: Text('下载地址'),
              columnWidth: FixedColumnWidth(200),
            ),
            DataColumn(label: Text('预估大小')),
            DataColumn(label: Text('时长')),
            DataColumn(label: Text('状态/速度')),
            DataColumn(label: Text('下载进度')),
            DataColumn(label: Text('自定义名字(双击)')),
          ],
          rows: viewModel.tasks.map((task) {
            return DataRow(
              selected: task.isSelected,
              onSelectChanged: (isSelected) =>
                  viewModel.onSelectChanged(isSelected, task),
              cells: [
                DataCell(Text(task.id.toString()), onTap: () {
                  _copyToClipboard(context, task.id.toString());
                }),
                DataCell(Text(task.fileType.name), onTap: () {
                  _copyToClipboard(context, task.fileType.name);
                }),
                DataCell(
                  Tooltip(
                    message: task.downloadUrl,
                    child: Text(
                      task.downloadUrl,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                  onTap: () {
                    _copyToClipboard(context, task.downloadUrl);
                  },
                ),
                DataCell( Text(CommonUtils.formatSize(task.totalSize))),
                DataCell( Text(CommonUtils.formatDuration(task.duration))),
                DataCell(Text(task.status == DownloadStatus.downloading ? CommonUtils.formatDownloadSpeed(task.bitSpeedPerSecond) : _getStatusText(task))),
                DataCell(LinearProgressIndicator(value: task.progress)),
                DataCell(Text(task.customName), onDoubleTap: () {
                  // Handle rename
                }, onTap: () {
                  _copyToClipboard(context, task.customName);
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getStatusText(ViewDownloadInfo task) {
    switch (task.status) {
      case DownloadStatus.idle:
        return '未开始';
      case DownloadStatus.downloading:
        return '下载中...';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.merging:
        return '合并中...';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return '失败';
    }
  }
} 