import 'package:flutter/material.dart';
import 'package:live_down/core/configs/app_config.dart';
import 'package:live_down/features/download/download_repository.dart';
import 'package:live_down/ui/home/viewmodels/home_viewmodel.dart';
import 'package:live_down/ui/home/widgets/home_view.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  final DownloadRepository downloadRepository;

  const MyApp({super.key, required this.downloadRepository});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(repository: downloadRepository),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.instance.appTitle,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.standard,
          useMaterial3: true,
          fontFamily: 'Microsoft YaHei',
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 14.0),
          ),
        ),
        home: const HomeView(),
      ),
    );
  }
} 