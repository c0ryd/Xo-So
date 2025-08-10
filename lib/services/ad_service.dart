import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // Replace with your actual Android ad unit ID
      return 'ca-app-pub-3940256099942544/6300978111'; // Test ad unit ID
    } else if (Platform.isIOS) {
      // Replace with your actual iOS ad unit ID
      return 'ca-app-pub-3940256099942544/2934735716'; // Test ad unit ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static BannerAd createBannerAd({
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
        onAdOpened: (Ad ad) => print('BannerAd onAdOpened'),
        onAdClosed: (Ad ad) => print('BannerAd onAdClosed'),
        onAdImpression: (Ad ad) => print('BannerAd impression recorded'),
      ),
    );
  }
}
