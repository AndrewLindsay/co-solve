import SwiftUI

struct RecommendationView: View {
    @EnvironmentObject var store: SolverStore

    var body: some View {
        GroupBox("Recommendation Ranking") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Information")
                    Slider(value: $store.informationWeight, in: 0...1, step: 0.05)
                    Text("\(Int(store.informationWeight * 100))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                    Text("Commonness \(Int((1 - store.informationWeight) * 100))%")
                        .monospacedDigit()
                }

                Text("Commonness uses the effective Zipf metric. Candidates with measured frequency data receive a small +6% ranking preference. Frequency changes ranking only; it never removes a valid candidate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Recommend Best Guess") { store.recommend() }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.candidates.isEmpty || store.isBusy)
                    Button("Update Commonness Data") { store.downloadFrequencyData() }
                        .disabled(store.isBusy)
                }

                if store.isBusy {
                    ProgressView()
                }

                if let first = store.recommendations.first {
                    Text("Best next guess: \(first.word.uppercased())")
                        .font(.subheadline.weight(.semibold))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            store.useSuggestedWord(first.word)
                        }
                        .help("Double-click to copy this word to the guess field")
                }

                if !store.recommendations.isEmpty {
                    Text("Double-click / double-tap a suggested word to copy it to the guess field.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    #if os(macOS)
                    Table(store.recommendations) {
                        TableColumn("Word") { rec in
                            Text(rec.word.uppercased())
                                .monospaced()
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    store.useSuggestedWord(rec.word)
                                }
                                .help("Double-click to copy to the guess field")
                        }
                        TableColumn("Score") { rec in Text(rec.combinedScore, format: .number.precision(.fractionLength(1)).scale(100)).monospacedDigit() }
                        TableColumn("Info") { rec in Text(rec.informationBits, format: .number.precision(.fractionLength(2))).monospacedDigit() }
                        TableColumn("Zipf") { rec in Text(zipfText(rec.zipf)).monospacedDigit() }
                        TableColumn("Common") { rec in Text(rec.commonness, format: .number.precision(.fractionLength(1))).monospacedDigit() }
                    }
                    .frame(minHeight: 220)
                    #else
                    VStack(spacing: 0) {
                        ForEach(store.recommendations.prefix(10)) { rec in
                            HStack {
                                Text(rec.word.uppercased())
                                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                Spacer()
                                Text("Zipf \(zipfText(rec.zipf))")
                                Text("Common \(rec.commonness, specifier: "%.0f")")
                            }
                            .font(.caption)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                store.useSuggestedWord(rec.word)
                            }
                            Divider()
                        }
                    }
                    #endif
                }
            }
            .padding(.top, 4)
        }
    }

    private func zipfText(_ zipf: Double?) -> String {
        guard let zipf else { return "n/a" }
        return String(format: "%.2f", zipf)
    }
}
