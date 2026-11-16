// ruflet-coverage: WebView
//
// The WebView control mounted from the protocol map Ruby sends, on the
// Cupertino (TargetPlatform.iOS) and Material (TargetPlatform.android) hosts.
// The native view cannot render in widget tests, so webview_flutter's
// platform interface is faked: the tests assert what the control hands the
// plugin, the values invokes return to Ruby and the events Ruby receives.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_webview/ruflet_webview.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_webview_platform.dart';
import 'support/harness.dart';

Map<String, dynamic> _wire([Map<String, dynamic> props = const {}]) => {
      '_c': 'WebView',
      '_i': 7,
      'url': 'https://ruflet.test/start',
      ...props,
    };

void main() {
  late FakeWebViewPlatform platform;

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  testWidgets('loads url with GET and fills the size Ruby gives it',
      (tester) async {
    final mounted = await mountWire(
        tester, _wire({'width': 320, 'height': 240}), Extension());

    expect(tester.takeException(), isNull);
    final controller = platform.controller;
    expect(controller.requests, hasLength(1));
    expect(controller.requests.single.uri,
        Uri.parse('https://ruflet.test/start'));
    expect(controller.requests.single.method, LoadRequestMethod.get);
    expect(controller.navigationDelegate, same(platform.delegates.single));
    expect(tester.getSize(find.byKey(FakeWebViewWidget.viewKey)),
        const Size(320, 240));
    expect(tester.getTopLeft(find.byKey(FakeWebViewWidget.viewKey)),
        Offset.zero);
    // Nothing was subscribed, so no optional plugin handler is installed.
    expect(
        controller.calls,
        isNot(anyOf(contains('setOnScrollPositionChange'),
            contains('setOnConsoleMessage'),
            contains('setOnJavaScriptAlertDialog'))));
    expect(mounted.backend.events, isEmpty);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('loads url with the request method Ruby sends', (tester) async {
    await mountWire(tester, _wire({'method': 'post'}), Extension());

    expect(tester.takeException(), isNull);
    expect(platform.controller.requests.single.method, LoadRequestMethod.post);
    await unmount(tester);
  }, variant: bothDesigns);
}
