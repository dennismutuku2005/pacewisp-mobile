import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/colors.dart';

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  
  const WebViewScreen({super.key, required this.title, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaceColors.getBackground(false),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        backgroundColor: PaceColors.getBackground(false),
        foregroundColor: PaceColors.getPrimaryText(false),
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: PaceColors.purple),
            ),
        ],
      ),
    );
  }
}
