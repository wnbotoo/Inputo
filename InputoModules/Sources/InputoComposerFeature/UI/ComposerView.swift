import InputoMacPlatform
import SwiftUI

public struct ComposerView: View {
    @ObservedObject public var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 6) {
                header
                if let providerSetupMessage = appState.providerSetupMessage {
                    ProviderSetupBanner(appState: appState, message: providerSetupMessage)
                }
                AnchorBarView(appState: appState)
                composerBody
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .ignoresSafeArea(.container, edges: .top)
        }
    }

    @ViewBuilder
    private var composerBody: some View {
        if InputoWebComposerAssets.areBundled {
            InputoWebComposerView(appState: appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            MissingWebComposerAssetsView()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("Inputo", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button {
                appState.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Settings")
        }
    }
}

private struct ProviderSetupBanner: View {
    @ObservedObject var appState: AppState
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Provider setup needed")
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                appState.openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AnchorBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            Label("Jump", systemImage: "arrowshape.turn.up.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            if appState.anchors.isEmpty {
                Text("No anchors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(appState.anchors) { anchor in
                            Button {
                                appState.requestActivate(anchor: anchor)
                            } label: {
                                HStack(spacing: 7) {
                                    if let icon = anchor.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 18, height: 18)
                                    } else {
                                        Image(systemName: "app")
                                    }
                                    Text(anchor.appName)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            .fixedSize(horizontal: true, vertical: false)
                            .help("Switch to \(anchor.appName)")
                        }
                    }
                }
                .frame(height: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                appState.refreshAnchors()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Refresh app anchors")
        }
    }
}

private struct MissingWebComposerAssetsView: View {
    var body: some View {
        ContentUnavailableView(
            "Composer assets missing",
            systemImage: "exclamationmark.triangle",
            description: Text("The bundled WebComposer resources were not found.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
