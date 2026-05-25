import SwiftUI

struct ConnectionCardView: View {
    let connection: ScoredConnection
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                // Tier indicator
                Circle()
                    .fill(tierColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    Text(connection.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(connection.sentence)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tierColor.opacity(isPressed ? 0.5 : 0.15), lineWidth: 1.5)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, perform: {}) { pressing in
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = pressing }
        }
    }

    private var tierColor: Color {
        switch connection.tier {
        case .closelyRelated: return .blue
        case .unexpectedAngle: return .yellow
        case .rabbitHole: return .red
        }
    }
}
