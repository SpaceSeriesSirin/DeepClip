import Foundation
import ServiceManagement

/// Registers/unregisters the app as a macOS Login Item via SMAppService
/// (SPEC Phase 6). Requires a proper `.app` bundle to fully function; during
/// `swift run` development the calls may throw, which we surface gracefully.
@MainActor
enum AutoStartService {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "Enabled"
        case .notRegistered: return "Not Registered"
        case .requiresApproval: return "Requires Approval in System Settings"
        case .notFound: return "Not Found"
        @unknown default: return "Unknown"
        }
    }

    /// Returns true on success. Throws the underlying error on failure.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
