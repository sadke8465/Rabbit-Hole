import SwiftUI

struct DailySurfaceCardView: View {
    let card: DailySurfaceCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.caption.weight(.semibold))
                    Text(typeLabel)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .foregroundStyle(accentColor)

                Text(card.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Text(card.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 240, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch card.type {
        case .forgottenThread:  return "clock"
        case .unexpectedBridge: return "arrow.triangle.branch"
        case .roadNotTaken:     return "arrow.turn.right.down"
        case .domainPortrait:   return "chart.bar"
        case .dormantDive:      return "moon.zzz"
        }
    }

    private var typeLabel: String {
        switch card.type {
        case .forgottenThread:  return "Forgotten"
        case .unexpectedBridge: return "Bridge"
        case .roadNotTaken:     return "Road not taken"
        case .domainPortrait:   return "This week"
        case .dormantDive:      return "Dormant"
        }
    }

    private var accentColor: Color {
        switch card.type {
        case .forgottenThread:  return .orange
        case .unexpectedBridge: return .purple
        case .roadNotTaken:     return .red
        case .domainPortrait:   return .blue
        case .dormantDive:      return .indigo
        }
    }
}
