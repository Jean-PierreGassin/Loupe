import Foundation
import Security

enum UpdateError: LocalizedError {
    case unavailable
    case noDiskImage
    case unreadableDiskImage
    case missingApp
    case notNewer
    case untrusted
    case translocated

    var errorDescription: String? {
        switch self {
        case .unavailable: "Loupe couldn't reach GitHub to check for updates."
        case .noDiskImage: "The latest release has no disk image to install."
        case .unreadableDiskImage: "The downloaded disk image couldn't be opened."
        case .missingApp: "The downloaded disk image doesn't contain Loupe."
        case .notNewer: "The downloaded app isn't newer than the one you have."
        case .untrusted: "The downloaded app isn't signed by the same developer, so it wasn't installed."
        case .translocated: "Move Loupe to your Applications folder, open it from there and try again."
        }
    }
}

struct UpdateInstaller {
    let app: URL
    let requirement: SecRequirement

    static func forRunningApp() throws -> UpdateInstaller {
        let app = Bundle.main.bundleURL
        guard !app.path.contains("/AppTranslocation/") else { throw UpdateError.translocated }
        var code: SecCode?
        var staticCode: SecStaticCode?
        var requirement: SecRequirement?
        guard
            SecCodeCopySelf([], &code) == errSecSuccess, let code,
            SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
            SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess, let requirement
        else { throw UpdateError.untrusted }
        return UpdateInstaller(app: app, requirement: requirement)
    }

    func install(from diskImage: URL, newerThan current: AppVersion) async throws {
        let work = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: app, create: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let (download, _) = try await URLSession.shared.download(from: diskImage)
        let image = work.appending(path: "update.dmg")
        try FileManager.default.moveItem(at: download, to: image)

        let staged = work.appending(path: app.lastPathComponent)
        try await copyApp(from: image, to: staged, mountingAt: work.appending(path: "mount"))
        try Self.verify(staged, satisfies: requirement)
        guard let version = Self.version(of: staged), version > current else { throw UpdateError.notNewer }
        _ = try FileManager.default.replaceItemAt(app, withItemAt: staged)
    }

    static func verify(_ code: URL, satisfies requirement: SecRequirement) throws {
        var staticCode: SecStaticCode?
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard
            SecStaticCodeCreateWithPath(code as CFURL, [], &staticCode) == errSecSuccess, let staticCode,
            SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
        else { throw UpdateError.untrusted }
    }

    static func version(of app: URL) -> AppVersion? {
        guard
            let data = try? Data(contentsOf: app.appending(path: "Contents/Info.plist")),
            let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return (info["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init)
    }

    private func copyApp(from image: URL, to destination: URL, mountingAt mount: URL) async throws {
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        try await Self.run("/usr/bin/hdiutil", "attach", image.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path, "-quiet")
        do {
            let source = mount.appending(path: "Loupe.app")
            guard FileManager.default.fileExists(atPath: source.path) else { throw UpdateError.missingApp }
            try FileManager.default.copyItem(at: source, to: destination)
            try? await Self.run("/usr/bin/hdiutil", "detach", mount.path, "-force", "-quiet")
        } catch {
            try? await Self.run("/usr/bin/hdiutil", "detach", mount.path, "-force", "-quiet")
            throw error
        }
    }

    private static func run(_ tool: String, _ arguments: String...) async throws {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UpdateError.unreadableDiskImage)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
