// BannerAd and InterstitialAd: the requests Ruby's properties make, the
// events Ruby subscribes to, and the ad lifecycle google_mobile_ads requires
// (one loaded ad per AdWidget, every ad disposed by its owner).
//
// The plugin's method channel is mocked: the test records every call the
// Dart plugin makes (loadBannerAd, disposeAd, showAdWithoutView, ...) and
// delivers native ad events as the plugin's own `onAdEvent` messages.
//
// ruflet-coverage: BannerAd InterstitialAd
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
// ignore: implementation_imports
import 'package:ruflet/src/services/service_binding.dart';
// ignore: implementation_imports
import 'package:ruflet/src/utils/cupertino_theme.dart';
// ignore: implementation_imports
import 'package:ruflet/src/utils/material_style_theme.dart';
import 'package:ruflet_ads/ruflet_ads.dart';
import 'package:ruflet_ads/src/banner.dart';

const designs = [TargetPlatform.iOS, TargetPlatform.android];

/// Records the events the renderer sends to Ruby, only when Ruby subscribed
/// with `on_<name>: true`, as the real backend does.
class _Backend extends RufletBackend {
  _Backend(TargetPlatform design)
      : super(
            pageUri: Uri.parse('ruflet://ads'),
            assetsDir: '',
            extensions: [Extension()],
            multiView: false) {
    platform = design;
  }

  final events = <({int id, String name, Object? data})>[];

  List<String> namesFor(int id) => [
        for (final e in events)
          if (e.id == id) e.name
      ];

  @override
  void triggerControlEvent(Control control, String eventName,
      [dynamic eventData]) {
    if (control.get("on_$eventName") == true) {
      events.add((id: control.id, name: eventName, data: eventData));
    }
  }
}

/// Every call the Dart plugin made, in order.
final _calls = <MethodCall>[];

List<Map<dynamic, dynamic>> _callsTo(String method) => [
      for (final call in _calls)
        if (call.method == method) call.arguments as Map<dynamic, dynamic>
    ];

List<int> _adIds(String method) =>
    [for (final args in _callsTo(method)) args['adId'] as int];

bool _isLive(int adId) => instanceManager.adFor(adId) != null;

/// Delivers a native ad event, as the plugin's platform side sends it.
Future<void> _adEvent(WidgetTester tester, int adId, String eventName,
    [Map<String, Object?> arguments = const {}]) async {
  final channel = instanceManager.channel;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('onAdEvent', <dynamic, dynamic>{
        'adId': adId,
        'eventName': eventName,
        ...arguments
      })),
      (_) {});
  await tester.pump();
}

// ignore: invalid_use_of_protected_member
final _noFill = LoadAdError(3, 'com.google.android.gms.ads', 'No fill.', null);

/// A banner as Ruby's `banner_ad(unit_id:, request:, width:, height:, ...)`
/// serializes it, inside a column so a patch can remove it.
Map<String, dynamic> _bannerPage([Map<String, dynamic> props = const {}]) => {
      '_c': 'Column',
      '_i': 1,
      'controls': [
        {
          '_c': 'BannerAd',
          '_i': 2,
          'unit_id': 'unit-banner',
          'request': {
            'content_url': 'https://ruflet.dev',
            'http_timeout': 3000
          },
          'width': 320,
          'height': 50,
          for (final event in [
            'load',
            'error',
            'open',
            'close',
            'click',
            'impression',
            'paid',
          ])
            'on_$event': true,
          ...props,
        },
      ],
    };

class _Banner {
  _Banner(this.backend, this.column);
  final _Backend backend;
  final Control column;

  Control get banner => column.children('controls').first;

  /// Applies a Ruby property update to the banner.
  Future<void> update(WidgetTester tester, Map<String, dynamic> props) async {
    banner.update(props, shouldNotify: true);
    await tester.pump();
  }

  /// Removes the banner from the column, as Ruby's patch does.
  Future<void> remove(WidgetTester tester) async {
    column.applyPatch([
      [
        0,
        {
          'controls': [1]
        }
      ],
      [2, 1, 0]
    ], backend);
    await tester.pump();
  }
}

Future<_Banner> _mountBanner(WidgetTester tester, TargetPlatform design,
    [Map<String, dynamic> props = const {}]) async {
  // Unmount the previous test's tree first, so its ad disposals are not
  // recorded as this test's.
  await tester.pumpWidget(const SizedBox());
  _calls.clear();
  final backend = _Backend(design);
  final column = Control.fromMap(_bannerPage(props), backend);
  final body = Align(
      alignment: Alignment.topLeft, child: ControlWidget(control: column));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: design == TargetPlatform.iOS
        ? CupertinoApp(
            builder: (context, child) =>
                cupertinoStyleThemeScope(context, child!),
            home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(
            builder: (context, child) => RufletStyleThemeScope(
                data: materialStyleTheme(material.Theme.of(context)),
                child: child!),
            home: material.Scaffold(body: body)),
  ));
  await tester.pump();
  return _Banner(backend, column);
}

/// Mounts an InterstitialAd the way the page's ServiceRegistry does.
ServiceBinding _mountInterstitial(_Backend backend, int id, String unitId) =>
    ServiceBinding(
        control: Control.fromMap({
          '_c': 'InterstitialAd',
          '_i': id,
          'unit_id': unitId,
          'request': {'non_personalized_ads': true},
          for (final event in [
            'load',
            'error',
            'open',
            'close',
            'click',
            'impression'
          ])
            'on_$event': true,
        }, backend),
        backend: backend);

/// Invokes [name] the way the backend does for a Ruby `page.invoke`; returns
/// what Ruby would receive.
Future<({Object? value, Object? error})> _invoke(
    WidgetTester tester, Control control, String name) async {
  Object? value;
  Object? error;
  var done = false;
  unawaited(
      control.invokeMethod(name, null, const Duration(seconds: 1)).then((v) {
    value = v;
    done = true;
  }, onError: (Object e) {
    error = e;
    done = true;
  }));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  expect(done, isTrue, reason: 'InterstitialAd.$name did not settle');
  return (value: value, error: error);
}

void main() {
  setUp(() {
    _calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, (call) async {
      _calls.add(call);
      return null;
    });
  });

  for (final design in designs) {
    group('BannerAd $design', () {
      testWidgets('requests one ad and keeps it across rebuilds',
          (tester) async {
        final page = await _mountBanner(tester, design);
        final banner = page.banner;
        final loads = _callsTo('loadBannerAd');
        expect(loads, hasLength(1));
        expect(loads.single['adUnitId'], 'unit-banner');
        final request = loads.single['request'] as AdRequest;
        expect(request.contentUrl, 'https://ruflet.dev');
        expect(request.httpTimeoutMillis, 3000);
        expect(loads.single['size'], AdSize.banner);
        final adId = loads.single['adId'] as int;
        expect(tester.getSize(find.byType(AdWidget)), const Size(320, 50));

        // Ruby updates the banner while the request is in flight.
        await page.update(tester, {'width': 321});
        await page.update(tester, {'width': 322});
        expect(_adIds('loadBannerAd'), [adId]);
        expect(tester.getSize(find.byType(AdWidget)), const Size(322, 50));

        await _adEvent(tester, adId, 'onAdLoaded');
        expect(page.backend.namesFor(banner.id), ['load']);
        final ad = tester.widget<AdWidget>(find.byType(AdWidget)).ad;
        final adWidgetState = tester.state(find.byType(AdWidget));

        // A wrapper Ruby adds or removes moves the loaded ad's view.
        for (final props in [
          {'opacity': 0.5},
          {'rtl': true},
          {'opacity': null, 'rtl': null},
        ]) {
          await page.update(tester, props);
          expect(tester.takeException(), isNull, reason: '$props');
          expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad),
              reason: '$props');
          expect(tester.state(find.byType(AdWidget)), same(adWidgetState),
              reason: '$props');
        }
        expect(_adIds('loadBannerAd'), [adId]);
        expect(_adIds('disposeAd'), isEmpty);
        expect(page.backend.namesFor(banner.id), ['load']);

        await tester.pumpWidget(const SizedBox());
        expect(_adIds('disposeAd'), [adId]);
        expect(_isLive(adId), isFalse);
      });

      testWidgets('forwards the ad events Ruby subscribes to', (tester) async {
        final page = await _mountBanner(tester, design);
        final adId = _adIds('loadBannerAd').single;
        await _adEvent(tester, adId, 'onAdLoaded');
        await _adEvent(tester, adId, 'onAdImpression');
        await _adEvent(tester, adId, 'onAdClicked');
        await _adEvent(tester, adId, 'onAdOpened');
        await _adEvent(tester, adId, 'onAdClosed');
        await _adEvent(tester, adId, 'onPaidEvent',
            {'valueMicros': 1500, 'precision': 3, 'currencyCode': 'USD'});
        expect(page.backend.namesFor(2),
            ['load', 'impression', 'click', 'open', 'close', 'paid']);
        expect(page.backend.events.map((e) => e.id), everyElement(2));
        expect(page.backend.events.take(5).map((e) => e.data),
            everyElement(isNull));
        expect(page.backend.events.last.data,
            {'value': 1500.0, 'precision': 'precise', 'currency_code': 'USD'});
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('a failed load is reported once and not retried',
          (tester) async {
        final page = await _mountBanner(tester, design);
        final adId = _adIds('loadBannerAd').single;
        await _adEvent(
            tester, adId, 'onAdFailedToLoad', {'loadAdError': _noFill});
        expect(tester.takeException(), isNull);
        expect(page.backend.events.single.name, 'error');
        expect(page.backend.events.single.data, contains('No fill.'));
        expect(_adIds('disposeAd'), [adId]);
        expect(_adIds('loadBannerAd'), [adId]);
        // The banner keeps its slot without the failed ad's view.
        expect(find.byType(AdWidget), findsNothing);
        expect(
            tester.getSize(find.byType(BannerAdControl)), const Size(320, 50));

        // Rebuilds and unrelated updates do not request again.
        await page.update(tester, {'width': 300});
        await page.update(tester, {'opacity': 0.5});
        expect(tester.takeException(), isNull);
        expect(_adIds('loadBannerAd'), [adId]);
        expect(
            tester.getSize(find.byType(BannerAdControl)), const Size(300, 50));

        // A new request from Ruby loads a new ad.
        await page.update(tester, {
          'request': {'content_url': 'https://ruflet.dev/docs'}
        });
        final loads = _callsTo('loadBannerAd');
        expect(loads, hasLength(2));
        expect((loads.last['request'] as AdRequest).contentUrl,
            'https://ruflet.dev/docs');
        expect(find.byType(AdWidget), findsOneWidget);
        expect(page.backend.events.map((e) => e.name), ['error']);
        await tester.pumpWidget(const SizedBox());
        expect(_adIds('disposeAd'), [adId, loads.last['adId']]);
      });

      testWidgets('a new unit_id or request replaces the ad', (tester) async {
        final page = await _mountBanner(tester, design);
        final first = _adIds('loadBannerAd').single;
        await _adEvent(tester, first, 'onAdLoaded');

        await page.update(tester, {'unit_id': 'unit-banner-2'});
        expect(tester.takeException(), isNull);
        final loads = _callsTo('loadBannerAd');
        expect(loads.map((args) => args['adUnitId']),
            ['unit-banner', 'unit-banner-2']);
        final second = loads.last['adId'] as int;
        expect(_adIds('disposeAd'), [first]);
        expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad,
            same(instanceManager.adFor(second)));

        // A request with the same values is not a new request.
        await page.update(tester, {
          'request': {'content_url': 'https://ruflet.dev', 'http_timeout': 3000}
        });
        expect(_adIds('loadBannerAd'), [first, second]);
        await page.update(tester, {
          'request': {'content_url': 'https://ruflet.dev', 'http_timeout': 5000}
        });
        expect(tester.takeException(), isNull);
        final third = _adIds('loadBannerAd').last;
        expect(_adIds('loadBannerAd'), [first, second, third]);
        expect(_adIds('disposeAd'), [first, second]);
        await _adEvent(tester, third, 'onAdLoaded');
        expect(page.backend.namesFor(2), ['load', 'load']);
        await tester.pumpWidget(const SizedBox());
        expect(_adIds('disposeAd'), [first, second, third]);
      });

      testWidgets('removing the banner disposes its ad', (tester) async {
        final page = await _mountBanner(tester, design);
        final adId = _adIds('loadBannerAd').single;
        await _adEvent(tester, adId, 'onAdLoaded');
        await page.remove(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(BannerAdControl), findsNothing);
        expect(_adIds('disposeAd'), [adId]);
        expect(_isLive(adId), isFalse);
        await tester.pumpWidget(const SizedBox());
        expect(_adIds('disposeAd'), [adId]);
      });
    });
  }

  group('InterstitialAd', () {
    testWidgets('each control loads, shows and disposes its own ad',
        (tester) async {
      final backend = _Backend(TargetPlatform.android);
      final a = _mountInterstitial(backend, 11, 'unit-A');
      final b = _mountInterstitial(backend, 12, 'unit-B');
      final loads = _callsTo('loadInterstitialAd');
      expect(loads.map((args) => args['adUnitId']), ['unit-A', 'unit-B']);
      expect((loads.first['request'] as AdRequest).nonPersonalizedAds, isTrue);
      final idA = loads[0]['adId'] as int;
      final idB = loads[1]['adId'] as int;
      await _adEvent(tester, idA, 'onAdLoaded');
      await _adEvent(tester, idB, 'onAdLoaded');
      expect(backend.namesFor(11), ['load']);
      expect(backend.namesFor(12), ['load']);

      expect((await _invoke(tester, a.control, 'show')).error, isNull);
      expect(_adIds('showAdWithoutView'), [idA]);
      expect((await _invoke(tester, b.control, 'show')).error, isNull);
      expect(_adIds('showAdWithoutView'), [idA, idB]);

      // Ruby removes B: only B's ad goes, and A still shows its own.
      b.dispose();
      expect(_adIds('disposeAd'), [idB]);
      expect(_isLive(idA), isTrue);
      expect((await _invoke(tester, a.control, 'show')).error, isNull);
      expect(_adIds('showAdWithoutView'), [idA, idB, idA]);

      // Ruby removes A: its ad goes and its invokes no longer reach it.
      a.dispose();
      expect(_adIds('disposeAd'), [idB, idA]);
      expect(_isLive(idA), isFalse);
      final afterRemoval = await _invoke(tester, a.control, 'show');
      expect(afterRemoval.error, isA<TimeoutException>());
      expect(_adIds('showAdWithoutView'), [idA, idB, idA]);
    });

    testWidgets("a failed load leaves another control's ad alone",
        (tester) async {
      final backend = _Backend(TargetPlatform.android);
      final a = _mountInterstitial(backend, 21, 'unit-A');
      final idA = _adIds('loadInterstitialAd').single;
      await _adEvent(tester, idA, 'onAdLoaded');
      final b = _mountInterstitial(backend, 22, 'unit-B');
      final idB = _adIds('loadInterstitialAd').last;
      await _adEvent(tester, idB, 'onAdFailedToLoad', {'loadAdError': _noFill});

      expect(backend.namesFor(22), ['error']);
      expect(backend.events.last.data, contains('No fill.'));
      // The plugin disposes the ad that failed; nothing else is disposed.
      expect(_adIds('disposeAd'), [idB]);
      expect(_isLive(idA), isTrue);
      expect((await _invoke(tester, a.control, 'show')).error, isNull);
      expect(_adIds('showAdWithoutView'), [idA]);
      // B has no ad to show.
      expect((await _invoke(tester, b.control, 'show')).error, isNull);
      expect(_adIds('showAdWithoutView'), [idA]);
      a.dispose();
      b.dispose();
      expect(_adIds('disposeAd'), [idB, idA]);
    });

    testWidgets('a dismissed ad is disposed and not shown again',
        (tester) async {
      final backend = _Backend(TargetPlatform.android);
      final a = _mountInterstitial(backend, 31, 'unit-A');
      final adId = _adIds('loadInterstitialAd').single;
      await _adEvent(tester, adId, 'onAdLoaded');
      expect((await _invoke(tester, a.control, 'show')).error, isNull);
      await _adEvent(tester, adId, 'onAdShowedFullScreenContent');
      await _adEvent(tester, adId, 'onAdImpression');
      await _adEvent(tester, adId, 'onAdClicked');
      await _adEvent(tester, adId, 'onAdDismissedFullScreenContent');
      expect(backend.namesFor(31),
          ['load', 'open', 'impression', 'click', 'close']);
      expect(_adIds('disposeAd'), [adId]);

      final again = await _invoke(tester, a.control, 'show');
      expect(again.error, isNull);
      expect(_adIds('showAdWithoutView'), [adId]);
      a.dispose();
      expect(_adIds('disposeAd'), [adId]);
    });

    testWidgets('an ad that fails to show is reported and disposed',
        (tester) async {
      final backend = _Backend(TargetPlatform.android);
      final a = _mountInterstitial(backend, 41, 'unit-A');
      final adId = _adIds('loadInterstitialAd').single;
      await _adEvent(tester, adId, 'onAdLoaded');
      await _adEvent(tester, adId, 'onFailedToShowFullScreenContent', {
        // ignore: invalid_use_of_protected_member
        'error': AdError(0, 'com.google.android.gms.ads', 'Not ready.'),
      });
      expect(backend.namesFor(41), ['load', 'error']);
      expect(backend.events.last.data, contains('Not ready.'));
      expect(_adIds('disposeAd'), [adId]);
      expect((await _invoke(tester, a.control, 'show')).error, isNull);
      expect(_adIds('showAdWithoutView'), isEmpty);
      a.dispose();
    });

    testWidgets('an ad that loads after its control is removed is disposed',
        (tester) async {
      final backend = _Backend(TargetPlatform.android);
      final a = _mountInterstitial(backend, 51, 'unit-A');
      final adId = _adIds('loadInterstitialAd').single;
      a.dispose();
      await _adEvent(tester, adId, 'onAdLoaded');
      expect(_adIds('disposeAd'), [adId]);
      expect(_isLive(adId), isFalse);
      expect(backend.events, isEmpty);
    });
  });
}
