import SwiftUI
#if os(iOS)
import CoreMotion
#endif

struct GuessEntryView: View {
    @EnvironmentObject var store: SolverStore
    @State private var showUndoConfirmation = false
    #if os(iOS)
    @StateObject private var shakeMonitor = ShakeMonitor()
    #endif

    var body: some View {
        GroupBox("Guess Feedback") {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 10) {
                        guessField
                        addButton
                        undoButton
                        resetButton
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        guessField

                        HStack(spacing: 10) {
                            addButton
                            undoButton
                            resetButton
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GeometryReader { proxy in
                    let spacing: CGFloat = 8
                    let length = store.wordLength
                    let tileSize = min(54, max(36, (proxy.size.width - spacing * CGFloat(length - 1)) / CGFloat(length)))

                    HStack(spacing: spacing) {
                        ForEach(0..<length, id: \.self) { index in
                            let chars = Array(store.currentGuess)
                            TileView(
                                letter: index < chars.count ? chars[index] : nil,
                                state: $store.tileStates[index],
                                size: tileSize
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 58)

                if !store.history.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(store.history) { guess in
                            HStack(spacing: 8) {
                                Text(guess.word.uppercased())
                                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                ForEach(0..<min(guess.feedback.count, store.wordLength), id: \.self) { i in
                                    Circle()
                                        .fill(color(for: guess.feedback[i]))
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 4)
        }
        #if os(iOS)
        .onAppear {
            shakeMonitor.onShake = {
                guard !store.history.isEmpty else { return }
                showUndoConfirmation = true
            }
            shakeMonitor.start()
        }
        .onDisappear {
            shakeMonitor.stop()
        }
        .alert("Undo Last Guess?", isPresented: $showUndoConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Undo") {
                store.undoLastGuess()
            }
        } message: {
            if let lastGuess = store.history.last {
                Text("Remove \(lastGuess.word.uppercased()) and return to the previous solver state?")
            } else {
                Text("Remove the most recent guess and return to the previous solver state?")
            }
        }
        #endif
    }

    private var guessField: some View {
        TextField(store.gameMode.guessPlaceholder, text: $store.currentGuess)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            #endif
            .onChange(of: store.currentGuess) { _, newValue in
                let cleaned = String(newValue.filter { $0.isLetter }.prefix(store.wordLength)).uppercased()
                if cleaned != newValue { store.currentGuess = cleaned }
            }
            .onSubmit { store.addGuess() }
    }

    private var addButton: some View {
        Button("Add Guess") { store.addGuess() }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
    }

    private var undoButton: some View {
        Button {
            store.undoLastGuess()
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(store.history.isEmpty)
        .help("Remove the last guess and restore the previous solver state")
    }

    private var resetButton: some View {
        Button("Reset", role: .destructive) {
            store.reset()
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private func color(for state: TileState) -> Color {
        switch state {
        case .grey: return Color(red: 0.47, green: 0.49, blue: 0.50)
        case .yellow: return Color(red: 0.79, green: 0.71, blue: 0.35)
        case .green: return Color(red: 0.42, green: 0.67, blue: 0.39)
        }
    }
}

#if os(iOS)
private final class ShakeMonitor: ObservableObject {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var lastShakeTime = Date.distantPast

    var onShake: (() -> Void)?

    init() {
        queue.name = "CoSolve.ShakeMonitor"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
    }

    func start() {
        // SwiftUI Canvas previews do not need physical shake detection.
        // Avoid starting CoreMotion while Xcode is rendering previews.
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        guard motionManager.isAccelerometerAvailable, !motionManager.isAccelerometerActive else { return }

        motionManager.accelerometerUpdateInterval = 0.08
        motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let acceleration = data?.acceleration else { return }

            // A deliberate shake typically produces a combined acceleration well
            // above normal handling.  Debouncing prevents one shake from opening
            // the confirmation alert more than once.
            let magnitudeSquared =
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z

            guard magnitudeSquared >= 6.25 else { return } // 2.5 g threshold
            let now = Date()
            guard now.timeIntervalSince(self.lastShakeTime) >= 0.9 else { return }
            self.lastShakeTime = now

            DispatchQueue.main.async { [weak self] in
                self?.onShake?()
            }
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
    }

    deinit {
        motionManager.stopAccelerometerUpdates()
    }
}
#endif
