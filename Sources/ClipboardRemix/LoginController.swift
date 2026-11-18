import AppKit
import SwiftUI
import ServiceManagement
import ClipboardCore

@MainActor final class LoginController: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var error: String?
    var registered: Bool { status == .enabled || status == .requiresApproval }
    var installed: Bool {
        AppLocations.supportsLogin(bundleURL: Bundle.main.bundleURL)
    }
    var summary: String {
        switch status {
        case .enabled: return "Launch at Login: On"
        case .requiresApproval: return "Launch at Login: Approval required in System Settings"
        case .notRegistered: return "Launch at Login: Off"
        case .notFound: return "Launch at Login: Service not found (not enabled)"
        @unknown default: return "Launch at Login: Unknown system status"
        }
    }
    func refresh() { status = SMAppService.mainApp.status }
    func toggle() {
        refresh()
        guard registered || installed else {
            error = "Move Clipboard Remix to Applications or your home Applications folder, quit this copy, and open the installed app before enabling Launch at Login."
            return
        }
        do {
            if registered { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            error = nil
        } catch {
            self.error = "Could not change Launch at Login: \(error.localizedDescription). Open Login Items settings to review approval; run the signed installed app and try again."
        }
        refresh()
    }
}

struct LoginMenu: View {
    @ObservedObject var controller: LoginController
    var body: some View {
        Text(controller.summary)
        Button(controller.registered ? "Disable Launch at Login" : "Enable Launch at Login") { controller.toggle() }
        if !controller.installed {
            Text("Requires installation in Applications or ~/Applications")
        }
        if let error = controller.error { Text(error) }
        Button("Refresh Login Status") { controller.refresh() }
        Button("Open Login Items Settings") { SMAppService.openSystemSettingsLoginItems() }
    }
}
