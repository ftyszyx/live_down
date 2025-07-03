import 'package:flutter/material.dart';

import 'action_buttons_row.dart';
import 'url_input_row.dart';
import 'task_list.dart';

class DownloadTabView extends StatelessWidget {
  const DownloadTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          UrlInputRow(),
          ActionButtonsRow(),
          TaskList(),
        ],
      ),
    );
  }
} 