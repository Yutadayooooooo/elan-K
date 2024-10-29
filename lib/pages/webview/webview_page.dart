import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '/helpers/widget_helper.dart';

class WebviewPage extends StatefulWidget {
  final String title;
  final String url;
  WebviewPage({required this.title, required this.url});

  @override
  State<WebviewPage> createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  var _title = "";
  String? _url;
  bool _loading = true;
  bool isBack = false;
  bool isGo = false;
  late final WebViewController _controller;
  late InAppWebViewController _webViewController;
  late PullToRefreshController _refreshController;

  @override
  void initState() {
    super.initState();

    _title = widget.title;
    Future(() async {
      _init();
      // _refreshController = PullToRefreshController(
      //   settings: PullToRefreshSettings(color: Colors.blue),
      //   onRefresh: () {
      //     _webViewController.reload();
      //   },
      // );
      // _url = widget.url;
    });
  }

  Future<void> _init() async {

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            //debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) async {
            setState(() {
              _loading = false;
            });
            //debugPrint('Page finished loading: $url');
          },
//           onWebResourceError: (WebResourceError error) {
//             debugPrint('''
// Page resource error:
//   code: ${error.errorCode}
//   description: ${error.description}
//   errorType: ${error.errorType}
//   isForMainFrame: ${error.isForMainFrame}
//           ''');
//           },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            debugPrint('url change to ${change.url}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }

  @override
  void dispose() {
    // _webViewController.dispose();
    // _refreshController.dispose();
    super.dispose();
  }

  Future<void> _handleLoadStop(InAppWebViewController controller, WebUri? url) async {
    setState(() {
      _loading = false;
    });
    if (await controller.canGoBack()) {
      setState(() {
        isBack = true;
      });
    } else {
      setState(() {
        isBack = false;
      });
    }
    if (await controller.canGoForward()) {
      setState(() {
        isGo = true;
      });
    } else {
      setState(() {
        isGo = false;
      });
    }
    _refreshController.endRefreshing();
  }

  Future<void> _handleLoadStart(InAppWebViewController controller, WebUri? url) async {
    setState(() {
      _loading = true;
    });
  }

  Future<NavigationActionPolicy?> _handleUrlLoading(
      InAppWebViewController controller,
      NavigationAction navigationAction) async {
    String url = navigationAction.request.url.toString();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NavigationActionPolicy.ALLOW;
    } else {
      launchUrl(Uri.parse(url));
      return NavigationActionPolicy.CANCEL;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: WidgetUtil.iosNavbarBG,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          // if (_url != null)
          //   InAppWebView(
          //     initialUrlRequest: URLRequest(
          //       url: WebUri.uri(
          //         Uri.parse(_url!),
          //       ),
          //     ),
          //     initialSettings: InAppWebViewSettings(
          //       cacheEnabled: true,
          //       cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
          //     ),
          //     pullToRefreshController: _refreshController,
          //     shouldOverrideUrlLoading: _handleUrlLoading,
          //     onWebViewCreated: (controller) {
          //       _webViewController = controller;
          //     },
          //     onLoadStart: _handleLoadStart,
          //     onLoadStop: _handleLoadStop,
          //   ),
          if (!_loading)
            WebViewWidget(controller: _controller),
          (_loading) ? Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.grey[100],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ) : const SizedBox.shrink(),
        ],
      ),
    );
  }
}