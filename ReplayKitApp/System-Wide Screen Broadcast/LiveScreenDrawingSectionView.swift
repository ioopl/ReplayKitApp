import SwiftUI

/// Reusable section/card for Live Screen Drawing and Web Annotation.
/// Can be used as a standalone styled card or embedded inside Settings lists.
public struct LiveScreenDrawingSectionView: View {
    @Binding var isDrawingActive: Bool
    var onBrowseAndDraw: () -> Void
    var isCardStyle: Bool

    public init(
        isDrawingActive: Binding<Bool>,
        onBrowseAndDraw: @escaping () -> Void,
        isCardStyle: Bool = true
    ) {
        self._isDrawingActive = isDrawingActive
        self.onBrowseAndDraw = onBrowseAndDraw
        self.isCardStyle = isCardStyle
    }

    public var body: some View {
        if isCardStyle {
            cardContent
        } else {
            listContent
        }
    }

    // MARK: - Card Style (for SystemWideScreenBroadcastView)
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "scribble.variable")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Screen Drawing")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Draw notes, circle items, or sketch on screen while broadcasting.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: $isDrawingActive)
                    .labelsHidden()
            }

            Button(action: onBrowseAndDraw) {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                        .font(.subheadline.weight(.semibold))
                    Text("Browse and Draw in Web")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.green)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    // MARK: - List Row Style (for SettingsView)
    private var listContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isDrawingActive) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "scribble.variable")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.purple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Screen Drawing")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        Text("Enable telestrator tools to sketch over apps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button(action: onBrowseAndDraw) {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                        .font(.subheadline.weight(.semibold))
                    Text("Browse and Draw in Web")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.green)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}
