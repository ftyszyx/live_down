import 'package:flutter/material.dart';
import 'package:live_down/core/configs/app_config.dart';
import 'package:live_down/core/services/logger_service.dart';
import 'package:live_down/ui/home/viewmodels/home_viewmodel.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'download_tab_view.dart';
import 'settings_tab_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin, WindowListener {
  late TabController _tabController;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _setPreventClose();
    _initPackageInfo();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _setPreventClose() async {
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() async {
    final viewModel = context.read<HomeViewModel>();
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      logger
          .i('Window close prevented. Stopping all downloads before exiting.');
      viewModel.stopAllDownloads();
      await Future.delayed(const Duration(milliseconds: 500));
      await windowManager.destroy();
    }
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = context.read<AppConfig>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('${appConfig.appTitle} $_appVersion',
                style: const TextStyle(fontSize: 16)),
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
        children: const [
          DownloadTabView(),
          SettingsTabView(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _tabController.dispose();
    super.dispose();
  }
}
