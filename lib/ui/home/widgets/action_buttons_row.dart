import 'package:flutter/material.dart';
import 'package:live_down/core/configs/local_setting.dart';
import 'package:live_down/core/services/logger_service.dart';
import 'package:live_down/core/services/path_service.dart';
import 'package:live_down/core/utils/common.dart';
import 'package:live_down/ui/home/viewmodels/home_viewmodel.dart';
import 'package:provider/provider.dart';


class ActionButtonsRow extends StatelessWidget {
  const ActionButtonsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const Text('操作'),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: viewModel.startSelectedDownloads,
            child: const Text('下载选中', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: viewModel.stopSelectedDownloads,
            child: const Text('停止下载选中', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: viewModel.mergeSelectedDownloads,
            child: const Text('合并分片', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
              onPressed: () async {
                final localSetting = LocalSetting.instance;
                final String absolutePath = await PathService.getAbsoluteSavePath(localSetting.saveDir);
                logger.i('Attempting to open directory: $absolutePath');
                CommonUtils.openPath(absolutePath);
              },
              child: const Text('打开保存目录')),
          const SizedBox(width: 8),
          ElevatedButton(
              onPressed: viewModel.clearCompletedTasks,
              child: const Text('清空已完成')),
        ],
      ),
    );
  }
} 