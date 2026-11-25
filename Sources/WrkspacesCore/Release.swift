import Foundation

/// A GitHub release the updater can install.
public struct Release: Equatable {
    public let version: String  // without the "v" of the tag
    public let zip: URL

    public init(version: String, zip: URL) {
        self.version = version
        self.zip = zip
    }
}

/// Compares numbers, not text: "0.1.10" is newer than "0.1.9", which a string comparison gets wrong.
/// A missing part counts as 0, so "0.2" and "0.2.0" are the same version.
public func isNewer(_ a: String, than b: String) -> Bool {
    func parts(_ v: String) -> [Int] { v.trimmingPrefix("v").split(separator: ".").map { Int($0) ?? 0 } }
    let (x, y) = (parts(a), parts(b))
    for i in 0..<max(x.count, y.count) {
        let (l, r) = (i < x.count ? x[i] : 0, i < y.count ? y[i] : 0)
        if l != r { return l > r }
    }
    return false
}

/// Reads GitHub's `releases/latest` answer. Nil when the release has no asset by that name,
/// so a release published without its zip is simply not offered.
public func parseRelease(_ json: Data, asset: String) -> Release? {
    struct Answer: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let assets: [Asset]
    }
    guard let answer = try? JSONDecoder().decode(Answer.self, from: json),
          let zip = answer.assets.first(where: { $0.name == asset }) else { return nil }
    return Release(version: String(answer.tag_name.trimmingPrefix("v")), zip: zip.browser_download_url)
}
