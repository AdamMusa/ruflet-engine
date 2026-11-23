import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../utils/ads.dart';

class InterstitialAdService extends RufletService {
  InterstitialAdService({required super.control});

  /// This control's ad: set when it loads, cleared when it is disposed.
  /// Each InterstitialAd control owns its own ad.
  InterstitialAd? _interstitialAd;
  bool _disposed = false;

  @override
  void init() {
    super.init();
    debugPrint("InterstitialAd(${control.id}).init: ${control.properties}");
    control.addInvokeMethodListener(_invokeMethod);

    InterstitialAd.load(
        adUnitId: control.getString(
            "unit_id",
            isIOSMobile()
                ? 'ca-app-pub-3940256099942544/4411468910'
                : 'ca-app-pub-3940256099942544/1033173712')!,
        request: parseAdRequest(control.get("request"), const AdRequest())!,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed) {
              // Ruby removed the control while the ad loaded.
              ad.dispose();
              return;
            }
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) => control.triggerEvent("open"),
              onAdImpression: (ad) => control.triggerEvent("impression"),
              onAdFailedToShowFullScreenContent: (ad, error) {
                control.triggerEvent("error", error.toString());
                _disposeAd(ad); // free resources
              },
              onAdDismissedFullScreenContent: (ad) {
                // Called when the ad dismissed full screen content.
                control.triggerEvent("close");
                // Dispose the ad here to free resources.
                _disposeAd(ad);
              },
              onAdClicked: (ad) => control.triggerEvent("click"),
            );

            // Keep a reference to show it later.
            _interstitialAd = ad;
            control.triggerEvent("load");
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (_disposed) return;
            control.triggerEvent("error", error.toString());
          },
        ));
  }

  /// Disposes [ad] and forgets it, so `show` never shows a disposed ad.
  void _disposeAd(InterstitialAd ad) {
    if (identical(ad, _interstitialAd)) _interstitialAd = null;
    ad.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("InterstitialAd.$name($args)");
    switch (name) {
      case "show":
        _interstitialAd?.show();
        return null;
      default:
        throw Exception("Unknown InterstitialAd method: $name");
    }
  }

  @override
  void dispose() {
    _disposed = true;
    control.removeInvokeMethodListener(_invokeMethod);
    _interstitialAd?.dispose();
    _interstitialAd = null;
    super.dispose();
  }
}
