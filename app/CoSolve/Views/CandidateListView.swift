import SwiftUI

struct CandidateListView: View {
    @EnvironmentObject var store: SolverStore

    var body: some View {
        GroupBox("Candidates") {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(store.candidates.count) candidate(s)")
                    .font(.subheadline.weight(.semibold))

                List(store.candidates, id: \.self) { word in
                    HStack {
                        Text(word.uppercased())
                            .font(.system(.subheadline, design: .monospaced))
                        Spacer()
                        if let zipf = store.zipf(for: word) {
                            Text("Zipf \(zipf, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No frequency data")
                                .foregroundStyle(.tertiary)
                        }
                        Text("\(store.commonness(for: word), specifier: "%.0f")")
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                    .font(.footnote)
                }
                .frame(minHeight: 220)
            }
            .padding(.top, 4)
        }
    }
}
