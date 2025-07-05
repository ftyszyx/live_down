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
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  Future<void> _showRenameDialog(
      BuildContext context, HomeViewModel viewModel, ViewDownloadInfo task) async {
    final controller = TextEditingController(text: task.title);
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('重命名任务'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入新的任务名称'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                viewModel.renameTask(task, controller.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return Expanded(
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(Theme.of(context).colorScheme.primary.withAlpha(25)),
          dataRowColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).colorScheme.primary.withAlpha(50);
            }
            if (states.contains(WidgetState.hovered)) {
              return Theme.of(context).colorScheme.primary.withAlpha(10);
            }
            return null;
          }),
          dividerThickness: 1,
          showCheckboxColumn: true,
          columns: const [
            DataColumn(label: Text('序号')),
            DataColumn(label: Text('平台')),
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
            DataColumn(label: Text('操作')),
          ],
          rows: viewModel.tasks.map((task) {
            return DataRow(
              selected: task.isSelected,
              onSelectChanged: (isSelected) =>
                  viewModel.onSelectChanged(isSelected, task),
              cells: [
                DataCell(
                  Tooltip(message: task.id, child: Text(task.id.substring(0, 6))),
                  onTap: () {
                    _copyToClipboard(context, task.id.toString());
                }),
                DataCell(Text(task.platform.name)),
                DataCell(Text(task.fileType.name.toUpperCase())),
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
                DataCell(Text(CommonUtils.formatSize(task.totalSize))),
                DataCell(Text(CommonUtils.formatDuration(task.duration))),
                DataCell(Text(task.status == DownloadStatus.downloading
                    ? CommonUtils.formatDownloadSpeed(task.bitSpeedPerSecond)
                    : _getStatusText(task))),
                DataCell(LinearProgressIndicator(value: task.progress)),
                DataCell(Text(task.title), onDoubleTap: () {
                  _showRenameDialog(context, viewModel, task);
                }, onTap: () {
                  _copyToClipboard(context, task.title);
                }),
                DataCell(Row(
                  children: [
                    IconButton(
                        tooltip: '下载',
                        onPressed: () => viewModel.startTask(task),
                        icon: const Icon(Icons.download)),
                    IconButton(
                        tooltip: '暂停',
                        onPressed: () => viewModel.pauseTask(task),
                        icon: const Icon(Icons.pause)),
                    IconButton(
                        tooltip: '删除',
                        onPressed: () => viewModel.deleteTask(task),
                        icon: const Icon(Icons.delete)),
                  ],
                )),
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