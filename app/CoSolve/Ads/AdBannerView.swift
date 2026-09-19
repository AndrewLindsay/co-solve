#if os(iOS)
import SwiftUI
import GoogleMobileAds
import UIKit

struct CoSolveBanner: View {
    var body: some View {
        BannerViewContainer()
            .frame(width: 320, height: 50)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Advertisement")
    }
}

private struct BannerViewContainer: UIViewRepresentable {

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)

        banner.adUnitID = AdConfiguration.bannerUnitID
        
        banner.rootViewController =
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController

        banner.load(Request())

        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // Fixed 320 x 50 banner — nothing to resize.
    }
}
#endif
