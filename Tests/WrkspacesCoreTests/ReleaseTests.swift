import Foundation
import Testing
import WrkspacesCore

@Test func versionsCompareAsNumbers() {
    #expect(isNewer("0.1.10", than: "0.1.9"))
    #expect(isNewer("v0.2.0", than: "0.1.10"))
    #expect(isNewer("1.0", than: "0.9.9"))
    #expect(!isNewer("0.1.9", than: "0.1.10"))
    #expect(!isNewer("0.2", than: "0.2.0"))
    #expect(!isNewer("0.1.10", than: "0.1.10"))
}

// Trimmed from a real `releases/latest` answer of wrkspaces.
let latest = """
{"tag_name": "v0.1.10", "draft": false, "assets": [
  {"name": "wrkspaces-macos-universal.dmg", "browser_download_url": "https://github.com/te-o-o-o/wrkspaces/releases/download/v0.1.10/wrkspaces-macos-universal.dmg"},
  {"name": "wrkspaces-macos-universal.zip", "browser_download_url": "https://github.com/te-o-o-o/wrkspaces/releases/download/v0.1.10/wrkspaces-macos-universal.zip"}
]}
""".data(using: .utf8)!

@Test func releaseGivesItsVersionAndZip() {
    let r = parseRelease(latest, asset: "wrkspaces-macos-universal.zip")
    #expect(r?.version == "0.1.10")
    #expect(r?.zip.absoluteString == "https://github.com/te-o-o-o/wrkspaces/releases/download/v0.1.10/wrkspaces-macos-universal.zip")
}

@Test func releaseWithoutTheZipIsNotOffered() {
    #expect(parseRelease(latest, asset: "missing.zip") == nil)
    #expect(parseRelease(Data("{\"message\": \"rate limited\"}".utf8), asset: "wrkspaces-macos-universal.zip") == nil)
}
