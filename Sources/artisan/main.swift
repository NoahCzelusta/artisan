import Darwin
import Foundation

struct OpenTarget: Codable, Hashable {
    let path: String
    let line: Int?
}

struct OpenRequest: Codable {
    let invocationID: String
    let targets: [OpenTarget]
    let wait: Bool

    enum CodingKeys: String, CodingKey {
        case invocationID
        case targets
        case paths
        case wait
    }

    init(invocationID: String, targets: [OpenTarget], wait: Bool) {
        self.invocationID = invocationID
        self.targets = targets
        self.wait = wait
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        invocationID = try container.decode(String.self, forKey: .invocationID)
        wait = try container.decode(Bool.self, forKey: .wait)
        if let targets = try container.decodeIfPresent([OpenTarget].self, forKey: .targets) {
            self.targets = targets
        } else {
            let paths = try container.decode([String].self, forKey: .paths)
            self.targets = paths.map { OpenTarget(path: $0, line: nil) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(invocationID, forKey: .invocationID)
        try container.encode(targets, forKey: .targets)
        try container.encode(targets.map(\.path), forKey: .paths)
        try container.encode(wait, forKey: .wait)
    }
}

struct OpenResponse: Codable {
    let ok: Bool
    let message: String
}

let socketPath = "/tmp/artisan-\(getuid()).sock"
let usageLine = "usage: artisan [--wait] <existing-file[:line]> [existing-file[:line]...]\n"

func usage() -> Never {
    fputs(usageLine, stderr)
    exit(64)
}

func help() -> Never {
    fputs("""
    \(usageLine)
    Open existing files in Artisan.

    Arguments:
      existing-file[:line]  Existing file to open. Line numbers are one-based.

    Options:
      --wait                Block until every file from this invocation closes.
      -h, --help, help      Show this help.

    Examples:
      artisan README.md
      artisan Sources/App.swift:42
      artisan --wait README.md Sources/App.swift:42
    """, stdout)
    exit(0)
}

func failUsage(_ message: String) -> Never {
    fputs("artisan: \(message)\n", stderr)
    fputs(usageLine, stderr)
    exit(64)
}

func connectToServer() -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let maxPathLength = MemoryLayout.size(ofValue: addr.sun_path)
    guard socketPath.utf8.count < maxPathLength else {
        close(fd)
        return nil
    }

    withUnsafeMutableBytes(of: &addr.sun_path) { rawBuffer in
        for index in rawBuffer.indices {
            rawBuffer[index] = 0
        }
        for (index, byte) in socketPath.utf8.enumerated() {
            rawBuffer[index] = byte
        }
    }

    let status = withUnsafePointer(to: &addr) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            Darwin.connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    guard status == 0 else {
        close(fd)
        return nil
    }

    return fd
}

func launchServerIfNeeded() {
    guard let executableURL = Bundle.main.executableURL else {
        fputs("artisan: could not locate executable directory\n", stderr)
        exit(70)
    }

    let executableDirectories = [
        executableURL.deletingLastPathComponent(),
        executableURL.resolvingSymlinksInPath().deletingLastPathComponent()
    ]

    for executableDirectory in uniqueURLs(executableDirectories) {
        let bundleExecutableURL = executableDirectory
            .appendingPathComponent("Artisan.app")
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent("ArtisanApp")
        if FileManager.default.isExecutableFile(atPath: bundleExecutableURL.path) {
            launchDetached(
                executableURL: bundleExecutableURL,
                arguments: ["--server"]
            )
            return
        }

        let appURL = executableDirectory.appendingPathComponent("ArtisanApp")
        if FileManager.default.isExecutableFile(atPath: appURL.path) {
            launchDetached(executableURL: appURL, arguments: ["--server"])
            return
        }
    }

    fputs("artisan: could not find Artisan.app near \(executableURL.path)\n", stderr)
    exit(69)
}

func uniqueURLs(_ urls: [URL]) -> [URL] {
    var seen: Set<String> = []
    return urls.filter { url in
        let path = url.standardizedFileURL.path
        return seen.insert(path).inserted
    }
}

func launchDetached(executableURL: URL, arguments: [String]) {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.standardInput = FileHandle(forReadingAtPath: "/dev/null")
    process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
    process.standardError = FileHandle(forWritingAtPath: "/dev/null")

    do {
        try process.run()
    } catch {
        fputs("artisan: failed to launch app: \(error)\n", stderr)
        exit(70)
    }
}

func connectWithRetry() -> Int32 {
    if let fd = connectToServer() {
        return fd
    }

    launchServerIfNeeded()

    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
        if let fd = connectToServer() {
            return fd
        }
        usleep(5_000)
    }

    fputs("artisan: timed out connecting to app\n", stderr)
    exit(75)
}

func readLineFromFD(_ fd: Int32) -> String? {
    var bytes: [UInt8] = []
    var byte: UInt8 = 0

    while true {
        let count = Darwin.read(fd, &byte, 1)
        if count == 0 {
            return bytes.isEmpty ? nil : String(bytes: bytes, encoding: .utf8)
        }
        if count < 0 {
            return nil
        }
        if byte == 10 {
            return String(bytes: bytes, encoding: .utf8)
        }
        bytes.append(byte)
    }
}

func resolvedPath(_ argument: String, relativeTo currentDirectory: URL) -> String {
    URL(fileURLWithPath: argument, relativeTo: currentDirectory).standardizedFileURL.path
}

func fileState(path: String) -> (exists: Bool, isDirectory: Bool) {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return (exists, isDirectory.boolValue)
}

func parseTarget(_ argument: String, relativeTo currentDirectory: URL) -> OpenTarget {
    let fullPath = resolvedPath(argument, relativeTo: currentDirectory)
    if fileState(path: fullPath).exists {
        return OpenTarget(path: fullPath, line: nil)
    }

    guard let separator = argument.lastIndex(of: ":") else {
        return OpenTarget(path: fullPath, line: nil)
    }

    let pathPart = String(argument[..<separator])
    let linePart = String(argument[argument.index(after: separator)...])
    guard !pathPart.isEmpty else {
        return OpenTarget(path: fullPath, line: nil)
    }

    let path = resolvedPath(pathPart, relativeTo: currentDirectory)
    if let line = Int(linePart) {
        guard line > 0 else {
            failUsage("invalid line in argument: \(argument)")
        }
        return OpenTarget(path: path, line: line)
    }

    if fileState(path: path).exists {
        failUsage("invalid line in argument: \(argument)")
    }
    return OpenTarget(path: fullPath, line: nil)
}

var args = Array(CommandLine.arguments.dropFirst())
if let first = args.first, first == "help" || first == "--help" || first == "-h" {
    help()
}

let shouldWait: Bool
if args.first == "--wait" {
    shouldWait = true
    args.removeFirst()
} else {
    shouldWait = false
}

if let first = args.first, first == "help" || first == "--help" || first == "-h" {
    help()
}

if args.first == "--" {
    args.removeFirst()
}

guard !args.isEmpty else {
    usage()
}

let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let targets = args.map { parseTarget($0, relativeTo: currentDirectory) }

for target in targets {
    let state = fileState(path: target.path)
    guard state.exists, !state.isDirectory else {
        fputs("artisan: file does not exist: \(target.path)\n", stderr)
        exit(66)
    }
}

let request = OpenRequest(invocationID: UUID().uuidString, targets: targets, wait: shouldWait)
let fd = connectWithRetry()
defer { close(fd) }

do {
    let data = try JSONEncoder().encode(request)
    _ = data.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, data.count) }
    _ = "\n".utf8CString.withUnsafeBufferPointer { buffer in
        Darwin.write(fd, buffer.baseAddress, 1)
    }
} catch {
    fputs("artisan: failed to encode request: \(error)\n", stderr)
    exit(70)
}

guard let line = readLineFromFD(fd),
      let data = line.data(using: .utf8),
      let response = try? JSONDecoder().decode(OpenResponse.self, from: data)
else {
    fputs("artisan: no response from app\n", stderr)
    exit(75)
}

if !response.ok {
    fputs("artisan: \(response.message)\n", stderr)
    exit(1)
}

if shouldWait {
    guard let finalLine = readLineFromFD(fd),
          let finalData = finalLine.data(using: .utf8),
          let finalResponse = try? JSONDecoder().decode(OpenResponse.self, from: finalData)
    else {
        fputs("artisan: app closed before wait completed\n", stderr)
        exit(1)
    }

    if !finalResponse.ok {
        fputs("artisan: \(finalResponse.message)\n", stderr)
        exit(1)
    }
} else {
    print(response.message)
}
