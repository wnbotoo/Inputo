import InputoComposerFeature
import SwiftUI

@main
struct InputoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(appState: AppState.shared)
                .frame(width: SettingsView.preferredSize.width, height: SettingsView.preferredSize.height)
        }
    }
}
