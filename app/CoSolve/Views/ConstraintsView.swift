import SwiftUI

struct ConstraintsView: View {
    @EnvironmentObject var store: SolverStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GroupBox("Direct Constraints / Guess Summary") {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            constraintField(
                title: "Pattern",
                text: $store.pattern,
                hint: "Example: \(store.gameMode.patternExample)",
                monospaced: true,
                isPattern: true
            )
            constraintField(
                title: "Required letters",
                text: $store.requiredLetters,
                hint: "Repeated letters are significant"
            )
            constraintField(
                title: "Excluded letters",
                text: $store.excludedLetters,
                hint: "Letters known to be absent"
            )
        }
        .padding(.top, 4)
    }

    private var regularLayout: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("Pattern").font(.subheadline)
                patternField
                Text("Example: \(store.gameMode.patternExample)")
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Required").font(.subheadline)
                requiredField
                Text("Repeated letters are significant")
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Excluded").font(.subheadline)
                excludedField
                Text("Letters known to be absent")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func constraintField(
        title: String,
        text: Binding<String>,
        hint: String,
        monospaced: Bool = false,
        isPattern: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(monospaced ? .system(.subheadline, design: .monospaced) : .subheadline)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if isPattern {
                        let allowed = newValue.filter { $0.isLetter || "-_?.".contains($0) }
                        let cleaned = String(allowed.prefix(store.wordLength)).uppercased()
                        if cleaned != newValue { text.wrappedValue = cleaned }
                    }
                    store.applyFilters()
                }

            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var patternField: some View {
        TextField("", text: $store.pattern)
            .textFieldStyle(.roundedBorder)
            .font(.system(.subheadline, design: .monospaced))
            .onChange(of: store.pattern) { _, newValue in
                let allowed = newValue.filter { $0.isLetter || "-_?.".contains($0) }
                let cleaned = String(allowed.prefix(store.wordLength)).uppercased()
                if cleaned != newValue { store.pattern = cleaned }
                store.applyFilters()
            }
    }

    private var requiredField: some View {
        TextField("", text: $store.requiredLetters)
            .textFieldStyle(.roundedBorder)
            .onChange(of: store.requiredLetters) { _, _ in store.applyFilters() }
    }

    private var excludedField: some View {
        TextField("", text: $store.excludedLetters)
            .textFieldStyle(.roundedBorder)
            .onChange(of: store.excludedLetters) { _, _ in store.applyFilters() }
    }
}
