import Foundation

public enum InputoWebComposerAssets {
    public static let directoryName = "WebComposer"
    public static let remoteContentBlockRuleList = """
    [
      {
        "trigger": {
          "url-filter": "https?://.*"
        },
        "action": {
          "type": "block"
        }
      }
    ]
    """

    public static var indexURL: URL? {
        Bundle.module.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: directoryName
        )
    }

    public static var readAccessURL: URL? {
        indexURL?.deletingLastPathComponent()
    }

    public static var areBundled: Bool {
        indexURL != nil && readAccessURL != nil
    }
}
