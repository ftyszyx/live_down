import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:live_down/ui/home/viewmodels/home_viewmodel.dart';
import 'package:provider/provider.dart';

class TaskList extends StatelessWidget {
  const TaskList({super.key});

  Widget _buildCopyableHeader(BuildContext context, String title, {double? width}) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: title));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$title" 已复制到剪贴板')),
        );
      },
      child: Container(
        width: width,
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            DataColumn(label: _buildCopyableHeader(context, '序号')),
            DataColumn(label: _buildCopyableHeader(context, '文件类型')),
            DataColumn(
                label:
                    _buildCopyableHeader(context, '下载地址', width: 100)),
            DataColumn(label: _buildCopyableHeader(context, '大小')),
            DataColumn(label: _buildCopyableHeader(context, '时长')),
            DataColumn(label: _buildCopyableHeader(context, '状态/速度')),
            DataColumn(label: _buildCopyableHeader(context, '下载进度')),
            DataColumn(label: _buildCopyableHeader(context, '自定义名字(双击)')),
          ],
          rows: viewModel.tasks.map((task) {
            return DataRow(
              selected: task.isSelected,
              onSelectChanged: (isSelected) =>
                  viewModel.onSelectChanged(isSelected, task),
              cells: [
                DataCell(Text(task.id.toString())),
                DataCell(Text(task.fileType.name)),
                DataCell(Text(task.downloadUrl)),
                DataCell(Text(task.totalSize > 0
                    ? '${(task.totalSize / 1024 / 1024).toStringAsFixed(2)}MB'
                    : '--')),
                DataCell(Text(task.duration > 0
                    ? '${(task.duration / 60).toStringAsFixed(2)}分钟'
                    : '--')),
                DataCell(Text(_getStatusText(task))),
                DataCell(LinearProgressIndicator(value: task.progress)),
                DataCell(Text(task.customName), onDoubleTap: () {
                  // Handle rename
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
        return task.speed;
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