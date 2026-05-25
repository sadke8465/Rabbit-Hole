import SwiftUI

struct DiveRowView: View {
    let dive: Dive

    var body: some View {
        HStack(spacing: 14) {
            // Visual indicator dot
            Circle()
                .fill(dive.isDormant ? Color.secondary.opacity(0.4) : Color.primary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(dive.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text("\(dive.nodeCount) nodes")
                    Text("·")
                    Text(relativeTime)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if dive.isDormant {
                Text("Dormant")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: dive.lastActiveAt, relativeTo: Date())
    }
}
