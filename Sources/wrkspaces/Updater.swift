import AppKit
import WrkspacesCore

/// Updates from the GitHub releases, on a click. The trust comes from the release signature
/// (macseal-builder, one key for every version): a download that does not satisfy the
/// installed app's designated requirement is thrown away. Nothing is downloaded by a browser,
/// so nothing is quarantined: no Gatekeeper dialog, and the Accessibility grant is kept
/// (verified by hand with curl + ditto, macOS 27.2.1).
final class Updater {
    static let latest = URL(string: "https://api.github.com/repos/te-o-o-o/wrkspaces/releases/latest")!
    static let asset = "wrkspaces-macos-universal.zip"

    /// The newer release, once a check found one.
    private(set) var available: Release?
    private(set) var installing = false
    var onChange: () -> Void = {}

    let bundle = Bundle.main.bundleURL
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    /// Nil turns the updater off: `swift run` (no bundle), or an ad-hoc build from `./bundle.sh`,
    /// whose requirement is its own cdhash, which no other build can ever satisfy.
    lazy var requirement: String? = {
        guard Bundle.main.bundleIdentifier != nil,
              let out = try? run("/usr/bin/codesign", "-d", "-r-", bundle.path),
              let line = out.split(separator: "\n").first(where: { $0.hasPrefix("designated => ") }),
              !line.contains("cdhash") else { return nil }
        return String(line.dropFirst("designated => ".count))
    }()

    /// Launched from the dmg or from Downloads, macOS runs a read-only copy (App Translocation):
    /// the app cannot replace itself there.
    var canReplace: Bool {
        !bundle.path.contains("/AppTranslocation/")
            && FileManager.default.isWritableFile(atPath: bundle.deletingLastPathComponent().path)
    }

    func start() {
        guard requirement != nil else { return }
        check()
        Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in self?.check() }
    }

    /// Quiet: offline, rate-limited or no newer version, nothing shows and the next check is tomorrow.
    func check() {
        var request = URLRequest(url: Self.latest)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data, let r = parseRelease(data, asset: Self.asset), isNewer(r.version, than: self.version) else { return }
            DispatchQueue.main.async {
                self.available = r
                self.onChange()
            }
        }.resume()
    }

    /// Download, check, then `quit` (which puts the parked windows back) while a detached shell
    /// swaps the bundles and opens the new one.
    func install(quit: @escaping () -> Void) {
        guard let r = available, let requirement, canReplace, !installing else { return }
        installing = true
        onChange()
        URLSession.shared.downloadTask(with: r.zip) { file, _, error in
            // The downloaded file is deleted when this handler returns: unzip it here.
            let result = Result { try self.unpack(file, error, r, requirement) }
            DispatchQueue.main.async {
                switch result {
                case .success(let app): self.swap(to: app, quit: quit)
                case .failure(let e): self.fail(e)
                }
            }
        }.resume()
    }

    private func unpack(_ file: URL?, _ error: Error?, _ r: Release, _ requirement: String) throws -> URL {
        guard let file else { throw error ?? UpdateError("the download failed") }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wrkspaces-update-\(UUID().uuidString)")
        try run("/usr/bin/ditto", "-x", "-k", file.path, dir.path)
        let app = dir.appendingPathComponent(bundle.lastPathComponent)
        let info = Bundle(url: app)
        guard info?.bundleIdentifier == Bundle.main.bundleIdentifier,
              info?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == r.version else {
            throw UpdateError("the download is not wrkspaces \(r.version)")
        }
        // The check that matters: signed with the same key as the installed app.
        // codesign -R takes "=requirement" for text, a file path otherwise.
        do {
            try run("/usr/bin/codesign", "--verify", "--deep", "--strict", "-R", "=" + requirement, app.path)
        } catch {
            throw UpdateError("the download is not signed like the installed app")
        }
        return app
    }

    private func swap(to app: URL, quit: () -> Void) {
        // Waits for this process to end, keeps the old bundle until the new one is in place,
        // and puts it back if the copy fails: the app is never lost.
        let script = """
            while kill -0 "$3" 2>/dev/null; do sleep 0.2; done
            old="$2.old-$$"
            mv "$2" "$old" || exit 1
            if ditto "$1" "$2"; then rm -rf "$old"; else rm -rf "$2"; mv "$old" "$2"; fi
            open "$2"
            """
        let sh = Process()
        sh.executableURL = URL(fileURLWithPath: "/bin/sh")
        sh.arguments = ["-c", script, "sh", app.path, bundle.path, String(ProcessInfo.processInfo.processIdentifier)]
        do {
            try sh.run()
        } catch {
            return fail(error)
        }
        quit()
    }

    private func fail(_ error: Error) {
        installing = false
        onChange()
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "wrkspaces could not update"
        alert.informativeText = (error as? UpdateError)?.message ?? error.localizedDescription
        alert.runModal()
    }
}

struct UpdateError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

/// Runs a tool that ships with macOS and returns stdout and stderr together (codesign -d
/// prints its requirement on stdout, the rest on stderr).
@discardableResult
func run(_ tool: String, _ args: String...) throws -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    try p.run()
    let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { throw UpdateError("\((tool as NSString).lastPathComponent) failed") }
    return out
}
