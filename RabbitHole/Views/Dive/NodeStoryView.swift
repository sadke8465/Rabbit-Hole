import SwiftUI

struct NodeStoryView: View {
    let node: Node
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(node.title)
                .font(.system(size: 26, weight: .bold, design: .serif))

            if isLoading || node.story.isEmpty {
                storyLoadingPlaceholder
            } else {
                Text(node.story)
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var storyLoadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([1.0, 0.9, 0.95, 0.7], id: \.self) { width in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.tertiarySystemFill))
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
                    .scaleEffect(x: width, anchor: .leading)
                    .shimmer()
            }
        }
    }
}
