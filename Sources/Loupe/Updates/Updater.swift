import AppKit

@MainActor @Observable final class Updater {
    enum State: Equatable {
        case idle
        case checking
        case installing
        case installed(AppVersion)
    }

    enum Prompt: Identifiable {
        case available(Release, AppVersion)
        case upToDate(AppVersion)
        case installed(AppVersion)
        case failed(String)

        var id: String {
            switch self {
            case let .available(_, version): "available-\(version)"
            case let .upToDate(version): "current-\(version)"
            case let .installed(version): "installed-\(version)"
            case let .failed(message): "failed-\(message)"
            }
        }
    }

    private(set) var state = State.idle
    var prompt: Prompt?
    let isEnabled: Bool

    @ObservationIgnored private let current: AppVersion?
    @ObservationIgnored private let feed: URL
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var schedule: Task<Void, Never>?

    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let lastCheckKey = "lastUpdateCheck"
    private static let skippedKey = "skippedUpdate"

    init(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) {
        current = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
        isEnabled = bundle.object(forInfoDictionaryKey: "LoupeUpdatesEnabled") as? Bool == true && current != nil
        feed = environment["LOUPE_UPDATE_FEED"].flatMap(URL.init(string:))
            ?? URL(string: "https://api.github.com/repos/Jean-PierreGassin/Loupe/releases/latest")!
    }

    func startChecking() {
        guard isEnabled, schedule == nil else { return }
        schedule = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            while !Task.isCancelled {
                await self?.check(userInitiated: false)
                try? await Task.sleep(for: .seconds(60 * 60))
            }
        }
    }

    func checkNow() {
        Task { await check(userInitiated: true) }
    }

    func install(_ release: Release, then relaunch: @escaping @MainActor () -> Void) {
        guard state == .idle || state == .checking, let current else { return }
        state = .installing
        Task {
            do {
                guard let diskImage = release.diskImage, let version = release.version else { throw UpdateError.noDiskImage }
                try await UpdateInstaller.forRunningApp().install(from: diskImage, newerThan: current)
                state = .installed(version)
                relaunch()
            } catch {
                state = .idle
                prompt = .failed(error.localizedDescription)
            }
        }
    }

    func skip(_ version: AppVersion) {
        defaults.set(version.description, forKey: Self.skippedKey)
    }

    private func check(userInitiated: Bool) async {
        guard isEnabled, state == .idle, let current else { return }
        if !userInitiated, let last = defaults.object(forKey: Self.lastCheckKey) as? Date, Date.now.timeIntervalSince(last) < Self.checkInterval {
            return
        }
        state = .checking
        defer { if state == .checking { state = .idle } }
        do {
            let release = try await latestRelease()
            defaults.set(Date.now, forKey: Self.lastCheckKey)
            if let version = release.version, version > current {
                if userInitiated || defaults.string(forKey: Self.skippedKey) != version.description {
                    prompt = .available(release, version)
                }
            } else if userInitiated {
                prompt = .upToDate(current)
            }
        } catch {
            if userInitiated { prompt = .failed(error.localizedDescription) }
        }
    }

    private func latestRelease() async throws -> Release {
        var request = URLRequest(url: feed)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let response = response as? HTTPURLResponse, response.statusCode != 200 {
            throw UpdateError.unavailable
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    static func relaunch() {
        let waiter = Process()
        waiter.executableURL = URL(filePath: "/bin/sh")
        waiter.arguments = [
            "-c", "while kill -0 \"$0\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$1\"",
            String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundleURL.path,
        ]
        try? waiter.run()
        NSApp.terminate(nil)
    }
}
