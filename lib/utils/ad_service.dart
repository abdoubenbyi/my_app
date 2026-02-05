import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  final _startAppSdk = StartAppSdk();
  StartAppRewardedVideoAd? _rewardedVideoAd;

  // Track callbacks for the currently loaded ad
  VoidCallback? _onVideoCompleted;
  VoidCallback? _onAdClosed;

  // IMPORTANT: Replace with your actual StartApp App ID
  // You can find this in your StartApp portal
  Future<void> init() async {
    // Enable test mode during development
    // TODO: Remove this before production release
    await _startAppSdk.setTestAdsEnabled(true);

    // Pre-load an ad
    loadRewardedVideoAd();
  }

  // Banners
  Future<StartAppBannerAd> loadBannerAd(StartAppBannerType type) {
    return _startAppSdk.loadBannerAd(type);
  }

  // Rewarded Video
  void loadRewardedVideoAd() {
    _startAppSdk
        .loadRewardedVideoAd(
          onVideoCompleted: () {
            print('AdService: Video completed');
            _onVideoCompleted?.call();
          },
          onAdHidden: () {
            print('AdService: Ad closed (hidden)');
            _onAdClosed?.call();
            _rewardedVideoAd = null;
            loadRewardedVideoAd(); // Load next ad
          },
          onAdNotDisplayed: () {
            print('AdService: Ad not displayed');
            _onAdClosed?.call();
            _rewardedVideoAd = null;
            loadRewardedVideoAd();
          },
          onAdClicked: () {
            print('AdService: Ad clicked');
          },
          onAdImpression: () {
            print('AdService: Ad impression');
          },
        )
        .then((ad) {
          _rewardedVideoAd = ad;
        })
        .catchError((error) {
          print('AdService: Failed to load rewarded video ad: $error');
          _rewardedVideoAd = null;
        });
  }

  void showRewardedVideoAd({
    VoidCallback? onVideoCompleted,
    VoidCallback? onAdClosed,
  }) {
    final ad = _rewardedVideoAd;
    if (ad != null) {
      _onVideoCompleted = onVideoCompleted;
      _onAdClosed = onAdClosed;
      ad.show();
    } else {
      print('AdService: Ad not ready');
      loadRewardedVideoAd(); // Try loading again
      onAdClosed
          ?.call(); // Still trigger close callback so navigation isn't blocked
    }
  }
}

// Global instance
final adService = AdService();
