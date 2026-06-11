import InputoComposerFeature
import SwiftUI

@main
struct InputoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(appState: AppState.shared)
                .frame(width: 560, height: 620)
        }
    }
}
