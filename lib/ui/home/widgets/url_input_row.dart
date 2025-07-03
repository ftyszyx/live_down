import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_down/ui/home/viewmodels/home_viewmodel.dart';
import 'package:provider/provider.dart';

class UrlInputRow extends StatefulWidget {
  const UrlInputRow({super.key});

  @override
  State<UrlInputRow> createState() => _UrlInputRowState();
}

class _UrlInputRowState extends State<UrlInputRow> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null) {
      _urlController.text = clipboardData.text ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const Text('分享地址'),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  border: OutlineInputBorder(),
                  hintText: '请输入分享地址',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton( onPressed: () => _urlController.clear(), child: const Text('清空')),
          const SizedBox(width: 8),
          ElevatedButton( onPressed: _pasteFromClipboard, child: const Text('粘贴')),
          const SizedBox(width: 8),
          ElevatedButton( style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[100]),
            onPressed: viewModel.isParsing
                ? null
                : () => viewModel.analyzeUrl(_urlController.text),
            child: viewModel.isParsing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : const Text('点我直接解析地址'),
          ),
        ],
      ),
    );
  }
} 