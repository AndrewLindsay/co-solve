import SwiftUI

struct TileView: View {
    let letter: Character?
    @Binding var state: TileState
    var size: CGFloat = 50

    var body: some View {
        Button {
            state = state.next
        } label: {
            Text(letter.map { String($0).uppercased() } ?? " ")
                .font(.system(size: max(18, size * 0.48), weight: .bold, design: .rounded))
                .frame(width: size, height: size)
                .foregroundStyle(.white)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: min(8, size * 0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(letter.map { String($0) } ?? "blank") tile, \(state.label)")
        .help("Click to cycle Grey → Yellow → Green")
    }

    private var backgroundColor: Color {
        switch state {
        case .grey: return Color(red: 0.47, green: 0.49, blue: 0.50)
        case .yellow: return Color(red: 0.79, green: 0.71, blue: 0.35)
        case .green: return Color(red: 0.42, green: 0.67, blue: 0.39)
        }
    }
}
