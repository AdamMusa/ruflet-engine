import 'package:collection/collection.dart';
import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../utils/ads.dart';

class BannerAdControl extends StatefulWidget {
  final Control control;

  const BannerAdControl({super.key, required this.control});

  @override
  State<BannerAdControl> createState() => _BannerAdControlState();
}

/// Shows one [BannerAd] for as long as the control is mounted.
///
/// Each [BannerAd] is a native ad view with its own ad requests, and an
/// [AdWidget] may only show an ad that `load()` was called on. So the ad is
/// created and loaded once, when the control mounts, and kept across
/// rebuilds. Ruby changing `unit_id` or `request` replaces it (the old ad is
/// disposed). A failed load reports `error` and is not retried. The ad is
/// disposed with the control.
class _BannerAdControlState extends State<BannerAdControl>
    with RufletStoreMixin {
  static const _equality = DeepCollectionEquality();

  /// The current ad, or null after it failed to load.
  BannerAd? _bannerAd;

  /// What the current ad was requested with.
  String? _adUnitId;
  Object? _request;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void didUpdateWidget(covariant BannerAdControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_unitId() != _adUnitId ||
        !_equality.equals(_snapshot(widget.control.get("request")), _request)) {
      _disposeAd();
      _loadAd();
    }
  }

  @override
  void dispose() {
    _disposeAd();
    super.dispose();
  }

  String _unitId() {
    final testAdUnitId = isIOSMobile()
        ? 'ca-app-pub-3940256099942544/4411468910'
        : 'ca-app-pub-3940256099942544/1033173712';
    return widget.control.getString("unit_id", testAdUnitId)!;
  }

  /// A copy of a raw property value: patches change nested maps in place.
  static Object? _snapshot(Object? value) => switch (value) {
        Map map => {
            for (final entry in map.entries) entry.key: _snapshot(entry.value)
          },
        List list => [for (final item in list) _snapshot(item)],
        _ => value,
      };

  void _loadAd() {
    _adUnitId = _unitId();
    _request = _snapshot(widget.control.get("request"));
    final bannerAd = BannerAd(
      adUnitId: _adUnitId!,
      request:
          parseAdRequest(widget.control.get("request"), const AdRequest())!,
      size: AdSize.banner,
      listener: BannerAdListener(
        // Called when an ad is successfully received.
        onAdLoaded: (ad) {
          widget.control.triggerEvent("load");
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (ad, error) {
          widget.control.triggerEvent("error", error.toString());
          // Dispose the ad to free resources. Requesting another one right
          // away would repeat the failure (no fill, no network) in a loop.
          ad.dispose();
          if (mounted && identical(ad, _bannerAd)) {
            setState(() {
              _bannerAd = null;
            });
          }
        },
        // Called when an ad opens an overlay that covers the screen.
        onAdOpened: (Ad ad) {
          widget.control.triggerEvent("open");
        },
        // Called when an ad removes an overlay that covers the screen.
        onAdClosed: (Ad ad) {
          widget.control.triggerEvent("close");
        },
        onAdClicked: (Ad ad) {
          widget.control.triggerEvent("click");
        },
        onAdWillDismissScreen: (Ad ad) {
          widget.control.triggerEvent("will_dismiss");
        },
        onPaidEvent: (ad, double valueMicros, PrecisionType precision,
            String currencyCode) {
          widget.control.triggerEvent("paid", {
            "value": valueMicros,
            "precision": precision.name,
            "currency_code": currencyCode
          });
        },
        // Called when an impression occurs on the ad.
        onAdImpression: (Ad ad) {
          widget.control.triggerEvent("impression");
        },
      ),
    );
    _bannerAd = bannerAd;
    bannerAd.load();
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        "BannerAd build: ${widget.control.id} (${widget.control.hashCode})");
    final bannerAd = _bannerAd;
    return LayoutControl(
        control: widget.control,
        child: bannerAd == null
            // The space the ad view took: a platform view fills its
            // constraints.
            ? const SizedBox.expand()
            // A global key moves the ad view when Ruby adds or removes a
            // wrapper (opacity, tooltip, rtl, ...) instead of mounting a
            // second AdWidget for the same ad, which AdWidget rejects.
            : AdWidget(key: GlobalObjectKey(bannerAd), ad: bannerAd));
  }
}
