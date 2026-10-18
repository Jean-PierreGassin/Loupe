import Foundation
import Security
import Testing
@testable import Loupe

@Suite final class UpdaterTests {
    let root = URL.temporaryDirectory.appending(path: "LoupeUpdates-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @Test func comparesVersions() throws {
        let version = { (string: String) in try #require(AppVersion(string)) }

        #expect(try version("v1.2.10") > version("1.2.9"))
        #expect(try version("1.2") == version("1.2.0"))
        #expect(try version("0.2.0-beta.1") < version("0.2.0"))
        #expect(try version("0.2.0-beta.1") > version("0.1.9"))
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("1..2") == nil)
    }

    @Test func readsTheDiskImageFromAGitHubRelease() throws {
        let json = """
        {"tag_name": "v0.2.0", "html_url": "https://github.com/o/r/releases/tag/v0.2.0", "assets": [
            {"name": "SHA256SUMS.txt", "browser_download_url": "https://example.com/SHA256SUMS.txt"},
            {"name": "Loupe-0.2.0.dmg", "browser_download_url": "https://example.com/Loupe-0.2.0.dmg"}
        ]}
        """
        let release = try JSONDecoder().decode(Release.self, from: Data(json.utf8))

        #expect(release.version == AppVersion("0.2.0"))
        #expect(release.diskImage == URL(string: "https://example.com/Loupe-0.2.0.dmg"))
    }

    @Test func installsAnUpdateSignedTheSameWay() async throws {
        let installed = try makeApp(at: root.appending(path: "Applications/Loupe.app"), identifier: "test.loupe", version: "1.0")
        let image = try makeDiskImage(containing: makeApp(at: root.appending(path: "New/Loupe.app"), identifier: "test.loupe", version: "2.0"))

        try await installer(for: installed).install(from: image, newerThan: #require(AppVersion("1.0")))

        #expect(UpdateInstaller.version(of: installed) == AppVersion("2.0"))
        try UpdateInstaller.verify(installed, satisfies: requirement("identifier \"test.loupe\""))
    }

    @Test func refusesAnUpdateSignedDifferently() async throws {
        let installed = try makeApp(at: root.appending(path: "Applications/Loupe.app"), identifier: "test.loupe", version: "1.0")
        let image = try makeDiskImage(containing: makeApp(at: root.appending(path: "New/Loupe.app"), identifier: "test.other", version: "2.0"))

        await #expect(throws: UpdateError.untrusted) {
            try await self.installer(for: installed).install(from: image, newerThan: #require(AppVersion("1.0")))
        }
        #expect(UpdateInstaller.version(of: installed) == AppVersion("1.0"))
    }

    @Test func refusesAnOlderAppBehindANewerTag() async throws {
        let installed = try makeApp(at: root.appending(path: "Applications/Loupe.app"), identifier: "test.loupe", version: "1.0")
        let image = try makeDiskImage(containing: makeApp(at: root.appending(path: "New/Loupe.app"), identifier: "test.loupe", version: "0.9"))

        await #expect(throws: UpdateError.notNewer) {
            try await self.installer(for: installed).install(from: image, newerThan: #require(AppVersion("1.0")))
        }
        #expect(UpdateInstaller.version(of: installed) == AppVersion("1.0"))
    }

    @Test func refusesUnsignedCode() throws {
        let app = try makeApp(at: root.appending(path: "Unsigned/Loupe.app"), identifier: "test.loupe", version: "1.0", signed: false)

        #expect(throws: UpdateError.untrusted) {
            try UpdateInstaller.verify(app, satisfies: self.requirement("identifier \"test.loupe\""))
        }
    }

    private func installer(for app: URL) throws -> UpdateInstaller {
        try UpdateInstaller(app: app, requirement: requirement("identifier \"test.loupe\""))
    }

    private func makeApp(at app: URL, identifier: String, version: String, signed: Bool = true) throws -> URL {
        let executable = app.appending(path: "Contents/MacOS/Loupe")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(filePath: "/usr/bin/true"), to: executable)
        let info: [String: String] = ["CFBundleIdentifier": identifier, "CFBundleExecutable": "Loupe", "CFBundleShortVersionString": version]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: app.appending(path: "Contents/Info.plist"))
        try run("/usr/bin/codesign", signed ? ["--force", "--sign", "-", app.path] : ["--remove-signature", executable.path])
        return app
    }

    private func makeDiskImage(containing app: URL) throws -> URL {
        let image = root.appending(path: "\(UUID().uuidString).dmg")
        try run("/usr/bin/hdiutil", ["create", "-volname", "Loupe", "-srcfolder", app.deletingLastPathComponent().path, "-format", "UDZO", "-quiet", image.path])
        return image
    }

    private func requirement(_ text: String) throws -> SecRequirement {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement else {
            throw UpdateError.untrusted
        }
        return requirement
    }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let process = try Process.run(URL(filePath: tool), arguments: arguments)
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "\(tool) \(arguments.joined(separator: " ")) failed")
    }
}
