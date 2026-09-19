import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SolverStore

    var body: some View {
        Form {
            Section("Recommendation weighting") {
                Slider(value: $store.informationWeight, in: 0...1, step: 0.05)
                Text("Information: \(Int(store.informationWeight * 100))%")
                Text("Commonness: \(Int((1 - store.informationWeight) * 100))%")
                Text("Known-frequency preference: +6 percentage points")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
