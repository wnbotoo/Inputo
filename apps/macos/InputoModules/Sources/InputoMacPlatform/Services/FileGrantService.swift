import AppKit
import Foundation
import InputoCore
import UniformTypeIdentifiers

@MainActor
public final class FileGrantService {
    private struct Grant {
        var id: String
        var scope: InputoFileGrantScope
        var url: URL
        var displayName: String
        var contentType: String?
        var byteCount: Int?
        var expiresAt: Date?
    }

    private var grants: [String: Grant] = [:]
    private let grantLifetimeSeconds: TimeInterval
    private let defaultMaxReadBytes: Int

    public init(grantLifetimeSeconds: TimeInterval = 600, defaultMaxReadBytes: Int = 1_048_576) {
        self.grantLifetimeSeconds = grantLifetimeSeconds
        self.defaultMaxReadBytes = defaultMaxReadBytes
    }

    public func pickReadableFiles(_ request: InputoFilePickRequest) throws -> InputoFilePickResponse {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = request.allowsMultipleSelection
        panel.allowedContentTypes = contentTypes(from: request.allowedContentTypes)

        guard panel.runModal() == .OK else {
            throw InputoNativeToolError(code: .fileAccessDenied, message: "No readable file was selected.")
        }

        return InputoFilePickResponse(
            grants: panel.urls.map { makeGrant(scope: .read, url: $0) }
        )
    }

    public func pickWritableFile(_ request: InputoFilePickRequest) throws -> InputoFilePickResponse {
        let panel = NSSavePanel()
        panel.allowedContentTypes = contentTypes(from: request.allowedContentTypes)
        panel.nameFieldStringValue = request.suggestedFileName ?? ""

        guard panel.runModal() == .OK, let url = panel.url else {
            throw InputoNativeToolError(code: .fileAccessDenied, message: "No writable file target was selected.")
        }

        return InputoFilePickResponse(grants: [makeGrant(scope: .write, url: url)])
    }

    public func readText(_ request: InputoFileReadTextRequest) throws -> InputoFileReadTextResponse {
        let grant = try validatedGrant(id: request.grantID, scope: .read)
        let maxBytes = max(1, min(request.maxBytes, defaultMaxReadBytes))

        if let byteCount = grant.byteCount, byteCount > maxBytes {
            throw InputoNativeToolError(
                code: .fileTooLarge,
                message: "The selected file is larger than the allowed read size."
            )
        }

        let didStartAccessing = grant.url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                grant.url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: grant.url, options: [.mappedIfSafe])
        } catch {
            throw InputoNativeToolError(code: .fileReadFailed, message: "Could not read the selected file.")
        }

        guard data.count <= maxBytes else {
            throw InputoNativeToolError(
                code: .fileTooLarge,
                message: "The selected file is larger than the allowed read size."
            )
        }

        let encodingName = request.encoding ?? "utf-8"
        let encoding = stringEncoding(named: encodingName)
        guard let text = String(data: data, encoding: encoding) else {
            throw InputoNativeToolError(
                code: .fileUnsupportedEncoding,
                message: "The selected file could not be decoded as \(encodingName)."
            )
        }

        return InputoFileReadTextResponse(
            grantID: grant.id,
            displayName: grant.displayName,
            text: text,
            encoding: encodingName
        )
    }

    public func writeText(_ request: InputoFileWriteTextRequest) throws -> InputoFileWriteTextResponse {
        let grant = try validatedGrant(id: request.grantID, scope: .write)
        let encoding = stringEncoding(named: request.encoding)
        guard let data = request.text.data(using: encoding) else {
            throw InputoNativeToolError(
                code: .fileUnsupportedEncoding,
                message: "The provided text could not be encoded as \(request.encoding)."
            )
        }

        if FileManager.default.fileExists(atPath: grant.url.path), !request.overwrite {
            throw InputoNativeToolError(
                code: .fileWriteFailed,
                message: "The target file already exists. Confirm overwrite before writing."
            )
        }

        let didStartAccessing = grant.url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                grant.url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try data.write(to: grant.url, options: [.atomic])
        } catch {
            throw InputoNativeToolError(code: .fileWriteFailed, message: "Could not write the selected file.")
        }

        return InputoFileWriteTextResponse(
            grantID: grant.id,
            displayName: grant.displayName,
            byteCount: data.count
        )
    }

    private func makeGrant(scope: InputoFileGrantScope, url: URL) -> InputoFileGrantSnapshot {
        let expiresAt = Date().addingTimeInterval(grantLifetimeSeconds)
        let grant = Grant(
            id: UUID().uuidString,
            scope: scope,
            url: url,
            displayName: url.lastPathComponent,
            contentType: contentType(for: url),
            byteCount: byteCount(for: url),
            expiresAt: expiresAt
        )
        grants[grant.id] = grant
        return snapshot(from: grant)
    }

    private func validatedGrant(id: String, scope: InputoFileGrantScope) throws -> Grant {
        guard let grant = grants[id], grant.scope == scope else {
            throw InputoNativeToolError(code: .fileGrantInvalid, message: "The file grant is not valid for this operation.")
        }
        if let expiresAt = grant.expiresAt, expiresAt < Date() {
            grants[id] = nil
            throw InputoNativeToolError(code: .fileGrantInvalid, message: "The file grant has expired.")
        }
        return grant
    }

    private func snapshot(from grant: Grant) -> InputoFileGrantSnapshot {
        InputoFileGrantSnapshot(
            id: grant.id,
            scope: grant.scope,
            displayName: grant.displayName,
            contentType: grant.contentType,
            byteCount: grant.byteCount,
            expiresAt: grant.expiresAt
        )
    }

    private func contentTypes(from identifiers: [String]) -> [UTType] {
        identifiers.compactMap { UTType($0) }
    }

    private func contentType(for url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.identifier
    }

    private func byteCount(for url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }

    private func stringEncoding(named name: String) -> String.Encoding {
        switch name.lowercased() {
        case "utf-16":
            return .utf16
        case "utf-16be":
            return .utf16BigEndian
        case "utf-16le":
            return .utf16LittleEndian
        default:
            return .utf8
        }
    }
}
