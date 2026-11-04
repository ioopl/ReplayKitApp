import SwiftUI
import ReplayKit

// MARK: - Native ReplayKit Broadcast Picker Representable
/**
    BroadcastPickerRepresentable – responsible for presenting Apple's native broadcast controls.
 */
struct BroadcastPickerRepresentable: UIViewRepresentable {
    let trigger: Int

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = CustomBroadcastPickerView(frame: .zero)
        picker.showsMicrophoneButton = true
        picker.preferredExtension = "com.apkia.replaykitapp.BroadcastExtension"
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView,
                      context: Context) {
        guard let picker = uiView as? CustomBroadcastPickerView else { return }

        guard picker.lastTrigger != trigger else { return }

        picker.lastTrigger = trigger
        picker.triggerBroadcastPicker()
    }
}

final class CustomBroadcastPickerView: RPSystemBroadcastPickerView {

    var lastTrigger = 0

    override func layoutSubviews() {
        super.layoutSubviews()

        for subview in subviews {
            if let button = subview as? UIButton {
                button.frame = bounds
            }
        }
    }

    func triggerBroadcastPicker() {
        layoutIfNeeded()

        for subview in subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                return
            }
        }
    }
}
