import SwiftUI

/// Reusable view for Live Screen Drawing and Web Annotation.
/// Clear distinction between:
/// 1) Live Screen Drawing (Telestrator overlay across screen)
/// 2) Browse & Draw in Web (Standalone in-app browser with canvas)
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
            VStack(spacing: 16) {
                liveScreenDrawingCard
                browseAndDrawCard
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                liveScreenDrawingListRow
                Divider()
                browseAndDrawListRow
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Section 1: Live Screen Drawing Card
    private var liveScreenDrawingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "scribble.variable")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Live Screen Drawing")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Toggle("", isOn: $isDrawingActive)
                            .labelsHidden()
                    }

                    Text("Overlay a floating telestrator toolbar on your screen to sketch, annotate, or circle items while broadcasting.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
            }

            if isDrawingActive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Drawing Overlay Active")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDrawingActive ? Color.purple.opacity(0.35) : Color.purple.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    // MARK: - Section 2: Browse and Draw in Web Card
    private var browseAndDrawCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "safari.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Browse & Draw in Web")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Launch an independent, integrated web browser with drawing tools to navigate any webpage and annotate content directly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
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
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    // MARK: - List Row Style (for SettingsView)
    private var liveScreenDrawingListRow: some View {
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
    }

    private var browseAndDrawListRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "safari.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Browse & Draw in Web")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                    Text("In-app browser with overlay annotation tools")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        }
    }
}
