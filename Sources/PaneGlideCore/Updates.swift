import Foundation

public struct ReleaseVersion: Equatable, Comparable, Sendable, CustomStringConvertible {
    private let parts: [Int]
    public init(_ text: String) throws {
        let value = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3, components.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              components.allSatisfy({ Int($0) != nil }) else { throw SettingsError.invalid("Release versions must use major.minor.patch.") }
        parts = components.compactMap { Int($0) }
    }
    public var description: String { parts.map(String.init).joined(separator: ".") }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}
public struct Release: Equatable, Sendable {
    public let version: ReleaseVersion
    public let assetID: Int
    public let byteCount: Int
    public init(version: ReleaseVersion, assetID: Int, byteCount: Int) { self.version = version; self.assetID = assetID; self.byteCount = byteCount }
}
public enum ReleaseCatalog {
    private struct Entry: Decodable {
        struct Asset: Decodable { let id: Int; let name: String; let size: Int }
        let tagName: String; let draft: Bool; let prerelease: Bool; let assets: [Asset]
    }
    public static func update(in data: Data, current: ReleaseVersion) throws -> Release? {
        guard data.count <= 2_000_000 else { throw SettingsError.invalid("The release response is too large.") }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let entries = try decoder.decode([Entry].self, from: data)
        return entries.filter { !$0.draft && !$0.prerelease }.compactMap { entry -> Release? in
            guard let version = try? ReleaseVersion(entry.tagName), version > current,
                  let asset = entry.assets.first(where: { $0.name == "PaneGlide.zip" && $0.id > 0 && (1...200_000_000).contains($0.size) }) else { return nil }
            return Release(version: version, assetID: asset.id, byteCount: asset.size)
        }.max { $0.version < $1.version }
    }
}

public protocol ReleaseSource: Sendable { func releases() async throws -> Data }
public struct UpdateChecker: Sendable {
    private let source: any ReleaseSource
    private let current: ReleaseVersion
    public init(source: any ReleaseSource, current: ReleaseVersion) { self.source = source; self.current = current }
    public func check() async throws -> Release? { try ReleaseCatalog.update(in: await source.releases(), current: current) }
}
