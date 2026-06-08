import SwiftUI
import AppKit
import Carbon

/// A "click to record" control that captures the next key combination the user
/// presses and reports it back as a (keyCode, modifiers) pair.
///
/// While idle it shows the current shortcut (e.g. "⌘⇧V"). While recording it
/// shows a prompt and listens for the next keyDown with at least one modifier.
struct HotkeyRecorderView: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    @State private var isRecording = false

    private var displayString: String {
        HotkeyService.displayString(
            keyCode: keyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        )
    }

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(isRecording ? "Press shortcut…" : displayString)
                .frame(minWidth: 110)
                .monospaced()
        }
        .overlay(
            // Invisible key catcher that becomes first responder while recording.
            KeyCaptureView(isRecording: $isRecording) { code, mods in
                keyCode = code
                modifiers = Int(mods.rawValue)
                isRecording = false
            }
            .allowsHitTesting(false)
        )
        .help("Click, then press the key combination you want to use.")
    }
}

/// AppKit bridge that installs a local event monitor while `isRecording` is true
/// and captures the first key combination that includes a modifier.
private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (Int, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onCapture = onCapture
        context.coordinator.setRecording(isRecording)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onCapture: ((Int, NSEvent.ModifierFlags) -> Void)?
        private var monitor: Any?

        func attach(to view: NSView) {}

        func setRecording(_ recording: Bool) {
            if recording {
                startMonitor()
            } else {
                stopMonitor()
            }
        }

        private func startMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }

                // Escape cancels recording without changing anything.
                if event.keyCode == 53 { // kVK_Escape
                    self.stopMonitor()
                    return nil
                }

                let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
                // Require at least one modifier to avoid capturing plain keys.
                guard !mods.isEmpty else { return nil }

                self.onCapture?(Int(event.keyCode), mods)
                self.stopMonitor()
                return nil // Swallow the event.
            }
        }

        private func stopMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit { stopMonitor() }
    }
}
