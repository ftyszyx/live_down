import 'package:flutter/material.dart';
import 'package:live_down/core/configs/local_setting.dart';
import 'package:live_down/core/services/logger_service.dart';
import 'package:live_down/core/utils/common.dart';

class SettingsTabView extends StatefulWidget {
  const SettingsTabView({super.key});

  @override
  State<SettingsTabView> createState() => _SettingsTabViewState();
}

class _SettingsTabViewState extends State<SettingsTabView> {
  @override
  Widget build(BuildContext context) {
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
                items: LogLevel.values
                    .map<DropdownMenuItem<LogLevel>>((LogLevel value) {
                  return DropdownMenuItem<LogLevel>(
                    value: value,
                    child: Text(value.name),
                  );
                }).toList(),
              ),
              //add open path b
              ElevatedButton(onPressed: () {
                CommonUtils.openPath(logger.logPath);
              }, child: const Text('打开保存路径')),
            ],
          ),
          //add setting dir path
          Row(
            children: [
              const Text('配置文件路径:'),
              const SizedBox(width: 20),
              Text(LocalSetting.instance.saveDir),
              //button open path
              ElevatedButton(onPressed: () {
                CommonUtils.openPath(LocalSetting.instance.appConfigPath);
              }, child: const Text('打开配置文件')),
            ],
          ),
        ],
      ),
    );
  }
} 