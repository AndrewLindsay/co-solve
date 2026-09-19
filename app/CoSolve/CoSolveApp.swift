import SwiftUI
#if os(iOS)
import UIKit
import AppTrackingTransparency
#endif

@main
struct CoSolveApp: App {
    @StateObject private var store = SolverStore()
    #if os(iOS)
    @StateObject private var consentManager = GoogleMobileAdsConsentManager()
    #endif

    init() {
        #if os(iOS)
        // Prevent the system's text-editing shake alert from competing with
        // Co-Solve's own confirmed Undo Last Guess action.
        UIApplication.shared.applicationSupportsShakeToEdit = false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            CoSolveRootView()
                .environmentObject(store)
                .environmentObject(consentManager)
                .task {
                    // Build 4 privacy gate:
                    // Resolve Apple's ATT permission BEFORE invoking UMP or the
                    // Google Mobile Ads SDK. This makes the ordering explicit:
                    // ATT -> UMP/legal consent -> ad SDK/ad requests.
                    await requestATTBeforeThirdPartyAdvertisingSDKs()
                    await consentManager.gatherConsentAndStartAds()
                }
            #else
            ContentView()
                .environmentObject(store)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 820)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo Last Guess") {
                    store.undoLastGuess()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(store.history.isEmpty)
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 420, height: 220)
        }
        #endif
    }

    #if os(iOS)
    @MainActor
    private func requestATTBeforeThirdPartyAdvertisingSDKs() async {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        print("[ATT] Pre-SDK gate status: \(currentStatus.rawValue)")

        guard currentStatus == .notDetermined else {
            print("[ATT] Pre-SDK gate already resolved")
            return
        }

        // ATT only presents while the app is active. Yield once so the first
        // SwiftUI scene has completed presentation before requesting it.
        await Task.yield()

        let status = await ATTrackingManager.requestTrackingAuthorization()
        print("[ATT] Pre-SDK gate completed: \(status.rawValue)")
    }
    #endif
}

#if os(iOS)
// MARK: - Animated iOS splash

/// The real iOS LaunchScreen.storyboard must remain static. This view appears
/// immediately afterwards and performs the short Co-Solve animation before
/// revealing the normal solver interface.
private struct CoSolveRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView()

            if showSplash {
                CoSolveAnimatedSplash(reduceMotion: reduceMotion) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}

private struct CoSolveAnimatedSplash: View {
    let reduceMotion: Bool
    let completion: () -> Void

    @State private var gridOpacity = 0.0
    @State private var coloredTiles = false
    @State private var splashOpacity = 1.0

    // A restrained pattern: yellow = present, green = correct.
    private let yellowTiles: Set<Int> = [3, 13]
    private let greenTiles: Set<Int> = [7, 16]

    var body: some View {
        GeometryReader { proxy in
            let tileSize = min(max((proxy.size.width - 96) / 6.0, 34), 52)

            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 70)

                    CoSolveSplashLogo()

                    Text("Smarter guesses. More wins.")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 22)

                    VStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 7) {
                                ForEach(0..<6, id: \.self) { column in
                                    let index = row * 6 + column
                                    CoSolveSplashTile(
                                        size: tileSize,
                                        target: targetColor(for: index),
                                        revealColor: coloredTiles,
                                        delay: Double(index) * 0.025,
                                        reduceMotion: reduceMotion
                                    )
                                }
                            }
                        }
                    }
                    .opacity(gridOpacity)
                    .padding(.top, 34)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .opacity(splashOpacity)
        .task {
            await runSequence()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func targetColor(for index: Int) -> Color {
        if yellowTiles.contains(index) { return Color(red: 0.79, green: 0.65, blue: 0.20) }
        if greenTiles.contains(index) { return Color(red: 0.36, green: 0.64, blue: 0.38) }
        return Color(.systemGray4)
    }

    @MainActor
    private func runSequence() async {
        if reduceMotion {
            gridOpacity = 1
            coloredTiles = true
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.25)) { splashOpacity = 0 }
            try? await Task.sleep(for: .seconds(0.25))
            completion()
            return
        }

        // 1. Three rows of grey tiles fade in.
        withAnimation(.easeOut(duration: 0.35)) {
            gridOpacity = 1
        }
        try? await Task.sleep(for: .seconds(0.45))

        // 2. Selected tiles flip to yellow/green.
        coloredTiles = true
        try? await Task.sleep(for: .seconds(1.45))

        // 3. Flip the coloured tiles back to grey.
        coloredTiles = false
        try? await Task.sleep(for: .seconds(0.85))

        // 4. Dissolve the splash into the solver.
        withAnimation(.easeOut(duration: 0.45)) {
            splashOpacity = 0
        }
        try? await Task.sleep(for: .seconds(0.45))
        completion()
    }
}

private struct CoSolveSplashLogo: View {
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 0) {
                Text("Co-")
                    .foregroundStyle(Color.primary)
                Text("Solve")
                    .foregroundStyle(Color.accentColor)
            }
            .font(.system(size: 46, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.75)
            .lineLimit(1)

            Capsule()
                .fill(Color.accentColor.opacity(0.75))
                .frame(width: 190, height: 3)
        }
    }
}

private struct CoSolveSplashTile: View {
    let size: CGFloat
    let target: Color
    let revealColor: Bool
    let delay: Double
    let reduceMotion: Bool

    @State private var shownColor: Color = Color(.systemGray4)
    @State private var angle = 0.0

    var body: some View {
        RoundedRectangle(cornerRadius: max(5, size * 0.12), style: .continuous)
            .fill(shownColor)
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: max(5, size * 0.12), style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
            .shadow(color: Color.black.opacity(0.055), radius: 2.5, y: 1.5)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .onChange(of: revealColor) { _, newValue in
                guard target != Color(.systemGray4) else { return }

                if reduceMotion {
                    shownColor = newValue ? target : Color(.systemGray4)
                    return
                }

                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))

                    // First half of the flip.
                    withAnimation(.easeIn(duration: 0.16)) {
                        angle = 90
                    }
                    try? await Task.sleep(for: .seconds(0.16))

                    // Swap the face while the tile is edge-on.
                    shownColor = newValue ? target : Color(.systemGray4)
                    angle = -90

                    // Second half of the flip.
                    withAnimation(.easeOut(duration: 0.18)) {
                        angle = 0
                    }
                }
            }
    }
}
#endif

#if os(iOS)
#Preview("Co-Solve Animated Splash") {
    CoSolveAnimatedSplash(reduceMotion: false) { }
}
#endif
