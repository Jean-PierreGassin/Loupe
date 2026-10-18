import Foundation

struct Release: Decodable, Equatable, Sendable {
    struct Asset: Decodable, Equatable, Sendable {
        let name: String
        let url: URL

        enum CodingKeys: String, CodingKey {
            case name
            case url = "browser_download_url"
        }
    }

    let tag: String
    let page: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tag = "tag_name"
        case page = "html_url"
        case assets
    }

    var version: AppVersion? { AppVersion(tag) }
    var diskImage: URL? { assets.first { $0.name.hasSuffix(".dmg") }?.url }
}

struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    let numbers: [Int]
    let isPrerelease: Bool
    let description: String

    init?(_ string: String) {
        let trimmed = string.hasPrefix("v") ? String(string.dropFirst()) : string
        let core = trimmed.prefix { $0 != "-" && $0 != "+" }
        let numbers = core.split(separator: ".", omittingEmptySubsequences: false).compactMap { Int($0) }
        guard !numbers.isEmpty, numbers.count == core.split(separator: ".", omittingEmptySubsequences: false).count else { return nil }
        self.numbers = numbers
        isPrerelease = trimmed.dropFirst(core.count).hasPrefix("-")
        description = trimmed
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        let count = max(lhs.numbers.count, rhs.numbers.count)
        let left = lhs.numbers + Array(repeating: 0, count: count - lhs.numbers.count)
        let right = rhs.numbers + Array(repeating: 0, count: count - rhs.numbers.count)
        return left == right ? lhs.isPrerelease && !rhs.isPrerelease : left.lexicographicallyPrecedes(right)
    }
}
