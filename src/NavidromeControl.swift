import SwiftUI
import AppKit

let navDir = NSHomeDirectory() + "/navidrome"
let tomlPath = navDir + "/navidrome.toml"
let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/com.navidrome.plist"
let logPath = navDir + "/navidrome.log"
let webURL = URL(string: "http://localhost:4533")!
let toolPATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

@discardableResult
func shell(_ path: String, _ args: [String], env: [String: String]? = nil) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    if let env = env {
        var merged = ProcessInfo.processInfo.environment
        for (k, v) in env { merged[k] = v }
        p.environment = merged
    }
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return "\(error)" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}

func firstExecutable(_ paths: [String]) -> String? {
    return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
}

func findBinary() -> String? {
    return firstExecutable(["/opt/homebrew/bin/navidrome", "/usr/local/bin/navidrome"])
}

func findBrew() -> String? {
    return firstExecutable(["/opt/homebrew/bin/brew", "/usr/local/bin/brew"])
}

func pingSync() -> Bool {
    var ok = false
    let sem = DispatchSemaphore(value: 0)
    var req = URLRequest(url: webURL.appendingPathComponent("ping"))
    req.timeoutInterval = 1.5
    URLSession.shared.dataTask(with: req) { _, resp, _ in
        ok = (resp as? HTTPURLResponse)?.statusCode == 200
        sem.signal()
    }.resume()
    _ = sem.wait(timeout: .now() + 3)
    return ok
}

func waitFor(_ target: Bool, seconds: Int) -> Bool {
    for _ in 0..<seconds {
        if pingSync() == target { return true }
        Thread.sleep(forTimeInterval: 1)
    }
    return pingSync() == target
}

func writePlist(bin: String) {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    <key>Label</key><string>com.navidrome</string>
    <key>ProgramArguments</key>
    <array>
    <string>\(bin)</string>
    <string>--configfile</string>
    <string>\(tomlPath)</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict><key>PATH</key><string>\(toolPATH)</string></dict>
    <key>WorkingDirectory</key><string>\(navDir)</string>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>\(logPath)</string>
    <key>StandardErrorPath</key><string>\(logPath)</string>
    </dict>
    </plist>
    """
    try? xml.write(toFile: plistPath, atomically: true, encoding: .utf8)
}

final class Model: ObservableObject {
    @Published var running = false
    @Published var busy = false
    @Published var message = ""
    @Published var musicFolder = ""
    @Published var setupFolder = ""
    @Published var hasBinary = false
    @Published var hasConfig = false
    @Published var hasService = false

    var needsSetup: Bool { return !(hasBinary && hasConfig && hasService) }

    init() {
        loadFolder()
        refreshSetup()
        poll()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            self.poll()
            self.refreshSetup()
        }
    }

    func refreshSetup() {
        let fm = FileManager.default
        hasBinary = findBinary() != nil
        hasConfig = fm.fileExists(atPath: tomlPath)
        hasService = fm.fileExists(atPath: plistPath)
    }

    func poll() {
        DispatchQueue.global().async {
            let ok = pingSync()
            DispatchQueue.main.async { self.running = ok }
        }
    }

    func loadFolder() {
        let text = (try? String(contentsOfFile: tomlPath, encoding: .utf8)) ?? ""
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("MusicFolder") {
                let parts = t.components(separatedBy: "\"")
                if parts.count >= 2 { musicFolder = parts[1]; return }
            }
        }
        musicFolder = "(not set)"
    }

    func work(_ text: String, _ job: @escaping () -> String) {
        busy = true
        message = text
        DispatchQueue.global().async {
            let result = job()
            DispatchQueue.main.async {
                self.busy = false
                self.message = result
                self.poll()
            }
        }
    }

    func startJob() -> String {
        if pingSync() { return "Server is already running." }
        shell("/bin/launchctl", ["unload", plistPath])
        shell("/bin/launchctl", ["load", "-w", plistPath])
        return waitFor(true, seconds: 20) ? "Server started." : "Server did not start. Try the Log button."
    }

    func stopJob() -> String {
        shell("/bin/launchctl", ["unload", "-w", plistPath])
        return waitFor(false, seconds: 10) ? "Server stopped." : "Server may still be shutting down."
    }

    func start() { work("Starting server...") { self.startJob() } }
    func stop() { work("Stopping server...") { self.stopJob() } }
    func restart() {
        work("Restarting server...") {
            _ = self.stopJob()
            return self.startJob()
        }
    }

    func openNavidrome() {
        work("Opening Navidrome...") {
            if !pingSync() {
                let r = self.startJob()
                if !pingSync() { return r }
            }
            DispatchQueue.main.async { NSWorkspace.shared.open(webURL) }
            return "Opened Navidrome in your browser."
        }
    }

    func pickFolder(message: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = message
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }

    func changeFolder() {
        guard let path = pickFolder(message: "Choose the main music folder for Navidrome") else { return }
        let text = (try? String(contentsOfFile: tomlPath, encoding: .utf8)) ?? ""
        var lines = text.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("MusicFolder") && !$0.isEmpty
        }
        lines.append("MusicFolder = \"\(path)\"")
        try? (lines.joined(separator: "\n") + "\n").write(toFile: tomlPath, atomically: true, encoding: .utf8)
        musicFolder = path
        restart()
    }

    func chooseSetupFolder() {
        if let path = pickFolder(message: "Choose the folder that holds your music") {
            setupFolder = path
        }
    }

    func runSetup() {
        let folder = setupFolder
        work("Setting up. Installing can take a few minutes...") {
            let fm = FileManager.default
            if findBinary() == nil {
                guard let brew = findBrew() else {
                    return "Homebrew is needed first. Install it from brew.sh, then try again."
                }
                shell(brew, ["install", "navidrome", "ffmpeg"],
                      env: ["PATH": toolPATH, "HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ENV_HINTS": "1"])
            }
            guard let bin = findBinary() else {
                return "Install did not finish. In Terminal, run: brew install navidrome ffmpeg"
            }
            try? fm.createDirectory(atPath: navDir, withIntermediateDirectories: true)
            if !fm.fileExists(atPath: tomlPath) {
                if folder.isEmpty { return "Choose your music folder first." }
                let cfg = "MusicFolder = \"\(folder)\"\nDataFolder = \"\(navDir)\"\n"
                try? cfg.write(toFile: tomlPath, atomically: true, encoding: .utf8)
            }
            if !fm.fileExists(atPath: plistPath) {
                try? fm.createDirectory(atPath: NSHomeDirectory() + "/Library/LaunchAgents",
                                        withIntermediateDirectories: true)
                writePlist(bin: bin)
            }
            let r = self.startJob()
            DispatchQueue.main.async {
                self.refreshSetup()
                self.loadFolder()
            }
            return r == "Server started." ? "All set. Click Open Navidrome to create your admin account." : r
        }
    }

    func openLibraries() {
        NSWorkspace.shared.open(webURL)
        message = "In Navidrome: profile icon, then Settings, then Libraries."
    }

    func openLog() { shell("/usr/bin/open", ["-a", "Console", logPath]) }
    func openConfig() { shell("/usr/bin/open", ["-t", tomlPath]) }
    func openFolder() { shell("/usr/bin/open", [navDir]) }
}

struct Header: View {
    let subtitle: String
    let dot: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("Navidrome Control").font(.title2.bold())
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 10, height: 10)
                    Text(subtitle).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}

struct StatusLine: View {
    @ObservedObject var m: Model
    var body: some View {
        HStack(spacing: 8) {
            if m.busy { ProgressView().controlSize(.small) }
            Text(m.message)
                .font(.callout)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .frame(minHeight: 20)
    }
}

struct CheckRow: View {
    let done: Bool
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? Color.green : Color.secondary)
            Text(text)
        }
    }
}

struct SetupView: View {
    @ObservedObject var m: Model

    var canSetUp: Bool {
        return !m.busy && (m.hasConfig || !m.setupFolder.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(subtitle: "First-time setup", dot: Color.orange)

            GroupBox(label: Text("What gets set up")) {
                VStack(alignment: .leading, spacing: 8) {
                    CheckRow(done: m.hasBinary, text: "Navidrome installed")
                    CheckRow(done: m.hasConfig, text: "Music folder and settings")
                    CheckRow(done: m.hasService, text: "Starts automatically when you log in")
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !m.hasConfig {
                GroupBox(label: Text("Your music")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(m.setupFolder.isEmpty ? "No folder chosen yet" : m.setupFolder)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                            .truncationMode(.middle)
                        Button(action: { m.chooseSetupFolder() }) {
                            Label("Choose Music Folder", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .disabled(m.busy)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !m.hasBinary && findBrew() == nil {
                Text("Installing Navidrome needs Homebrew, a free installer for Mac tools. Install it from brew.sh, then come back.")
                    .font(.callout)
                    .foregroundColor(.orange)
                Button("Open brew.sh") {
                    NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
                }
            }

            Button(action: { m.runSetup() }) {
                Label("Set Up Navidrome", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSetUp)

            StatusLine(m: m)
        }
        .padding(20)
        .frame(width: 460)
    }
}

struct MainView: View {
    @ObservedObject var m: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(subtitle: m.running ? "Server is running" : "Server is stopped",
                   dot: m.running ? Color.green : Color.red)

            Button(action: { m.openNavidrome() }) {
                Label("Open Navidrome", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(m.busy)

            GroupBox(label: Text("Server")) {
                HStack(spacing: 10) {
                    Button(action: { m.start() }) {
                        Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    Button(action: { m.stop() }) {
                        Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    Button(action: { m.restart() }) {
                        Label("Restart", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                    }
                }
                .controlSize(.large)
                .disabled(m.busy)
                .padding(8)
            }

            GroupBox(label: Text("Music")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Main folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(m.musicFolder)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    HStack(spacing: 10) {
                        Button(action: { m.changeFolder() }) {
                            Label("Change Folder", systemImage: "folder").frame(maxWidth: .infinity)
                        }
                        Button(action: { m.openLibraries() }) {
                            Label("Add or Remove Libraries", systemImage: "books.vertical").frame(maxWidth: .infinity)
                        }
                    }
                    .controlSize(.large)
                    .disabled(m.busy)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(label: Text("Tools")) {
                HStack(spacing: 10) {
                    Button(action: { m.openLog() }) {
                        Label("Log", systemImage: "doc.text").frame(maxWidth: .infinity)
                    }
                    Button(action: { m.openConfig() }) {
                        Label("Config", systemImage: "gearshape").frame(maxWidth: .infinity)
                    }
                    Button(action: { m.openFolder() }) {
                        Label("Data Folder", systemImage: "externaldrive").frame(maxWidth: .infinity)
                    }
                }
                .controlSize(.large)
                .padding(8)
            }

            StatusLine(m: m)
        }
        .padding(20)
        .frame(width: 460)
    }
}

struct ContentView: View {
    @StateObject var m = Model()
    var body: some View {
        if m.needsSetup {
            SetupView(m: m)
        } else {
            MainView(m: m)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct NavidromeControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup { ContentView() }
            .windowResizability(.contentSize)
    }
}
